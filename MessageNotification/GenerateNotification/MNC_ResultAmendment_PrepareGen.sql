/*<info serverAlias="DBCRM-MessageNotification" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE MNC_ResultAmendment_PrepareGen
	@Environment VARCHAR(5)
AS
/*
	Created: 20231213@Roy
	Task: Prepare to start generate message process
	DB: DBCRM.MessageNotification
	Revisions:
		20230515@Roy: CRM - Implement Message Notifications Center for Result Amendment of Cricket(#197621)
	
	Explanation:
		@Environment
			If UATMode = OFF
			  + @Environment = PRD => handle all data
			  + @Environment = UAT => return
			If UATMode = ON
			  + @Environment = PRD => handle REAL data
			  + @Environment = UAT => handle TEST data
		
		Steps
			- Check / Update [Generate Message Process] Status
			- Change SettlementLogID from [Successfully Retrieved] to [Generating] filter by Environment/UATMode (REAL or TEST data)
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
		,@StsRetrieved INT
		,@StsGenerating INT
		,@ErrLogPrefix NVARCHAR(150) = ''
		,@InfLogPrefix NVARCHAR(150) = ''
		,@ProcessID INT
		,@IsTestFlag BIT
		,@UATMode VARCHAR(5) = 'OFF'
	
	/*
		Load setting
	*/
	SELECT @LogUserID = TRY_CONVERT(INT, VValue)
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 2 --ID of StarixIT
	
	SELECT @StsRetrieved = StatusID
	FROM NotiStatus WITH (NOLOCK)
	WHERE Status = 'Successfully Retrieved'
	
	SELECT @StsGenerating = StatusID
	FROM NotiStatus WITH (NOLOCK)
	WHERE Status = 'Generating'
	
	SELECT @ProcessID = (
					CASE WHEN @Environment = 'PRD' THEN 5 --Process_GenerateNoti
					ELSE 8 END --ProcessUAT_GenerateNoti
				)
	
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
	
	SELECT @UATMode = VValue
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 10 --UATMode
	
	SELECT @ErrLogPrefix = 'Error - ' + ISNULL(@Environment,'Environment NULL') + ' - '
	SELECT @InfLogPrefix = 'Info - ' + ISNULL(@Environment,'Environment NULL') + ' - '
	SELECT @Environment = ISNULL(@Environment,'UAT')
	
	/*
		Filter data by UATMode
			If UATMode = OFF
			  + @Environment = PRD => handle all data
			  + @Environment = UAT => return
			If UATMode = ON
			  + @Environment = PRD => handle REAL data
			  + @Environment = UAT => handle TEST data
	*/
	IF @UATMode = 'OFF' AND @Environment = 'UAT' --no action (RETURN)
	BEGIN
		SELECT NULL AS SettlementLogIDs
			,NULL AS GroupName
			,NULL AS RefId1
			,NULL AS RefId2
		WHERE 1 = 0
		
		INSERT INTO [Log] (
			ActionID
			,UserID
			,LogBef
		)
		SELECT @LogActionID
			,@LogUserID
			,@InfLogPrefix + 'NO Action for UATMode = OFF AND Environment = UAT'
		
		RETURN
	END
	ELSE IF @UATMode = 'ON' AND @Environment = 'PRD' --REAL data only
	BEGIN
		SET @IsTestFlag = 0
	END
	ELSE IF @UATMode = 'ON' AND @Environment = 'UAT' --TEST data only
	BEGIN
		SET @IsTestFlag = 1
	END
	ELSE --both REAL & TEST
	BEGIN
		SET @IsTestFlag = NULL
	END
	
	--check current status of generate message process
	IF NOT EXISTS (SELECT 1 FROM SystemSetting WHERE VID = @ProcessID AND VValue = 'Done') --ProcessStatus_GenerateMessage
	BEGIN
		SELECT NULL AS SettlementLogIDs
			,NULL AS GroupName
			,NULL AS RefId1
			,NULL AS RefId2
		WHERE 1 = 0
		
		INSERT INTO [Log] (
			ActionID
			,UserID
			,LogBef
		)
		SELECT @LogActionID
			,@LogUserID
			,@ErrLogPrefix + 'Another Generate Message Process(' + CONVERT(VARCHAR,@ProcessID) + ') is still active.'
		
		RETURN
	END
	ELSE
	BEGIN
		UPDATE SystemSetting WITH (ROWLOCK,UPDLOCK)
		SET VValue = 'Running'
		WHERE VID = @ProcessID
			AND VValue = 'Done'
	END
	
	CREATE TABLE #tmpRemotingRef (
		SettlementLogID INT
		,GroupName VARCHAR(50)
		,RefId1 VARCHAR(50)
		,RefId2 VARCHAR(50)
	)
	
	CREATE TABLE #tmpUpdatedRH (
		SettlementLogID INT NOT NULL
		,StatusID TINYINT NOT NULL
		,SportType SMALLINT NOT NULL
		,ActualResult VARCHAR(MAX)
		,ActualResultXML XML
		,WrongResult VARCHAR(MAX)
		,WrongResultXML XML
	)
	
	CREATE TABLE #tmpEventInfo (
		SettlementLogID INT
		,MatchID INT
		,SportType INT
		,HomeID INT
		,AwayID INT
		,LeagueID INT
	)
	
	CREATE TABLE #tmpAffectedResult (
		SettlementLogID INT
		,HomeValue VARCHAR(50) DEFAULT ''
		,AwayValue VARCHAR(50) DEFAULT ''
		,RefBettypeID VARCHAR(50) DEFAULT ''
		,OtherInfo VARCHAR(200) DEFAULT ''
		,TeamIDs VARCHAR(200) DEFAULT ''
		,G VARCHAR(50) DEFAULT ''
	)
	
	/*
		- Mark StatusID = Generating to start gen message process
		- Get Updated SettlementLogID
	*/
	UPDATE sh
	SET sh.StatusID = @StsGenerating
		,sh.LastModifiedTime = GETDATE()
	OUTPUT INSERTED.SettlementLogID
		,INSERTED.StatusID
		,INSERTED.SportType
		,INSERTED.ActualResult
		,INSERTED.WrongResult
	INTO #tmpUpdatedRH (
		SettlementLogID
		,StatusID
		,ActualResult
		,WrongResult
	) --Get Updated SettlementLogID
	FROM SettlementResultHist AS sh WITH (ROWLOCK,UPDLOCK)
	WHERE sh.StatusID = @StsRetrieved --Captured
		AND ISNULL(@IsTestFlag,sh.IsTest) = sh.IsTest --filter by Environment/UATMode
		AND sh.SportType = 50 --Cricket, need modify for others sport
	
	--write log
	INSERT INTO [Log] (
		RefID
		,ActionID
		,UserID
		,LogBef
	)
	SELECT SettlementLogID
		,@LogActionID
		,@LogUserID
		,@InfLogPrefix + 'Changed SettlementLogID Status from [Successfully Retrieved] to [Generating]'
	FROM #tmpUpdatedRH AS rh
	ORDER BY SettlementLogID
	
	--Define ALL things need to use RemotingRef Func
	DECLARE @JSResource NVARCHAR(MAX)
		,@SettlIDs VARCHAR(MAX)
	
	SELECT @SettlIDs = STRING_AGG(CONVERT(VARCHAR(MAX),SettlementLogID),',')
	FROM #tmpUpdatedRH
	
	EXEC MNC_ResultAmendment_JSParseResult
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
	
	--return for RemotingRef
	SELECT STRING_AGG(CONVERT(VARCHAR(MAX),rh.SettlementLogID),',') AS SettlementLogIDs
		,rf.GroupName
		,rf.RefId1
		,rf.RefId2
	FROM #tmpUpdatedRH AS rh
		LEFT JOIN #tmpRemotingRef AS rf ON rh.SettlementLogID = rf.SettlementLogID
	GROUP BY rf.GroupName
		,rf.RefId1
		,rf.RefId2
	
	DROP TABLE #tmpUpdatedRH
	DROP TABLE #tmpEventInfo
	DROP TABLE #tmpRemotingRef
	DROP TABLE #tmpAffectedResult
END
