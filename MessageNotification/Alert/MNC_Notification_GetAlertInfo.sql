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
	
	CREATE TABLE #tmpPrepareAlert (
		AlertID INT
	)
	
	CREATE TABLE #tmpAlertExt (
		AlertID INT
		,MatchID INT
		,NotificationID INT
		,SettlementLogID INT
		,IsTest TINYINT
	)
	
	CREATE TABLE #tmpAlertBySite (
		AlertID INT
		,TargetSite NVARCHAR(50)
		,UUSCurrency TINYINT
	)
	
	CREATE TABLE #tmpSendingAlert (
		AlertID INT
		,ExistTest TINYINT
		,ExistReal TINYINT
		,MatchID INT
		,IsNoneSaba TINYINT
		,ChatGroupID VARCHAR(50)
		,TemplateID SMALLINT
		,ValidToSendChatGroup TINYINT NOT NULL
		,RefInfo VARCHAR(50)
		,NotificationID INT
		,SettlementLogID INT
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
	SELECT @JSAlertInfo = ''
	
	UPDATE a
	SET a.StatusID = @StsSending
	OUTPUT INSERTED.AlertID
	INTO #tmpPrepareAlert ( AlertID ) --Get Updated AlertID
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
	FROM #tmpPrepareAlert
	ORDER BY AlertID
	
	/*
		Prepare data before check valid Alert
	*/
	--------EventAlert: Result after EXEC AlertRule--------
	INSERT INTO #tmpSendingAlert (
		AlertID
		,ChatGroupID
		,IsNoneSaba
		,TemplateID
		,MatchID
		-----
		,RefInfo
		,NotificationID
		,SettlementLogID
		,SessionID
		-----
		,AlertType
		,ValidToSendChatGroup
	)
	SELECT DISTINCT a.AlertID
		,ISNULL(TRIM(cg.value),@IT_ChatGroupID) AS ChatGroupID
		,(CASE WHEN TRIM(cg.value) = @777_ChatGroupID THEN 1 END) AS IsNoneSaba --by ChatGroupID
		,ar.TemplateID
		,ext.MatchID
		-----
		,ext.RefInfo
		,(CASE WHEN ext.RefInfo = 'NotificationID' THEN TRY_CONVERT(INT, a.RefID) END) AS NotificationID
		,(CASE WHEN ext.RefInfo = 'SettlementLogID' THEN TRY_CONVERT(INT, a.RefID) END) AS SettlementLogID
		,(CASE WHEN ext.RefInfo = 'SessionID' THEN a.RefID END) AS SessionID
		-----
		,'EventAlert' AS AlertType
		,1 AS ValidToSendChatGroup
	FROM #tmpPrepareAlert AS ea
		INNER JOIN Alert AS a WITH (NOLOCK) ON a.AlertID = ea.AlertID
		LEFT JOIN AlertRule AS ar WITH (NOLOCK) ON a.RuleID = ar.RuleID
		OUTER APPLY STRING_SPLIT(ar.ChatGroupIDs,',') AS cg
		OUTER APPLY OPENJSON(a.RefExtraInfo) WITH (
				MatchID INT '$.MatchID'
				,RefInfo VARCHAR(50) '$.RefInfo'
			) AS ext
	WHERE ISJSON(a.RefExtraInfo) = 1
		AND ext.RefInfo <> 'RuleID'
	
	--------SelfAlert: Alert by itself--------
	INSERT INTO #tmpSendingAlert (
		AlertID
		,ChatGroupID
		-----
		,RefInfo
		,ExistTest
		,ExistReal
		-----
		,AlertType
		,ValidToSendChatGroup
	)
	SELECT DISTINCT a.AlertID
		,@IT_ChatGroupID AS ChatGroupID
		-----
		,ext.RefInfo
		,0 AS ExistTest
		,1 AS ExistReal
		-----
		,'SelfAlert' AS AlertType
		,1 AS ValidToSendChatGroup
	FROM #tmpPrepareAlert AS ea
		INNER JOIN Alert AS a WITH (NOLOCK) ON a.AlertID = ea.AlertID
		OUTER APPLY OPENJSON(a.RefExtraInfo) WITH (
				MatchID INT '$.MatchID'
				,RefInfo VARCHAR(50) '$.RefInfo'
			) AS ext
	WHERE ISJSON(a.RefExtraInfo) = 1
		AND ext.RefInfo = 'RuleID'
	
	CREATE CLUSTERED INDEX CIX_tmpSendingAlert ON #tmpSendingAlert (AlertID, ChatGroupID)
	
	--Define NotificationID of SettlementLogID / SessionID Alert
	INSERT INTO #tmpAlertExt (
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
		FROM #tmpSendingAlert AS a
			LEFT JOIN NotiMapping AS nm WITH (NOLOCK) ON nm.NotificationID = a.NotificationID
		WHERE a.MatchID IS NOT NULL
			AND a.NotificationID IS NOT NULL --refer get by NotificationID

		UNION ALL

		SELECT a.AlertID
			,a.MatchID
			,nm.NotificationID
			,a.SettlementLogID
		FROM #tmpSendingAlert AS a
			LEFT JOIN NotiMapping AS nm WITH (NOLOCK) ON nm.SettlementLogID = a.SettlementLogID
		WHERE a.MatchID IS NOT NULL
			AND a.NotificationID IS NULL --IF NotificationID NULL
			AND a.SettlementLogID IS NOT NULL --refer get by SettlementLogID

		UNION ALL

		SELECT a.AlertID
			,a.MatchID
			,nm.NotificationID
			,rs.SettlementLogID
		FROM #tmpSendingAlert AS a
			LEFT JOIN SettlementResultHist AS rs WITH (NOLOCK) ON a.SessionID = rs.SessionID
			LEFT JOIN NotiMapping AS nm WITH (NOLOCK) ON nm.SettlementLogID = rs.SettlementLogID
		WHERE a.MatchID IS NOT NULL
			AND a.NotificationID IS NULL --IF NotificationID NULL
			AND a.SettlementLogID IS NULL --IF SettlementLogID NULL
			AND a.SessionID IS NOT NULL --refer get by SessionID
	) AS t
	
	-- Get IsTest
	UPDATE ext
	SET ext.IsTest = rh.IsTest
	FROM #tmpAlertExt AS ext
		LEFT JOIN SettlementResultHist AS rh WITH (NOLOCK) ON ext.SettlementLogID = rh.SettlementLogID
	
	CREATE CLUSTERED INDEX CIX_tmpAlertExt ON #tmpAlertExt (NotificationID)
	
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
	INSERT INTO #tmpAlertBySite (
		AlertID
		,TargetSite
		,UUSCurrency
	)
	SELECT DISTINCT ae.AlertID
		,nt.TargetSite
		,(CASE WHEN c.Currency = 20 THEN 1 ELSE 0 END) AS UUSCurrency
	FROM #tmpAlertExt AS ae
		INNER JOIN NotificationTarget AS nt WITH (NOLOCK) ON ae.NotificationID = nt.NotificationID
		LEFT JOIN bodb02.dbo.Customer AS c WITH (NOLOCK) ON c.CustID = nt.TargetID AND c.roleid = 1 --cust
	WHERE c.currency IS NOT NULL
	
	--RefInfo = 'SessionID' / 'SettlementLogID'
	INSERT INTO #tmpAlertBySite (
		AlertID
		,TargetSite
		,UUSCurrency
	)
	SELECT DISTINCT ae.AlertID
		,ag.Site AS TargetSite
		,(CASE WHEN c.Currency = 20 THEN 1 ELSE 0 END) AS UUSCurrency
	FROM #tmpAlertExt AS ae
		INNER JOIN SettlementResultHist AS rh WITH (NOLOCK) ON ae.SettlementLogID = rh.SettlementLogID
		INNER JOIN SettlementResultHistDetail AS rhd WITH (NOLOCK) ON ae.SettlementLogID = rhd.SettlementLogID
		INNER JOIN bodb02.dbo.Customer AS c WITH (NOLOCK) ON rhd.CustID = c.CustID
		INNER JOIN bodb02.dbo.Customer AS ag WITH (NOLOCK) ON c.recommend = ag.CustID
	WHERE NOT EXISTS (
		SELECT 1
		FROM #tmpAlertBySite AS ac
		WHERE ac.AlertID = ae.AlertID
	)
	--Follow rule create Noti - NOT create for UUS tickets of Real Match
	AND ISNULL(rhd.IsDeleted,0) <> 1
	AND (
		rh.IsTest = 1
		OR (rh.IsTest = 0 AND c.currency <> 20)
	)
	
	CREATE CLUSTERED INDEX CIX_tmpAlertByCust ON #tmpAlertBySite (AlertID)
	
	/*
		Start to check valid Alert
			- SelfAlert: Alert by itself
			- EventAlert: Result after EXEC AlertRule
	*/
	-----------------Verify Alert by ChatGroupID-----------------
	UPDATE #tmpSendingAlert
	SET ValidToSendChatGroup = 0
		,IgnoreReason = 'Invalid ChatGroupID (' + ISNULL(ChatGroupID,'NULL') + ')'
	WHERE ISNULL(ChatGroupID,'') NOT IN (
			@OST_ChatGroupID
			,@777_ChatGroupID
			,@IT_ChatGroupID
		) --hardcode ChatGroupID
	
	-----------------Verify Alert by content-----------------
	UPDATE sa
	SET sa.ValidToSendChatGroup = 0
		,sa.IgnoreReason = ISNULL(IgnoreReason + ', ','') + 'Alert content of IT_ChatGroupID is BLANK'
	FROM #tmpSendingAlert AS sa
		LEFT JOIN Alert AS a WITH (NOLOCK) ON sa.AlertID = a.AlertID
	WHERE sa.ChatGroupID = @IT_ChatGroupID
		AND ISNULL(TRIM(a.Content),'') = ''
	
	-----------------EventAlert - Verify Alert by requried info-----------------
	UPDATE sa
	SET sa.ValidToSendChatGroup = 0
		,sa.IgnoreReason = ISNULL(sa.IgnoreReason + ', EventAlert - ','EventAlert - ')
			+ (CASE WHEN sa.MatchID IS NULL THEN 'Missing Alert.RefExtraInfo.MatchID'
				WHEN (sa.TemplateID IS NULL AND sa.ChatGroupID <> @IT_ChatGroupID) THEN 'TemplateID(NULL) for User group'
				ELSE 'TemplateID(' + ISNULL(CONVERT(NVARCHAR,sa.TemplateID),'NULL') + ') NOT EXISTS in NotiTemplate' END
			)
	FROM #tmpSendingAlert AS sa
		LEFT JOIN NotiTemplate AS ntp WITH (NOLOCK) ON sa.TemplateID = ntp.TemplateID
	WHERE sa.ValidToSendChatGroup = 1
		AND sa.AlertType = 'EventAlert'
		AND (
			sa.MatchID IS NULL
			OR (sa.TemplateID IS NULL AND sa.ChatGroupID <> @IT_ChatGroupID)
			OR (ntp.TemplateID IS NULL AND sa.ChatGroupID <> @IT_ChatGroupID)
		)
	
	-----------------EventAlert - Verify and UPDATE ExistTest / ExistReal-----------------
	;WITH CTE_TR AS (
		SELECT a.AlertID
			,(CASE WHEN MAX(ext.IsTest) = 1 THEN 1 ELSE 0 END) AS ExistTest
			,(CASE WHEN MIN(ext.IsTest) = 0 THEN 1 ELSE 0 END) AS ExistReal
		FROM #tmpSendingAlert AS a
			LEFT JOIN #tmpAlertExt AS ext ON a.AlertID = ext.AlertID
		WHERE ext.IsTest IS NOT NULL
		GROUP BY a.AlertID
	)
	UPDATE a
	SET a.ExistTest = rt.ExistTest
		,a.ExistReal = rt.ExistReal
		,a.ValidToSendChatGroup = (CASE WHEN rt.AlertID IS NULL THEN 0 ELSE 1 END) --for ExistTest / ExistReal
		,a.IgnoreReason = (CASE WHEN rt.AlertID IS NULL THEN 'Can NOT define Alert for Real or Test SessionID' END) --for ExistTest / ExistReal
	FROM #tmpSendingAlert AS a
		LEFT JOIN CTE_TR AS rt ON rt.AlertID = a.AlertID
	WHERE a.ValidToSendChatGroup = 1
		AND a.AlertType = 'EventAlert'
	
	-----------------EventAlert - Verify message by ChatGroupID-----------------
	;WITH CTE_ChatGroupFilter AS (
		SELECT ac.AlertID
			,MAX(CASE WHEN sep.value IS NULL THEN 1 ELSE 0 END) AS ExistOST
			,MAX(CASE WHEN sep.value IS NOT NULL THEN 1 ELSE 0 END) AS Exist777
		FROM #tmpAlertBySite AS ac
			LEFT JOIN STRING_SPLIT(@Sites777, ',') AS sep ON ac.TargetSite = TRIM(sep.value)
		GROUP BY ac.AlertID
	)
	,CTE_Check AS (
		SELECT DISTINCT a.AlertID
			,a.ChatGroupID
			,(CASE WHEN a.ChatGroupID = @IT_ChatGroupID AND g.AlertID IS NOT NULL THEN 1 --IT_ChatGroupID can receive all message
				WHEN a.ChatGroupID = @OST_ChatGroupID AND g.ExistOST = 1 THEN 1 --Exists TargetSite NOT 777
				WHEN a.ChatGroupID = @777_ChatGroupID AND g.Exist777 = 1 THEN 1 --Exists TargetSite 777
				ELSE 0 END) AS ValidChatGroup
		FROM #tmpSendingAlert AS a
			LEFT JOIN CTE_ChatGroupFilter AS g ON a.AlertID = g.AlertID
		WHERE a.ValidToSendChatGroup = 1
			AND a.AlertType = 'EventAlert'
	)
	UPDATE a
	SET a.ValidToSendChatGroup = 0
		,a.IgnoreReason = ISNULL(a.IgnoreReason + ', ','') + 'Send to ChatGroupID(' + ISNULL(a.ChatGroupID,'NULL') + ') but NOT EXISTS Target Site'
	FROM #tmpSendingAlert AS a
		INNER JOIN CTE_Check AS ck ON a.AlertID = ck.AlertID AND a.ChatGroupID = ck.ChatGroupID
	WHERE a.ValidToSendChatGroup = 1
		AND a.AlertType = 'EventAlert'
		AND ck.ValidChatGroup = 0
	
	-----------------EventAlert - Verify and Update ExistTest/ExistReal-----------------
	;WITH CTE_RealCurr AS (
		SELECT AlertID
			,MAX(CASE WHEN UUSCurrency = 0 THEN 1 ELSE 0 END) AS ExistRealCust
		FROM #tmpAlertBySite
		GROUP BY AlertID
	)
	UPDATE a
	SET a.ExistTest = (CASE WHEN c.ExistRealCust = 0 THEN 1 ELSE a.ExistTest END) --IF ExistReal = 1 BUT ExistRealCust = 0 => all Test Cust => ExistTest = 1
		,a.ExistReal = (CASE WHEN c.ExistRealCust = 0 THEN 0 ELSE a.ExistReal END) --IF ExistReal = 1 BUT ExistRealCust = 0 => all Test Cust => ExistReal = 0
		,a.ValidToSendChatGroup = (CASE WHEN c.ExistRealCust IS NULL THEN 0 ELSE 1 END) --have NO cust of AlertID
		,a.IgnoreReason = (CASE WHEN c.ExistRealCust IS NULL THEN ISNULL(a.IgnoreReason + ', ','') + 'Real Match but NOT EXISTS Target Cust' ELSE a.IgnoreReason END) --for ExistTest / ExistReal
	FROM #tmpSendingAlert AS a
		LEFT JOIN CTE_RealCurr AS c ON a.AlertID = c.AlertID
	WHERE a.ValidToSendChatGroup = 1
		AND a.ExistReal = 1
		AND a.AlertType = 'EventAlert'
	
	-----------------Verify by @IT_ChatGroupID-----------------
	UPDATE #tmpSendingAlert
	SET ValidToSendChatGroup = 0
		,IgnoreReason = ISNULL(IgnoreReason + ', ','') + 'Only send real to @IT_ChatGroupID'
	WHERE ValidToSendChatGroup = 1
		AND ExistReal = 0
		AND ExistTest = 1
		AND ChatGroupID = @IT_ChatGroupID --Only send real to @IT_ChatGroupID
	
	---------prepare & convert data as JSON------------------
	SELECT @JSAlertInfo = CONVERT(NVARCHAR(MAX),(
							SELECT *
							FROM #tmpSendingAlert
							FOR JSON AUTO
						))
	
	DROP TABLE #tmpPrepareAlert
	DROP TABLE #tmpAlertExt
	DROP TABLE #tmpAlertBySite
	DROP TABLE #tmpSendingAlert
END
