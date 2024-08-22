/*<info serverAlias="DBCRM-MessageNotification" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE MNC_Notification_AlertSel
	@Environment VARCHAR(20)
AS
/*
	Created: 20231213@Roy
	Task: Get Alert info to send
	DB: DBCRM.MessageNotification
	Revisions:
		20231121@Roy: CRM - Implement Message Notifications Center for Result Amendment of Cricket(#197621)
	
	Explanation:
		
		Select and create message for OST, 777 or SYS group
		
		For OST group - EXCLUDE 777 target CustID
			+ User group: Only send message of REAL data (real match) and EXISTS Non-UUS cust
			+ Local/SIT group: send message of both REAL and TEST data
		For 777 group - ONLY 777 target CustID
			+ User group: Only send message of REAL data (real match) and EXISTS Non-UUS cust
			+ Local/SIT group: send message of both REAL and TEST data
		For SYS group
			+ Only send message of REAL data (real match) and EXISTS Non-UUS cust
		
		**Note: IGNORE message of TEST data for SYS group
	Example:
		EXEC MessageNotification.dbo.MNC_Notification_AlertSel
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @LogActionID SMALLINT
		,@LogUserID INT
		,@ErrLogPrefix NVARCHAR(150)
		,@InfLogPrefix NVARCHAR(150)
		,@StsIgnore TINYINT
		,@StsSending TINYINT
		,@StsSucceedSend TINYINT
		,@OST_ChatGroupID VARCHAR(50)
		,@777_ChatGroupID VARCHAR(50)
		,@IT_ChatGroupID VARCHAR(50)
		,@Sites777 VARCHAR(500) = ''
		,@ProcessID INT
	
	IF @Environment = 'LIVE'
	BEGIN
		SELECT @ProcessID = 21 --AlertService
		SELECT @ErrLogPrefix = 'Error - [AlertService - Send] - '
		SELECT @InfLogPrefix = 'Info - [AlertService - Send] - '
	END
	ELSE
	BEGIN
		SELECT @ProcessID = 22 --UAT_AlertService
		SELECT @ErrLogPrefix = 'Error - [UAT_AlertService - Send] - '
		SELECT @InfLogPrefix = 'Info - [UAT_AlertService - Send] - '
		
		SELECT @Environment = ISNULL(@Environment,'UAT')
	END
	
	/*
		Filter data by IncludeTestMatch
			If IncludeTestMatch = ON
			  + @Environment = LIVE => handle all data
			  + @Environment = UAT => return
			If IncludeTestMatch = OFF
			  + @Environment = LIVE => handle REAL data
			  + @Environment = UAT => handle TEST data
	*/
	IF @Environment = 'UAT' --no action (RETURN)
	BEGIN
		
		DECLARE @PRODIncludeTest BIT = 0
		SELECT @PRODIncludeTest = TRY_CONVERT(BIT, VValue)
		FROM SystemSetting WITH (NOLOCK)
		WHERE VID = 10 --IncludeTestMatch
		
		IF @PRODIncludeTest = 1
		BEGIN
			INSERT INTO UserLog (
				ActionID
				,UserID
				,LogBef
			)
			SELECT @LogActionID
				,@LogUserID
				,COMPRESS(@ErrLogPrefix + 'NO Action for IncludeTestMatch = ON AND Environment = UAT')
			
			RETURN
		END
	END
	
	--check current status of AlertService process
	DECLARE @WaitCnt INT = 0
		,@WaitTimes INT = 10
	
	WHILE (1 = 1)
	BEGIN
		--Increase @WaitCnt
		SELECT @WaitCnt = @WaitCnt + 1
		
		--IF GenerateNotifService Running
		IF EXISTS (SELECT 1 FROM SystemSetting WHERE VID = @ProcessID AND VValue = 'Running')
		BEGIN
			
			IF @WaitCnt <= @WaitTimes
			BEGIN
				WAITFOR DELAY '00:00:02' --Two seconds
			END
			ELSE
			BEGIN
				INSERT INTO UserLog (
					ActionID
					,UserID
					,LogBef
				)
				SELECT @LogActionID
					,@LogUserID
					,COMPRESS(@ErrLogPrefix + 'Another Process(' + ISNULL(CONVERT(VARCHAR,@ProcessID),'NULL') + ') is still active (after ' + ISNULL(CONVERT(VARCHAR,@WaitCnt),'NULL') + ' times retry).')
				
				--EXIT SP
				RETURN
			END
		END
		ELSE
		BEGIN
			--Start [process]
			UPDATE SystemSetting WITH (ROWLOCK,UPDLOCK)
			SET VValue = 'Running'
			WHERE VID = @ProcessID
				AND VValue = 'Done'
			
			INSERT INTO UserLog (
				ActionID
				,UserID
				,LogBef
			)
			SELECT @LogActionID
				,@LogUserID
				,COMPRESS(@InfLogPrefix + 'Change ProcessID(' + ISNULL(CONVERT(VARCHAR,@ProcessID),'NULL') + ') to [' + ISNULL(VValue,'NULL') + ']' + (CASE WHEN @WaitCnt > 1 THEN ' after ' + CONVERT(VARCHAR,@WaitCnt) + ' times retry' ELSE '' END)) AS LogBef
			FROM SystemSetting WITH (NOLOCK)
			WHERE VID = @ProcessID
			
			--EXIT WHILE
			BREAK
		END
	END
	
	CREATE TABLE #tmpAlertByCust (
		AlertID INT
		,TargetID INT
		,TargetSite NVARCHAR(50)
		,Currency INT
	)
	
	CREATE TABLE #tmpSendingAlert (
		AlertID INT
		,IsTest TINYINT
		,ChatGroupID VARCHAR(50)
		,Content NVARCHAR(MAX)
		,IsNoneSaba TINYINT
		,TemplateID SMALLINT
		,MatchID INT
		,RefInfo VARCHAR(50)
		,NotificationID INT
		,ValidToSendChatGroup TINYINT NOT NULL
		,IgnoreReason NVARCHAR(MAX)
	)
	
	CREATE TABLE #tmpResultSet (
		AlertID INT
		,ChatGroupID VARCHAR(50)
		,IsTest TINYINT
		,Content NVARCHAR(MAX)
	)
	
	CREATE TABLE #tmpTemplateDetl (
		AlertID INT
		,ChatGroupID VARCHAR(50)
		,RequiredParam VARCHAR(50)
		,ParamValue NVARCHAR(MAX)
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
	
	-- SELECT @ErrLogPrefix = 'Error - [AlertService] - '
	SELECT @InfLogPrefix = 'Info - [AlertService] - '
	
	SELECT @Sites777 = ISNULL(VValue,'')
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 16 --Separate Noti by Site
	
	-------------------HARD CODE ChatGroupID---------------------------
	SELECT @IT_ChatGroupID = 'SYS' --IT ChatGroupID
		,@OST_ChatGroupID = 'OST' --OST ChatGroupID
		,@777_ChatGroupID = '777' --777 ChatGroupID
	
	-----------------------------Start to get Alert with [RefInfo <> RuleID] and mark [Sending]-----------------
	DECLARE @OutJSAlertInfo NVARCHAR(MAX)
	EXEC MessageNotification.dbo.MNC_Notification_GetAlertInfo
		@Environment = @Environment
		,@JSAlertInfo = @OutJSAlertInfo OUTPUT
	
	--Parse JSON SendingAlert
	INSERT INTO #tmpSendingAlert (
		AlertID
		,IsTest
		,ChatGroupID
		,IsNoneSaba
		,TemplateID
		,MatchID
		,RefInfo
		,NotificationID
		,ValidToSendChatGroup
		,IgnoreReason
	)
	SELECT DISTINCT AlertID
		,IsTest
		,ChatGroupID
		,IsNoneSaba
		,TemplateID
		,MatchID
		,RefInfo
		,NotificationID
		,ValidToSendChatGroup
		,IgnoreReason
	FROM OPENJSON(@OutJSAlertInfo) WITH (
			AlertID INT '$.AlertID'
			,IsTest TINYINT '$.IsTest'
			,ChatGroupID VARCHAR(50) '$.ChatGroupID'
			,IsNoneSaba TINYINT '$.IsNoneSaba'
			,TemplateID SMALLINT '$.TemplateID'
			,MatchID INT '$.MatchID'
			,RefInfo VARCHAR(50) '$.RefInfo'
			,NotificationID INT '$.NotificationID'
			,ValidToSendChatGroup TINYINT '$.ValidToSendChatGroup'
			,IgnoreReason NVARCHAR(MAX) '$.IgnoreReason'
		)--OPENJSON case-sensitive
	WHERE ISJSON(@OutJSAlertInfo) = 1
	
	CREATE UNIQUE CLUSTERED INDEX CIX_tmpSendingAlert ON #tmpSendingAlert (AlertID, ChatGroupID)
	
	-------------------Get Alert Content / Template-------------------
	UPDATE sa
	SET sa.Content = (CASE WHEN sa.ChatGroupID = @IT_ChatGroupID THEN a.Content ELSE tp.Content_en END) --keep content for @IT_ChatGroupID
	FROM #tmpSendingAlert AS sa
		LEFT JOIN Alert AS a WITH (NOLOCK) ON sa.AlertID = a.AlertID
		LEFT JOIN NotiTemplate AS tp WITH (NOLOCK) ON sa.TemplateID = tp.TemplateID
	WHERE sa.ValidToSendChatGroup = 1
	
	--Verify Alert Content
	UPDATE #tmpSendingAlert
	SET ValidToSendChatGroup = 0
		,IgnoreReason = ISNULL(IgnoreReason + ', ','') + 'Can NOT initial Alert Content'
	WHERE ValidToSendChatGroup = 1
		AND ISNULL(TRIM(Content),'') = ''
	
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
		,ISNULL(ext.EventDate, ne.EventDate) AS EventDate --For Cricket of LAP, NotificationExtra.EventDate = Match.GlobalShowTime => Get from ExtraInfo[EventDate]
		,ext.KOTime
		,MAX(ext.LeagueNameEN) AS LeagueName --IF exists Saba and Non-Saba League => Choose Saba LeagueName
		,ext.HomeNameEN + ISNULL(' ' + ext.NeutralEN,'') AS HomeName
		,ext.AwayNameEN AS AwayName
	FROM #tmpSendingAlert AS a
		LEFT JOIN NotificationExtra AS ne WITH (NOLOCK) ON a.NotificationID = ne.NotificationID --current, only for Msg Noti
		OUTER APPLY OPENJSON(ne.ExtraInfo) WITH (
				MatchID INT '$.MatchID'
				,KOTime DATETIME '$.KOTime'
				,EventDate DATE '$.EventDate'
				,LeagueNameEN NVARCHAR(500) '$.LeagueNameEN'
				,HomeNameEN NVARCHAR(500) '$.HomeNameEN'
				,NeutralEN NVARCHAR(10) '$.NeutralEN'
				,AwayNameEN NVARCHAR(500) '$.AwayNameEN'
			) AS ext --OPENJSON case-sensitive
	WHERE ISJSON(ne.ExtraInfo) = 1
		AND a.ValidToSendChatGroup = 1
		AND ext.MatchID = a.MatchID
	GROUP BY a.MatchID
		,ISNULL(ext.EventDate, ne.EventDate)
		,ext.KOTime
		,ext.HomeNameEN + ISNULL(' ' + ext.NeutralEN,'')
		,ext.AwayNameEN
	
	--Event info by match table
	IF EXISTS (
		SELECT 1
		FROM #tmpSendingAlert AS a
			LEFT JOIN #tmpEventInfo AS ev ON a.MatchID = ev.MatchID
		WHERE a.ValidToSendChatGroup = 1
			AND ev.MatchID IS NULL
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
		FROM #tmpSendingAlert AS a
			LEFT JOIN bodb02.dbo.match AS m WITH (NOLOCK) ON a.MatchID = m.MatchID
			LEFT JOIN bodb02.dbo.match14 AS m14 WITH (NOLOCK) ON a.MatchID = m14.MatchID
			LEFT JOIN bodb02.dbo.team AS th WITH (NOLOCK) ON ISNULL(m.HomeID, m14.HomeID) = th.TeamID
			LEFT JOIN bodb02.dbo.team AS ta WITH (NOLOCK) ON ISNULL(m.AwayID, m14.AwayID) = ta.TeamID
			LEFT JOIN bodb02.dbo.league AS l WITH (NOLOCK) ON ISNULL(m.LeagueID, m14.LeagueID) = l.LeagueID
		WHERE a.ValidToSendChatGroup = 1
			AND l.LeagueID IS NOT NULL
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
	FROM #tmpSendingAlert AS a
		INNER JOIN NotiTemplate AS tp WITH (NOLOCK) ON tp.TemplateID = a.TemplateID
		OUTER APPLY STRING_SPLIT(tp.RequiredParams, ',') AS rq
	WHERE a.ValidToSendChatGroup = 1
		AND ISNULL(TRIM(rq.value),'') <> ''
	
	CREATE CLUSTERED INDEX CIX_tmpTemplateDetl ON #tmpTemplateDetl (AlertID)
	
	------------------------Build Alert content-----------------------------
	-- {MatchID},{EventDate},{KOTime},{LeagueName},{HomeName},{AwayName},{NotificationID},{Content_en},{Content_ch},{Content_cs}

	UPDATE tp
	SET tp.ParamValue = CONVERT(NVARCHAR,ev.MatchID)
	FROM #tmpTemplateDetl AS tp
		INNER JOIN #tmpSendingAlert AS a ON tp.AlertID = a.AlertID AND tp.ChatGroupID = a.ChatGroupID
		INNER JOIN #tmpEventInfo AS ev ON a.MatchID = ev.MatchID
	WHERE tp.RequiredParam = '{MatchID}'
	
	UPDATE tp
	SET tp.ParamValue = FORMAT(ev.EventDate, 'MMM dd, yyyy') --GMT-4
	FROM #tmpTemplateDetl AS tp
		INNER JOIN #tmpSendingAlert AS a ON tp.AlertID = a.AlertID AND tp.ChatGroupID = a.ChatGroupID
		INNER JOIN #tmpEventInfo AS ev ON a.MatchID = ev.MatchID
	WHERE tp.RequiredParam = '{EventDate}'
	
	UPDATE tp
	SET tp.ParamValue = FORMAT(DATEADD(HH, 12, ev.KOTime),'MMM dd, yyyy hh:mm tt') --KOTime GMT+8
	FROM #tmpTemplateDetl AS tp
		INNER JOIN #tmpSendingAlert AS a ON tp.AlertID = a.AlertID AND tp.ChatGroupID = a.ChatGroupID
		INNER JOIN #tmpEventInfo AS ev ON a.MatchID = ev.MatchID
	WHERE tp.RequiredParam = '{KOTime}'
	
	UPDATE tp
	SET tp.ParamValue = CASE WHEN a.IsNoneSaba = 1 THEN ev.LeagueName_NoneSaba ELSE ev.LeagueName END
	FROM #tmpTemplateDetl AS tp
		INNER JOIN #tmpSendingAlert AS a ON tp.AlertID = a.AlertID AND tp.ChatGroupID = a.ChatGroupID
		INNER JOIN #tmpEventInfo AS ev ON a.MatchID = ev.MatchID
	WHERE tp.RequiredParam = '{LeagueName}'
	
	UPDATE tp
	SET tp.ParamValue = ev.HomeName
	FROM #tmpTemplateDetl AS tp
		INNER JOIN #tmpSendingAlert AS a ON tp.AlertID = a.AlertID AND tp.ChatGroupID = a.ChatGroupID
		INNER JOIN #tmpEventInfo AS ev ON a.MatchID = ev.MatchID
	WHERE tp.RequiredParam = '{HomeName}'
	
	UPDATE tp
	SET tp.ParamValue = ev.AwayName
	FROM #tmpTemplateDetl AS tp
		INNER JOIN #tmpSendingAlert AS a ON tp.AlertID = a.AlertID AND tp.ChatGroupID = a.ChatGroupID
		INNER JOIN #tmpEventInfo AS ev ON a.MatchID = ev.MatchID
	WHERE tp.RequiredParam = '{AwayName}'
	
	UPDATE tp
	SET tp.ParamValue = CONVERT(NVARCHAR,a.NotificationID)
	FROM #tmpTemplateDetl AS tp
		INNER JOIN #tmpSendingAlert AS a ON tp.AlertID = a.AlertID AND tp.ChatGroupID = a.ChatGroupID AND a.RefInfo = 'NotificationID'
	WHERE tp.RequiredParam = '{NotificationID}'
	
	UPDATE tp
	SET tp.ParamValue = (CASE WHEN tp.RequiredParam = '{Content_en}' THEN n.Content_en
							WHEN tp.RequiredParam = '{Content_ch}' THEN n.Content_ch
							ELSE n.Content_cs
						END)
	FROM #tmpTemplateDetl AS tp
		INNER JOIN #tmpSendingAlert AS a ON tp.AlertID = a.AlertID AND tp.ChatGroupID = a.ChatGroupID
		LEFT JOIN Notification AS n WITH (NOLOCK) ON a.NotificationID = n.NotificationID
	WHERE tp.RequiredParam IN ('{Content_en}', '{Content_ch}', '{Content_cs}')
	
	---Replace RequiredParam into Template	
	DECLARE @iLoopParam VARCHAR(50)
	SELECT @iLoopParam = MIN(RequiredParam)
	FROM #tmpTemplateDetl
	
	WHILE EXISTS(SELECT 1 FROM #tmpTemplateDetl WHERE RequiredParam = @iLoopParam)
	BEGIN
		--Start to replace RequiredParams
		UPDATE a
		SET a.Content = REPLACE(a.Content,tpd.RequiredParam,tpd.ParamValue)
		FROM #tmpSendingAlert AS a
			INNER JOIN #tmpTemplateDetl AS tpd ON a.AlertID = tpd.AlertID AND a.ChatGroupID = tpd.ChatGroupID
		WHERE tpd.RequiredParam = @iLoopParam
			AND a.ValidToSendChatGroup = 1
			AND a.ChatGroupID <> @IT_ChatGroupID
		
		SET @iLoopParam = (SELECT MIN(RequiredParam) FROM #tmpTemplateDetl WHERE RequiredParam > @iLoopParam )
	END
	
	-----------------------------Validate after Build Alert content--------------------------------
	;WITH CTE_ParamError AS (
		SELECT DISTINCT a.AlertID
			,a.ChatGroupID
			,'Invalid Content - RequiredParam can NOT be replaced - Content(' + ISNULL(a.Content,'NULL') + ')' AS IgnoreReason
		FROM #tmpSendingAlert AS a
		WHERE a.ValidToSendChatGroup = 1
			AND a.ChatGroupID <> @IT_ChatGroupID
			AND EXISTS (
				SELECT 1
				FROM #tmpTemplateDetl AS tp
				WHERE ISNULL(CHARINDEX(tp.RequiredParam, a.Content),0) <> 0
			)
	)
	,CTE_ContentError AS (
		SELECT DISTINCT a.AlertID
			,a.ChatGroupID
			,'Invalid Content - BLANK after build content - '
			+ (CASE WHEN tp.AlertID IS NULL THEN 'S.T wrong with Template detail NO VALUE'
				WHEN ev.MatchID IS NULL THEN 'can NOT retrieve MatchID info.'
				WHEN (a.IsNoneSaba = 0 AND ev.LeagueName IS NULL) THEN 'can NOT retrieve LeagueName info.'
				WHEN (a.IsNoneSaba = 1 AND ev.LeagueName_NoneSaba IS NULL) THEN 'can NOT retrieve LeagueName_NoneSaba info.'
				ELSE 'Unknown' END) AS IgnoreReason
		FROM #tmpSendingAlert AS a
			LEFT JOIN #tmpTemplateDetl AS tp ON tp.AlertID = a.AlertID AND tp.ChatGroupID = a.ChatGroupID
			LEFT JOIN #tmpEventInfo AS ev ON a.MatchID = ev.MatchID
		WHERE a.ValidToSendChatGroup = 1
			AND ISNULL(TRIM(a.Content),'') = ''
	)
	,CTE_Err AS (
		SELECT AlertID
			,ChatGroupID
			,STRING_AGG(CONVERT(NVARCHAR(MAX),IgnoreReason),', ') AS IgnoreReason
		FROM (
			SELECT AlertID
				,ChatGroupID
				,IgnoreReason
			FROM CTE_ParamError
			
			UNION ALL
			
			SELECT AlertID
				,ChatGroupID
				,IgnoreReason
			FROM CTE_ContentError
		) AS t
		GROUP BY AlertID
			,ChatGroupID
	)
	UPDATE sa
	SET sa.ValidToSendChatGroup = 0
		,sa.IgnoreReason = ISNULL(sa.IgnoreReason + ', ','') + ig.IgnoreReason
	FROM #tmpSendingAlert AS sa
		INNER JOIN CTE_Err AS ig ON sa.AlertID = ig.AlertID AND sa.ChatGroupID = ig.ChatGroupID
	WHERE sa.ValidToSendChatGroup = 1
	
	/*****************************************
		Build the result set
	*******************************************/
	--for Real group
	INSERT INTO #tmpResultSet (
		AlertID
		,ChatGroupID
		,IsTest
		,Content
	)
	SELECT DISTINCT AlertID
		,ChatGroupID
		,IsTest
		,Content
	FROM #tmpSendingAlert
	WHERE ValidToSendChatGroup = 1
	
	CREATE CLUSTERED INDEX CIX_tmpResultSet ON #tmpResultSet (AlertID, ChatGroupID)
	
	/*
		Change Alert status
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
				,ValidToSendChatGroup AS Succeed
			FROM #tmpSendingAlert
		) AS t
		GROUP BY AlertID
	)
	UPDATE a
	SET a.StatusID = (CASE WHEN rs.Succeed = 1 THEN @StsSucceedSend ELSE @StsIgnore END)
	FROM Alert AS a WITH (ROWLOCK,UPDLOCK)
		INNER JOIN CTE_Alert AS rs ON a.AlertID = rs.AlertID
	WHERE a.StatusID = @StsSending
	
	/*****************************************
		Return result set
	*******************************************/
	SELECT DISTINCT ChatGroupID
		,IsTest
		,Content
	FROM #tmpResultSet
	ORDER BY ChatGroupID
		,IsTest
	
	--Change ProcessID Status
	UPDATE SystemSetting WITH (ROWLOCK,UPDLOCK)
	SET VValue = 'Done'
	WHERE VID = @ProcessID
		AND VValue = 'Running'
	-------------------------------write log-------------------------------
	;WITH CTE_Sent AS (
		SELECT s.AlertID
			,STRING_AGG(CONVERT(NVARCHAR(MAX),s.ChatGroupID),', ') AS ChatGroupIDs
			,CONVERT(NVARCHAR(MAX),(
					SELECT DISTINCT t.ChatGroupID
						,t.Content
						,t.MatchID
						,t.TemplateID
						,t.IsTest
					FROM #tmpSendingAlert AS t
					WHERE t.AlertID = s.AlertID
						AND t.ValidToSendChatGroup = 1
					FOR JSON PATH
				)) AS SentContent
		FROM #tmpResultSet AS s
		GROUP BY s.AlertID
	)
	,CTE_Ignore AS (
		SELECT s.AlertID
			,STRING_AGG(CONVERT(NVARCHAR(MAX),ISNULL(s.ChatGroupID,'NULL')),', ') AS ChatGroupIDs
			,CONVERT(NVARCHAR(MAX),(
				SELECT ISNULL(t.IgnoreReason,'NULL') AS IgnoreReason
					,STRING_AGG(CONVERT(NVARCHAR(MAX),ISNULL(t.ChatGroupID, 'NULL')),', ') AS ChatGroupIDs
					,STRING_AGG(CONVERT(NVARCHAR(MAX),t.IsTest),', ') AS IsTest
				FROM #tmpSendingAlert AS t
				WHERE t.AlertID = s.AlertID
					AND t.ValidToSendChatGroup = 0
				GROUP BY ISNULL(t.IgnoreReason,'NULL')
				FOR JSON PATH
			)) AS IngoreLog
		FROM #tmpSendingAlert AS s
			INNER JOIN #tmpResultSet AS st ON s.AlertID = st.AlertID
		WHERE s.ValidToSendChatGroup = 0
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
						+ ISNULL(' - Ignore Reason(' + ia.IngoreLog + ')' , ''))
		,COMPRESS(N'Sent Content(' + ISNULL(sa.SentContent,'Refer Alert.Content')+ ')')
	FROM #tmpResultSet AS a
		LEFT JOIN CTE_Sent AS sa ON a.AlertID = sa.AlertID
		LEFT JOIN CTE_Ignore AS ia ON a.AlertID = ia.AlertID
	ORDER BY a.AlertID
	
	;WITH CTE_IgnoreAlert AS (
		SELECT s.AlertID
			,STRING_AGG(CONVERT(NVARCHAR(MAX),s.ChatGroupID),', ') AS ChatGroupIDs
			,CONVERT(NVARCHAR(MAX),(
				SELECT STRING_AGG(CONVERT(NVARCHAR(MAX),t.ChatGroupID),', ') AS ChatGroupIDs
					,t.IgnoreReason
				FROM #tmpSendingAlert AS t
				WHERE t.AlertID = s.AlertID
				GROUP BY t.IgnoreReason
				FOR JSON PATH
			)) AS IngoreLog
		FROM #tmpSendingAlert AS s
			LEFT JOIN #tmpResultSet AS st ON s.AlertID = st.AlertID
		WHERE st.AlertID IS NULL
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
						+ ' - Ignore ChatGroupIDs(' + ISNULL(ig.ChatGroupIDs,'NULL')+ ')'
						+ ' - Ignore Log(' + ISNULL(ig.IngoreLog,'NULL')+ ')')
	FROM CTE_IgnoreAlert AS ig
	ORDER BY ig.AlertID
	
	/*
		Handle LastRunTime
	*/
	IF @Environment = 'LIVE'
	BEGIN
		UPDATE SystemSetting WITH (ROWLOCK,UPDLOCK)
		SET VValue = CONVERT(VARCHAR, GETDATE(), 120)
		WHERE VID = 18 --LastRunTime
	END
	ELSE
	BEGIN
		UPDATE SystemSetting WITH (ROWLOCK,UPDLOCK)
		SET VValue = CONVERT(VARCHAR, GETDATE(), 120)
		WHERE VID = 20 --UAT_LastRunTime
	END
	
	INSERT INTO UserLog (
		ActionID
		,UserID
		,LogBef
	)
	SELECT @LogActionID
		,@LogUserID
		,COMPRESS(@InfLogPrefix + 'Debug - UPDATE LastSessionID/LastRunTime'
					+ ' - @LastRunTime(' + ISNULL(CONVERT(VARCHAR, GETDATE()),'NULL') + ')'
		)
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 13 --LogMode
		AND VValue = 'Debug'
	
	DROP TABLE #tmpAlertByCust
	DROP TABLE #tmpSendingAlert
	DROP TABLE #tmpTemplateDetl
	DROP TABLE #tmpEventInfo
	DROP TABLE #tmpResultSet
END
