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
	
	DECLARE @LogActionID TINYINT
		,@LogUserID INT
		,@ErrLogPrefix NVARCHAR(150) = ''
		,@InfLogPrefix NVARCHAR(150) = ''
		,@StsNew TINYINT
		,@StsSending TINYINT
		,@StsFailedSend TINYINT
		,@StsSucceedSend TINYINT
		,@OST_ChatGroupID VARCHAR(50)
		,@777_ChatGroupID VARCHAR(50)
		,@IT_ChatGroupID VARCHAR(50)
		,@SabaLeagueGroup VARCHAR(500) = '42,74,108,113,122,151,215'
	
	CREATE TABLE #tmpPrepareEventAlert (
		AlertID INT
	)

	CREATE TABLE #tmpPrepareSystemAlert (
		AlertID INT
	)
	
	CREATE TABLE #tmpMatchBySession (
		MatchID INT
		,SessionID VARCHAR(50)
	)
	
	CREATE TABLE #tmpAlertByCust (
		AlertID INT
		,TargetID INT
		,TargetSite NVARCHAR(50)
		,Currency INT
		,IsTest BIT
	)
	
	CREATE TABLE #tmpFailedAlert (
		AlertID INT
		,InvalidType TINYINT
	)
	
	CREATE TABLE #tmpSendingAlert (
		AlertID INT
		,MatchID INT
		,RuleID INT
		,RefID VARCHAR(50)
		,RefExtraInfo NVARCHAR(MAX)
		,ChatGroupID VARCHAR(50)
		,RuleType VARCHAR(50)
		,Content NVARCHAR(MAX)
		,ValidToSendChatGroup TINYINT
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
		,LeagueName_Saba NVARCHAR(500)
		,HomeName NVARCHAR(100)
		,AwayName NVARCHAR(100)
	)
	
	SELECT @StsNew = StatusID
	FROM NotiStatus WITH (NOLOCK)
	WHERE Status = 'New'
	
	SELECT @StsSending = StatusID
	FROM NotiStatus WITH (NOLOCK)
	WHERE Status = 'Sending'
	
	SELECT @StsFailedSend = StatusID
	FROM NotiStatus WITH (NOLOCK)
	WHERE Status = 'Failed to Send'
	
	SELECT @StsSucceedSend = StatusID
	FROM NotiStatus WITH (NOLOCK)
	WHERE Status = 'Sent'
	
	SELECT @LogActionID = ActionID
	FROM LogAction WITH (NOLOCK)
	WHERE ActName = ISNULL(OBJECT_NAME(@@PROCID),'Unknown')
	
	SELECT @LogUserID = TRY_CONVERT(INT, VValue)
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 2 --ID of StarixIT
	
	SELECT @ErrLogPrefix = 'Error - '
	SELECT @InfLogPrefix = 'Info - '
	
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
Match: {HomeName} -vs- {AwayName}{Refer AlertID}

