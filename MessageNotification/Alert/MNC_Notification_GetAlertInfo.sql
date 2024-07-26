/*<info serverAlias="DBCRM-MessageNotification" executers="wsv_nap" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE MNC_Notification_GetAlertInfo
	@JSAlertInfo NVARCHAR(MAX) OUTPUT
AS
/*
	Created: 20231213@Roy
	Task: Get Alert info to send
	DB: DBCRM.MessageNotification
	Revisions:
		20231121@Roy: CRM - Implement Message Notifications Center for Result Amendment of Cricket(#197621)
	
	Explanation:
		Get Valid Alert to create Alert Message
	Example:
		EXEC MessageNotification.dbo.MNC_Notification_AlertSel
*/
BEGIN
	SET NOCOUNT ON
	
	/*
		Reset OUTPUT
	*/
	SELECT @JSAlertInfo = ''
	
	DECLARE @LogActionID SMALLINT
		,@LogUserID INT
		-- ,@ErrLogPrefix NVARCHAR(150)
		,@InfLogPrefix NVARCHAR(150)
		,@StsNew TINYINT
		,@StsSending TINYINT
		,@OST_ChatGroupID VARCHAR(50)
		,@777_ChatGroupID VARCHAR(50)
		,@IT_ChatGroupID VARCHAR(50)
		,@Sites777 VARCHAR(500) = ''
	
	/*
		Faced to Issues When Using Temporary Tables in Nested Stored Procedures
		
		Use Prefix #tmpGAI (GAI = GetAlertInfo) in Nested SP instead of #tmp when using temporary table
		Make sure to use a different naming convention
	*/
	
	CREATE TABLE #tmpGAIPrepareAlert (
		AlertID INT
	)
	
	CREATE TABLE #tmpGAIAlertExt (
		AlertID INT
		,MatchID INT
		,NotificationID INT
		,SettlementLogID INT
		,IsTest TINYINT
	)
	
	CREATE TABLE #tmpGAIAlertBySite (
		AlertID INT
		,TargetSite NVARCHAR(50)
		,UUSCurrency TINYINT
	)
	
	CREATE TABLE #tmpGAISendingAlert (
		AlertID INT
		,IsTest TINYINT
		,MatchID INT
		,IsNoneSaba TINYINT
		,ChatGroupID VARCHAR(50)
		,TemplateID SMALLINT
		,ValidToSendChatGroup TINYINT NOT NULL
		,RefInfo VARCHAR(50)
		,NotificationID INT
		,SessionID VARCHAR(50)
		,AlertType VARCHAR(50)
		,IgnoreReason NVARCHAR(MAX)
	)
	
	SELECT @StsNew = StatusID
	FROM NotiStatus WITH (NOLOCK)
	WHERE Status = 'New'
	
	SELECT @StsSending = StatusID
	FROM NotiStatus WITH (NOLOCK)
	WHERE Status = 'Sending'
	
	SELECT @LogActionID = ActionID
	FROM LogAction WITH (NOLOCK)
	WHERE ActName = ISNULL(OBJECT_NAME(@@PROCID),'Unknown')
	
	SELECT @LogUserID = TRY_CONVERT(INT, VValue)
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 2 --ID of StarixIT
	
	-- SELECT @ErrLogPrefix = 'Error - [AlertService - GetValid] - '
	SELECT @InfLogPrefix = 'Info - [AlertService - GetValid] - '
	
	SELECT @Sites777 = ISNULL(VValue,'')
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 16 --Separate Noti by Site
	
	-------------------HARD CODE ChatGroupID---------------------------
	SELECT @IT_ChatGroupID = 'SYS' --IT ChatGroupID
		,@OST_ChatGroupID = 'OST' --OST ChatGroupID
		,@777_ChatGroupID = '777' --777 ChatGroupID
	
	-----------------------------Start to get Alert with [RefInfo <> RuleID] and mark [Sending]-----------------	
	UPDATE a
	SET a.StatusID = @StsSending
	OUTPUT INSERTED.AlertID
	INTO #tmpGAIPrepareAlert ( AlertID ) --Get Updated AlertID
	FROM Alert AS a WITH (ROWLOCK,UPDLOCK)
	WHERE a.StatusID = @StsNew
	OPTION (RECOMPILE)
	
	INSERT INTO UserLog (
		RefID
		,ActionID
		,UserID
		,LogBef
	)
	SELECT AlertID
		,@LogActionID
		,@LogUserID
		,COMPRESS(@InfLogPrefix + 'Changed AlertID(' + ISNULL(CONVERT(VARCHAR,AlertID),'NULL')+ ') Status from [New] to [Sending]')
	FROM #tmpGAIPrepareAlert
	ORDER BY AlertID
	
	/*
		Prepare data before check valid Alert
	*/
	--------EventAlert: Result after EXEC AlertRule--------
	INSERT INTO #tmpGAISendingAlert (
		AlertID
		,ChatGroupID
		,TemplateID
		,MatchID
		-----
		,RefInfo
		,NotificationID
		,SessionID
		-----
		,AlertType
		,ValidToSendChatGroup
	)
	SELECT DISTINCT a.AlertID
		,ISNULL(TRIM(cg.value),@IT_ChatGroupID) AS ChatGroupID
		,(CASE WHEN ISNULL(TRIM(cg.value),@IT_ChatGroupID) <> @IT_ChatGroupID THEN ar.TemplateID END) --TemplateID NULL for @IT_ChatGroupID
		,ext.MatchID
		-----
		,ext.RefInfo
		,(CASE WHEN ext.RefInfo = 'NotificationID' THEN TRY_CONVERT(INT, a.RefID) END) AS NotificationID
		,(CASE WHEN ext.RefInfo = 'SessionID' THEN a.RefID ELSE ext.SessionID END) AS SessionID
		-----
		,'EventAlert' AS AlertType
		,1 AS ValidToSendChatGroup
	FROM #tmpGAIPrepareAlert AS ea
		INNER JOIN Alert AS a WITH (NOLOCK) ON a.AlertID = ea.AlertID
		LEFT JOIN AlertRule AS ar WITH (NOLOCK) ON a.RuleID = ar.RuleID
		OUTER APPLY STRING_SPLIT(ar.ChatGroupIDs,',') AS cg
		OUTER APPLY OPENJSON(a.RefExtraInfo) WITH (
				MatchID INT '$.MatchID'
				,SessionID NVARCHAR(50) '$.SessionID'
				,RefInfo VARCHAR(50) '$.RefInfo'
			) AS ext
	WHERE ISJSON(a.RefExtraInfo) = 1
		AND ext.RefInfo <> 'RuleID'
	
	--------SelfAlert: Alert by itself--------
	INSERT INTO #tmpGAISendingAlert (
		AlertID
		,ChatGroupID
		-----
		,RefInfo
		,IsTest
		-----
		,AlertType
		,ValidToSendChatGroup
	)
	SELECT DISTINCT a.AlertID
		,@IT_ChatGroupID AS ChatGroupID
		-----
		,ext.RefInfo
		,0 AS IsTest
		-----
		,'SelfAlert' AS AlertType
		,1 AS ValidToSendChatGroup
	FROM #tmpGAIPrepareAlert AS ea
		INNER JOIN Alert AS a WITH (NOLOCK) ON a.AlertID = ea.AlertID
		OUTER APPLY OPENJSON(a.RefExtraInfo) WITH (
				RefInfo VARCHAR(50) '$.RefInfo'
			) AS ext
	WHERE ISJSON(a.RefExtraInfo) = 1
		AND ext.RefInfo = 'RuleID'
	
	CREATE CLUSTERED INDEX CIX_tmpSendingAlert ON #tmpGAISendingAlert (AlertID, ChatGroupID)
	
	--Define NotificationID of SettlementLogID / SessionID Alert
	INSERT INTO #tmpGAIAlertExt (
		AlertID
		,MatchID
		,NotificationID
		,SettlementLogID
	)
	SELECT DISTINCT AlertID
		,MatchID
		,NotificationID
		,SettlementLogID
	FROM (
		SELECT a.AlertID
			,a.MatchID
			,a.NotificationID
			,nm.SettlementLogID
		FROM #tmpGAISendingAlert AS a
			LEFT JOIN NotiMapping AS nm WITH (NOLOCK) ON nm.NotificationID = a.NotificationID
		WHERE a.MatchID IS NOT NULL
			AND a.NotificationID IS NOT NULL --refer get by NotificationID

		UNION ALL

		SELECT a.AlertID
			,a.MatchID
			,nm.NotificationID
			,rs.SettlementLogID
		FROM #tmpGAISendingAlert AS a
			LEFT JOIN SettlementResultHist AS rs WITH (NOLOCK) ON a.SessionID = rs.SessionID
			LEFT JOIN NotiMapping AS nm WITH (NOLOCK) ON nm.SettlementLogID = rs.SettlementLogID
		WHERE a.MatchID IS NOT NULL
			AND a.NotificationID IS NULL --IF NotificationID NULL
			AND a.SessionID IS NOT NULL --refer get by SessionID
	) AS t
	
	/*
		UPDATE AlertExt.IsTest
	*/
	UPDATE ext
	SET ext.IsTest = rh.IsTest
	FROM #tmpGAIAlertExt AS ext
		LEFT JOIN SettlementResultHist AS rh WITH (NOLOCK) ON ext.SettlementLogID = rh.SettlementLogID
	
	CREATE CLUSTERED INDEX CIX_tmpAlertExt ON #tmpGAIAlertExt (NotificationID)
	
	/*
		UPDATE SendingAlert.NotificationID IF EXISTS
		
		=> use at MNC_Notification_AlertSel
	*/
	;WITH CTE_Noti AS (
		SELECT AlertID
			,MAX(NotificationID) AS NotificationID
		FROM #tmpGAIAlertExt
		WHERE NotificationID IS NOT NULL
		GROUP BY AlertID
	)
	UPDATE a
	SET a.NotificationID = ext.NotificationID
	FROM #tmpGAISendingAlert AS a
		INNER JOIN CTE_Noti AS ext ON a.AlertID = ext.AlertID
	WHERE a.NotificationID IS NULL
	
	/*
		UPDATE SendingAlert.IsTest
	*/
	;WITH CTE_RealSession AS (
		SELECT AlertID
			,MIN(IsTest) AS IsTest --Session only EXISTS only 1 real => real
		FROM #tmpGAIAlertExt
		GROUP BY AlertID
	)
	UPDATE a
	SET a.IsTest = ext.IsTest
	FROM #tmpGAISendingAlert AS a
		INNER JOIN CTE_RealSession AS ext ON a.AlertID = ext.AlertID
	
	/*
		UPDATE SendingAlert.IsNoneSaba
		
		For @777_ChatGroupID				=> IsNoneSaba = 1
		For OST_ChatGroupID
			- IF EIXTS NotificationID 		=> get IsNoneSaba from by NotificationID
			- IF NOT EIXTS NotificationID 	=> No need to check => default 0
	*/
	;WITH CTE_NotiSaba AS (
		SELECT ae.AlertID
			,MAX(TRY_CONVERT(TINYINT,nex.IsNoneSaba)) AS IsNoneSaba --If EXISTS NotificationID, get IsNoneSaba
		FROM #tmpGAIAlertExt AS ae
			LEFT JOIN NotificationExtra AS ne WITH (NOLOCK) ON ae.NotificationID = ne.NotificationID
			OUTER APPLY OPENJSON(ne.ExtraInfo) WITH (
				IsNoneSaba BIT '$.IsNoneSaba'
			) AS nex --OPENJSON case-sensitive
		WHERE ISJSON(ne.ExtraInfo) = 1
		GROUP BY ae.AlertID
	)
	UPDATE a
	SET a.IsNoneSaba = (
		CASE WHEN a.ChatGroupID = @777_ChatGroupID THEN 1
			WHEN a.ChatGroupID = @OST_ChatGroupID THEN ISNULL(n.IsNoneSaba,0)
			ELSE 0 END --default
		) --Just check EXISTS any IsNoneSaba value of AlertID
	FROM #tmpGAISendingAlert AS a
		LEFT JOIN CTE_NotiSaba AS n ON a.AlertID = n.AlertID
	
	/*
		Check Alert target
			- Get all Targests of AlertID
			- Filter by ChatGroupID: for @777_ChatGroupID, only send message if EXISTS
			- Filter by Real Message: only send message if EXISTS real TargetID
	*/
	--RefInfo = 'NotificationID'
	INSERT INTO #tmpGAIAlertBySite (
		AlertID
		,TargetSite
		,UUSCurrency
	)
	SELECT DISTINCT ae.AlertID
		,nt.TargetSite
		,(CASE WHEN c.Currency = 20 THEN 1 ELSE 0 END) AS UUSCurrency
	FROM #tmpGAIAlertExt AS ae
		INNER JOIN NotificationTarget AS nt WITH (NOLOCK) ON ae.NotificationID = nt.NotificationID
		LEFT JOIN bodb02.dbo.Customer AS c WITH (NOLOCK) ON c.CustID = nt.TargetID AND c.roleid = 1 --cust
	WHERE c.currency IS NOT NULL
	
	--RefInfo = 'SessionID' / 'SettlementLogID'
	INSERT INTO #tmpGAIAlertBySite (
		AlertID
		,TargetSite
		,UUSCurrency
	)
	SELECT DISTINCT ae.AlertID
		,ag.Site AS TargetSite
		,(CASE WHEN c.Currency = 20 THEN 1 ELSE 0 END) AS UUSCurrency
	FROM #tmpGAIAlertExt AS ae
		INNER JOIN SettlementResultHist AS rh WITH (NOLOCK) ON ae.SettlementLogID = rh.SettlementLogID
		INNER JOIN SettlementResultHistDetail AS rhd WITH (NOLOCK) ON ae.SettlementLogID = rhd.SettlementLogID
		INNER JOIN bodb02.dbo.Customer AS c WITH (NOLOCK) ON rhd.CustID = c.CustID
		INNER JOIN bodb02.dbo.Customer AS ag WITH (NOLOCK) ON c.recommend = ag.CustID
	WHERE NOT EXISTS (
		SELECT 1
		FROM #tmpGAIAlertBySite AS ac
		WHERE ac.AlertID = ae.AlertID
	)
	--Follow rule create Noti - NOT create for UUS tickets of Real Match
	AND ISNULL(rhd.IsDeleted,0) <> 1
	AND (
		rh.IsTest = 1
		OR (rh.IsTest = 0 AND c.currency <> 20)
	)
	
	CREATE CLUSTERED INDEX CIX_tmpAlertByCust ON #tmpGAIAlertBySite (AlertID)
	
	/*
		Start to check valid Alert
			- SelfAlert: Alert by itself
			- EventAlert: Result after EXEC AlertRule
	*/
	-----------------Verify Alert by ChatGroupID-----------------
	UPDATE #tmpGAISendingAlert
	SET ValidToSendChatGroup = 0
		,IgnoreReason = 'Invalid ChatGroupID (' + ISNULL(ChatGroupID,'NULL') + ')'
	WHERE ISNULL(ChatGroupID,'') NOT IN (
			@OST_ChatGroupID
			,@777_ChatGroupID
			,@IT_ChatGroupID
		) --hardcode ChatGroupID
	
	-----------------EventAlert - Verify IsTest-----------------
	UPDATE #tmpGAISendingAlert
	SET ValidToSendChatGroup = 0
		,IgnoreReason = 'Can NOT define Alert for Real or Test SessionID'
	WHERE ValidToSendChatGroup = 1
		AND IsTest IS NULL
	
	-----------------Verify by @IT_ChatGroupID & Content-----------------
	UPDATE sa
	SET sa.ValidToSendChatGroup = 0
		,sa.IgnoreReason = (CASE WHEN sa.IsTest = 1 THEN 'Only send REAL to @IT_ChatGroupID' ELSE 'Alert content of IT_ChatGroupID is BLANK' END)
	FROM #tmpGAISendingAlert AS sa
		LEFT JOIN Alert AS a WITH (NOLOCK) ON sa.AlertID = a.AlertID
	WHERE sa.ValidToSendChatGroup = 1
		AND sa.ChatGroupID = @IT_ChatGroupID
		AND (
			sa.IsTest = 1 --Only send real to @IT_ChatGroupID
			OR ISNULL(TRIM(a.Content),'') = '' --content BLANK
		)
	
	-----------------EventAlert - Verify Alert by requried info-----------------
	UPDATE sa
	SET sa.ValidToSendChatGroup = 0
		,sa.IgnoreReason = ISNULL(sa.IgnoreReason + ', EventAlert - ','EventAlert - ')
			+ (CASE WHEN sa.MatchID IS NULL THEN 'Missing Alert.RefExtraInfo.MatchID'
				WHEN sa.TemplateID IS NULL THEN 'TemplateID(NULL) for User group'
				ELSE 'TemplateID(' + ISNULL(CONVERT(NVARCHAR,sa.TemplateID),'NULL') + ') NOT EXISTS in NotiTemplate' END
			)
	FROM #tmpGAISendingAlert AS sa
		LEFT JOIN NotiTemplate AS ntp WITH (NOLOCK) ON sa.TemplateID = ntp.TemplateID
	WHERE sa.ValidToSendChatGroup = 1
		AND sa.AlertType = 'EventAlert'
		AND sa.ChatGroupID <> @IT_ChatGroupID
		AND (
			sa.MatchID IS NULL
			OR sa.TemplateID IS NULL
			OR ntp.TemplateID IS NULL
		)
	
	-----------------EventAlert - Verify IsTest vs Cust-----------------
	;WITH CTE_RealCurr AS (
		SELECT AlertID
			,MAX(CASE WHEN UUSCurrency = 0 THEN 1 ELSE 0 END) AS ExistRealCust
		FROM #tmpGAIAlertBySite
		GROUP BY AlertID
	)
	UPDATE sa
	SET sa.ValidToSendChatGroup = 0 --have NO cust of AlertID
		,sa.IgnoreReason = 'Real Session but NOT EXISTS Valid Target'
	FROM #tmpGAISendingAlert AS sa
		LEFT JOIN CTE_RealCurr AS c ON sa.AlertID = c.AlertID
	WHERE sa.ValidToSendChatGroup = 1
		AND sa.AlertType = 'EventAlert'
		AND sa.ChatGroupID <> @IT_ChatGroupID
		AND sa.IsTest = 0
		AND ISNULL(c.ExistRealCust,0) = 0 --IsTest = 0 BUT [have NO cust] OR [NOT Exist Real Cust]
	
	-----------------EventAlert - Verify message by ChatGroupID vs TargetSite-----------------
	;WITH CTE_ChatGroupFilter AS (
		SELECT ac.AlertID
			,MAX(CASE WHEN sep.value IS NULL THEN 1 ELSE 0 END) AS ExistOST
			,MAX(CASE WHEN sep.value IS NOT NULL THEN 1 ELSE 0 END) AS Exist777
		FROM #tmpGAIAlertBySite AS ac
			LEFT JOIN STRING_SPLIT(@Sites777, ',') AS sep ON ac.TargetSite = TRIM(sep.value)
		GROUP BY ac.AlertID
	)
	UPDATE a
	SET a.ValidToSendChatGroup = 0
		,a.IgnoreReason = 'EventAlert send to ChatGroupID(' + ISNULL(a.ChatGroupID,'NULL') + ') but [NOT EXISTS Valid Target Site] OR [All UUS]'
	FROM #tmpGAISendingAlert AS a
		LEFT JOIN CTE_ChatGroupFilter AS g ON a.AlertID = g.AlertID
	WHERE a.ValidToSendChatGroup = 1
		AND a.AlertType = 'EventAlert'
		AND a.ChatGroupID <> @IT_ChatGroupID
		AND (CASE WHEN a.ChatGroupID = @OST_ChatGroupID AND g.ExistOST = 1 THEN 1 --Exists TargetSite NOT 777
				WHEN a.ChatGroupID = @777_ChatGroupID AND g.Exist777 = 1 THEN 1 --Exists TargetSite 777
			ELSE 0 END) = 0
	
	---------convert data as JSON------------------
	SELECT @JSAlertInfo = CONVERT(NVARCHAR(MAX),(
							SELECT *
							FROM #tmpGAISendingAlert
							FOR JSON AUTO
						))
	
	DROP TABLE #tmpGAIPrepareAlert
	DROP TABLE #tmpGAIAlertExt
	DROP TABLE #tmpGAIAlertBySite
	DROP TABLE #tmpGAISendingAlert
END
