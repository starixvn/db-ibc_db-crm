/*<info serverAlias="DBCRM-MessageNotification" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE MNC_PushNotification_PrepareNoti
AS
/*
	Created: 20231213@Roy
	Task: Prepare to start Push Notification process
	DB: DBCRM.MessageNotification
	Revisions:
		20231121@Roy: CRM - Implement Message Notifications Center for Result Amendment of Cricket(#197621)
	
	Explanation:
		Steps
			- Check / Update [Push Notification] Process Status
			- Get [Sending] NotificationID
			- Parse Notification data to JSON
		
		Output
			Dataset
			----|-------------------|---------------------------------
				|NotificationID		|JSNotification
			----|-------------------|---------------------------------
				| 50				| Notification data as JSON format
				| 52				| Notification data as JSON format
			----|-------------------|---------------------------------
	
	Example:
		EXEC MessageNotification.dbo.MNC_PushNotification_PrepareNoti
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @LogUserID INT
		,@LogActionID SMALLINT
		,@StsSending TINYINT
		,@ErrLogPrefix NVARCHAR(150) = ''
		,@InfLogPrefix NVARCHAR(150) = ''
		,@ProcessID INT = 6 --Process_PushNoti
		,@JSNotification NVARCHAR(MAX)
		,@iLoop INT = 0
	
	/*
		Load setting
	*/
	SELECT @LogUserID = TRY_CONVERT(INT, VValue)
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 2 --ID of StarixIT
	
	SELECT @StsSending = StatusID
	FROM NotiStatus WITH (NOLOCK)
	WHERE Status = 'Sending'
	
	--Insert if NOT EXISTS
	INSERT INTO LogAction (ActName)
	SELECT o.[name]
	FROM sys.objects AS o WITH (NOLOCK)
	WHERE o.[is_ms_shipped] = 0 --created by user
		AND o.[type] IN (
			'P', -- stored procedures
			'FN', -- scalar functions 
			'IF', -- inline table-valued functions
			'TF' -- table-valued functions
		)
		AND o.[name] NOT LIKE '_delete%'
		AND o.[name] NOT LIKE '[_delete%'
		AND o.[name] NOT LIKE '_DEL%'
		AND NOT EXISTS (
			SELECT 1
			FROM LogAction AS a
			WHERE a.ActName = o.[name]
		)
	
	SELECT @LogActionID = ActionID
	FROM LogAction WITH (NOLOCK)
	WHERE ActName = ISNULL(OBJECT_NAME(@@PROCID),'Unknown')
	
	SELECT @ErrLogPrefix = 'Error - '
	SELECT @InfLogPrefix = 'Info - '
	
	--check current status of [Push Notification] process
	IF NOT EXISTS (SELECT 1 FROM SystemSetting WHERE VID = @ProcessID AND VValue = 'Done') --ProcessStatus_PushNoti
	BEGIN
		
		SELECT NULL AS NotificationID
			,NULL AS JSNotification
		WHERE 1 = 0
		
		INSERT INTO [Log] (
			ActionID
			,UserID
			,LogBef
		)
		SELECT @LogActionID
			,@LogUserID
			,@ErrLogPrefix + 'Another [Push Notification] Process(' + CONVERT(VARCHAR,@ProcessID) + ') is still active.'
		
		RETURN
	END
	ELSE
	BEGIN
		UPDATE SystemSetting WITH (ROWLOCK,UPDLOCK)
		SET VValue = 'Running'
		WHERE VID = @ProcessID
			AND VValue = 'Done'
		
		INSERT INTO [Log] (
			ActionID
			,UserID
			,LogBef
		)
		SELECT @LogActionID
			,@LogUserID
			,@InfLogPrefix + 'Start [Push Notification Msg process - Prepare] - change ProcessID(' + ISNULL(CONVERT(VARCHAR,@ProcessID),'NULL') + ') to [' + ISNULL(VValue,'NULL') + ']' AS LogBef
		FROM SystemSetting WITH (NOLOCK)
		WHERE VID = @ProcessID
	END
	
	--------------------------------------------------------
	CREATE TABLE #tmpResult (
		NotificationID INT
		,JSNotification NVARCHAR(MAX)
	)
	
	CREATE TABLE #tmpJSData (
		ObjectName NVARCHAR(150)
		,JSONData NVARCHAR(MAX)
	)
	
	CREATE TABLE #tmpMsg (
		NotificationID INT
		,Content_en NVARCHAR(4000)
		,Content_ch NVARCHAR(4000)
		,Content_cs NVARCHAR(4000)
		,MatchID INT
		,LeagueGroupID SMALLINT
		,Creator INT
		,CreatorName NVARCHAR(50)
	)
	
	CREATE TABLE #tmpMsgTarget (
		NotificationID INT
		,TargetID INT NOT NULL
		,TargetName NVARCHAR(30)
		,BetTransID VARCHAR(MAX)
	)
	
	CREATE TABLE #tmpSendingNoti (
		NotificationID INT NOT NULL
	)
	
	/*
		Get Sending NotificationID
	*/
	INSERT INTO #tmpSendingNoti (NotificationID)
	SELECT DISTINCT n.NotificationID
	FROM Notification AS n WITH (ROWLOCK,UPDLOCK)
	WHERE n.StatusID = @StsSending
		AND n.NotificationType = 1 --Result Amendment to Msg
		AND EXISTS (SELECT 1 FROM NotificationTarget AS nt WITH (NOLOCK) WHERE nt.NotificationID = n.NotificationID)
	
	CREATE CLUSTERED INDEX CIX_tmpSendingNoti ON #tmpSendingNoti(NotificationID)
	
	----update NotificationTarget
	UPDATE nt
	SET nt.StatusID = @StsSending
	FROM NotificationTarget AS nt WITH (ROWLOCK,UPDLOCK)
		INNER JOIN #tmpSendingNoti AS s ON nt.NotificationID = s.NotificationID
	WHERE nt.StatusID <> @StsSending
	
	--write log
	INSERT INTO [Log] (
		ActionID
		,UserID
		,LogBef
	)
	SELECT @LogActionID
		,@LogUserID
		,@InfLogPrefix + 'Debug - [Push Notification Msg process - Prepare]'
						+ ' - NotiIDs('
							+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
										SELECT NotificationID
										FROM #tmpSendingNoti
										ORDER BY NotificationID
										FOR JSON PATH
									))
								),'NO ROW') + ')'
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 13 --LogMode
		AND VValue = 'Debug'
	
	----------Get Notification data----------
	;WITH CTE_NotiExtra AS (
		SELECT DISTINCT s.NotificationID
			,nex.MatchID
			,nex.LeagueGroupID
		FROM #tmpSendingNoti AS s
			INNER JOIN NotificationExtra AS ne WITH (NOLOCK) ON ne.NotificationID = s.NotificationID
			OUTER APPLY OPENJSON(ne.ExtraInfo) WITH (
				MatchID INT '$.MatchID'
				,LeagueGroupID SMALLINT '$.LeagueGroupID'
			) AS nex--OPENJSON case-sensitive
		WHERE ISJSON(ne.ExtraInfo) = 1
	)
	INSERT INTO #tmpMsg (
		NotificationID
		,Content_en
		,Content_ch
		,Content_cs
		,MatchID
		,LeagueGroupID
		,Creator
		,CreatorName
	)
	SELECT DISTINCT s.NotificationID
		,n.Content_en
		,n.Content_ch
		,n.Content_cs
		,ne.MatchID
		,ne.LeagueGroupID
		,@LogUserID AS Creator --ID of StarixIT
		,c.username AS CreatorName --StarixIT
	FROM #tmpSendingNoti AS s
		INNER JOIN Notification AS n WITH (NOLOCK) ON s.NotificationID = n.NotificationID
		LEFT JOIN CTE_NotiExtra AS ne ON s.NotificationID = ne.NotificationID
		LEFT JOIN bodb02.dbo.Customer AS c WITH (NOLOCK) ON c.CustID = @LogUserID
	
	----------Get NotificationTarget data----------
	;WITH CTE_NotiTarget AS (
		SELECT DISTINCT s.NotificationID
			,nt.TargetID
			,ex.TransID
		FROM #tmpSendingNoti AS s
			INNER JOIN NotificationTarget AS nt WITH (NOLOCK) ON s.NotificationID = nt.NotificationID
			OUTER APPLY OPENJSON(nt.ExtraInfo) WITH (
				TransID BIGINT '$.TransID'
			) AS ex--OPENJSON case-sensitive
		WHERE ISJSON(nt.ExtraInfo) = 1
	)
	INSERT INTO #tmpMsgTarget (
		NotificationID
		,TargetID
		,TargetName
		,BetTransID
	)
	SELECT nt.NotificationID
		,nt.TargetID
		,c.username AS TargetName
		,STRING_AGG(CONVERT(VARCHAR(MAX),nt.TransID),',')
	FROM CTE_NotiTarget AS nt
		LEFT JOIN bodb02.dbo.Customer AS c WITH (NOLOCK) ON nt.TargetID = c.CustID
	GROUP BY nt.NotificationID
		,nt.TargetID
		,c.username
	
	----------Build dataset---------
	SELECT @iLoop = MIN(NotificationID)
	FROM #tmpSendingNoti
	
	WHILE EXISTS( SELECT 1 FROM #tmpSendingNoti WHERE NotificationID = @iLoop)
	BEGIN
		TRUNCATE TABLE #tmpJSData
		
		INSERT INTO #tmpJSData (ObjectName, JSONData)
		SELECT 'Notification' AS ObjectName
			,CONVERT(NVARCHAR(MAX),(
						SELECT NotificationID
							,Content_en
							,Content_ch
							,Content_cs
							,MatchID
							,LeagueGroupID
							,Creator
							,CreatorName
						FROM #tmpMsg
						WHERE NotificationID = @iLoop
						FOR JSON AUTO
					)) AS JSONData
		
		INSERT INTO #tmpJSData (ObjectName, JSONData)
		SELECT 'NotificationTarget' AS ObjectName
			,CONVERT(NVARCHAR(MAX),(
						SELECT TargetID
							,TargetName
							,BetTransID
						FROM #tmpMsgTarget
						WHERE NotificationID = @iLoop
						FOR JSON AUTO
					)) AS JSONData
		
		SELECT @JSNotification = CONVERT(NVARCHAR(MAX),(
					SELECT ObjectName
						,JSONData
					FROM #tmpJSData
					FOR JSON AUTO
				))
				
		INSERT INTO #tmpResult (
			NotificationID
			,JSNotification
		)
		SELECT @iLoop AS NotificationID
			,@JSNotification AS JSNotification
		
		--reset for loop
		SELECT @iLoop = (SELECT TOP 1 NotificationID FROM #tmpSendingNoti WHERE NotificationID > @iLoop ORDER BY NotificationID)
	END
	
	SELECT NotificationID
		,JSNotification
	FROM #tmpResult
	
	--Mark completed [Push Notification] process => MNC_PushNotification_Complete
	-- UPDATE SystemSetting WITH (ROWLOCK,UPDLOCK)
	-- SET VValue = 'Done'
	-- WHERE VID = @ProcessID
		-- AND VValue = 'Running'
		-- AND NOT EXISTS (SELECT 1 FROM #tmpResult)
	
	--write log
	INSERT INTO [Log] (
		ActionID
		,UserID
		,LogBef
	)
	SELECT @LogActionID
		,@LogUserID
		,@InfLogPrefix + '[Push Notification Msg process - Prepare]'
						+ ' - Return('
							+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
										SELECT NotificationID
											,JSNotification
										FROM #tmpResult
										ORDER BY NotificationID
										FOR JSON PATH
									))
								),'NO ROW') + ')'
	
	DROP TABLE #tmpResult
	DROP TABLE #tmpJSData
	DROP TABLE #tmpMsg
	DROP TABLE #tmpMsgTarget
	DROP TABLE #tmpSendingNoti
END
