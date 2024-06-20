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
		,IsTest TINYINT
	)
	
	CREATE TABLE #tmpIngoredAlert (
		AlertID INT
		,ChatGroupID VARCHAR(50)
		,IgnoreLog NVARCHAR(MAX)
	)
	
	CREATE TABLE #tmpSendingAlert (
		AlertID INT
		,MatchID INT
		,IsNoneSaba TINYINT
		,RuleID INT
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
		,MatchID INT
		,MsgType VARCHAR(50)
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
	
	SELECT @ErrLogPrefix = 'Error - Alert - '
	SELECT @InfLogPrefix = 'Info - Alert - '
	
	SELECT @Sites777 = ISNULL(VValue,'')
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 16 --Separate Noti by Site
	
	-------------------HARD CODE ChatGroupID---------------------------
	SELECT @OST_ChatGroupID = TRIM(VValue)
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 14 --OST ChatGroupID
	
	SELECT @777_ChatGroupID = TRIM(VValue)
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 15 --777 ChatGroupID
	
	SELECT @IT_ChatGroupID = ISNULL((SELECT TRIM(VValue) FROM SystemSetting WITH (NOLOCK) WHERE VID = 12),'') --IT ChatGroupID
	
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
	
	--Get SystemAlert
	INSERT INTO #tmpPrepareSystemAlert(
		AlertID
		,InvalidSend
	)
	SELECT DISTINCT ea.AlertID
		,(CASE WHEN ISNULL(TRIM(a.Content),'') = '' THEN 'Alert content(BLANK)'
			WHEN @IT_ChatGroupID = '' THEN 'Configuration [IT ChatGroupID](BLANK)' END) AS InvalidSend
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
	
	INSERT INTO UserLog (
		RefID
		,ActionID
		,UserID
		,LogBef
	)
	SELECT AlertID
		,@LogActionID
		,@LogUserID
		,COMPRESS(@InfLogPrefix + '[Send Alert process - Prepare] - Changed System AlertID(' + ISNULL(CONVERT(VARCHAR,AlertID),'NULL')+ ') Status from [New] to [Sending]')
	FROM #tmpPrepareSystemAlert
	ORDER BY AlertID
	
	--------Get Event Alert--------
	DELETE ev
	FROM #tmpPrepareEventAlert AS ev
		INNER JOIN #tmpPrepareSystemAlert AS s ON ev.AlertID = s.AlertID
	
	CREATE UNIQUE CLUSTERED INDEX CIX_tmpPrepareEventAlert ON #tmpPrepareEventAlert (AlertID)
	
	--write log
	INSERT INTO UserLog (
		RefID
		,ActionID
		,UserID
		,LogBef
	)
	SELECT AlertID
		,@LogActionID
		,@LogUserID
		,COMPRESS(@InfLogPrefix + '[Send Alert process - Prepare] - Changed AlertID(' + ISNULL(CONVERT(VARCHAR,AlertID),'NULL')+ ') Status from [New] to [Sending]')
	FROM #tmpPrepareEventAlert
	ORDER BY AlertID
	
	INSERT INTO #tmpSendingAlert (
		AlertID
		,RuleID
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
		,a.RuleID
		,conf.VValue AS ChatGroupID
		,(CASE WHEN conf.VValue = @777_ChatGroupID THEN 1 END) AS IsNoneSaba --by ChatGroupID
		,ar.RuleType
		,ext.MatchID
		,(CASE WHEN conf.VValue = @IT_ChatGroupID THEN a.Content ELSE tp.Template END) AS Content --keep content for @IT_ChatGroupID
		,ext.RefInfo
		,(CASE WHEN ext.RefInfo = 'NotificationID' THEN TRY_CONVERT(INT, a.RefID) END) AS NotificationID
		,(CASE WHEN ext.RefInfo = 'SettlementLogID' THEN TRY_CONVERT(INT, a.RefID) END) AS SettlementLogID
		,(CASE WHEN ext.RefInfo = 'SessionID' THEN a.RefID END) AS SessionID
	FROM #tmpPrepareEventAlert AS ea
		INNER JOIN Alert AS a WITH (NOLOCK) ON a.AlertID = ea.AlertID
		INNER JOIN AlertRule AS ar WITH (NOLOCK) ON a.RuleID = ar.RuleID
		OUTER APPLY STRING_SPLIT(ar.ChatGroupIDs,',') AS cg --all things send to @IT_ChatGroupID
		LEFT JOIN SystemSetting AS conf WITH (NOLOCK) ON TRY_CONVERT(INT, TRIM(cg.value)) = conf.VID
		LEFT JOIN #tmpAlertTemplate AS tp ON ar.RuleType = tp.RuleType
		OUTER APPLY OPENJSON(a.RefExtraInfo) WITH (
				MatchID INT '$.MatchID'
				,RefInfo VARCHAR(50) '$.RefInfo'
			) AS ext
	WHERE conf.VValue IN (
			@OST_ChatGroupID
			,@777_ChatGroupID
			,@IT_ChatGroupID
		) --hardcode ChatGroupID
		AND TRIM(conf.VValue) <> ''
		AND tp.RuleType IN ('SysErr', 'NewNoti', 'PushErr') --hardcode RuleType
	
	CREATE CLUSTERED INDEX CIX_tmpSendingAlert ON #tmpSendingAlert (AlertID)
	
	-----------------Filter Alert by requried info-----------------
	UPDATE a
	SET a.ValidToSendChatGroup = 0
	FROM #tmpSendingAlert AS a
	WHERE ISNULL(TRIM(a.ChatGroupID),'') = ''
		OR a.RuleType IS NULL
		OR a.MatchID IS NULL
	
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
	SET a.IsNoneSaba = ISNULL(n.IsNoneSaba,0)
	FROM #tmpSendingAlert AS a
		LEFT JOIN CTE_NotiSaba AS n ON a.AlertID = n.AlertID
	WHERE a.IsNoneSaba IS NULL
	
	/*
		Check Alert target
			- Get all Targests of AlertID
			- Filter by Real TargetID: only send message if EXISTS real TargetID
			- Filter by Real ChatGroupID: for @777_ChatGroupID, only send message if EXISTS 
	*/
	--RefInfo = 'NotificationID'
	INSERT INTO #tmpAlertByCust (
		AlertID
		,TargetSite
		,Currency
		,IsTest
	)
	SELECT a.AlertID
		,nt.TargetSite
		,c.Currency
		,MIN(TRY_CONVERT(TINYINT,rh.IsTest)) AS IsTest
	FROM #tmpAlertExt AS a
		INNER JOIN NotificationTarget AS nt WITH (NOLOCK) ON a.NotificationID = nt.NotificationID
		LEFT JOIN bodb02.dbo.Customer AS c WITH (NOLOCK) ON c.CustID = nt.TargetID AND c.roleid = 1 --cust
		LEFT JOIN NotiMapping AS nm WITH (NOLOCK) ON a.NotificationID = nm.NotificationID
		LEFT JOIN SettlementResultHist AS rh WITH (NOLOCK) ON nm.SettlementLogID = rh.SettlementLogID
	WHERE c.currency IS NOT NULL
		AND rh.IsTest IS NOT NULL
	GROUP BY a.AlertID
		,nt.TargetSite
		,c.Currency
	
	--RefInfo = 'SessionID' / 'SettlementLogID'
	INSERT INTO #tmpAlertByCust (
		AlertID
		,TargetSite
		,Currency
		,IsTest
	)
	SELECT DISTINCT a.AlertID
		,ag.Site AS TargetSite
		,c.Currency
		,MIN(TRY_CONVERT(TINYINT,rh.IsTest)) AS IsTest
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
	GROUP BY a.AlertID
		,ag.Site
		,c.Currency
	
	CREATE CLUSTERED INDEX CIX_tmpAlertByCust ON #tmpAlertByCust (AlertID)
	
	-----------------Filter message by OST_ChatGroupID-----------------
	UPDATE a
	SET a.ValidToSendChatGroup = 1
	FROM #tmpSendingAlert AS a
	WHERE a.ValidToSendChatGroup IS NULL
		AND a.ChatGroupID = @OST_ChatGroupID
		AND EXISTS (
			SELECT 1
			FROM #tmpAlertByCust AS ac
				LEFT JOIN STRING_SPLIT(@Sites777, ',') AS sep ON ac.TargetSite = TRIM(sep.value)
			WHERE ac.AlertID = a.AlertID
				AND ac.Currency <> 20 --Cust real
				AND ac.IsTest = 0
				AND sep.value IS NULL --Exclude 777
		)
	-----------------Filter message by 777_ChatGroupID-----------------
	UPDATE a
	SET a.ValidToSendChatGroup = 1
	FROM #tmpSendingAlert AS a
	WHERE a.ValidToSendChatGroup IS NULL
		AND a.ChatGroupID = @777_ChatGroupID
		AND EXISTS (
			SELECT 1
			FROM #tmpAlertByCust AS ac
				LEFT JOIN STRING_SPLIT(@Sites777, ',') AS sep ON ac.TargetSite = TRIM(sep.value)
			WHERE ac.AlertID = a.AlertID
				AND sep.value IS NOT NULL
				AND ac.Currency <> 20 --Cust real
				AND ac.IsTest = 0
		)
	
	-----------------IT ChatGroupID can receive all message EXCLUDE testing-----------------
	UPDATE a
	SET a.ValidToSendChatGroup = 1
	FROM #tmpSendingAlert AS a
	WHERE a.ValidToSendChatGroup IS NULL
		AND a.ChatGroupID = @IT_ChatGroupID
		AND EXISTS (
			SELECT 1
			FROM #tmpAlertByCust AS ac
			WHERE ac.AlertID = a.AlertID
				AND ac.Currency <> 20 --Cust real
				AND ac.IsTest = 0
		)
	
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
			OR ISNULL(TRIM(a.ChatGroupID),'') = ''
			OR a.RuleType IS NULL
			OR a.MatchID IS NULL
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
	DELETE sa
	FROM #tmpSendingAlert AS sa
		INNER JOIN #tmpIngoredAlert AS ig ON sa.AlertID = ig.AlertID AND sa.ChatGroupID = ISNULL(ig.ChatGroupID,sa.ChatGroupID) --the ChatGroupID can be NULL
	
	DELETE ex
	FROM #tmpAlertExt AS ex
		LEFT JOIN #tmpSendingAlert AS sa ON ex.AlertID = sa.AlertID AND ex.MatchID = sa.MatchID
	WHERE ex.AlertID IS NULL
		
	UPDATE STATISTICS #tmpAlertExt
	UPDATE STATISTICS #tmpSendingAlert
	
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
		INNER JOIN #tmpSendingAlert AS a ON tp.RuleType = a.RuleType
	WHERE ISNULL(TRIM(rq.value),'') <> ''
	
	CREATE CLUSTERED INDEX CIX_tmpTemplateDetl ON #tmpTemplateDetl (AlertID)
	
	------------------------Build Alert content-----------------------------
	-- {MatchID},{EventDate},{KOTime},{LeagueName},{HomeName},{AwayName},{NotificationID}
	UPDATE tp
	SET tp.Content = CONVERT(NVARCHAR,ev.MatchID)
	FROM #tmpTemplateDetl AS tp
		INNER JOIN #tmpSendingAlert AS a ON tp.AlertID = a.AlertID AND tp.ChatGroupID = a.ChatGroupID
		INNER JOIN #tmpEventInfo AS ev ON a.MatchID = ev.MatchID
	WHERE tp.RequiredParam = '{MatchID}'
	
	UPDATE tp
	SET tp.Content = FORMAT(ev.EventDate, 'MMM dd, yyyy') --GMT-4
	FROM #tmpTemplateDetl AS tp
		INNER JOIN #tmpSendingAlert AS a ON tp.AlertID = a.AlertID AND tp.ChatGroupID = a.ChatGroupID
		INNER JOIN #tmpEventInfo AS ev ON a.MatchID = ev.MatchID
	WHERE tp.RequiredParam = '{EventDate}'
	
	UPDATE tp
	SET tp.Content = FORMAT(DATEADD(HH, 12, ev.KOTime),'MMM dd, yyyy hh:mm tt') --KOTime GMT+8
	FROM #tmpTemplateDetl AS tp
		INNER JOIN #tmpSendingAlert AS a ON tp.AlertID = a.AlertID AND tp.ChatGroupID = a.ChatGroupID
		INNER JOIN #tmpEventInfo AS ev ON a.MatchID = ev.MatchID
	WHERE tp.RequiredParam = '{KOTime}'
	
	UPDATE tp
	SET tp.Content = CASE WHEN a.IsNoneSaba = 1 THEN ev.LeagueName_NoneSaba ELSE ev.LeagueName END
	FROM #tmpTemplateDetl AS tp
		INNER JOIN #tmpSendingAlert AS a ON tp.AlertID = a.AlertID AND tp.ChatGroupID = a.ChatGroupID
		INNER JOIN #tmpEventInfo AS ev ON a.MatchID = ev.MatchID
	WHERE tp.RequiredParam = '{LeagueName}'
	
	UPDATE tp
	SET tp.Content = ev.HomeName
	FROM #tmpTemplateDetl AS tp
		INNER JOIN #tmpSendingAlert AS a ON tp.AlertID = a.AlertID AND tp.ChatGroupID = a.ChatGroupID
		INNER JOIN #tmpEventInfo AS ev ON a.MatchID = ev.MatchID
	WHERE tp.RequiredParam = '{HomeName}'
	
	UPDATE tp
	SET tp.Content = ev.AwayName
	FROM #tmpTemplateDetl AS tp
		INNER JOIN #tmpSendingAlert AS a ON tp.AlertID = a.AlertID AND tp.ChatGroupID = a.ChatGroupID
		INNER JOIN #tmpEventInfo AS ev ON a.MatchID = ev.MatchID
	WHERE tp.RequiredParam = '{AwayName}'
	
	UPDATE tp
	SET tp.Content = CONVERT(NVARCHAR,a.NotificationID)
	FROM #tmpTemplateDetl AS tp
		INNER JOIN #tmpSendingAlert AS a ON tp.AlertID = a.AlertID AND tp.ChatGroupID = a.ChatGroupID AND a.RefInfo = 'NotificationID'
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
			INNER JOIN #tmpTemplateDetl AS tpd ON a.AlertID = tpd.AlertID AND a.ChatGroupID = tpd.ChatGroupID
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
	DELETE sa
	FROM #tmpSendingAlert AS sa
		INNER JOIN #tmpIngoredAlert AS ig ON sa.AlertID = ig.AlertID AND sa.ChatGroupID = ISNULL(ig.ChatGroupID,sa.ChatGroupID) --the ChatGroupID can be NULL
	
	/*****************************************
		Build the result set
	*******************************************/
	;WITH CTE_Alert AS (
		SELECT AlertID
			,ChatGroupID
			,MatchID
			,RuleType AS MsgType
			,Content
		FROM #tmpSendingAlert AS a
		
		UNION ALL
		
		SELECT a.AlertID
			,@IT_ChatGroupID AS ChatGroupID
			,ext.MatchID
			,ar.RuleType AS MsgType
			,ac.Content
		FROM #tmpPrepareSystemAlert AS a
			INNER JOIN Alert AS ac WITH (NOLOCK) ON a.AlertID = ac.AlertID
			INNER JOIN AlertRule AS ar WITH (NOLOCK) ON ac.RuleID = ar.RuleID
			OUTER APPLY OPENJSON(ac.RefExtraInfo) WITH (
					MatchID INT '$.MatchID'
				) AS ext
		WHERE ac.StatusID = @StsSending
	)
	INSERT INTO #tmpResultSet (
		AlertID
		,ChatGroupID
		,MatchID
		,MsgType
		,Content
	)
	SELECT DISTINCT AlertID
		,ChatGroupID
		,MatchID
		,MsgType
		,Content
	FROM CTE_Alert
	
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
		,MatchID
		,MsgType
		,Content
	FROM #tmpResultSet
	ORDER BY ChatGroupID
		,MsgType
	
	-------------------------------write log-------------------------------
	;WITH CTE_SentAlert AS (
		SELECT AlertID
			,STRING_AGG(CONVERT(NVARCHAR(MAX),(CASE WHEN ChatGroupID = @OST_ChatGroupID THEN 'OST' WHEN ChatGroupID = @777_ChatGroupID THEN '777' ELSE 'IT' END)),', ') AS ChatGroupIDs
			,CONVERT(NVARCHAR(MAX),(
					SELECT DISTINCT t.ChatGroupID
						,t.Content
						,t.MatchID
						,t.RuleType AS MsgType
						,ISNULL(t.ValidToSendChatGroup,0) AS ValidToSendChatGroup
					FROM #tmpSendingAlert AS t
					WHERE t.AlertID = s.AlertID
					FOR JSON PATH
				)) AS SentContent
		FROM #tmpResultSet AS s
		GROUP BY AlertID
	)
	,CTE_IgnoreAlert AS (
		SELECT s.AlertID
			,STRING_AGG(CONVERT(NVARCHAR(MAX),(CASE WHEN ig.ChatGroupID = @OST_ChatGroupID THEN 'OST' WHEN ig.ChatGroupID = @777_ChatGroupID THEN '777' ELSE 'IT' END)),', ') AS ChatGroupIDs
			,CONVERT(NVARCHAR(MAX),(
				SELECT STRING_AGG(CONVERT(NVARCHAR(MAX),(CASE WHEN ChatGroupID = @OST_ChatGroupID THEN 'OST' WHEN ChatGroupID = @777_ChatGroupID THEN '777' ELSE 'IT' END)),', ') AS ChatGroupIDs
					,t.IgnoreLog
				FROM #tmpIngoredAlert AS t
				WHERE t.AlertID = s.AlertID
				GROUP BY t.IgnoreLog
				FOR JSON PATH
			)) AS IngoreLog
		FROM #tmpResultSet AS s
			INNER JOIN #tmpIngoredAlert AS ig ON s.AlertID = ig.AlertID
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
		,COMPRESS(@InfLogPrefix + '[Send Alert process - Completed] - Changed AlertID(' + ISNULL(CONVERT(VARCHAR,a.AlertID),'NULL')+ ') Status from [Sending] to [Sent]'
						+ ' - Sent ChatGroupIDs(' + ISNULL(sa.ChatGroupIDs,'NULL')+ ')'
						+ ISNULL(' - Ignore ChatGroupIDs(' + ia.ChatGroupIDs + ')' , '')
						+ ISNULL(' - Ignore Log(' + ia.IngoreLog + ')' , ''))
		,COMPRESS(N'Sent Content(' + ISNULL(sa.SentContent,'Refer Alert.Content')+ ')')
	FROM #tmpResultSet AS a
		LEFT JOIN CTE_SentAlert AS sa ON a.AlertID = sa.AlertID
		LEFT JOIN CTE_IgnoreAlert AS ia ON a.AlertID = ia.AlertID
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
			,STRING_AGG(CONVERT(NVARCHAR(MAX),(CASE WHEN ChatGroupID = @OST_ChatGroupID THEN 'OST' WHEN ChatGroupID = @777_ChatGroupID THEN '777' ELSE 'IT' END)),', ') AS ChatGroupIDs
			,CONVERT(NVARCHAR(MAX),(
				SELECT STRING_AGG(CONVERT(NVARCHAR(MAX),(CASE WHEN ChatGroupID = @OST_ChatGroupID THEN 'OST' WHEN ChatGroupID = @777_ChatGroupID THEN '777' ELSE 'IT' END)),', ') AS ChatGroupIDs
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
		,COMPRESS(@InfLogPrefix + '[Send Alert process - Completed] - Changed AlertID(' + ISNULL(CONVERT(VARCHAR,ig.AlertID),'NULL')+ ') Status from [Sending] to [Ignore]'
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
