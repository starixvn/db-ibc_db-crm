/*<info serverAlias="DBCRM-MessageNotification" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE MNC_Notification_AlertIns
	@ErrCode INT = 0 OUTPUT
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
	
	DECLARE @LogActionID SMALLINT
		,@LogUserID INT
		,@StsNew TINYINT
		,@IT_ChatGroupID VARCHAR(50) = 'SYS' --IT ChatGroupID
		,@RuleID INT
		,@SiteCnt INT = 0
		,@WaitSec INT = 0
		,@FromTime DATETIME = DATEADD(DD, -1, GETDATE())
		,@ToTime DATETIME = GETDATE()
	
	SELECT @StsNew = StatusID
	FROM NotiStatus WITH (NOLOCK)
	WHERE Status = 'New'
	
	SELECT @LogActionID = ActionID
	FROM LogAction WITH (NOLOCK)
	WHERE ActName = ISNULL(OBJECT_NAME(@@PROCID),'Unknown')
	
	SELECT @LogUserID = TRY_CONVERT(INT, VValue)
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 2 --ID of StarixIT
	
	SELECT @ErrCode = 0
		,@ErrMsg = ''
	
	CREATE TABLE #tmpSettl (
		SessionID NVARCHAR(50) NOT NULL
		,SettlementLogID INT NOT NULL
		,LastModifiedTime DATETIME NOT NULL
		------------------
		,MatchID INT NOT NULL
		,Status VARCHAR(50) NOT NULL
	)
	
	CREATE TABLE #tmpMsgNoti (
		MsgNotiID INT
		,LapNotiID INT
		,MessageID INT
		,MatchID INT
		,Status VARCHAR(50)
		,LastModifiedTime DATETIME
		,SessionID NVARCHAR(50)
		,SettlementLogID INT
	)

	CREATE TABLE #tmpError_New (
		InternalID INT IDENTITY (1,1)
		,RefID NVARCHAR(50)
		--------
		,RuleID INT NOT NULL
		,SessionID NVARCHAR(50)
		,LastModifiedTime DATETIME
		--------
		,SettlementLogID INT
		,NotificationID INT
		,MatchID INT
		,Content NVARCHAR(4000)
	)

	CREATE TABLE #tmpError_Old (
		RuleID INT NOT NULL
		,SessionID NVARCHAR(50)
		,SettlementLogID INT
		,LastModifiedTime DATETIME
		,NotificationID INT
	)
	---------------------Prepare-------------------------
	INSERT INTO #tmpSettl (
		SessionID
		,SettlementLogID
		,LastModifiedTime
		,MatchID
		,Status
	)
	SELECT DISTINCT rh.SessionID
		,rh.SettlementLogID
		,rh.LastModifiedTime
		,rh.MatchID
		,st.Status
	FROM MessageNotification.dbo.SettlementResultHist AS rh WITH (NOLOCK)
		LEFT JOIN MessageNotification.dbo.NotiStatus AS st WITH (NOLOCK) ON rh.StatusID = st.StatusID
	WHERE rh.LastModifiedTime > @FromTime
		AND rh.LastModifiedTime <= @ToTime
		AND rh.SportType = 50 --Cricket, need modify for others sport
	
	CREATE CLUSTERED INDEX CIX_tmpSettl ON #tmpSettl(SessionID)
	
	INSERT INTO #tmpMsgNoti (
		MsgNotiID
		,MessageID
		,MatchID
		,Status
		,LastModifiedTime
		,SessionID
		,SettlementLogID
	)
	SELECT DISTINCT nMsg.NotificationID AS MsgNotiID
		,nMsg.RefID AS MessageID
		,rh.MatchID
		,st.Status
		,nMsg.LastModifiedTime
		,rh.SessionID
		,rh.SettlementLogID
	FROM MessageNotification.dbo.Notification AS nMsg WITH (NOLOCK)
		LEFT JOIN MessageNotification.dbo.NotiMapping AS mMsg WITH (NOLOCK) ON nMsg.NotificationID = mMsg.NotificationID
		LEFT JOIN MessageNotification.dbo.SettlementResultHist AS rh WITH (NOLOCK) ON mMsg.SettlementLogID = rh.SettlementLogID
		LEFT JOIN MessageNotification.dbo.NotiStatus AS st WITH (NOLOCK) ON nMsg.StatusID = st.StatusID
	WHERE nMsg.LastModifiedTime > @FromTime
		AND nMsg.LastModifiedTime <= @ToTime
		AND nMsg.NotificationType = 1 --1: Result Amendment to Msg
		AND st.Status IN ( 'Generating', 'Sending', 'Sent', 'New', 'Failed to Send')
	
	DELETE n
	FROM #tmpMsgNoti AS n
		LEFT JOIN MessageNotification.dbo.SettlementResultHist AS rh WITH (NOLOCK) ON n.SettlementLogID = rh.SettlementLogID
	WHERE ISNULL(rh.SportType,0) <> 50 --Cricket, need modify for others sport
	
	CREATE CLUSTERED INDEX CIX_tmpMsgNoti ON #tmpMsgNoti(MsgNotiID)
	
	-------------------------------------------------------
	IF EXISTS (SELECT 1 FROM #tmpSettl)
		OR EXISTS (SELECT 1 FROM #tmpMsgNoti)
	BEGIN TRY
		/*
			#1.RA_SysErr - Running Status Too Long - OST
			Message 1
		*/
		SELECT @RuleID = 1
		
		---1.For [Capture Data Service] process, [Retrieving] over 2*Configuration_WaitSec---
		SELECT @WaitSec = ISNULL(TRY_CONVERT(INT, VValue),0) * 2
		FROM MessageNotification.dbo.SystemSetting WITH (NOLOCK)
		WHERE VID = 11 --Retrieving_WaitSec
		
		;WITH CTE_LongSession AS (
			SELECT SessionID
				,MIN(LastModifiedTime) AS Mi_LastModifiedTime
			FROM #tmpSettl
			WHERE Status = 'Retrieving'
			GROUP BY SessionID
			HAVING DATEDIFF(SECOND, MIN(LastModifiedTime),GETDATE()) > @WaitSec
		)
		INSERT INTO #tmpError_New (
			RuleID
			,SessionID
			,LastModifiedTime
			--------------
			,SettlementLogID
			,MatchID
			,Content
		)
		SELECT DISTINCT @RuleID
			,l.SessionID
			,rh.LastModifiedTime
			--------------
			,rh.SettlementLogID
			,rh.MatchID
			,'SessionID [' + l.SessionID + '] in [Retrieving] state too long, exceeding '+ ISNULL(CONVERT(VARCHAR, @WaitSec),'NULL')+' seconds. Please double check [Capture Data Service] process.' AS Content
		FROM CTE_LongSession AS l
			LEFT JOIN #tmpSettl AS rh ON l.SessionID = rh.SessionID AND rh.Status = 'Retrieving'
		
		---2.For [Generate Notif Service] process, [Generating] over 60s---
		SELECT @WaitSec = 60

		;WITH CTE_LongSession AS (
			SELECT SessionID
				,MIN(LastModifiedTime) AS Mi_LastModifiedTime
			FROM #tmpSettl
			WHERE Status = 'Generating'
			GROUP BY SessionID
			HAVING DATEDIFF(SECOND, MIN(LastModifiedTime),GETDATE()) > @WaitSec
		)
		INSERT INTO #tmpError_New (
			RuleID
			,SessionID
			,LastModifiedTime
			--------------
			,SettlementLogID
			,MatchID
			,Content
		)
		SELECT DISTINCT @RuleID
			,rh.SessionID
			,rh.LastModifiedTime
			--------------
			,rh.SettlementLogID
			,rh.MatchID
			,'SessionID [' + rh.SessionID + '] in [Generating] Msg state too long, exceeding '+ ISNULL(CONVERT(VARCHAR, @WaitSec),'NULL')+' seconds. Please double check [Generate Notif Service] process.' AS Content
		FROM CTE_LongSession AS l
			LEFT JOIN #tmpSettl AS rh ON l.SessionID = rh.SessionID AND rh.Status = 'Generating'
		
		--3.For Notification.StatusID = Generating / Sending
		SELECT @WaitSec = 60
		
		INSERT INTO #tmpError_New (
			RuleID
			,SessionID
			,LastModifiedTime
			--------------
			,SettlementLogID
			,MatchID
			,Content
		)
		SELECT DISTINCT @RuleID
			,m.SessionID
			,m.LastModifiedTime
			--------------
			,m.SettlementLogID
			,m.MatchID
			,(CASE WHEN m.Status = 'Generating' THEN 'Notification(' + ISNULL(CONVERT(VARCHAR, m.MsgNotiID),'NULL') + ') of SessionID [' + m.SessionID + '] in [Generating] Msg state too long, exceeding '+ ISNULL(CONVERT(VARCHAR, @WaitSec),'NULL')+' seconds. Please double check [Generate Notification] process.'
				ELSE 'Notification(' + ISNULL(CONVERT(VARCHAR, m.MsgNotiID),'NULL') + ') of SessionID [' + m.SessionID + '] in [Sending] state too long, exceeding '+ ISNULL(CONVERT(VARCHAR, @WaitSec),'NULL')+' seconds. Please double check [Insert Message Service] process.'
			END) AS Content
		FROM #tmpMsgNoti AS m
		WHERE m.Status IN ('Generating', 'Sending')
			AND DATEDIFF(SECOND, m.LastModifiedTime, GETDATE()) > @WaitSec
		
		
		/*
			#2.RA_NewNoti - Need Review
			Message 2
		*/
		SELECT @RuleID = 2
		
		INSERT INTO #tmpError_New (
			RuleID
			,SessionID
			,LastModifiedTime
			-----------
			,NotificationID
			,MatchID
			,Content
		)
		SELECT DISTINCT @RuleID
			,SessionID
			,LastModifiedTime
			-----------
			,MsgNotiID AS NotificationID
			,MatchID
			,'Result Amendment message(s) for SessionID ['+ ISNULL(SessionID,'NULL') +'] created. Please review it.' AS Content
		FROM #tmpMsgNoti
		WHERE Status = 'New' --Only for OST, LAP notified by Chatbot LIC
		
		/*
			#3.RA_PushErr - Sent Issue
			Message 3
		*/
		SELECT @RuleID = 3
		
		INSERT INTO #tmpError_New (
			RuleID
			,SessionID
			,LastModifiedTime
			-----------
			,NotificationID
			,MatchID
			,Content
		)
		SELECT DISTINCT @RuleID
			,SessionID
			,LastModifiedTime
			-----------
			,MsgNotiID AS NotificationID
			,MatchID
			,'Result Amendment message associated with SessionID ['+ ISNULL(SessionID,'NULL') +'] was NOT successfully inserted to DBMSG. Please review it.' AS Content
		FROM #tmpMsgNoti
		WHERE Status = 'Failed to Send'
		
		/*
			#4.RA_SysErr - Missing From Any SiteGroupDB
			Message 1
		*/
		SELECT @RuleID = 4
		
		SELECT @WaitSec = ISNULL(TRY_CONVERT(INT, VValue),0) * 2
		FROM MessageNotification.dbo.SystemSetting WITH (NOLOCK)
		WHERE VID = 11 --Retrieving_WaitSec
		
		SELECT @SiteCnt = COUNT(DISTINCT SiteDBGroupID)
		FROM bodb02.dbo.SiteDBConfig WITH (NOLOCK)
		WHERE SiteDBGroupID <> 0
		
		;WITH CTE_SessionInfo AS (
			SELECT s.SessionID
				,s.MatchID
				,COUNT(DISTINCT rh.SiteDBGroupID) AS SiteCnt
				,MIN(rh.InsertedTime) AS Mi_InsertedTime
			FROM #tmpSettl AS s
				INNER JOIN MessageNotification.dbo.SettlementResultHist AS rh WITH (NOLOCK) ON s.SessionID = rh.SessionID
			GROUP BY s.SessionID
				,s.MatchID
		)
		,CTE_MissReason AS (
			SELECT SessionID
				,MatchID
				,(CASE WHEN SiteCnt = @SiteCnt THEN 1 --Enough SiteDBs count => Ignore
						WHEN DATEDIFF(SECOND, Mi_InsertedTime,GETDATE()) < @WaitSec THEN 2 --NOT enough SiteDBs count BUT Wait time < @WaitSec => Ignore
						ELSE 0
					END
				) AS MissReason
			FROM CTE_SessionInfo
		)
		INSERT INTO #tmpError_New (
			RuleID
			,SessionID
			-----------
			,MatchID
			,Content
		)
		SELECT DISTINCT @RuleID
			,SessionID
			-----------
			,MatchID
			,'SessionID [' + ISNULL(SessionID,'NULL') + '] NOT enough data from SiteDBs, exceeding '+ ISNULL(CONVERT(VARCHAR, @WaitSec),'NULL')+' seconds. Please double check [Capture Data Service] process.' AS Content
		FROM CTE_MissReason
		WHERE MissReason = 0
		
		/*
			#5.RA_SysErr - Failed Status
			Message 1
		*/
		SELECT @RuleID = 5
		
		INSERT INTO #tmpError_New (
			RuleID
			,SessionID
			,LastModifiedTime
			-----------
			,SettlementLogID
			,MatchID
			,Content
		)
		SELECT DISTINCT @RuleID
			,rh.SessionID
			,rh.LastModifiedTime
			-----------
			,rh.SettlementLogID
			,rh.MatchID
			,'Result Amendment message associated with SessionID ['+ ISNULL(rh.SessionID,'NULL') +'] was NOT successfully '
				+ (CASE WHEN rh.Status = 'Failed to Retrieve' THEN 'RETRIEVED' ELSE 'GENERATED' END)
				+ '. Please review it.' AS Content
		FROM #tmpSettl AS rh
		WHERE rh.Status IN ('Failed to Retrieve','Failed to Generate', 'Unknown')
		
		/*
			#6.RA_SysErr - Running Status Too Long - SYS
			Message 1
			
			For [Generate LAP Notif Service] process, over 60s
		*/
		SELECT @RuleID = 6
		
		;WITH CTE_NOLAP AS (
			SELECT DISTINCT i.MsgNotiID
				,i.MatchID
				,i.LastModifiedTime
				,nLap.NotificationID AS LapNotiID
				,(CASE WHEN nLap.NotificationID IS NULL THEN 'NOLAP' ELSE 'Generating LAP' END) AS ErrType
			FROM #tmpMsgNoti AS i
				LEFT JOIN MessageNotification.dbo.Notification AS nLap WITH (NOLOCK) ON i.MessageID = nLap.RefID AND nLap.NotificationType = 2 --2: Result Amendment to LAP
			WHERE i.MatchID IS NOT NULL
				AND (
					nLap.NotificationID IS NULL --NOLAP
					OR nLap.StatusID = 5 --Generating LAP
				)
				AND EXISTS (
					SELECT 1
					FROM MessageNotification.dbo.NotificationTarget AS nt WITH (NOLOCK)
						LEFT JOIN bodb02.dbo.Site AS s WITH (NOLOCK) ON nt.TargetSite = s.site AND s.isDeposit = 1 --deposit user
					WHERE i.MsgNotiID = nt.NotificationID
						AND s.site IS NOT NULL --EXISTS [deposit] Target
				)
				AND DATEDIFF(SECOND, i.LastModifiedTime,GETDATE()) > @WaitSec --[after being approved MessageID] => Use Notification.LastModifiedTime
		)
		INSERT INTO #tmpError_New (
			RuleID
			,SessionID
			,LastModifiedTime
			-----------
			,SettlementLogID
			,MatchID
			,Content
		)
		SELECT DISTINCT @RuleID
			,n.SessionID
			,ck.LastModifiedTime --[after being approved MessageID]
			-----------
			,n.SettlementLogID
			,ck.MatchID
			,(CASE WHEN ck.ErrType = 'NOLAP' THEN 'LAP Notification of SessionID [' + n.SessionID + '] NOT EXISTS after being approved MessageID [' + CONVERT(VARCHAR,n.MessageID) + '] for more than '+ ISNULL(CONVERT(VARCHAR, @WaitSec),'NULL')+' seconds. Please double check [Generate LAP Notif Service] process.'
				ELSE 'LAP Notification(' + ISNULL(CONVERT(VARCHAR, ck.LapNotiID),'NULL') + ') of SessionID [' + n.SessionID + '] in [Generating] state too long, exceeding ' + ISNULL(CONVERT(VARCHAR, @WaitSec),'NULL') + ' seconds. Please double check [Generate LAP Notif Service] process.'
			END) AS Content
		FROM CTE_NOLAP AS ck
			LEFT JOIN #tmpMsgNoti AS n WITH (NOLOCK) ON ck.MsgNotiID = n.MsgNotiID
		------------------------------Check VALID AlertRule---------------------------------
		--send error log
		INSERT INTO Alert (
			StatusID
			,RuleID
			,RefID
			,RefExtraInfo
			,Content
		)
		SELECT DISTINCT @StsNew AS StatusID
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
			CASE WHEN RuleID = 1 THEN SessionID
				WHEN RuleID = 2 THEN CONVERT(VARCHAR,NotificationID)
				WHEN RuleID = 3 THEN CONVERT(VARCHAR,NotificationID)
				WHEN RuleID = 4 THEN SessionID
				WHEN RuleID = 5 THEN SessionID
				WHEN RuleID = 6 THEN SessionID
			END
		)
		
		/*
			RuleID 1 n.SessionID = o.SessionID AND n.LastModifiedTime = o.LastModifiedTime AND n.SettlementLogID = o.SettlementLogID
			RuleID 2 n.SessionID = o.SessionID AND n.LastModifiedTime = o.LastModifiedTime AND n.NotificationID = o.NotificationID
			RuleID 3 n.SessionID = o.SessionID AND n.LastModifiedTime = o.LastModifiedTime AND n.NotificationID = o.NotificationID
			RuleID 4 n.SessionID = o.SessionID
			RuleID 5 n.SettlementLogID = o.SettlementLogID AND n.SessionID = o.SessionID AND n.LastModifiedTime = o.LastModifiedTime
			RuleID 6 n.SessionID = o.SessionID AND n.SettlementLogID = o.SettlementLogID AND n.LastModifiedTime = o.LastModifiedTime
		*/
		IF EXISTS (SELECT 1 FROM #tmpError_New)
		BEGIN
			CREATE CLUSTERED INDEX CIX_tmpError_New ON #tmpError_New(RuleID, SessionID, LastModifiedTime)
			
			INSERT INTO #tmpError_Old (
				RuleID
				,SessionID
				,SettlementLogID
				,LastModifiedTime
				,NotificationID
			)
			SELECT DISTINCT a.RuleID
				,(CASE WHEN ext.RefInfo = 'SessionID' THEN a.RefID ELSE ext.SessionID END) AS SessionID
				,ext.SettlementLogID
				,ext.LastModifiedTime
				,(CASE WHEN ext.RefInfo = 'NotificationID' THEN a.RefID END) AS NotificationID
			FROM MessageNotification.dbo.Alert AS a WITH (NOLOCK)
				INNER JOIN #tmpError_New AS sn ON a.RuleID = sn.RuleID AND a.RefID = sn.RefID
				OUTER APPLY OPENJSON(a.RefExtraInfo) WITH (
						RefInfo VARCHAR(50) '$.RefInfo'
						,SettlementLogID INT '$.SettlementLogID'
						,SessionID NVARCHAR(50) '$.SessionID'
						,LastModifiedTime DATETIME '$.LastModifiedTime'
					) AS ext --OPENJSON case-sensitive
			WHERE ISJSON(a.RefExtraInfo) = 1
			
			CREATE CLUSTERED INDEX CIX_tmpError_Old ON #tmpError_Old(RuleID, SessionID, LastModifiedTime)
			
			-------------------------------------
			INSERT INTO Alert (
				StatusID
				,RuleID
				,RefID
				,RefExtraInfo
				,Content
			)
			SELECT DISTINCT @StsNew AS StatusID
				,n.RuleID
				,n.RefID
				,CONVERT(NVARCHAR(MAX),(
					SELECT DISTINCT
						(CASE WHEN RuleID IN (1,4,5,6) THEN 'SessionID'
							WHEN RuleID IN (2,3) THEN 'NotificationID'
						END) AS RefInfo
						,t.SettlementLogID
						,t.SessionID
						,t.LastModifiedTime
						,t.MatchID
					FROM #tmpError_New AS t
					WHERE t.InternalID = n.InternalID
					FOR JSON PATH)
				) AS RefExtraInfo
				,n.Content
			FROM #tmpError_New AS n
			WHERE ISNULL(TRIM(n.Content),'') <> ''
				AND (
					(n.RuleID IN (1,5,6) AND NOT EXISTS (SELECT 1 FROM #tmpError_Old AS o WHERE o.RuleID = n.RuleID AND n.SessionID = o.SessionID AND n.LastModifiedTime = o.LastModifiedTime AND n.SettlementLogID = o.SettlementLogID ))
					OR (n.RuleID IN (2,3) AND NOT EXISTS (SELECT 1 FROM #tmpError_Old AS o WHERE o.RuleID = n.RuleID AND n.SessionID = o.SessionID AND n.LastModifiedTime = o.LastModifiedTime AND n.NotificationID = o.NotificationID ))
					OR (n.RuleID = 4 AND NOT EXISTS (SELECT 1 FROM #tmpError_Old AS o WHERE o.RuleID = n.RuleID AND n.SessionID = o.SessionID ))
				)
			ORDER BY n.RuleID
				,n.RefID
		END
		
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR --output for web
			,@ErrMsg = ERROR_MESSAGE() --output for web
		
		--send error log
		INSERT INTO Alert (
			StatusID
			,RuleID
			,RefID
			,RefExtraInfo
			,Content
		)
		SELECT DISTINCT @StsNew AS StatusID
			,0 AS RuleID
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
			,COMPRESS(N'Error - AlertService - FAILED while EXEC AlertRule(' + ISNULL(CONVERT(VARCHAR,@RuleID),'NULL') + ')'
					+ ' - ERROR_MESSAGE(' + ISNULL(@ErrMsg,'NULL') + ')')
		
		--Continue exec for next RuleID
		SELECT @RuleID = (SELECT MIN(RuleID) FROM AlertRule WITH (NOLOCK) WHERE RuleID > @RuleID)
	END CATCH
	
	DROP TABLE #tmpSettl
	DROP TABLE #tmpMsgNoti
	DROP TABLE #tmpError_New
	DROP TABLE #tmpError_Old
END
