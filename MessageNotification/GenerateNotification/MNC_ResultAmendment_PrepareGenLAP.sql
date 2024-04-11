/*<info serverAlias="DBCRM-MessageNotification" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE MNC_ResultAmendment_PrepareGenLAP
	@NotificationIDs VARCHAR(MAX)
AS
/*
	Created: 20231213@Roy
	Task: Prepare to generate message for LAP
	DB: DBCRM.MessageNotification
	Revisions:
		20231121@Roy: CRM - Implement Message Notifications Center for Result Amendment of Cricket(#197621)
	
	Explanation:
		@NotificationIDs: List of DBMSG NotificationID
		
		Steps
			- Validate
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
		,iNoti VARCHAR(MAX)
		,SportType SMALLINT
		,StatusID TINYINT
		,NotificationType TINYINT
		,ValidTargetCnt INT
		,SettlIDs VARCHAR(MAX)
	)
	
	CREATE TABLE #tmpRemotingRef (
		NotificationID INT
		,SettlementLogID INT
		,GroupName VARCHAR(50)
		,RefId1 VARCHAR(50)
		,RefId2 VARCHAR(50)
	)
	
	--------------------------------------------------------
	INSERT INTO #tmpNoti (NotificationID, iNoti)
	SELECT DISTINCT TRY_CONVERT(INT, value) AS NotificationID
		,value AS iNoti
	FROM STRING_SPLIT(@NotificationIDs, ',')
	WHERE value <> ''
	
	CREATE UNIQUE CLUSTERED INDEX CIX_tmpNoti ON #tmpNoti(NotificationID)
	
	;WITH CTE_Validate AS (
		SELECT n.NotificationID
			,rh.SportType
			,n.StatusID
			,n.NotificationType
			,COUNT(1) AS ValidTargetCnt
			,STRING_AGG(CONVERT(VARCHAR(MAX),nm.SettlementLogID),',') AS SettlIDs
		FROM #tmpNoti AS i
			INNER JOIN Notification AS n WITH (NOLOCK) ON i.NotificationID = n.NotificationID
			INNER JOIN NotiMapping AS nm WITH (NOLOCK) ON i.NotificationID = nm.NotificationID
			INNER JOIN SettlementResultHist AS rh WITH (NOLOCK) ON nm.SettlementLogID = rh.SettlementLogID
			INNER JOIN NotificationTarget AS nt WITH (NOLOCK) ON i.NotificationID = nt.NotificationID
			INNER JOIN bodb02.dbo.Dep_CustSuper AS d WITH (NOLOCK) ON nt.TargetID = d.CustID --deposit Super
		GROUP BY n.NotificationID
			,rh.SportType
			,n.StatusID
			,n.NotificationType
	)
	UPDATE i
	SET i.SportType = v.SportType
		,i.StatusID = v.StatusID
		,i.NotificationType = v.NotificationType
		,i.ValidTargetCnt = v.ValidTargetCnt
		,i.SettlIDs = v.SettlIDs
	FROM #tmpNoti AS i
		INNER JOIN CTE_Validate AS v ON v.NotificationID = v.NotificationID
	WHERE v.NotificationType = 1 --1: Result Amendment to Msg
		AND v.SportType = 50 --Cricket, need modify for others sport
		AND v.StatusID IN (
				9 --Ready to Send
				,12 --Sending
				,13 --Sent
				,14 --Failed to Send
			)--only need Status over the 'Ready to Send' step
		AND v.ValidTargetCnt > 0
		AND ISNULL(v.SettlIDs,'') <> ''
	
	/*
		build things to get from RemotingRef
			Loop foreach NotificationID to create as many LAP noti as possible (ignore Error NotificationID - NOT break if any Failed)
	*/
	IF EXISTS (SELECT 1 FROM #tmpNoti WHERE SettlIDs IS NOT NULL)
	BEGIN
		DECLARE @JSResource NVARCHAR(MAX)
			,@SettlIDs VARCHAR(MAX)
			,@ErrCode INT = 0
			,@ErrMsg NVARCHAR(2000) = ''
			,@iLoop INT
		
		SELECT @iLoop = MIN(NotificationID)
		FROM #tmpNoti
		WHERE SettlIDs IS NOT NULL
		
		--loop NotificationID
		WHILE (1=1)
		BEGIN
			IF @iLoop IS NULL
				BREAK
			
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
					,'Error - Msg_NotiID - FAILED at step [JS Parse ActualResult/WrongResult] while Preparing to generate Notification for LAP with NotificationID = ' + ISNULL(CONVERT(VARCHAR,NotificationID),'NULL')
						+ ', NotificationType = ' + ISNULL(CONVERT(VARCHAR,NotificationType),'NULL')
						+ ', SportType = ' + ISNULL(CONVERT(VARCHAR,SportType),'NULL')
						+ ', StatusID = ' + ISNULL(CONVERT(VARCHAR,StatusID),'NULL')
						+ ', Deposit Target Count = ' + ISNULL(CONVERT(VARCHAR,ValidTargetCnt),'NULL')
						+ '- ERROR_MESSAGE(' + ISNULL(@ErrMsg,'NULL') + ')'
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
			SELECT @iLoop = (SELECT MIN(NotificationID) FROM #tmpNoti WHERE NotificationID > @iLoop AND SettlIDs IS NOT NULL)
				,@ErrCode = 0
				,@ErrMsg = ''
		END --end while
	END
	
	--write log
	IF NOT EXISTS (SELECT 1 FROM #tmpNoti WHERE SettlIDs IS NOT NULL)
	BEGIN
		INSERT INTO [Log] (
			ActionID
			,UserID
			,LogBef
		)
		SELECT @LogActionID
			,@LogUserID
			,'Error - Preparing to generate Notification for LAP with @NotificationIDs = (' + ISNULL(CONVERT(VARCHAR,@NotificationIDs),'NULL') + ') - BUT have NO valid NotificationID'
	END
	ELSE
	BEGIN
		;WITH CTE_Ref AS (
			SELECT DISTINCT NotificationID
			FROM #tmpRemotingRef
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
			,CASE WHEN rf.NotificationID IS NOT NULL THEN 'Info - Msg_NotiID - Preparing to generate Notification for LAP - Get RemotingRef'
				ELSE 'Error - Msg_NotiID - FAILED while Preparing to generate Notification for LAP with NotificationID = ' + ISNULL(CONVERT(VARCHAR,i.NotificationID),'NULL')
					+ ', Input NotificationID = ' + ISNULL(iNoti,'NULL')
					+ ', NotificationType = ' + ISNULL(CONVERT(VARCHAR,NotificationType),'NULL')
					+ ', SportType = ' + ISNULL(CONVERT(VARCHAR,SportType),'NULL')
					+ ', StatusID = ' + ISNULL(CONVERT(VARCHAR,StatusID),'NULL')
					+ ', Deposit Target Count = ' + ISNULL(CONVERT(VARCHAR,ValidTargetCnt),'NULL')
					+ ', SettlementLogIDs = ' + ISNULL(SettlIDs,'NULL') + ')'
				END
		FROM #tmpNoti AS i
			LEFT JOIN CTE_Ref AS rf ON i.NotificationID = rf.NotificationID
	END
	
	--return for RemotingRef
	;WITH CTE_DT AS (
		SELECT DISTINCT NotificationID
			,GroupName
			,RefId1
			,RefId2
		FROM #tmpRemotingRef AS rf
	)
	SELECT STRING_AGG(CONVERT(VARCHAR(MAX),rf.NotificationID),',') AS NotificationIDs
		,rf.GroupName
		,rf.RefId1
		,rf.RefId2
	FROM CTE_DT AS rf
	GROUP BY rf.GroupName
		,rf.RefId1
		,rf.RefId2
	
	DROP TABLE #tmpNoti
	DROP TABLE #tmpRemotingRef
END