Due to an error, the system could not create the new notification. Please pay attention and contact the IT team for further details. Thank you!'
			,N'{MatchID},{EventDate},{KOTime},{LeagueName},{HomeName},{AwayName},{Refer AlertID}'
		)
		,(
			'NewNoti'
			,N'MatchID: {MatchID}
Event Date: {EventDate}
Event Time: {KOTime}
League: {LeagueName}
Match: {HomeName} -vs- {AwayName}{Refer AlertID}

Notification ID: {NotificationID}
Status: NEW'
			,N'{MatchID},{EventDate},{KOTime},{LeagueName},{HomeName},{AwayName},{NotificationID},{Refer AlertID}'
		)
		,(
			'PushErr'
			,N'MatchID: {MatchID}
Event Date: {EventDate}
Event Time: {KOTime}
League: {LeagueName}
Match: {HomeName} -vs- {AwayName}{Refer AlertID}

Notification ID: {NotificationID}
Status: FAILED'
			,N'{MatchID},{EventDate},{KOTime},{LeagueName},{HomeName},{AwayName},{NotificationID},{Refer AlertID}'
		)
	
	-----------------------------Start to get Alert with [RefInfo <> RuleID] and mark [Sending]-----------------
	UPDATE a
	SET a.StatusID = @StsSending
	OUTPUT INSERTED.AlertID
	INTO #tmpPrepareEventAlert ( AlertID ) --Get Updated AlertID
	FROM Alert AS a WITH (ROWLOCK,UPDLOCK)
		OUTER APPLY OPENJSON(a.RefExtraInfo) WITH (
				RefInfo VARCHAR(50) '$.RefInfo'
			) AS ext --OPENJSON case-sensitive
	WHERE a.StatusID = @StsNew
		AND ext.RefInfo <> 'RuleID'
	
	CREATE CLUSTERED INDEX CIX_tmpPrepareEventAlert ON #tmpPrepareEventAlert (AlertID)
	
	--write log
	INSERT INTO [Log] (
		RefID
		,ActionID
		,UserID
		,LogBef
	)
	SELECT AlertID
		,@LogActionID
		,@LogUserID
		,@InfLogPrefix + '[Send Alert process - Prepare] - Changed AlertID(' + ISNULL(CONVERT(VARCHAR,AlertID),'NULL')+ ') Status from [New] to [Sending]'
	FROM #tmpPrepareEventAlert
	ORDER BY AlertID
	
	INSERT INTO #tmpSendingAlert (
		AlertID
		,RuleID
		,RefID
		,RefExtraInfo
		,ChatGroupID
		,RuleType
		,MatchID
		,Content
	)
	SELECT DISTINCT a.AlertID
		,a.RuleID
		,a.RefID
		,a.RefExtraInfo
		,conf.VValue --ChatGroupID
		,ar.RuleType
		,ext.MatchID
		,tp.Template
	FROM #tmpPrepareEventAlert AS ea
		INNER JOIN Alert AS a WITH (NOLOCK) ON a.AlertID = ea.AlertID
		INNER JOIN AlertRule AS ar WITH (NOLOCK) ON a.RuleID = ar.RuleID
		OUTER APPLY STRING_SPLIT(ar.ChatGroupIDs,',') AS cg --all things send to @IT_ChatGroupID
		LEFT JOIN SystemSetting AS conf WITH (NOLOCK) ON TRY_CONVERT(INT, TRIM(cg.value)) = conf.VID
		LEFT JOIN #tmpAlertTemplate AS tp ON ar.RuleType = tp.RuleType
		OUTER APPLY OPENJSON(a.RefExtraInfo) WITH (
				MatchID INT '$.MatchID'
			) AS ext
	WHERE conf.VValue IN (
			@OST_ChatGroupID
			,@777_ChatGroupID
			,@IT_ChatGroupID
		) --hardcode ChatGroupID
		AND TRIM(conf.VValue) <> ''
		AND tp.RuleType IN ('SysErr', 'NewNoti', 'PushErr') --hardcode RuleType
	
	CREATE CLUSTERED INDEX CIX_tmpSendingAlert ON #tmpSendingAlert (AlertID)
	/*
		Check Alert target
			- Get all Targests of AlertID
			- Filter by Real TargetID: only send message if EXISTS real TargetID
			- Filter by Real ChatGroupID: for @777_ChatGroupID, only send message if EXISTS 
	*/
	--RefInfo = 'NotificationID'
	;WITH CTE_AlertByNoti AS (
		SELECT a.AlertID
			,TRY_CONVERT(INT, a.RefID) AS NotificationID
		FROM #tmpSendingAlert AS a
			OUTER APPLY OPENJSON(a.RefExtraInfo) WITH (
					RefInfo VARCHAR(50) '$.RefInfo'
				) AS ext --OPENJSON case-sensitive
		WHERE ext.RefInfo = 'NotificationID'
			AND TRY_CONVERT(INT, a.RefID) IS NOT NULL
	)
	INSERT INTO #tmpAlertByCust (
		AlertID
		,TargetID
		,TargetSite
		,Currency
		,IsTest
	)
	SELECT DISTINCT a.AlertID
		,nt.TargetID
		,nt.TargetSite
		,c.Currency
		,m.IsTest
	FROM CTE_AlertByNoti AS a
		INNER JOIN NotificationTarget AS nt WITH (NOLOCK) ON a.NotificationID = nt.NotificationID
		OUTER APPLY (
			SELECT c.currency
			FROM bodb02.dbo.Customer AS c WITH (NOLOCK)
			WHERE c.CustID = nt.TargetID
				AND c.roleid = 1 --cust
		) AS c
		OUTER APPLY (
			SELECT MIN(CONVERT(TINYINT,rh.IsTest)) AS IsTest--exists real match?
			FROM NotiMapping AS nm WITH (NOLOCK)
				INNER JOIN SettlementResultHist AS rh WITH (NOLOCK) ON nm.SettlementLogID = rh.SettlementLogID
			WHERE nm.NotificationID = a.NotificationID
		) AS m
	WHERE c.currency IS NOT NULL
		AND m.IsTest IS NOT NULL
	
	--RefInfo = 'SessionID' / 'SettlementLogID'
	;WITH CTE_AlertBySettlID AS (
		SELECT a.AlertID
			,rh.IsTest
			,rh.SettlementLogID
		FROM #tmpSendingAlert AS a
			OUTER APPLY OPENJSON(a.RefExtraInfo) WITH (
					RefInfo VARCHAR(50) '$.RefInfo'
				) AS ext --OPENJSON case-sensitive
			LEFT JOIN SettlementResultHist AS rh WITH (NOLOCK) ON ext.RefInfo = 'SettlementLogID' AND TRY_CONVERT(INT, a.RefID) = rh.SettlementLogID
		WHERE rh.SettlementLogID IS NOT NULL
		
		UNION ALL
		
		SELECT a.AlertID
			,rs.IsTest
			,rs.SettlementLogID
		FROM #tmpSendingAlert AS a
			OUTER APPLY OPENJSON(a.RefExtraInfo) WITH (
					RefInfo VARCHAR(50) '$.RefInfo'
				) AS ext --OPENJSON case-sensitive
			LEFT JOIN SettlementResultHist AS rs WITH (NOLOCK) ON ext.RefInfo = 'SessionID' AND a.RefID = rs.SessionID
		WHERE rs.SettlementLogID IS NOT NULL
	)
	INSERT INTO #tmpAlertByCust (
		AlertID
		,TargetID
		,TargetSite
		,Currency
		,IsTest
	)
	SELECT DISTINCT a.AlertID
		,rhd.CustID AS TargetID
		,ag.Site AS TargetSite
		,c.Currency
		,a.IsTest
	FROM CTE_AlertBySettlID AS a
		INNER JOIN SettlementResultHistDetail AS rhd WITH (NOLOCK) ON a.SettlementLogID = rhd.SettlementLogID
		INNER JOIN bodb02.dbo.Customer AS c WITH (NOLOCK) ON rhd.CustID = c.CustID
		INNER JOIN bodb02.dbo.Customer AS ag WITH (NOLOCK) ON c.recommend = ag.CustID
	WHERE NOT EXISTS (
		SELECT 1
		FROM #tmpAlertByCust AS ac
		WHERE ac.AlertID = a.AlertID
	)
	
	CREATE CLUSTERED INDEX CIX_tmpAlertByCust ON #tmpAlertByCust (AlertID)
	-----------------Filter message by OST_ChatGroupID-----------------
	UPDATE a
	SET a.ValidToSendChatGroup = 1
	FROM #tmpSendingAlert AS a
	WHERE a.ChatGroupID = @OST_ChatGroupID
		AND EXISTS (
			SELECT 1
			FROM #tmpAlertByCust AS ac
			WHERE ac.AlertID = a.AlertID
				AND ac.Currency <> 20 --Cust real
				AND ac.IsTest = 0
		)
	-----------------Filter message by 777_ChatGroupID-----------------
	UPDATE a
	SET a.ValidToSendChatGroup = 1
	FROM #tmpSendingAlert AS a
	WHERE a.ChatGroupID = @777_ChatGroupID
		AND EXISTS (
			SELECT 1
			FROM #tmpAlertByCust AS ac
			WHERE ac.AlertID = a.AlertID
				AND ac.TargetSite = '777777'
				AND ac.Currency <> 20 --Cust real
				AND ac.IsTest = 0
		)
	-- IT ChatGroupID can receive all message include testing
	UPDATE a
	SET a.ValidToSendChatGroup = 1
	FROM #tmpSendingAlert AS a
	WHERE a.ChatGroupID = @IT_ChatGroupID
	
	-------Change Alert status---------------
	;WITH CTE_IgnoreSend AS (
		SELECT ea.AlertID
		FROM #tmpPrepareEventAlert AS ea
			LEFT JOIN #tmpSendingAlert AS a ON a.AlertID = ea.AlertID
		GROUP BY ea.AlertID
		HAVING MAX(ISNULL(a.ValidToSendChatGroup,0)) = 0
	)
	UPDATE a
	SET a.StatusID = @StsSucceedSend
	FROM Alert AS a WITH (ROWLOCK,UPDLOCK)
		INNER JOIN CTE_IgnoreSend AS ig ON a.AlertID = ig.AlertID
	WHERE a.StatusID = @StsSending
	
	--write log
	INSERT INTO [Log] (
		RefID
		,ActionID
		,UserID
		,LogBef
	)
	SELECT a.AlertID
		,@LogActionID
		,@LogUserID
		,@InfLogPrefix + '[Send Alert process - Completed] - Changed AlertID(' + ISNULL(CONVERT(VARCHAR,a.AlertID),'NULL')+ ') Status from [Sending] to [Sent] - WITHOUT send message out - (may all Target is test)'
	FROM Alert AS a WITH (NOLOCK)
		INNER JOIN #tmpPrepareEventAlert AS ea ON a.AlertID = ea.AlertID
	WHERE a.StatusID = @StsSucceedSend
	
	DELETE s
	FROM #tmpSendingAlert AS s
		INNER JOIN Alert AS a WITH (NOLOCK) ON s.AlertID = a.AlertID
	WHERE a.StatusID = @StsSucceedSend
	
	UPDATE STATISTICS #tmpSendingAlert
	------------------------Build EventInfo-----------------------------
	INSERT INTO #tmpMatchBySession (
		MatchID
		,SessionID
	)
	SELECT DISTINCT a.MatchID
		,COALESCE(rhn.SessionID, rh.SessionID, rs.SessionID) AS SessionID --follow order Msg.SessionID, SettlementLogID{SessionID}, SessionID
	FROM #tmpSendingAlert AS a
		OUTER APPLY OPENJSON(a.RefExtraInfo) WITH (
				RefInfo VARCHAR(50) '$.RefInfo'
			) AS ext --OPENJSON case-sensitive
		LEFT JOIN NotiMapping AS nm WITH (NOLOCK) ON ext.RefInfo = 'NotificationID' AND nm.NotificationID = TRY_CONVERT(INT, a.RefID)
		LEFT JOIN SettlementResultHist AS rhn WITH (NOLOCK) ON nm.SettlementLogID = rhn.SettlementLogID --Msg
		
		LEFT JOIN SettlementResultHist AS rh WITH (NOLOCK) ON ext.RefInfo = 'SettlementLogID' AND TRY_CONVERT(INT, a.RefID) = rh.SettlementLogID
		LEFT JOIN SettlementResultHist AS rs WITH (NOLOCK) ON ext.RefInfo = 'SessionID' AND a.RefID = rs.SessionID
	
	CREATE CLUSTERED INDEX CIX_tmpMatchBySession ON #tmpMatchBySession (SessionID)
	
	--Event info by Msg Noti
	INSERT INTO #tmpEventInfo (
		MatchID
		,EventDate
		,KOTime
		,LeagueName
		,LeagueName_Saba
		,HomeName
		,AwayName
	)
	SELECT DISTINCT a.MatchID
		,ne.EventDate
		,ext.KOTime
		,ext.LeagueNameEN AS LeagueName
		,ext.LeagueNameEN AS LeagueName_Saba
		,ext.HomeNameEN + ISNULL(' ' + ext.NeutralEN,'') AS HomeName
		,ext.AwayNameEN AS AwayName
	FROM #tmpMatchBySession AS a
		LEFT JOIN SettlementResultHist AS rh WITH (NOLOCK) ON a.SessionID = rh.SessionID
		LEFT JOIN NotiMapping AS nm WITH (NOLOCK) ON rh.SettlementLogID = nm.SettlementLogID
		LEFT JOIN NotificationExtra AS ne WITH (NOLOCK) ON nm.NotificationID = ne.NotificationID
		LEFT JOIN Notification AS n WITH (NOLOCK) ON ne.NotificationID = n.NotificationID
		OUTER APPLY OPENJSON(ne.ExtraInfo) WITH (
				MatchID INT '$.MatchID'
				,KOTime DATETIME '$.KOTime'
				,LeagueNameEN NVARCHAR(500) '$.LeagueNameEN'
				,HomeNameEN NVARCHAR(500) '$.HomeNameEN'
				,NeutralEN NVARCHAR(10) '$.NeutralEN'
				,AwayNameEN NVARCHAR(500) '$.AwayNameEN'
			) AS ext --OPENJSON case-sensitive
	WHERE n.NotificationType = 1 --Msg Noti
		AND ISJSON(ne.ExtraInfo) = 1
		AND ext.MatchID = a.MatchID
	
	--Event info by match table
	IF EXISTS (
		SELECT 1
		FROM #tmpSendingAlert AS a
			LEFT JOIN #tmpEventInfo AS ev ON a.MatchID = ev.MatchID
		WHERE ev.MatchID IS NULL
	)
	BEGIN
		INSERT INTO #tmpEventInfo (
			MatchID
			,EventDate
			,KOTime
			,LeagueName
			,LeagueName_Saba
			,HomeName
			,AwayName
		)
		SELECT DISTINCT a.MatchID
			,ISNULL(m.EventDate, m14.EventDate) AS EventDate
			,ISNULL(m.KickoffTime, m14.KickoffTime) AS KOTime
			,l.LeagueName AS LeagueName
			,REPLACE(l.LeagueName,'Saba','') AS LeagueName_Saba --REMOVE 'SABA'
			,th.TeamName + (CASE WHEN ISNULL(m.IsNeutral, m14.IsNeutral) = 1 THEN N' (N)' ELSE '' END) AS HomeName
			,ta.TeamName AS AwayName
		FROM #tmpSendingAlert AS a
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
	
	-----------------------------Remove Invalid--------------------------------
	INSERT INTO #tmpFailedAlert (
		AlertID
		,InvalidType
	)
	SELECT a.AlertID
		,MIN(CASE WHEN ISNULL(TRIM(a.ChatGroupID),'') = '' THEN 1
			WHEN a.RuleType IS NULL THEN 2
			WHEN a.MatchID IS NULL THEN 3
			WHEN tp.AlertID IS NULL THEN 4
			ELSE 5 END) AS InvalidType
	FROM #tmpSendingAlert AS a
		LEFT JOIN #tmpTemplateDetl AS tp ON tp.AlertID = a.AlertID AND tp.ChatGroupID = a.ChatGroupID
		LEFT JOIN #tmpEventInfo AS ev ON a.MatchID = ev.MatchID
	WHERE a.ValidToSendChatGroup = 1
		AND (
			ISNULL(TRIM(a.ChatGroupID),'') = ''
			OR a.RuleType IS NULL
			OR a.MatchID IS NULL
			OR tp.AlertID IS NULL
			OR ev.MatchID IS NULL
		)
	GROUP BY a.AlertID
	
	DELETE s
	FROM #tmpSendingAlert AS s
		INNER JOIN #tmpFailedAlert AS f ON s.AlertID = f.AlertID
	
	UPDATE STATISTICS #tmpSendingAlert
	
	--ValidToSendChatGroup = 1 but Error
	UPDATE s
	SET s.StatusID = @StsFailedSend
	FROM Alert AS s WITH (ROWLOCK,UPDLOCK)
		INNER JOIN #tmpFailedAlert AS f ON s.AlertID = f.AlertID
	WHERE s.StatusID = @StsSending
	
	--write log
	INSERT INTO [Log] (
		RefID
		,ActionID
		,UserID
		,LogBef
	)
	SELECT AlertID
		,@LogActionID
		,@LogUserID
		,@ErrLogPrefix + '[Send Alert process - Prepare] - Changed AlertID(' + ISNULL(CONVERT(VARCHAR,AlertID),'NULL')+ ') Status from [Sending] to [Failed to Send]'
					+' - Due to ' + CASE WHEN InvalidType = 1 THEN 'can NOT map ChatGroupID.'
										WHEN InvalidType = 2 THEN 'RuleType NOT EXISTS [HARDCODE] AlertTemplate.'
										WHEN InvalidType = 3 THEN 'Missing Alert.RefExtraInfo.MatchID.'
										WHEN InvalidType = 4 THEN 'S.T wrong with Template detail. (' + (ISNULL((SELECT CONVERT(NVARCHAR(MAX),(SELECT * FROM #tmpTemplateDetl FOR JSON PATH))),'NO ROW')) + ')'
										ELSE 'can NOT retrieve MatchID info.' END
	FROM #tmpFailedAlert
	ORDER BY AlertID
	
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
	SET tp.Content = CONVERT(VARCHAR, DATEADD(HH, 12, ev.KOTime), 25) --KOTime GMT+8
	FROM #tmpTemplateDetl AS tp
		INNER JOIN #tmpSendingAlert AS a ON tp.AlertID = a.AlertID AND tp.ChatGroupID = a.ChatGroupID
		INNER JOIN #tmpEventInfo AS ev ON a.MatchID = ev.MatchID
	WHERE tp.RequiredParam = '{KOTime}'
	
	UPDATE tp
	SET tp.Content = CASE WHEN a.ChatGroupID = @777_ChatGroupID THEN ev.LeagueName_Saba ELSE ev.LeagueName END --saba or not based on target ChatGroupID
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
	SET tp.Content = CONVERT(NVARCHAR,a.RefID)
	FROM #tmpTemplateDetl AS tp
		INNER JOIN #tmpSendingAlert AS a ON tp.AlertID = a.AlertID AND tp.ChatGroupID = a.ChatGroupID
		OUTER APPLY OPENJSON(a.RefExtraInfo) WITH (
				RefInfo VARCHAR(50) '$.RefInfo'
			) AS ext --OPENJSON case-sensitive
	WHERE tp.RequiredParam = '{NotificationID}'
		AND ext.RefInfo = 'NotificationID'
	
	--add more info into IT ChatGroupID
	UPDATE tp
	SET tp.Content = CASE WHEN a.ChatGroupID = @IT_ChatGroupID THEN '
Refer AlertID: ' + ISNULL(CONVERT(VARCHAR,tp.AlertID),'NULL') ELSE '' END --add Refer AlertID for IT Check
	FROM #tmpTemplateDetl AS tp
		INNER JOIN #tmpSendingAlert AS a ON tp.AlertID = a.AlertID AND tp.ChatGroupID = a.ChatGroupID
		INNER JOIN #tmpEventInfo AS ev ON a.MatchID = ev.MatchID
	WHERE tp.RequiredParam = '{Refer AlertID}'
	
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
	
	-----------------------------Start to get Alert with [RefInfo RuleID] and mark [Sending]-----------------
	UPDATE a
	SET a.StatusID = @StsSending
	OUTPUT INSERTED.AlertID
	INTO #tmpPrepareSystemAlert ( AlertID ) --Get Updated AlertID
	FROM Alert AS a WITH (ROWLOCK,UPDLOCK)
		OUTER APPLY OPENJSON(a.RefExtraInfo) WITH (
				RefInfo VARCHAR(50) '$.RefInfo'
			) AS ext --OPENJSON case-sensitive
	WHERE a.StatusID = @StsNew
		AND ext.RefInfo = 'RuleID'
		AND ISNULL(TRIM(a.Content),'') <> ''
		AND @IT_ChatGroupID <> ''
	CREATE CLUSTERED INDEX CIX_tmpPrepareSystemAlert ON #tmpPrepareSystemAlert(AlertID)
	
	--write log
	INSERT INTO [Log] (
		RefID
		,ActionID
		,UserID
		,LogBef
	)
	SELECT AlertID
		,@LogActionID
		,@LogUserID
		,@InfLogPrefix + '[Send Alert process - Prepare] - Changed System AlertID(' + ISNULL(CONVERT(VARCHAR,AlertID),'NULL')+ ') Status from [New] to [Sending]'
	FROM #tmpPrepareSystemAlert
	ORDER BY AlertID
	
	--------Change status----------
	UPDATE a
	SET a.StatusID = @StsSucceedSend
	FROM Alert AS a WITH (ROWLOCK,UPDLOCK)
		INNER JOIN #tmpPrepareSystemAlert AS sa ON a.AlertID = sa.AlertID
	WHERE a.StatusID = @StsSending
	
	UPDATE a
	SET a.StatusID = @StsSucceedSend
	FROM Alert AS a WITH (ROWLOCK,UPDLOCK)
		INNER JOIN #tmpSendingAlert AS ea ON a.AlertID = ea.AlertID
	WHERE a.StatusID = @StsSending
	
	--write log
	;WITH CTE_SendingAlert AS (
		SELECT DISTINCT AlertID
		FROM (
			SELECT AlertID
			FROM #tmpSendingAlert
		
			UNION ALL
			
			SELECT AlertID
			FROM #tmpPrepareSystemAlert
		) AS a
	)
	INSERT INTO [Log] (
		RefID
		,ActionID
		,UserID
		,LogBef
	)
	SELECT a.AlertID
		,@LogActionID
		,@LogUserID
		,@InfLogPrefix + '[Send Alert process - Completed] - Changed AlertID(' + ISNULL(CONVERT(VARCHAR,a.AlertID),'NULL')+ ') Status from [Sending] to [Sent]'
	FROM Alert AS a WITH (NOLOCK)
		INNER JOIN CTE_SendingAlert AS ea ON a.AlertID = ea.AlertID
	ORDER BY a.AlertID
	
	---------Return---------
	;WITH CTE_Alert AS (
		SELECT ChatGroupID
			,MatchID
			,RuleType AS MsgType
			,Content
		FROM #tmpSendingAlert AS a
		WHERE (a.ChatGroupID <> @IT_ChatGroupID AND a.ValidToSendChatGroup = 1)
			OR (a.ChatGroupID = @IT_ChatGroupID)
		
		UNION ALL
		
		SELECT @IT_ChatGroupID AS ChatGroupID
			,ext.MatchID
			,ar.RuleType AS MsgType
			,ac.Content
		FROM #tmpPrepareSystemAlert AS a
			INNER JOIN Alert AS ac WITH (NOLOCK) ON a.AlertID = ac.AlertID
			INNER JOIN AlertRule AS ar WITH (NOLOCK) ON ac.RuleID = ar.RuleID
			OUTER APPLY OPENJSON(ac.RefExtraInfo) WITH (
					MatchID INT '$.MatchID'
				) AS ext
	)
	SELECT DISTINCT ChatGroupID
			,MatchID
			,MsgType
			,Content
	FROM CTE_Alert
	ORDER BY ChatGroupID
		,MsgType
	
	DROP TABLE #tmpPrepareEventAlert
	DROP TABLE #tmpPrepareSystemAlert
	DROP TABLE #tmpMatchBySession
	DROP TABLE #tmpAlertByCust
	DROP TABLE #tmpFailedAlert
	DROP TABLE #tmpSendingAlert
	DROP TABLE #tmpAlertTemplate
	DROP TABLE #tmpTemplateDetl
	DROP TABLE #tmpEventInfo
END
