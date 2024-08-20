/*<info serverAlias="DBCRM-MessageNotification" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE MNC_Notification_AlertIns
	@Environment VARCHAR(20)
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(2000) = '' OUTPUT
AS
/*
	Created: 20231213@Roy
	Task: Insert Alert based on AlertRule
	DB: DBCRM.MessageNotification
	Revisions:
		20231121@Roy: CRM - Implement Message Notifications Center for Result Amendment of Cricket(#197621)
	
	Explanation:

		Output
			@ErrCode
			@ErrMsg
	
	Example:
		EXEC MessageNotification.dbo.MNC_Notification_AlertIns
*/
BEGIN
	SET NOCOUNT ON
	
	/*
		Reset OUTPUT
	*/
	SELECT @ErrCode = 0
		,@ErrMsg = ''
	
	DECLARE @LogActionID SMALLINT
		,@LogUserID INT
		,@StsNew TINYINT
		,@IT_ChatGroupID VARCHAR(50) = 'SYS' --IT ChatGroupID
		,@RuleID INT
		,@SiteCnt INT = 0
		,@WaitSec INT = 0
		,@FromTime DATETIME = DATEADD(DD, -1, GETDATE())
		,@CurrTime DATETIME = GETDATE()
		,@PRODIncludeTest BIT = 0
		,@IsTestFlag TINYINT
	
	SELECT @StsNew = StatusID
	FROM NotiStatus WITH (NOLOCK)
	WHERE Status = 'New'
	
	SELECT @LogActionID = ActionID
	FROM LogAction WITH (NOLOCK)
	WHERE ActName = ISNULL(OBJECT_NAME(@@PROCID),'Unknown')
	
	SELECT @LogUserID = TRY_CONVERT(INT, VValue)
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 2 --ID of StarixIT
	
	SELECT @PRODIncludeTest = TRY_CONVERT(BIT, VValue)
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 10 --IncludeTestMatch
	
	/*
		Filter data by IncludeTestMatch
			If IncludeTestMatch = ON
			  + @Environment = LIVE => handle all data
			  + @Environment = UAT => return
			If IncludeTestMatch = OFF
			  + @Environment = LIVE => handle REAL data
			  + @Environment = UAT => handle TEST data
	*/
	IF @PRODIncludeTest = 1 AND @Environment = 'UAT' --no action (RETURN)
	BEGIN
		INSERT INTO UserLog (
			ActionID
			,UserID
			,LogBef
		)
		SELECT @LogActionID
			,@LogUserID
			,COMPRESS(N'Error - [AlertService] - NO Action for IncludeTestMatch = ON AND Environment = UAT')
		
		RETURN
	END
	ELSE IF @PRODIncludeTest = 0 AND @Environment = 'LIVE' --REAL data only
	BEGIN
		SET @IsTestFlag = 0
	END
	ELSE IF @PRODIncludeTest = 0 AND @Environment = 'UAT' --TEST data only
	BEGIN
		SET @IsTestFlag = 1
	END
	ELSE --both REAL & TEST
	BEGIN
		SET @IsTestFlag = NULL
	END
	
	CREATE TABLE #tmpSettl (
		SessionID NVARCHAR(50) NOT NULL
		,SettlementLogID INT NOT NULL
		,LastModifiedTime DATETIME NOT NULL
		------------------
		,IsTest TINYINT NOT NULL
		,MatchID INT NOT NULL
		,Status VARCHAR(50) NOT NULL
	)
	
	CREATE TABLE #tmpMsgNoti (
		MsgNotiID INT
		,LapNotiID INT
		,MessageID INT
		,IsTest TINYINT NOT NULL
		,MatchID INT NOT NULL
		,Status VARCHAR(50) NOT NULL
		,LastModifiedTime DATETIME NOT NULL
		,SessionID NVARCHAR(50) NOT NULL
		,SettlementLogID INT NOT NULL
	)

	CREATE TABLE #tmpError_New (
		InternalID INT IDENTITY (1,1)
		--------
		,RuleID INT NOT NULL
		,IsTest BIT NOT NULL
		,RefInfo NVARCHAR(50) NOT NULL
		,SessionID NVARCHAR(50)
		,LastModifiedTime DATETIME NOT NULL
		--------
		,NotificationID INT
		,MatchID INT
		,Content NVARCHAR(4000)
		,RefID NVARCHAR(50)
	)
	
	CREATE TABLE #tmpError_Old (
		RuleID INT NOT NULL
		,IsTest BIT NOT NULL
		,RefInfo NVARCHAR(50) NOT NULL
		,SessionID NVARCHAR(50)
		,LastModifiedTime DATETIME
		--------
		,NotificationID INT
	)
	
	BEGIN TRY
		---------------------Prepare-------------------------
		INSERT INTO #tmpSettl (
			SessionID
			,SettlementLogID
			,LastModifiedTime
			,IsTest
			,MatchID
			,Status
		)
		SELECT DISTINCT rh.SessionID
			,rh.SettlementLogID
			,rh.LastModifiedTime
			,CONVERT(TINYINT,rh.IsTest) AS IsTest
			,rh.MatchID
			,st.Status
		FROM SettlementResultHist AS rh WITH (NOLOCK)
			LEFT JOIN NotiStatus AS st WITH (NOLOCK) ON rh.StatusID = st.StatusID
		WHERE rh.LastModifiedTime > @FromTime
			AND rh.LastModifiedTime <= @CurrTime
			AND rh.SportType = 50 --Cricket, need modify for others sport
			AND (
				@IsTestFlag IS NULL
				OR CONVERT(TINYINT,rh.IsTest) = @IsTestFlag
			) --filter by Environment/IncludeTestMatch
		
		CREATE CLUSTERED INDEX CIX_tmpSettl ON #tmpSettl (SessionID)
		
		;WITH CTE_Noti AS (
			SELECT DISTINCT (CASE WHEN n.NotificationType = 1 THEN n.NotificationID END) AS MsgNotiID
				,(CASE WHEN n.NotificationType = 2 THEN n.NotificationID END) AS LapNotiID
				,n.RefID AS MessageID
				,CONVERT(TINYINT,rh.IsTest) AS IsTest
				,rh.MatchID
				,st.Status
				,n.LastModifiedTime
				,rh.SessionID
				,rh.SettlementLogID
			FROM Notification AS n WITH (NOLOCK)
				LEFT JOIN NotiMapping AS nm WITH (NOLOCK) ON n.NotificationID = nm.NotificationID
				LEFT JOIN SettlementResultHist AS rh WITH (NOLOCK) ON nm.SettlementLogID = rh.SettlementLogID
				LEFT JOIN NotiStatus AS st WITH (NOLOCK) ON n.StatusID = st.StatusID
			WHERE n.LastModifiedTime > @FromTime
				AND n.LastModifiedTime <= @CurrTime
				AND n.NotificationType IN (1, 2) --1: Result Amendment to Msg; --2: LAP of NotificationType = 1 (Result Amendment)
		)
		INSERT INTO #tmpMsgNoti (
			MsgNotiID
			,LapNotiID
			,MessageID
			,IsTest
			,MatchID
			,Status
			,LastModifiedTime
			,SessionID
			,SettlementLogID
		)
		SELECT MsgNotiID
			,LapNotiID
			,MessageID
			,MIN(IsTest) AS IsTest --any IsTest=0 => REAL => IsTest = 0
			,MatchID
			,Status
			,LastModifiedTime
			,SessionID
			,SettlementLogID
		FROM CTE_Noti
		GROUP BY MsgNotiID
			,LapNotiID
			,MessageID
			,MatchID
			,Status
			,LastModifiedTime
			,SessionID
			,SettlementLogID
		
		----filter by Environment/IncludeTestMatch
		IF @IsTestFlag IS NULL --both REAL & TEST => no need to check IsTest
		BEGIN
			DELETE n
			FROM #tmpMsgNoti AS n
				LEFT JOIN SettlementResultHist AS rh WITH (NOLOCK) ON n.SettlementLogID = rh.SettlementLogID
			WHERE ISNULL(rh.SportType,0) <> 50 --Cricket, need modify for others sport
		END
		ELSE
		BEGIN
			DELETE n
			FROM #tmpMsgNoti AS n
				LEFT JOIN SettlementResultHist AS rh WITH (NOLOCK) ON n.SettlementLogID = rh.SettlementLogID
			WHERE n.IsTest <> @IsTestFlag --@IsTestFlag = 0 => REAL data only => DEL <> REAL
				OR ISNULL(rh.SportType,0) <> 50 --Cricket, need modify for others sport
		END
		
		CREATE CLUSTERED INDEX CIX_tmpMsgNoti ON #tmpMsgNoti (MsgNotiID)
	
		---------------------Start to check-------------------------

		/*
			#1.RA_SysErr - Error send only for IT Group
			- Send to SYS only
		*/
		SELECT @RuleID = 1
		
		---1.1 - For [Capture Data Service] process, SessionID [Retrieving] over 2*Configuration_WaitSec---
		SELECT @WaitSec = ISNULL(TRY_CONVERT(INT, VValue),0) * 2
		FROM SystemSetting WITH (NOLOCK)
		WHERE VID = 11 --Retrieving_WaitSec
		
		;WITH CTE_LongSession AS (
			SELECT SessionID
				,MIN(IsTest) AS Mi_IsTest
				,MIN(LastModifiedTime) AS Mi_LastModifiedTime
			FROM #tmpSettl
			WHERE Status = 'Retrieving'
			GROUP BY SessionID
			HAVING DATEDIFF(SECOND, MIN(LastModifiedTime),@CurrTime) > @WaitSec
		)
		INSERT INTO #tmpError_New (
			RuleID
			,IsTest
			,RefInfo
			,SessionID
			,LastModifiedTime
			--------------
			,MatchID
			,Content
		)
		SELECT DISTINCT @RuleID
			,l.Mi_IsTest
			,'SessionID' AS RefInfo
			,l.SessionID
			,l.Mi_LastModifiedTime
			--------------
			,rh.MatchID
			,'SessionID [' + l.SessionID + '] in [Retrieving] state too long, exceeding '+ ISNULL(CONVERT(VARCHAR, @WaitSec),'NULL')+' seconds. Please double check [Capture Data Service] process.' AS Content
		FROM CTE_LongSession AS l
			LEFT JOIN #tmpSettl AS rh ON l.SessionID = rh.SessionID AND rh.Status = 'Retrieving'
		
		---1.2 - For [Generate Notif Service] process, SessionID [Generating] over 60s---
		SELECT @WaitSec = 60

		;WITH CTE_LongSession AS (
			SELECT SessionID
				,MIN(IsTest) AS Mi_IsTest
				,MIN(LastModifiedTime) AS Mi_LastModifiedTime
			FROM #tmpSettl
			WHERE Status = 'Generating'
			GROUP BY SessionID
			HAVING DATEDIFF(SECOND, MIN(LastModifiedTime),@CurrTime) > @WaitSec
		)
		INSERT INTO #tmpError_New (
			RuleID
			,IsTest
			,RefInfo
			,SessionID
			,LastModifiedTime
			--------------
			,MatchID
			,Content
		)
		SELECT DISTINCT @RuleID
			,l.Mi_IsTest
			,'SessionID' AS RefInfo
			,rh.SessionID
			,l.Mi_LastModifiedTime
			--------------
			,rh.MatchID
			,'SessionID [' + rh.SessionID + '] in [Generating] Msg state too long, exceeding '+ ISNULL(CONVERT(VARCHAR, @WaitSec),'NULL')+' seconds. Please double check [Generate Notif Service] process.' AS Content
		FROM CTE_LongSession AS l
			LEFT JOIN #tmpSettl AS rh ON l.SessionID = rh.SessionID AND rh.Status = 'Generating'
		
		--1.3 - For [Generate Notif Service] process, Notification.StatusID = Generating over 60s
		SELECT @WaitSec = 60
		
		INSERT INTO #tmpError_New (
			RuleID
			,IsTest
			,RefInfo
			,SessionID
			,LastModifiedTime
			--------------
			,NotificationID
			,MatchID
			,Content
		)
		SELECT DISTINCT @RuleID
			,m.IsTest
			,'NotificationID' AS RefInfo
			,m.SessionID
			,m.LastModifiedTime
			--------------
			,m.MsgNotiID
			,m.MatchID
			,'Notification(' + CONVERT(VARCHAR, m.MsgNotiID) + ') of SessionID [' + m.SessionID + '] in [Generating] state too long, exceeding '+ ISNULL(CONVERT(VARCHAR, @WaitSec),'NULL')+' seconds. Please double check [Generate Notif Service] process.' AS Content
		FROM #tmpMsgNoti AS m
		WHERE m.Status = 'Generating'
			AND m.MsgNotiID IS NOT NULL
			AND DATEDIFF(SECOND, m.LastModifiedTime, @CurrTime) > @WaitSec
		
		--1.4 - For [Insert Message Service] process, Notification.StatusID = Sending over 60s
		SELECT @WaitSec = 60
		
		INSERT INTO #tmpError_New (
			RuleID
			,IsTest
			,RefInfo
			,SessionID
			,LastModifiedTime
			--------------
			,NotificationID
			,MatchID
			,Content
		)
		SELECT DISTINCT @RuleID
			,m.IsTest
			,'NotificationID' AS RefInfo
			,m.SessionID
			,m.LastModifiedTime
			--------------
			,m.MsgNotiID
			,m.MatchID
			,'Notification(' + CONVERT(VARCHAR, m.MsgNotiID) + ') of SessionID [' + m.SessionID + '] in [Sending] state too long, exceeding '+ ISNULL(CONVERT(VARCHAR, @WaitSec),'NULL')+' seconds. Please double check [Insert Message Service] process.' AS Content
		FROM #tmpMsgNoti AS m
		WHERE m.MsgNotiID IS NOT NULL --NotificationType = 1 - Result Amendment to Msg
			AND m.Status = 'Sending'
			AND DATEDIFF(SECOND, m.LastModifiedTime, @CurrTime) > @WaitSec
		
		--1.5 - For [Generate LAP Notif Service] process, NOT EXISTS after being approved MessageID over 60s
		SELECT @WaitSec = 60
		
		;WITH CTE_Lap AS (
			SELECT MessageID
			FROM #tmpMsgNoti
			WHERE LapNotiID IS NOT NULL
		)
		INSERT INTO #tmpError_New (
			RuleID
			,IsTest
			,RefInfo
			,SessionID
			,LastModifiedTime
			--------------
			,NotificationID
			,MatchID
			,Content
		)
		SELECT DISTINCT @RuleID
			,m.IsTest
			,'NotificationID' AS RefInfo
			,m.SessionID
			,m.LastModifiedTime
			--------------
			,m.MsgNotiID
			,m.MatchID
			,'LAP Notification belong to Msg Notification [' + CONVERT(VARCHAR,m.MsgNotiID) + '] - SessionID [' + ISNULL(m.SessionID,'NULL') + '] NOT EXISTS after being approved MessageID [' + CONVERT(VARCHAR,m.MessageID) + '] for more than '+ ISNULL(CONVERT(VARCHAR, @WaitSec),'NULL')+' seconds. Please double check [Generate LAP Notif Service] process.'
		FROM #tmpMsgNoti AS m
			LEFT JOIN CTE_Lap AS l ON m.MessageID = l.MessageID
		WHERE m.MsgNotiID IS NOT NULL
			AND m.MessageID IS NOT NULL
			AND m.Status = 'Sent'
			AND DATEDIFF(SECOND, m.LastModifiedTime,@CurrTime) > @WaitSec
			---Check EXISTS
			AND l.MessageID IS NULL
			AND EXISTS (
				SELECT 1
				FROM MessageNotification.dbo.NotificationTarget AS nt WITH (NOLOCK)
					LEFT JOIN bodb02.dbo.Site AS s WITH (NOLOCK) ON nt.TargetSite = s.site AND s.isDeposit = 1 --deposit user
				WHERE m.MsgNotiID = nt.NotificationID
					AND s.site IS NOT NULL --EXISTS [deposit] Target
			)
		
		--1.6 - For [Generate LAP Notif Service] process, Notification.StatusID = Generating over 60s / Failed to Generate
		INSERT INTO #tmpError_New (
			RuleID
			,IsTest
			,RefInfo
			,SessionID
			,LastModifiedTime
			--------------
			,NotificationID
			,MatchID
			,Content
		)
		SELECT DISTINCT @RuleID
			,m.IsTest
			,'NotificationID' AS RefInfo
			,m.SessionID
			,m.LastModifiedTime
			--------------
			,m.LapNotiID
			,m.MatchID
			,'LAP Notification [' + CONVERT(VARCHAR,m.LapNotiID) + '] of SessionID [' + m.SessionID + '] '
				+ (CASE WHEN m.Status = 'Failed to Generate' THEN 'was NOT successfully GENERATED. ' ELSE 'in [Generating] state too long, exceeding '+ ISNULL(CONVERT(VARCHAR, @WaitSec),'NULL')+' seconds. ' END)
				+ 'Please double check [Generate LAP Notif Service] process.' AS Content
		FROM #tmpMsgNoti AS m
		WHERE m.LapNotiID IS NOT NULL
			AND (
				m.Status = 'Failed to Generate'
				OR (
					m.Status = 'Generating'
					AND DATEDIFF(SECOND, m.LastModifiedTime, @CurrTime) > @WaitSec
				)
			)
		
		/*
			#2.RA_NewNoti - Need Review
			- Send to OST,777
			- Template: Message 2
		*/
		SELECT @RuleID = 2
		
		INSERT INTO #tmpError_New (
			RuleID
			,IsTest
			,RefInfo
			,SessionID
			,LastModifiedTime
			-----------
			,NotificationID
			,MatchID
			,Content
		)
		SELECT DISTINCT @RuleID
			,IsTest
			,'NotificationID' AS RefInfo
			,SessionID
			,LastModifiedTime
			-----------
			,MsgNotiID AS NotificationID
			,MatchID
			,'Result Amendment Notification [' + CONVERT(VARCHAR,MsgNotiID) + '] for SessionID ['+ ISNULL(SessionID,'NULL') +'] created. Please review it.' AS Content
		FROM #tmpMsgNoti
		WHERE Status = 'New' --Only for OST, LAP notified by Chatbot LIC
			AND MsgNotiID IS NOT NULL --NotificationType = 1 - Result Amendment to Msg
		
		/*
			#3.RA_PushErr - Sent Issue
			- Send to SYS,OST,777
			- Template: Message 3
		*/
		SELECT @RuleID = 3
		
		INSERT INTO #tmpError_New (
			RuleID
			,IsTest
			,RefInfo
			,SessionID
			,LastModifiedTime
			-----------
			,NotificationID
			,MatchID
			,Content
		)
		SELECT DISTINCT @RuleID
			,IsTest
			,'NotificationID' AS RefInfo
			,SessionID
			,LastModifiedTime
			-----------
			,MsgNotiID AS NotificationID
			,MatchID
			,'Result Amendment message associated with SessionID ['+ ISNULL(SessionID,'NULL') +'] was NOT successfully inserted to DBMSG. Please review it.' AS Content
		FROM #tmpMsgNoti
		WHERE Status = 'Failed to Send'
			AND MsgNotiID IS NOT NULL --NotificationType = 1 - Result Amendment to Msg
		
		/*
			#4.RA_GenErr - Create Noti for DBMSG Failed
			- Send to SYS,OST,777
			- Template: Message 1
		*/
		SELECT @RuleID = 4
		
		INSERT INTO #tmpError_New (
			RuleID
			,IsTest
			,RefInfo
			,SessionID
			,LastModifiedTime
			-----------
			,NotificationID
			,MatchID
			,Content
		)
		SELECT @RuleID AS RuleID
			,CONVERT(BIT,MIN(s.IsTest)) AS IsTest --any IsTest=0 => REAL => IsTest = 0
			,'SessionID' AS RefInfo
			,s.SessionID
			,MIN(ISNULL(rh.LastModifiedTime,n.LastModifiedTime)) AS LastModifiedTime
			,MIN(n.MsgNotiID) AS NotificationID
			,MIN(ISNULL(rh.MatchID,n.MatchID)) AS MatchID
			,'Result Amendment message associated with SessionID ['+ ISNULL(s.SessionID,'NULL') +'] was NOT successfully GENERATED. Please double check [Generate Notif Service] process.' AS Content
		FROM (
			SELECT rh.SessionID
				,rh.SettlementLogID
				,rh.IsTest
			FROM #tmpSettl AS rh
			WHERE rh.Status = 'Failed to Generate'
			
			UNION ALL
			
			SELECT SessionID
				,SettlementLogID
				,IsTest
			FROM #tmpMsgNoti
			WHERE Status = 'Failed to Generate'
				AND MsgNotiID IS NOT NULL --NotificationType = 1 - Result Amendment to Msg
		) AS s
			LEFT JOIN #tmpSettl AS rh ON s.SessionID = rh.SessionID AND s.SettlementLogID = rh.SettlementLogID
			LEFT JOIN #tmpMsgNoti AS n ON s.SessionID = n.SessionID AND s.SettlementLogID = n.SettlementLogID
		GROUP BY s.SessionID
		
		/*
			#5.RA_GenWarn - Missing data from SiteDBs
			- Send to SYS,OST,777
			- Template: Message 4
		*/
		SELECT @RuleID = 5
		
		SELECT @SiteCnt = COUNT(DISTINCT SiteDBGroupID)
		FROM bodb02.dbo.SiteDBConfig WITH (NOLOCK)
		WHERE SiteDBGroupID <> 0
		
		--Generated Session BUT NOT enough SiteDBs
		;WITH CTE_SessionInfo AS (
			SELECT s.SessionID
				,s.MatchID
				,MIN(rh.LastModifiedTime) AS LastModifiedTime
				,MIN(CONVERT(TINYINT,rh.IsTest)) AS IsTest
				,COUNT(DISTINCT rh.SiteDBGroupID) AS SiteCnt
				,MAX(CASE WHEN st.Status = 'Failed to Retrieve' THEN 1 ELSE 0 END) AS ExistRetrvFailed
			FROM #tmpSettl AS s
				INNER JOIN SettlementResultHist AS rh WITH (NOLOCK) ON s.SessionID = rh.SessionID
				INNER JOIN NotiStatus AS st WITH (NOLOCK) ON rh.StatusID = st.StatusID
			WHERE s.Status = 'Successfully Generated'
			GROUP BY s.SessionID
				,s.MatchID
		)
		INSERT INTO #tmpError_New (
			RuleID
			,IsTest
			,RefInfo
			,SessionID
			,LastModifiedTime
			-----------
			,MatchID
			,Content
		)
		SELECT DISTINCT @RuleID
			,IsTest
			,'SessionID' AS RefInfo
			,SessionID
			,LastModifiedTime
			-----------
			,MatchID
			,(CASE WHEN ExistRetrvFailed = 1 THEN 'SessionID [' + SessionID + '] NOT fully generated because one of SiteDB(s) has a [Failed to Retrieve] status. '
				ELSE 'SessionID [' + SessionID + '] NOT enough data from SiteDBs (' + ISNULL(CONVERT(VARCHAR, SiteCnt),'NULL') + ' out of ' + ISNULL(CONVERT(VARCHAR, @SiteCnt),'NULL') + '). ' END)
				+ 'Please double check [Capture Data Service] process.' AS Content
		FROM CTE_SessionInfo
		WHERE SiteCnt <> @SiteCnt
			OR ExistRetrvFailed = 1
		
		------------------------------Check VALID AlertRule---------------------------------
		--send error log
		INSERT INTO Alert (
			StatusID
			,IsTest
			,RuleID
			,RefID
			,RefExtraInfo
			,Content
		)
		SELECT DISTINCT @StsNew AS StatusID
			,0 AS IsTest
			,ar.RuleID AS RuleID
			,CONVERT(VARCHAR,ar.RuleID) AS RefID
			,'[{"RefInfo":"RuleID"}]' AS RefExtraInfo --RefInfo=RuleID => only send in IT ChatGroup
			,'Invalid AlertRule(' + ISNULL(CONVERT(VARCHAR,ar.RuleID),'NULL') + ')'
				+ ' - ERROR_MESSAGE(Invalid ChatGroupIDs)' AS Content
		FROM AlertRule AS ar WITH (NOLOCK)
		WHERE (
			ISNULL(TRIM(ChatGroupIDs),'') = '' --NULL/BLANK
			OR (TemplateID IS NULL AND REPLACE(TRIM(ChatGroupIDs),',','') <> @IT_ChatGroupID) --TemplateID NULL but NOT only SYS
		)
		AND NOT EXISTS (
			SELECT 1
			FROM Alert AS a WITH (NOLOCK)
			WHERE a.RuleID = ar.RuleID
				AND a.RefID = CONVERT(VARCHAR,ar.RuleID)
				AND DATEADD(MI, 30, a.InsertedTime) > GETDATE() --Not Spam - insert after 30 mins
		)
		
		------------------------------Check EXISTED in Alert---------------------------------
		UPDATE #tmpError_New
		SET RefID = (
				CASE WHEN RefInfo = 'SessionID' THEN SessionID
					WHEN RefInfo = 'NotificationID' THEN CONVERT(NVARCHAR,NotificationID)
				END
			)
			,NotificationID = ISNULL(NotificationID,0)
		
		/*
			For any Error, Key for duplication check: value of RefInfo / LastModifiedTime
			
			|--------------------------------------------------------------------------------------------------------------------------------|
			| **Notification Rules**                                                                                                         |
			|--------------------------------------------------------------------------------------------------------------------------------|
			| RuleID | ChatGrouplDs   | Template	  | Key to check dup | Remark |
			|--------|----------------|---------------|------------------|-------------------------------------------------------------------
			| 1 	 | SYS 			  | N/A			  | SessionID 		 | For [Capture Data Service] process, SessionID [Retrieving] over 2 * [SystemSetting.VName = Retrieving_WaitSec]
			| 		 | 				  | 			  | SessionID 		 | For [Generate Notif Service] process, SessionID [Generating] over 60s
			| 		 | 				  | 			  | NotificationID	 | For [Generate Notif Service] process, Notification. StatusID = Generating over 60s
			| 		 | 				  | 			  | NotificationID	 | For [Insert Message Service] process, Notification StatusID = Sending over 60s
			| 		 | 				  | 			  | NotificationID	 | For [Generate LAP Notif Service] process, NOT EXISTS after being approved MessageID over 60s
			| 		 | 				  | 			  | NotificationID	 | For [Generate LAP Notif Service] process, Notification StatusID = Generating over 60s / Failed to Generate
			| 2 	 | OST,777		  | 8 (Message 2) | NotificationID	 | Any [New] Notification(s) of Msg
			| 3 	 | SYS,OST,777	  | 9 (Message 3) | NotificationID	 | Any [Failed to Send] Notification(s)
			| 4 	 | SYS,OST,777	  | 7 (Message 1) | SessionID 		 | Any [Failed to Generate] SessionID / Notification
			| 5 	 | SYS,OST,777	  | 10(Message 4) | SessionID 		 | Missing data from any SiteGroupDB over 2 * [SystemSetting.VName = Retrieving_WaitSec]
			|--------------------------------------------------------------------------------------------------------------------------------
		*/
		IF EXISTS (SELECT 1 FROM #tmpError_New)
		BEGIN
			CREATE CLUSTERED INDEX CIX_tmpError_New ON #tmpError_New(RuleID, SessionID, NotificationID, RefInfo)
			
			INSERT INTO #tmpError_Old (
				RuleID
				,IsTest
				,RefInfo
				,SessionID
				,LastModifiedTime
				,NotificationID
			)
			SELECT DISTINCT a.RuleID
				,a.IsTest
				,ext.RefInfo
				,(CASE WHEN ext.RefInfo = 'SessionID' THEN a.RefID ELSE ext.SessionID END) AS SessionID
				/*
					Special for RuleID = 5
						=> Ignore check LastModifiedTime
						=> SessionID notify only 1 time
				*/
				,(CASE WHEN sn.RuleID = 5 THEN sn.LastModifiedTime ELSE ext.LastModifiedTime END) AS LastModifiedTime
				,(CASE WHEN ext.RefInfo = 'NotificationID' THEN a.RefID ELSE 0 END) AS NotificationID --0 if NotificationID IS NULL
			FROM Alert AS a WITH (NOLOCK)
				INNER JOIN #tmpError_New AS sn ON a.RuleID = sn.RuleID AND a.RefID = sn.RefID
				OUTER APPLY OPENJSON(a.RefExtraInfo) WITH (
						RefInfo VARCHAR(50) '$.RefInfo'
						,SessionID NVARCHAR(50) '$.SessionID'
						,LastModifiedTime DATETIME '$.LastModifiedTime'
					) AS ext --OPENJSON case-sensitive
			WHERE ISJSON(a.RefExtraInfo) = 1
			
			CREATE CLUSTERED INDEX CIX_tmpError_Old ON #tmpError_Old(RuleID, SessionID, NotificationID, RefInfo)
			
			----------------RefInfo = 'SessionID'---------------------
			INSERT INTO Alert (
				StatusID
				,RuleID
				,IsTest
				,RefID
				,RefExtraInfo
				,Content
			)
			SELECT DISTINCT @StsNew AS StatusID
				,n.RuleID
				,n.IsTest
				,n.RefID
				,CONVERT(NVARCHAR(MAX),(
					SELECT DISTINCT t.RefInfo
						,t.SessionID
						,t.LastModifiedTime
						,t.MatchID
					FROM #tmpError_New AS t
					WHERE t.InternalID = n.InternalID
					FOR JSON PATH)
				) AS RefExtraInfo
				,n.Content
			FROM #tmpError_New AS n
				LEFT JOIN #tmpError_Old AS o ON n.RuleID = o.RuleID AND n.IsTest = o.IsTest AND n.SessionID = o.SessionID AND n.RefInfo = o.RefInfo AND n.LastModifiedTime = o.LastModifiedTime
			WHERE ISNULL(TRIM(n.Content),'') <> ''
				AND n.RefInfo = 'SessionID'
				AND o.RuleID IS NULL --NOT EXISTS Before
			ORDER BY n.RuleID
				,n.IsTest
				,n.RefID
			
			----------------RefInfo = 'NotificationID'---------------------
			INSERT INTO Alert (
				StatusID
				,RuleID
				,IsTest
				,RefID
				,RefExtraInfo
				,Content
			)
			SELECT DISTINCT @StsNew AS StatusID
				,n.RuleID
				,n.IsTest
				,n.RefID
				,CONVERT(NVARCHAR(MAX),(
					SELECT DISTINCT t.RefInfo
						,t.SessionID
						,t.LastModifiedTime
						,t.MatchID
					FROM #tmpError_New AS t
					WHERE t.InternalID = n.InternalID
					FOR JSON PATH)
				) AS RefExtraInfo
				,n.Content
			FROM #tmpError_New AS n
				LEFT JOIN #tmpError_Old AS o ON n.RuleID = o.RuleID AND n.IsTest = o.IsTest AND n.NotificationID = o.NotificationID AND n.RefInfo = o.RefInfo AND n.LastModifiedTime = o.LastModifiedTime
			WHERE ISNULL(TRIM(n.Content),'') <> ''
				AND n.RefInfo = 'NotificationID'
				AND o.RuleID IS NULL --NOT EXISTS Before
			ORDER BY n.RuleID
				,n.IsTest
				,n.RefID
		END
		
		--write log
		IF EXISTS (
			SELECT 1
			FROM SystemSetting WITH (NOLOCK)
			WHERE VID = 13 --LogMode
				AND VValue = 'Debug'
		)
		AND EXISTS (
			SELECT 1
			FROM Alert WITH (NOLOCK)
			WHERE StatusID = @StsNew
		)
		BEGIN
			INSERT INTO UserLog (
				RefID
				,ActionID
				,UserID
				,LogBef
			)
			SELECT AlertID
				,@LogActionID
				,@LogUserID
				,COMPRESS(N'Info - [AlertService] - Debug - Created Alert with Status = [New]')
			FROM Alert WITH (NOLOCK)
			WHERE StatusID = @StsNew
				AND InsertedTime > @CurrTime
			ORDER BY AlertID
		END
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR --output for web
			,@ErrMsg = ERROR_MESSAGE() --output for web
		
		--send error log
		INSERT INTO Alert (
			StatusID
			,RuleID
			,IsTest
			,RefID
			,RefExtraInfo
			,Content
		)
		SELECT DISTINCT @StsNew AS StatusID
			,0 AS RuleID
			,0 AS IsTest
			,'0' AS RefID
			,'[{"RefInfo":"RuleID"}]' AS RefExtraInfo --RefInfo=RuleID => only send in IT ChatGroup
			,'FAILED while EXEC AlertRule(' + ISNULL(CONVERT(VARCHAR,@RuleID),'NULL') + ')'
				+ ' - ERROR_MESSAGE(' + ISNULL(@ErrMsg,'NULL') + ')' AS Content
		WHERE NOT EXISTS (
			SELECT 1
			FROM Alert AS a WITH (NOLOCK)
			WHERE a.RuleID = 0
				AND a.RefID = '0'
				AND DATEADD(MI, 30, a.InsertedTime) > GETDATE() --Not Spam - insert after 30 mins
		)
		
		INSERT INTO UserLog (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT @RuleID
			,@LogActionID
			,@LogUserID
			,COMPRESS(N'Error - [AlertService] - FAILED while EXEC AlertRule(' + ISNULL(CONVERT(VARCHAR,@RuleID),'NULL') + ')'
					+ ' - ERROR_MESSAGE(' + ISNULL(@ErrMsg,'NULL') + ')')
	END CATCH
	
	DROP TABLE #tmpSettl
	DROP TABLE #tmpMsgNoti
	DROP TABLE #tmpError_New
	DROP TABLE #tmpError_Old
END
