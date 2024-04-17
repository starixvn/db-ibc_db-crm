/*<info serverAlias="DBCRM-MessageNotification" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE MNC_ResultAmendment_PrepareGenLAP
AS
/*
	Created: 20231213@Roy
	Task: Prepare to generate message for LAP
	DB: DBCRM.MessageNotification
	Revisions:
		20231121@Roy: CRM - Implement Message Notifications Center for Result Amendment of Cricket(#197621)
	
	Explanation:
		Steps
			- List of DBMSG NotificationID
				+ NOT EXISTS LAP Notification
				+ Status = Sent => successful push to DBMSG
				+ Scan back only 48 hours from DBMSG NotificationID created
			- Define things need to use RemotingRef Func
		
		Output
			Dataset to get multilanguage from RemotingRef
			----|-------------------|---------------|-------------------|-------------
				|NotificationIDs	|GroupName		|RefId1				|RefId2
			----|-------------------|---------------|-------------------|-------------
				| 50				| RefResource	| ResourceCricket	| G1
				| 52,64				| RefResource	| ResourceCricket	| G2
			----|-------------------|---------------|-------------------|-------------
	
	Example:
		EXEC MessageNotification.dbo.MNC_ResultAmendment_PrepareGenLAP
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @LogUserID INT
		,@LogActionID SMALLINT
		,@NotificationIDs VARCHAR(MAX)
	
	/*
		Load setting
	*/
	SELECT @LogUserID = TRY_CONVERT(INT, VValue)
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 2 --ID of StarixIT
	
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
	
	CREATE TABLE #tmpNoti (
		NotificationID INT
		,SettlIDs VARCHAR(MAX)
	)
	
	CREATE TABLE #tmpRemotingRef (
		NotificationID INT
		,SettlementLogID INT
		,GroupName VARCHAR(50)
		,RefId1 VARCHAR(50)
		,RefId2 VARCHAR(50)
	)
	
	/*
		Get List of Msg NotificationID which not EXISTS Lap NotificationID
	*/
	;WITH CTE_Noti AS (
		SELECT DISTINCT nMsg.NotificationID
			,mMsg.SettlementLogID
			,(CASE WHEN nL.NotificationID IS NOT NULL THEN 1 ELSE 0 END) AS LapCnt
		FROM Notification AS nMsg WITH (NOLOCK)
			INNER JOIN NotiMapping AS mMsg WITH (NOLOCK) ON nMsg.NotificationID = mMsg.NotificationID
			INNER JOIN SettlementResultHist AS rh WITH (NOLOCK) ON mMsg.SettlementLogID = rh.SettlementLogID
			OUTER APPLY (
				SELECT nLap.NotificationID
				FROM NotiMapping AS mLap WITH (NOLOCK)
					INNER JOIN Notification AS nLap WITH (NOLOCK) ON mLap.NotificationID = nLap.NotificationID
				WHERE mLap.SettlementLogID = mMsg.SettlementLogID
					AND nLap.NotificationType = 2 --2: Result Amendment to LAP
			) AS nL
		WHERE nMsg.InsertedTime >= DATEADD(HH, - 48, GETDATE())
			AND nMsg.NotificationType = 1 --1: Result Amendment to Msg
			AND rh.SportType = 50 --Cricket, need modify for others sport
			AND nMsg.StatusID IN (13)--Sent only successful push to DBMSG
			AND nMsg.RefID IS NOT NULL
	)
	INSERT INTO #tmpNoti (
		NotificationID
		,SettlIDs
	)
	SELECT NotificationID
		,STRING_AGG(CONVERT(VARCHAR(MAX),SettlementLogID),',') AS SettlIDs
	FROM CTE_Noti
	GROUP BY NotificationID
	HAVING SUM(LapCnt) = 0
	
	CREATE UNIQUE CLUSTERED INDEX CIX_tmpNoti ON #tmpNoti(NotificationID)
	
	--validate again
	;WITH CTE_Valid AS (
		SELECT i.NotificationID
		FROM #tmpNoti AS i
			INNER JOIN NotificationTarget AS nt WITH (NOLOCK) ON i.NotificationID = nt.NotificationID --must EXISTS Target
			INNER JOIN bodb02.dbo.Site AS s WITH (NOLOCK) ON nt.TargetSite = s.site AND s.isDeposit = 1 --deposit user
		WHERE ISNULL(TRIM(i.SettlIDs),'') <> ''
	)
	DELETE t
	FROM #tmpNoti AS t
		LEFT JOIN CTE_Valid AS v ON t.NotificationID = v.NotificationID
	WHERE v.NotificationID IS NULL
	
	/*
		build things to get from RemotingRef
			Loop foreach NotificationID to create as many LAP noti as possible (ignore Error NotificationID - NOT break if any Failed)
	*/
	DECLARE @JSResource NVARCHAR(MAX)
		,@SettlIDs VARCHAR(MAX)
		,@ErrCode INT = 0
		,@ErrMsg NVARCHAR(2000) = ''
		,@iLoop INT
		
	SELECT @iLoop = MIN(NotificationID)
	FROM #tmpNoti
		
	--loop NotificationID
	WHILE (@iLoop IS NOT NULL)
	BEGIN		
		SELECT @SettlIDs = SettlIDs
		FROM #tmpNoti
		WHERE NotificationID = @iLoop
		
		--get RemotingRef of ResourceID in ActualResult/WrongResult 
		EXEC MNC_ResultAmendment_JSParseResult
			@SettlementLogIDs = @SettlIDs
			,@ParseAmendInfo = 'ActualResult,WrongResult'
			,@ParseTo = 'RemotingRef'
			,@OutJSResource = @JSResource OUTPUT
			,@ErrCode = @ErrCode OUTPUT
			,@ErrMsg = @ErrMsg OUTPUT
		
		IF @ErrCode <> 0
		BEGIN
			--write log
			INSERT INTO [Log] (
				RefID
				,ActionID
				,UserID
				,LogBef
			)
			SELECT NotificationID
				,@LogActionID
				,@LogUserID
				,'Error - FAILED at step [JS Parse ActualResult/WrongResult] while Preparing to gen LAP Notification'
					+ '- SettlIDs = ' + ISNULL(@SettlIDs,'NULL')
					+ '- @JSResource OUTPUT = ' + ISNULL(@JSResource,'NULL')
					+ '- ErrCode = ' + ISNULL(CONVERT(VARCHAR,@ErrCode),'NULL')
					+ '- ERROR_MESSAGE = ' + ISNULL(@ErrMsg,'NULL')
			FROM #tmpNoti
			WHERE NotificationID = @iLoop
		END
		ELSE
		BEGIN
			INSERT INTO #tmpRemotingRef (
				NotificationID
				,SettlementLogID
				,GroupName
				,RefId1
				,RefId2
			)
			SELECT DISTINCT @iLoop AS NotificationID
				,SettlementLogID
				,GroupName
				,RefId1
				,RefId2
			FROM OPENJSON(@JSResource) WITH (
					SettlementLogID INT '$.SettlementLogID'
					,GroupName VARCHAR(50) '$.GroupName'
					,RefId1 VARCHAR(50) '$.RefId1'
					,RefId2 VARCHAR(50) '$.RefId2'
				)--OPENJSON case-sensitive
		END
		
		--reset for loop
		SELECT @iLoop = (SELECT MIN(NotificationID) FROM #tmpNoti WHERE NotificationID > @iLoop)
			,@ErrCode = 0
			,@ErrMsg = ''
	END --end while
	
	-- write log
	;WITH CTE_Ref AS (
		SELECT DISTINCT s.NotificationID
			,CONVERT(NVARCHAR(MAX),(
				SELECT DISTINCT SettlementLogID
					,GroupName
					,RefId1
					,RefId2
				FROM #tmpRemotingRef AS t
				WHERE t.NotificationID = s.NotificationID
				FOR JSON PATH)
			) AS LText
		FROM #tmpRemotingRef AS s
	)
	INSERT INTO [Log] (
		RefID
		,ActionID
		,UserID
		,LogBef
	)
	SELECT i.NotificationID
		,@LogActionID
		,@LogUserID
		,'Debug log - Prepare gen LAP Notification for Msg NotificationIDs(' + ISNULL((SELECT STRING_AGG(CONVERT(VARCHAR(MAX),NotificationID) + '-SettlIDs(' + SettlIDs + ')',',') FROM #tmpNoti),'NO valid Msg NotificationID') + ')'
			+ 'RemotingRef (' + ISNULL(rf.LText,'NULL') + ')'
	FROM #tmpNoti AS i
		LEFT JOIN CTE_Ref AS rf ON i.NotificationID = rf.NotificationID
	WHERE 'Debug' = (SELECT VValue FROM SystemSetting WITH (NOLOCK) WHERE VID = 13) --LogMode
	
	--return for RemotingRef
	;WITH CTE_Ref AS (
		SELECT DISTINCT NotificationID
			,GroupName
			,RefId1
			,RefId2
		FROM #tmpRemotingRef
	)
	SELECT STRING_AGG(CONVERT(VARCHAR(MAX),rf.NotificationID),',') AS NotificationIDs
		,rf.GroupName
		,rf.RefId1
		,rf.RefId2
	FROM CTE_Ref AS rf
	GROUP BY rf.GroupName
		,rf.RefId1
		,rf.RefId2
	
	DROP TABLE #tmpNoti
	DROP TABLE #tmpRemotingRef
END
