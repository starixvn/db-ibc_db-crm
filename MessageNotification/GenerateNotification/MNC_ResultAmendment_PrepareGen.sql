/*<info serverAlias="DBCRM-MessageNotification" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE MNC_ResultAmendment_PrepareGen
	@Environment VARCHAR(20)
AS
/*
	Created: 20231213@Roy
	Task: Prepare to start generate message process
	DB: DBCRM.MessageNotification
	Revisions:
		20231121@Roy: CRM - Implement Message Notifications Center for Result Amendment of Cricket(#197621)
	
	Explanation:
		@Environment
			If IncludeTestMatch = ON
			  + @Environment = LIVE => handle all data
			  + @Environment = UAT => return
			If IncludeTestMatch = OFF
			  + @Environment = LIVE => handle REAL data
			  + @Environment = UAT => handle TEST data
		
		Steps
			- Check / Update [Generate Message Process] Status
			- Change SettlementLogID from [Successfully Retrieved] to [Generating] filter by Environment/IncludeTestMatch (REAL or TEST data)
			- Define things need to use RemotingRef Func
		
		Output
			Dataset to get multilanguage from RemotingRef
			----|-------------------|---------------|-------------------|-------------
				|SettlementLogIDs	|GroupName		|RefId1				|RefId2
			----|-------------------|---------------|-------------------|-------------
				| 50				| RefResource	| ResourceCricket	| G1
				| 52,64				| RefResource	| ResourceCricket	| G2
				| 171,167,168		| EventInfo		| LeagueID			| 89700
				| 124				| EventInfo		| SportType			| 50
			----|-------------------|---------------|-------------------|-------------
	
	Example:
		EXEC MessageNotification.dbo.MNC_ResultAmendment_PrepareGen
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @LogUserID INT
		,@LogActionID SMALLINT
		,@StsRetrieved TINYINT
		,@ErrLogPrefix NVARCHAR(150) = ''
		,@InfLogPrefix NVARCHAR(150) = ''
		,@ProcessID INT
		,@IsTestFlag BIT
		,@PRODIncludeTest BIT = 0
	
	/*
		Load setting
	*/
	SELECT @LogUserID = TRY_CONVERT(INT, VValue)
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 2 --ID of StarixIT
	
	SELECT @StsRetrieved = StatusID
	FROM NotiStatus WITH (NOLOCK)
	WHERE Status = 'Successfully Retrieved'
	
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
	
	SELECT @PRODIncludeTest = VValue
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 10 --IncludeTestMatch
	
	IF @Environment = 'LIVE'
	BEGIN
		SELECT @ProcessID = 5 --GenerateNotifService
		SELECT @ErrLogPrefix = 'Error - [GenerateNotifService - Prepare] - '
		SELECT @InfLogPrefix = 'Info - [GenerateNotifService - Prepare] - '
	END
	ELSE
	BEGIN
		SELECT @ProcessID = 8 --UAT_GenerateNotifService
		SELECT @ErrLogPrefix = 'Error - [UAT_GenerateNotifService - Prepare] - '
		SELECT @InfLogPrefix = 'Info - [UAT_GenerateNotifService - Prepare] - '
		
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
	IF @PRODIncludeTest = 1 AND @Environment = 'UAT' --no action (RETURN)
	BEGIN
		SELECT NULL AS SettlementLogIDs
			,NULL AS GroupName
			,NULL AS RefId1
			,NULL AS RefId2
		WHERE 1 = 0
		
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
	
	CREATE TABLE #tmpRemotingRef (
		SettlementLogID INT
		,GroupName VARCHAR(50)
		,RefId1 VARCHAR(50)
		,RefId2 VARCHAR(50)
	)
	
	CREATE TABLE #tmpPrepareRH (
		SettlementLogID INT NOT NULL
	)
	
	/*
		Get SettlementLogID
	*/
	INSERT INTO #tmpPrepareRH ( SettlementLogID )
	SELECT DISTINCT sh.SettlementLogID
	FROM SettlementResultHist AS sh WITH (ROWLOCK,UPDLOCK)
	WHERE sh.StatusID = @StsRetrieved --Captured
		AND sh.SportType = 50 --Cricket, need modify for others sport
		AND (
			@IsTestFlag IS NULL
			OR sh.IsTest = @IsTestFlag
		) --filter by Environment/IncludeTestMatch
		
	--write log
	INSERT INTO UserLog (
		RefID
		,ActionID
		,UserID
		,LogBef
	)
	SELECT SettlementLogID
		,@LogActionID
		,@LogUserID
		,COMPRESS(@InfLogPrefix + 'Changed SettlementLogID Status from [Successfully Retrieved] to [Generating]')
	FROM #tmpPrepareRH AS rh
	ORDER BY SettlementLogID
	
	--Define ALL things need to use RemotingRef Func
	DECLARE @JSResource NVARCHAR(MAX)
		,@SettlIDs VARCHAR(MAX)
	
	SELECT @SettlIDs = STRING_AGG(CONVERT(VARCHAR(MAX),SettlementLogID),',')
	FROM #tmpPrepareRH
	
	IF NULLIF(TRIM(@SettlIDs), '') IS NOT NULL
	BEGIN
		EXEC MessageNotification.dbo.MNC_ResultAmendment_JSParseResult
			@SettlementLogIDs = @SettlIDs
			,@ParseTo = 'RemotingRef'
			,@OutJSResource = @JSResource OUTPUT
		
		INSERT INTO #tmpRemotingRef (
			SettlementLogID
			,GroupName
			,RefId1
			,RefId2
		)
		SELECT DISTINCT SettlementLogID
			,GroupName
			,RefId1
			,RefId2
		FROM OPENJSON(@JSResource) WITH (
				SettlementLogID INT '$.SettlementLogID'
				,GroupName VARCHAR(50) '$.GroupName'
				,RefId1 VARCHAR(50) '$.RefId1'
				,RefId2 VARCHAR(50) '$.RefId2'
			)--OPENJSON case-sensitive
		WHERE ISJSON(@JSResource) = 1
	END
	
	--return for RemotingRef
	SELECT STRING_AGG(CONVERT(VARCHAR(MAX),rh.SettlementLogID),',') AS SettlementLogIDs
		,rf.GroupName
		,rf.RefId1
		,rf.RefId2
	FROM #tmpPrepareRH AS rh
		LEFT JOIN #tmpRemotingRef AS rf ON rh.SettlementLogID = rf.SettlementLogID
	GROUP BY rf.GroupName
		,rf.RefId1
		,rf.RefId2
	
	--Mark completed process
	IF NOT EXISTS (SELECT 1 FROM #tmpRemotingRef)
	BEGIN
		UPDATE SystemSetting WITH (ROWLOCK,UPDLOCK)
		SET VValue = 'Done'
		WHERE VID = @ProcessID
			AND VValue = 'Running'
	
		INSERT INTO UserLog (
			ActionID
			,UserID
			,LogBef
		)
		SELECT @LogActionID
			,@LogUserID
			,COMPRESS(@InfLogPrefix + 'Completed - Change ProcessID(' + ISNULL(CONVERT(VARCHAR,@ProcessID),'NULL') + ') to [' + ISNULL(VValue,'NULL') + ']') AS LogBef
		FROM SystemSetting WITH (NOLOCK)
		WHERE VID = @ProcessID
	END
	
	----------------------
	INSERT INTO UserLog (
		RefID
		,ActionID
		,UserID
		,LogBef
	)
	SELECT SettlementLogID
		,@LogActionID
		,@LogUserID
		,COMPRESS(@InfLogPrefix + 'Completed - @Environment(' + ISNULL(@Environment,'NULL') + ')'
						+ ' - @IncludeTestMatch(' + ISNULL(CONVERT(VARCHAR,@PRODIncludeTest),'NULL') + ')'
						+ ' - @IsTestFlag(' + ISNULL(CONVERT(VARCHAR,@IsTestFlag),'both REAL & TEST') + ')'
						+ ' - Return('
							+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
										SELECT STRING_AGG(CONVERT(VARCHAR(MAX),rh.SettlementLogID),',') AS SettlementLogIDs
											,rf.GroupName
											,rf.RefId1
											,rf.RefId2
										FROM #tmpPrepareRH AS rh
											LEFT JOIN #tmpRemotingRef AS rf ON rh.SettlementLogID = rf.SettlementLogID
										GROUP BY rf.GroupName
											,rf.RefId1
											,rf.RefId2
										FOR JSON PATH
									))
								),'NO ROW') + ')')
	FROM #tmpPrepareRH AS rh
	
	DROP TABLE #tmpPrepareRH
	DROP TABLE #tmpRemotingRef
END
