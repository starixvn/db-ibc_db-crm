/*<info serverAlias="DBCRM-MessageNotification" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE MNC_Notification_AlertSel
AS
/*
	Created: 20231213@Roy
	Task: Get Alert info to send
	DB: DBCRM.MessageNotification
	Revisions:
		20231121@Roy: CRM - Implement Message Notifications Center for Result Amendment of Cricket(#197621)
	
	Explanation:
	Example:
		EXEC MessageNotification.dbo.MNC_Notification_AlertSel
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @LogActionID SMALLINT
		,@LogUserID INT
		,@ErrLogPrefix NVARCHAR(150) = ''
		,@InfLogPrefix NVARCHAR(150) = ''
		,@StsNew TINYINT
		,@StsIgnore TINYINT
		,@StsSending TINYINT
		,@StsSucceedSend TINYINT
		,@OST_ChatGroupID VARCHAR(50)
		,@777_ChatGroupID VARCHAR(50)
		,@IT_ChatGroupID VARCHAR(50)
		,@Sites777 VARCHAR(500) = ''
		,@SabaLeagueGroup VARCHAR(500) = '42,74,108,113,122,151,215'
	
	CREATE TABLE #tmpPrepareEventAlert (
		AlertID INT
	)

	CREATE TABLE #tmpPrepareSystemAlert (
		AlertID INT
		,InvalidSend TINYINT
	)
	
	CREATE TABLE #tmpAlertExt (
		AlertID INT
		,MatchID INT
		,NotificationID INT
		,SettlementLogID INT
	)
	
	CREATE TABLE #tmpAlertByCust (
		AlertID INT
		,TargetID INT
		,TargetSite NVARCHAR(50)
		,Currency INT
	)
	
	CREATE TABLE #tmpIngoredAlert (
		AlertID INT
		,ChatGroupID VARCHAR(50)
		,IgnoreLog NVARCHAR(MAX)
	)
	
	CREATE TABLE #tmpSendingAlert (
		AlertID INT
		,ExistTest TINYINT
		,ExistReal TINYINT
		,MatchID INT
		,IsNoneSaba TINYINT
		-- ,RuleID INT
		,ChatGroupID VARCHAR(50)
		,RuleType VARCHAR(50)
		,Content NVARCHAR(MAX)
		,ValidToSendChatGroup TINYINT
		,RefInfo VARCHAR(50)
		,NotificationID INT
		,SettlementLogID INT
		,SessionID VARCHAR(50)
	)
	
	CREATE TABLE #tmpResultSet (
		AlertID INT
		,ChatGroupID VARCHAR(50)
		,IsTest TINYINT
		,Content NVARCHAR(MAX)
	)
	
	CREATE TABLE #tmpAlertTemplate (
		RuleType VARCHAR(50)
		,Template NVARCHAR(MAX)
		,RequiredParams NVARCHAR(MAX)
	)
	
	CREATE TABLE #tmpTemplateDetl (
		AlertID INT
		,ChatGroupID VARCHAR(50)
		,RequiredParam VARCHAR(50)
		,Content NVARCHAR(MAX)
	)
	
	CREATE TABLE #tmpEventInfo (
		MatchID INT
		,EventDate DATE
		,KOTime DATETIME
		,LeagueName NVARCHAR(500)
		,LeagueName_NoneSaba NVARCHAR(500)
		,HomeName NVARCHAR(100)
		,AwayName NVARCHAR(100)
	)
	
	SELECT @StsNew = StatusID
	FROM NotiStatus WITH (NOLOCK)
	WHERE Status = 'New'
	
	SELECT @StsSending = StatusID
	FROM NotiStatus WITH (NOLOCK)
	WHERE Status = 'Sending'
	
	SELECT @StsSucceedSend = StatusID
	FROM NotiStatus WITH (NOLOCK)
	WHERE Status = 'Sent'
	
	SELECT @StsIgnore = StatusID
	FROM NotiStatus WITH (NOLOCK)
	WHERE Status = 'Ignore'
	
	SELECT @LogActionID = ActionID
	FROM LogAction WITH (NOLOCK)
	WHERE ActName = ISNULL(OBJECT_NAME(@@PROCID),'Unknown')
	
	SELECT @LogUserID = TRY_CONVERT(INT, VValue)
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 2 --ID of StarixIT
	
	SELECT @ErrLogPrefix = 'Error - [Send Alert process] - '
	SELECT @InfLogPrefix = 'Info - [Send Alert process] - '
	
	SELECT @Sites777 = ISNULL(VValue,'')
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 16 --Separate Noti by Site
	
	-------------------HARD CODE ChatGroupID---------------------------
	SELECT @IT_ChatGroupID = 'SYS' --IT ChatGroupID
		,@OST_ChatGroupID = 'OST' --OST ChatGroupID
		,@777_ChatGroupID = '777' --777 ChatGroupID
	
	-------------------HARD CODE Template---------------------------
	INSERT INTO #tmpAlertTemplate (
		RuleType
		,Template
		,RequiredParams
	)
	VALUES
		(
			'SysErr'
			,N'MatchID: {MatchID}
Event Date: {EventDate}
Event Time: {KOTime}
League: {LeagueName}
Match: {HomeName} -vs- {AwayName}

Due to an error, the system could not create the new notification. Please pay attention and contact the IT team for further details. Thank you!'
			,N'{MatchID},{EventDate},{KOTime},{LeagueName},{HomeName},{AwayName}'
		)
		,(
			'NewNoti'
			,N'MatchID: {MatchID}
Event Date: {EventDate}
Event Time: {KOTime}
League: {LeagueName}
Match: {HomeName} -vs- {AwayName}

Notification ID: {NotificationID}
Status: NEW'
			,N'{MatchID},{EventDate},{KOTime},{LeagueName},{HomeName},{AwayName},{NotificationID}'
		)
		,(
			'PushErr'
			,N'MatchID: {MatchID}
Event Date: {EventDate}
Event Time: {KOTime}
League: {LeagueName}
Match: {HomeName} -vs- {AwayName}

Notification ID: {NotificationID}
Status: FAILED'
			,N'{MatchID},{EventDate},{KOTime},{LeagueName},{HomeName},{AwayName},{NotificationID}'
		)
	
	-----------------------------Start to get Alert with [RefInfo <> RuleID] and mark [Sending]-----------------
	UPDATE a
	SET a.StatusID = @StsSending
	OUTPUT INSERTED.AlertID
	INTO #tmpPrepareEventAlert ( AlertID ) --Get Updated AlertID
	FROM Alert AS a WITH (ROWLOCK,UPDLOCK)
	WHERE a.StatusID = @StsNew
	
	INSERT INTO UserLog (
		RefID
		,ActionID
		,UserID
		,LogBef
	)
	SELECT AlertID
		,@LogActionID
		,@LogUserID
		,COMPRESS(@InfLogPrefix + 'Prepare - Changed AlertID(' + ISNULL(CONVERT(VARCHAR,AlertID),'NULL')+ ') Status from [New] to [Sending]')
	FROM #tmpPrepareEventAlert
	ORDER BY AlertID
	
	--Get SystemAlert
	INSERT INTO #tmpPrepareSystemAlert(
		AlertID
		,InvalidSend
	)
	SELECT DISTINCT ea.AlertID
		,(CASE WHEN ISNULL(TRIM(a.Content),'') = '' THEN 'Alert content(BLANK)'END) AS InvalidSend
	FROM #tmpPrepareEventAlert AS ea
		INNER JOIN Alert AS a WITH (NOLOCK) ON a.AlertID = ea.AlertID
		OUTER APPLY OPENJSON(a.RefExtraInfo) WITH (
				RefInfo VARCHAR(50) '$.RefInfo'
			) AS ext --OPENJSON case-sensitive
	WHERE ISJSON(a.RefExtraInfo) = 1
		AND ext.RefInfo = 'RuleID'
	
	CREATE UNIQUE CLUSTERED INDEX CIX_tmpPrepareSystemAlert ON #tmpPrepareSystemAlert( AlertID )
	
	--Add ingored alert
	INSERT INTO #tmpIngoredAlert (
		AlertID
		,ChatGroupID
		,IgnoreLog
	)
	SELECT AlertID
		,@IT_ChatGroupID AS ChatGroupID
		,InvalidSend
	FROM #tmpPrepareSystemAlert
	WHERE InvalidSend IS NOT NULL
	
	--Clean ingored alert
	DELETE sa
	FROM #tmpPrepareSystemAlert AS sa
		INNER JOIN #tmpIngoredAlert AS ig ON sa.AlertID = ig.AlertID
	
	--------Get Event Alert--------
	DELETE ev
	FROM #tmpPrepareEventAlert AS ev
		INNER JOIN #tmpPrepareSystemAlert AS s ON ev.AlertID = s.AlertID
	
	CREATE UNIQUE CLUSTERED INDEX CIX_tmpPrepareEventAlert ON #tmpPrepareEventAlert (AlertID)
	
	--------Start to build Event Alert--------
	INSERT INTO #tmpSendingAlert (
		AlertID
		-- ,RuleID
		,ChatGroupID
		,IsNoneSaba
		,RuleType
		,MatchID
		,Content
		-----
		,RefInfo
		,NotificationID
		,SettlementLogID
		,SessionID
	)
	SELECT DISTINCT a.AlertID
		,TRIM(cg.value) AS ChatGroupID
		,(CASE WHEN TRIM(cg.value) = @777_ChatGroupID THEN 1 END) AS IsNoneSaba --by ChatGroupID
		,ar.RuleType
		,ext.MatchID
		,(CASE WHEN TRIM(cg.value) = @IT_ChatGroupID THEN a.Content ELSE tp.Template END) AS Content --keep content for @IT_ChatGroupID
		,ext.RefInfo
		,(CASE WHEN ext.RefInfo = 'NotificationID' THEN TRY_CONVERT(INT, a.RefID) END) AS NotificationID
		,(CASE WHEN ext.RefInfo = 'SettlementLogID' THEN TRY_CONVERT(INT, a.RefID) END) AS SettlementLogID
		,(CASE WHEN ext.RefInfo = 'SessionID' THEN a.RefID END) AS SessionID
	FROM #tmpPrepareEventAlert AS ea
		INNER JOIN Alert AS a WITH (NOLOCK) ON a.AlertID = ea.AlertID
		INNER JOIN AlertRule AS ar WITH (NOLOCK) ON a.RuleID = ar.RuleID
		OUTER APPLY STRING_SPLIT(ar.ChatGroupIDs,',') AS cg
		LEFT JOIN #tmpAlertTemplate AS tp ON ar.RuleType = tp.RuleType
		OUTER APPLY OPENJSON(a.RefExtraInfo) WITH (
				MatchID INT '$.MatchID'
				,RefInfo VARCHAR(50) '$.RefInfo'
			) AS ext
	WHERE ISJSON(a.RefExtraInfo) = 1
		AND TRIM(cg.value) IN (
			@OST_ChatGroupID
			,@777_ChatGroupID
			,@IT_ChatGroupID
		) --hardcode ChatGroupID
		AND ISNULL(TRIM(cg.value),'') <> ''
		AND tp.RuleType IN ('SysErr', 'NewNoti', 'PushErr') --hardcode RuleType
	
	CREATE CLUSTERED INDEX CIX_tmpSendingAlert ON #tmpSendingAlert (AlertID)
	
	-----------------Filter Alert by requried info-----------------
	/*
		UPDATE ExistTest / ExistReal
	*/
	;WITH CTE_TR AS (
		SELECT a.AlertID
			,(CASE WHEN MAX(TRY_CONVERT(TINYINT,rh.IsTest)) = 1 THEN 1 ELSE 0 END) AS ExistTest
			,(CASE WHEN MIN(TRY_CONVERT(TINYINT,rh.IsTest)) = 0 THEN 1 ELSE 0 END) AS ExistReal
		FROM #tmpSendingAlert AS a
			LEFT JOIN NotiMapping AS nm WITH (NOLOCK) ON nm.NotificationID = a.NotificationID OR nm.SettlementLogID = a.SettlementLogID
			LEFT JOIN SettlementResultHist AS rh WITH (NOLOCK) ON rh.SessionID = a.SessionID OR rh.SettlementLogID = ISNULL(a.SettlementLogID,nm.SettlementLogID)
		GROUP BY a.AlertID
	)
	UPDATE a
	SET a.ExistTest = rt.ExistTest
		,a.ExistReal = rt.ExistReal
		,a.ValidToSendChatGroup = (CASE WHEN (rt.AlertID IS NULL --for ExistTest / ExistReal
											OR ISNULL(TRIM(a.ChatGroupID),'') = '' --for requried info
											OR a.RuleType IS NULL
											OR a.MatchID IS NULL
										)
									THEN 0 END)
	FROM #tmpSendingAlert AS a
		LEFT JOIN CTE_TR AS rt ON rt.AlertID = a.AlertID
	
	--Define NotificationID of SettlementLogID / SessionID Alert
	INSERT INTO #tmpAlertExt (
		AlertID
		,MatchID
		,NotificationID
		,SettlementLogID
	)
	SELECT DISTINCT a.AlertID
		,a.MatchID
		,ISNULL(a.NotificationID, nm.NotificationID)
		,ISNULL(a.SettlementLogID, rs.SettlementLogID)
	FROM #tmpSendingAlert AS a
		LEFT JOIN SettlementResultHist AS rs WITH (NOLOCK) ON a.SessionID = rs.SessionID
		LEFT JOIN NotiMapping AS nm WITH (NOLOCK) ON nm.SettlementLogID = ISNULL(a.SettlementLogID, rs.SettlementLogID)
	WHERE a.ValidToSendChatGroup IS NULL
		AND a.MatchID IS NOT NULL
	
	/*
		UPDATE IsNoneSaba
		
		Just check EXISTS any IsNoneSaba value of AlertID
	*/
	;WITH CTE_NotiSaba AS (
		SELECT ae.AlertID
			,MAX(ISNULL(TRY_CONVERT(TINYINT,nex.IsNoneSaba),0)) AS IsNoneSaba --If EXISTS NotificationID, get IsNoneSaba
		FROM #tmpAlertExt AS ae
			LEFT JOIN NotificationExtra AS ne WITH (NOLOCK) ON ae.NotificationID = ne.NotificationID
			OUTER APPLY OPENJSON(ne.ExtraInfo) WITH (
				IsNoneSaba BIT '$.IsNoneSaba'
			) AS nex --OPENJSON case-sensitive
		WHERE ISJSON(ne.ExtraInfo) = 1
		GROUP BY ae.AlertID
	)
	UPDATE a
	SET a.IsNoneSaba = ISNULL(n.IsNoneSaba,0) --Just check EXISTS any IsNoneSaba value of AlertID
	FROM #tmpSendingAlert AS a
		LEFT JOIN CTE_NotiSaba AS n ON a.AlertID = n.AlertID
	WHERE a.IsNoneSaba IS NULL
	
	/*
		Check Alert target
			- Get all Targests of AlertID
			- Filter by ChatGroupID: for @777_ChatGroupID, only send message if EXISTS
			- Filter by Real Message: only send message if EXISTS real TargetID
	*/
	--RefInfo = 'NotificationID'
	INSERT INTO #tmpAlertByCust (
		AlertID
		,TargetSite
		,Currency
	)
	SELECT DISTINCT a.AlertID
		,nt.TargetSite
		,c.Currency
	FROM #tmpAlertExt AS a
		INNER JOIN NotificationTarget AS nt WITH (NOLOCK) ON a.NotificationID = nt.NotificationID
		LEFT JOIN bodb02.dbo.Customer AS c WITH (NOLOCK) ON c.CustID = nt.TargetID AND c.roleid = 1 --cust
	WHERE c.currency IS NOT NULL
	
	--RefInfo = 'SessionID' / 'SettlementLogID'
	INSERT INTO #tmpAlertByCust (
		AlertID
		,TargetSite
		,Currency
	)
	SELECT DISTINCT a.AlertID
		,ag.Site AS TargetSite
		,c.Currency
	FROM #tmpAlertExt AS a
		INNER JOIN SettlementResultHist AS rh WITH (NOLOCK) ON a.SettlementLogID = rh.SettlementLogID
		INNER JOIN SettlementResultHistDetail AS rhd WITH (NOLOCK) ON a.SettlementLogID = rhd.SettlementLogID
		INNER JOIN bodb02.dbo.Customer AS c WITH (NOLOCK) ON rhd.CustID = c.CustID
		INNER JOIN bodb02.dbo.Customer AS ag WITH (NOLOCK) ON c.recommend = ag.CustID
	WHERE NOT EXISTS (
		SELECT 1
		FROM #tmpAlertByCust AS ac
		WHERE ac.AlertID = a.AlertID
	)
	
	CREATE CLUSTERED INDEX CIX_tmpAlertByCust ON #tmpAlertByCust (AlertID)
	
	-----------------Filter message by ChatGroupID-----------------
	;WITH CTE_ChatGroupFilter AS (
		SELECT ac.AlertID
			,MAX(CASE WHEN sep.value IS NULL THEN 1 ELSE 0 END) AS ExistOST
			,MAX(CASE WHEN sep.value IS NOT NULL THEN 1 ELSE 0 END) AS Exist777
		FROM #tmpAlertByCust AS ac
			LEFT JOIN STRING_SPLIT(@Sites777, ',') AS sep ON ac.TargetSite = TRIM(sep.value)
		GROUP BY ac.AlertID
	)
	UPDATE a
	SET a.ValidToSendChatGroup = (CASE WHEN a.ChatGroupID = @IT_ChatGroupID AND g.AlertID IS NOT NULL THEN 1 --IT_ChatGroupID can receive all message
									WHEN a.ChatGroupID = @OST_ChatGroupID AND g.ExistOST = 1 THEN 1 --Exists TargetSite NOT 777?
									WHEN a.ChatGroupID = @777_ChatGroupID AND g.Exist777 = 1 THEN 1 --Exists TargetSite 777?
									ELSE 0 END)
	FROM #tmpSendingAlert AS a
		LEFT JOIN CTE_ChatGroupFilter AS g ON a.AlertID = g.AlertID
	WHERE a.ValidToSendChatGroup IS NULL
	
	-----------------Filter message by Real Message-----------------
	;WITH CTE_RealCurr AS (
		SELECT ac.AlertID
			,MAX(CASE WHEN ac.Currency <> 20 THEN 1 ELSE 0 END) AS ExistRealCust
		FROM #tmpAlertByCust AS ac
		GROUP BY ac.AlertID
	)
	UPDATE a
	SET a.ValidToSendChatGroup = (CASE WHEN c.ExistRealCust IS NULL THEN 0 ELSE 1 END) --have NO cust of AlertID
		,a.ExistTest = (CASE WHEN c.ExistRealCust = 0 THEN 1 ELSE a.ExistTest END) --IF ExistReal = 1 BUT ExistRealCust = 0 => all Test Cust => ExistTest = 1
		,a.ExistReal = (CASE WHEN c.ExistRealCust = 0 THEN 0 ELSE a.ExistReal END) --IF ExistReal = 1 BUT ExistRealCust = 0 => all Test Cust => ExistReal = 0
	FROM #tmpSendingAlert AS a
		LEFT JOIN CTE_RealCurr AS c ON a.AlertID = c.AlertID
	WHERE a.ValidToSendChatGroup = 1
		AND a.ExistReal = 1
	
	-------Add ingored alert------------
	;WITH CTE_Error AS (
		SELECT DISTINCT AlertID
			,ChatGroupID
			,(CASE WHEN ISNULL(TRIM(a.ChatGroupID),'') = '' THEN 'can NOT map ChatGroupID.'
				WHEN a.RuleType IS NULL THEN 'RuleType NOT EXISTS [HARDCODE] AlertTemplate.'
				WHEN a.MatchID IS NULL THEN 'Missing Alert.RefExtraInfo.MatchID.'
				ELSE 'Have NO Target OR all Target is test' END) AS IgnoreLog
		FROM #tmpSendingAlert AS a
		WHERE ISNULL(a.ValidToSendChatGroup,0) = 0
	)
	INSERT INTO #tmpIngoredAlert (
		AlertID
		,ChatGroupID
		,IgnoreLog
	)
	SELECT AlertID
		,ChatGroupID
		,STRING_AGG(CONVERT(NVARCHAR(MAX),IgnoreLog), ', ') AS IgnoreLog
	FROM CTE_Error
	GROUP BY AlertID
		,ChatGroupID
	
	--Clean ingored alert
	DELETE ex
	FROM #tmpAlertExt AS ex
	WHERE NOT EXISTS (
		SELECT 1
		FROM #tmpSendingAlert AS sa
		WHERE sa.AlertID = ex.AlertID
			AND sa.MatchID = ex.MatchID
			AND sa.ValidToSendChatGroup = 1
	)
	
	UPDATE STATISTICS #tmpAlertExt
	
	------------------------Build EventInfo-----------------------------
	--Event info by NotificationID
	INSERT INTO #tmpEventInfo (
		MatchID
		,EventDate
		,KOTime
		,LeagueName
		,HomeName
		,AwayName
	)
	SELECT a.MatchID
		,ne.EventDate
		,ext.KOTime
		,MAX(ext.LeagueNameEN) AS LeagueName
		,ext.HomeNameEN + ISNULL(' ' + ext.NeutralEN,'') AS HomeName
		,ext.AwayNameEN AS AwayName
	FROM #tmpAlertExt AS a
		LEFT JOIN NotificationExtra AS ne WITH (NOLOCK) ON a.NotificationID = ne.NotificationID --current, only for Msg Noti
		OUTER APPLY OPENJSON(ne.ExtraInfo) WITH (
				MatchID INT '$.MatchID'
				,KOTime DATETIME '$.KOTime'
				,LeagueNameEN NVARCHAR(500) '$.LeagueNameEN'
				,HomeNameEN NVARCHAR(500) '$.HomeNameEN'
				,NeutralEN NVARCHAR(10) '$.NeutralEN'
				,AwayNameEN NVARCHAR(500) '$.AwayNameEN'
			) AS ext --OPENJSON case-sensitive
	WHERE ISJSON(ne.ExtraInfo) = 1
		AND ext.MatchID = a.MatchID
	GROUP BY a.MatchID
		,ne.EventDate
		,ext.KOTime
		,ext.HomeNameEN + ISNULL(' ' + ext.NeutralEN,'')
		,ext.AwayNameEN
	
	--Event info by match table
	IF EXISTS (
		SELECT 1
		FROM #tmpAlertExt AS a
			LEFT JOIN #tmpEventInfo AS ev ON a.MatchID = ev.MatchID
		WHERE ev.MatchID IS NULL
	)
	BEGIN
		INSERT INTO #tmpEventInfo (
			MatchID
			,EventDate
			,KOTime
			,LeagueName
			,HomeName
			,AwayName
		)
		SELECT DISTINCT a.MatchID
			,ISNULL(m.EventDate, m14.EventDate) AS EventDate
			,COALESCE(m.GlobalShowTime, m14.GlobalShowTime, m.kickofftime, m14.kickofftime) AS KOTime ----prefer GlobalShowTime
			,l.LeagueName AS LeagueName
			,th.TeamName + (CASE WHEN ISNULL(m.IsNeutral, m14.IsNeutral) = 1 THEN N' (N)' ELSE '' END) AS HomeName
			,ta.TeamName AS AwayName
		FROM #tmpAlertExt AS a
			LEFT JOIN bodb02.dbo.match AS m WITH (NOLOCK) ON a.MatchID = m.MatchID
			LEFT JOIN bodb02.dbo.match14 AS m14 WITH (NOLOCK) ON a.MatchID = m14.MatchID
			LEFT JOIN bodb02.dbo.team AS th WITH (NOLOCK) ON ISNULL(m.HomeID, m14.HomeID) = th.TeamID
			LEFT JOIN bodb02.dbo.team AS ta WITH (NOLOCK) ON ISNULL(m.AwayID, m14.AwayID) = ta.TeamID
			LEFT JOIN bodb02.dbo.league AS l WITH (NOLOCK) ON ISNULL(m.LeagueID, m14.LeagueID) = l.LeagueID
		WHERE l.LeagueID IS NOT NULL
			AND ISNULL(m.MatchID, m14.MatchID) IS NOT NULL
			AND th.TeamID IS NOT NULL
			AND ta.TeamID IS NOT NULL
			AND NOT EXISTS (
				SELECT 1
				FROM #tmpEventInfo AS ev
				WHERE ev.MatchID = a.MatchID
			)
	END
	
	CREATE CLUSTERED INDEX CIX_tmpEventInfo ON #tmpEventInfo (MatchID)
	
	--Make sure LeagueName_NoneSaba NOT NULL
	UPDATE #tmpEventInfo
	SET LeagueName_NoneSaba = TRIM(REPLACE(REPLACE(LeagueName,' Saba ',' '),'Saba',''))
	WHERE LeagueName_NoneSaba IS NULL
	
	------------------------Build Template detail-----------------------------
	INSERT INTO #tmpTemplateDetl (
		AlertID
		,ChatGroupID
		,RequiredParam
	)
	SELECT DISTINCT a.AlertID
		,a.ChatGroupID
		,TRIM(rq.value) AS RequiredParam
	FROM #tmpAlertTemplate AS tp
		CROSS APPLY STRING_SPLIT(tp.RequiredParams, ',') AS rq
		INNER JOIN #tmpSendingAlert AS a ON tp.RuleType = a.RuleType AND a.ValidToSendChatGroup = 1
	WHERE ISNULL(TRIM(rq.value),'') <> ''
	
	CREATE CLUSTERED INDEX CIX_tmpTemplateDetl ON #tmpTemplateDetl (AlertID)
	
	------------------------Build Alert content-----------------------------
	-- {MatchID},{EventDate},{KOTime},{LeagueName},{HomeName},{AwayName},{NotificationID}
	UPDATE tp
	SET tp.Content = CONVERT(NVARCHAR,ev.MatchID)
	FROM #tmpTemplateDetl AS tp
		INNER JOIN #tmpSendingAlert AS a ON tp.AlertID = a.AlertID AND tp.ChatGroupID = a.ChatGroupID AND a.ValidToSendChatGroup = 1
		INNER JOIN #tmpEventInfo AS ev ON a.MatchID = ev.MatchID
	WHERE tp.RequiredParam = '{MatchID}'
	
	UPDATE tp
	SET tp.Content = FORMAT(ev.EventDate, 'MMM dd, yyyy') --GMT-4
	FROM #tmpTemplateDetl AS tp
		INNER JOIN #tmpSendingAlert AS a ON tp.AlertID = a.AlertID AND tp.ChatGroupID = a.ChatGroupID AND a.ValidToSendChatGroup = 1
		INNER JOIN #tmpEventInfo AS ev ON a.MatchID = ev.MatchID
	WHERE tp.RequiredParam = '{EventDate}'
	
	UPDATE tp
	SET tp.Content = FORMAT(DATEADD(HH, 12, ev.KOTime),'MMM dd, yyyy hh:mm tt') --KOTime GMT+8
	FROM #tmpTemplateDetl AS tp
		INNER JOIN #tmpSendingAlert AS a ON tp.AlertID = a.AlertID AND tp.ChatGroupID = a.ChatGroupID AND a.ValidToSendChatGroup = 1
		INNER JOIN #tmpEventInfo AS ev ON a.MatchID = ev.MatchID
	WHERE tp.RequiredParam = '{KOTime}'
	
	UPDATE tp
	SET tp.Content = CASE WHEN a.IsNoneSaba = 1 THEN ev.LeagueName_NoneSaba ELSE ev.LeagueName END
	FROM #tmpTemplateDetl AS tp
		INNER JOIN #tmpSendingAlert AS a ON tp.AlertID = a.AlertID AND tp.ChatGroupID = a.ChatGroupID AND a.ValidToSendChatGroup = 1
		INNER JOIN #tmpEventInfo AS ev ON a.MatchID = ev.MatchID
	WHERE tp.RequiredParam = '{LeagueName}'
	
	UPDATE tp
	SET tp.Content = ev.HomeName
	FROM #tmpTemplateDetl AS tp
		INNER JOIN #tmpSendingAlert AS a ON tp.AlertID = a.AlertID AND tp.ChatGroupID = a.ChatGroupID AND a.ValidToSendChatGroup = 1
		INNER JOIN #tmpEventInfo AS ev ON a.MatchID = ev.MatchID
	WHERE tp.RequiredParam = '{HomeName}'
	
	UPDATE tp
	SET tp.Content = ev.AwayName
	FROM #tmpTemplateDetl AS tp
		INNER JOIN #tmpSendingAlert AS a ON tp.AlertID = a.AlertID AND tp.ChatGroupID = a.ChatGroupID AND a.ValidToSendChatGroup = 1
		INNER JOIN #tmpEventInfo AS ev ON a.MatchID = ev.MatchID
	WHERE tp.RequiredParam = '{AwayName}'
	
	UPDATE tp
	SET tp.Content = CONVERT(NVARCHAR,a.NotificationID)
	FROM #tmpTemplateDetl AS tp
		INNER JOIN #tmpSendingAlert AS a ON tp.AlertID = a.AlertID AND tp.ChatGroupID = a.ChatGroupID AND a.RefInfo = 'NotificationID' AND a.ValidToSendChatGroup = 1
	WHERE tp.RequiredParam = '{NotificationID}'
	
	---Replace RequiredParam into Template	
	DECLARE @iLoopParam VARCHAR(50)
	SELECT @iLoopParam = MIN(RequiredParam)
	FROM #tmpTemplateDetl
	
	WHILE EXISTS(SELECT 1 FROM #tmpTemplateDetl WHERE RequiredParam = @iLoopParam)
	BEGIN
		--Start to replace RequiredParams
		UPDATE a
		SET a.Content = REPLACE(a.Content,tpd.RequiredParam,tpd.Content)
		FROM #tmpSendingAlert AS a
			INNER JOIN #tmpTemplateDetl AS tpd ON a.AlertID = tpd.AlertID AND a.ChatGroupID = tpd.ChatGroupID AND a.ValidToSendChatGroup = 1
		WHERE tpd.RequiredParam = @iLoopParam
		
		SET @iLoopParam = (SELECT MIN(RequiredParam) FROM #tmpTemplateDetl WHERE RequiredParam > @iLoopParam )
	END
	
	-----------------------------Validate after Build Alert content--------------------------------
	;WITH CTE_ContentError AS (
		SELECT DISTINCT a.AlertID
			,a.ChatGroupID
			,'Content (BLANK) - '
			+ (CASE WHEN tp.AlertID IS NULL THEN 'S.T wrong with Template detail. (' + (ISNULL((SELECT CONVERT(NVARCHAR(MAX),(SELECT tp.* FOR JSON PATH))),'NO ROW')) + ')'
				WHEN ev.MatchID IS NULL THEN 'can NOT retrieve MatchID info.'
				WHEN (a.IsNoneSaba = 0 AND ev.LeagueName IS NULL) THEN 'can NOT retrieve LeagueName info.'
				ELSE 'can NOT retrieve LeagueName_NoneSaba info.' END) AS IgnoreLog
		FROM #tmpSendingAlert AS a
			LEFT JOIN #tmpTemplateDetl AS tp ON tp.AlertID = a.AlertID AND tp.ChatGroupID = a.ChatGroupID
			LEFT JOIN #tmpEventInfo AS ev ON a.MatchID = ev.MatchID
		WHERE a.ValidToSendChatGroup = 1
			AND ISNULL(TRIM(a.Content),'') = ''
			AND (tp.AlertID IS NULL
				OR ev.MatchID IS NULL
				OR (a.IsNoneSaba = 0 AND ev.LeagueName IS NULL)
				OR (a.IsNoneSaba = 1 AND ev.LeagueName_NoneSaba IS NULL)
			)
	)
	-------Add ingored alert------------
	INSERT INTO #tmpIngoredAlert (
		AlertID
		,ChatGroupID
		,IgnoreLog
	)
	SELECT AlertID
		,ChatGroupID
		,STRING_AGG(CONVERT(NVARCHAR(MAX),IgnoreLog), ', ') AS IgnoreLog
	FROM CTE_ContentError
	GROUP BY AlertID
		,ChatGroupID
	
	--Clean ingored alert
	UPDATE sa
	SET sa.ValidToSendChatGroup = 0
	FROM #tmpSendingAlert AS sa
		INNER JOIN #tmpIngoredAlert AS ig ON sa.AlertID = ig.AlertID AND sa.ChatGroupID = ig.ChatGroupID
	
	/*****************************************
		Build the result set
	*******************************************/
	;WITH CTE_AlertRealGrp AS (
		SELECT AlertID
			,ChatGroupID
			,Content
		FROM #tmpSendingAlert AS a
		WHERE a.ValidToSendChatGroup = 1
			AND a.ExistReal = 1
		
		UNION ALL
		
		SELECT a.AlertID
			,@IT_ChatGroupID AS ChatGroupID
			,ac.Content
		FROM #tmpPrepareSystemAlert AS a
			INNER JOIN Alert AS ac WITH (NOLOCK) ON a.AlertID = ac.AlertID
			INNER JOIN AlertRule AS ar WITH (NOLOCK) ON ac.RuleID = ar.RuleID
		WHERE ac.StatusID = @StsSending
	)
	--for real group
	INSERT INTO #tmpResultSet (
		AlertID
		,ChatGroupID
		,IsTest
		,Content
	)
	SELECT DISTINCT AlertID
		,ChatGroupID
		,0 AS IsTest
		,Content
	FROM CTE_AlertRealGrp
	
	--for Test group
	INSERT INTO #tmpResultSet (
		AlertID
		,ChatGroupID
		,IsTest
		,Content
	)
	SELECT a.AlertID
		,a.ChatGroupID
		,1 AS IsTest
		,a.Content
	FROM #tmpSendingAlert AS a
		LEFT JOIN #tmpResultSet AS rs ON a.AlertID = rs.AlertID
	WHERE a.ValidToSendChatGroup = 1
		AND a.ExistTest = 1
		AND rs.AlertID IS NULL
	
	CREATE UNIQUE CLUSTERED INDEX CIX_tmpResultSet ON #tmpResultSet (AlertID, ChatGroupID)
	
	/*
		Clean up and change Alert status
	*/
	;WITH CTE_Alert AS (
		SELECT AlertID
			,MAX(Succeed) AS Succeed
		FROM (
			SELECT AlertID
				,1 AS Succeed
			FROM #tmpResultSet
			
			UNION ALL
			
			SELECT AlertID
				,0 AS Succeed
			FROM #tmpPrepareSystemAlert
			
			UNION ALL
			
			SELECT AlertID
				,0 AS Succeed
			FROM #tmpPrepareEventAlert
			
			UNION ALL
			
			SELECT AlertID
				,0 AS Succeed
			FROM #tmpIngoredAlert
		) AS t
		GROUP BY AlertID
	)
	UPDATE a
	SET a.StatusID = (CASE WHEN rs.Succeed = 1 THEN @StsSucceedSend ELSE @StsIgnore END)
	FROM Alert AS a WITH (ROWLOCK,UPDLOCK)
		INNER JOIN CTE_Alert AS rs ON a.AlertID = rs.AlertID
	
	/*****************************************
		Return result set
	*******************************************/
	SELECT DISTINCT ChatGroupID
		,IsTest
		,Content
	FROM #tmpResultSet
	ORDER BY ChatGroupID
		,IsTest
	
	-------------------------------write log-------------------------------
	;WITH CTE_SentAlert AS (
		SELECT AlertID
			,STRING_AGG(CONVERT(NVARCHAR(MAX),ChatGroupID),', ') AS ChatGroupIDs
			,CONVERT(NVARCHAR(MAX),(
					SELECT DISTINCT t.ChatGroupID
						,t.Content
						,t.MatchID
						,t.RuleType
						,t.ExistReal
						,t.ExistTest
						,ISNULL(t.ValidToSendChatGroup,0) AS ValidToSendChatGroup
					FROM #tmpSendingAlert AS t
						INNER JOIN #tmpResultSet AS st ON t.AlertID = st.AlertID AND t.ChatGroupID = st.ChatGroupID
					WHERE st.AlertID = s.AlertID
					FOR JSON PATH
				)) AS SentContent
		FROM #tmpResultSet AS s
		GROUP BY AlertID
	)
	,CTE_IgnoreChatGroup AS (
		SELECT s.AlertID
			,STRING_AGG(CONVERT(NVARCHAR(MAX),ISNULL(s.ChatGroupID,'NULL')),', ') AS ChatGroupIDs
			,CONVERT(NVARCHAR(MAX),(
				SELECT ISNULL(t.IgnoreLog,'NULL') AS IgnoreLog
					,STRING_AGG(CONVERT(NVARCHAR(MAX),ISNULL(st.ChatGroupID, t.ChatGroupID)),', ') AS ChatGroupIDs
					,STRING_AGG(CONVERT(NVARCHAR(MAX),st.ExistTest),', ') AS ExistTest
					,STRING_AGG(CONVERT(NVARCHAR(MAX),st.ExistReal),', ') AS ExistReal
				FROM #tmpIngoredAlert AS t
					LEFT JOIN #tmpSendingAlert AS st ON t.AlertID = st.AlertID AND t.ChatGroupID = st.ChatGroupID AND st.ValidToSendChatGroup = 0
				WHERE t.AlertID = s.AlertID
				GROUP BY ISNULL(t.IgnoreLog,'NULL')
				FOR JSON PATH
			)) AS IngoreLog
		FROM #tmpIngoredAlert AS s
		GROUP BY s.AlertID
	)
	INSERT INTO UserLog (
		RefID
		,ActionID
		,UserID
		,LogBef
		,LogAft
	)
	SELECT DISTINCT a.AlertID
		,@LogActionID
		,@LogUserID
		,COMPRESS(@InfLogPrefix + 'Completed - Changed AlertID(' + ISNULL(CONVERT(VARCHAR,a.AlertID),'NULL')+ ') Status from [Sending] to [Sent]'
						+ ' - Sent ChatGroupIDs(' + ISNULL(sa.ChatGroupIDs,'NULL')+ ')'
						+ ISNULL(' - Ignore ChatGroupIDs(' + ia.ChatGroupIDs + ')' , '')
						+ ISNULL(' - Ignore Log(' + ia.IngoreLog + ')' , ''))
		,COMPRESS(N'Sent Content(' + ISNULL(sa.SentContent,'Refer Alert.Content')+ ')')
	FROM #tmpResultSet AS a
		LEFT JOIN CTE_SentAlert AS sa ON a.AlertID = sa.AlertID
		LEFT JOIN CTE_IgnoreChatGroup AS ia ON a.AlertID = ia.AlertID
	ORDER BY a.AlertID
	
	--clear @StsSucceedSend
	DELETE ig
	FROM #tmpIngoredAlert AS ig
	WHERE EXISTS (
		SELECT 1
		FROM #tmpResultSet AS rs
		WHERE rs.AlertID = ig.AlertID
	)
	
	;WITH CTE_IgnoreAlert AS (
		SELECT s.AlertID
			,STRING_AGG(CONVERT(NVARCHAR(MAX),ChatGroupID),', ') AS ChatGroupIDs
			,CONVERT(NVARCHAR(MAX),(
				SELECT STRING_AGG(CONVERT(NVARCHAR(MAX),ChatGroupID),', ') AS ChatGroupIDs
					,t.IgnoreLog
				FROM #tmpIngoredAlert AS t
				WHERE t.AlertID = s.AlertID
				GROUP BY t.IgnoreLog
				FOR JSON PATH
			)) AS IngoreLog
		FROM #tmpIngoredAlert AS s
		GROUP BY s.AlertID
	)
	INSERT INTO UserLog (
		RefID
		,ActionID
		,UserID
		,LogBef
	)
	SELECT DISTINCT ig.AlertID
		,@LogActionID
		,@LogUserID
		,COMPRESS(@InfLogPrefix + 'Completed - Changed AlertID(' + ISNULL(CONVERT(VARCHAR,ig.AlertID),'NULL')+ ') Status from [Sending] to [Ignore]'
						+ ' - Ignore ChatGroupIDs(' + ISNULL(ia.ChatGroupIDs,'NULL')+ ')'
						+ ' - Ignore Log(' + ISNULL(ia.IngoreLog,'NULL')+ ')')
	FROM #tmpIngoredAlert AS ig
		LEFT JOIN CTE_IgnoreAlert AS ia ON ig.AlertID = ia.AlertID
	ORDER BY ig.AlertID
	
	DROP TABLE #tmpPrepareEventAlert
	DROP TABLE #tmpPrepareSystemAlert
	DROP TABLE #tmpAlertExt
	DROP TABLE #tmpAlertByCust
	DROP TABLE #tmpIngoredAlert
	DROP TABLE #tmpSendingAlert
	DROP TABLE #tmpAlertTemplate
	DROP TABLE #tmpTemplateDetl
	DROP TABLE #tmpEventInfo
	DROP TABLE #tmpResultSet
END
