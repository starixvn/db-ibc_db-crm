/*<info serverAlias="DBCRM-MessageNotification" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE MNC_ResultAmendment_GetSettlementLogIDs
	@Environment VARCHAR(20)
	,@JSRemotingRef NVARCHAR(MAX)
	,@ValidSettlementLogIDs VARCHAR(MAX) OUTPUT
AS
/*
	Created: 20231213@Roy
	Task: get valid SettlementLogIDs and return it as list
	DB: DBCRM.MessageNotification
	Revisions:
		20231121@Roy: CRM - Implement Message Notifications Center for Result Amendment of Cricket(#197621)
	
	Param's Explanation:
		@Environment
			If UATMode = OFF
			  + @Environment = LIVE => handle all data
			  + @Environment = UAT => return
			If UATMode = ON
			  + @Environment = LIVE => handle REAL data
			  + @Environment = UAT => handle TEST data
		
		Input
			@JSRemotingRef NVARCHAR(MAX) = N'
				[
					{"SettlementLogIDs":"2,5,3,4","GroupName":"EventInfo","RefId1":"TeamID","RefId2":"5","RefValueEN":"Manchester United","RefValueCH":"曼聯","RefValueCS":"曼联"},
					{"SettlementLogIDs":"2,5,3,4","GroupName":"RefResource","RefId1":"ResourceCricket","RefId2":"9651","RefValueEN":"Away @G Top Batsman","RefValueCH":"客隊最佳擊球手","RefValueCS":"客隊最佳擊球手"},
					{"SettlementLogIDs":"2,5,3,4","GroupName":"RefResource","RefId1":"ResourceCricket","RefId2":"G1","RefValueEN":"1st Inns","RefValueCH":"首局","RefValueCS":"首局"},
					{"SettlementLogIDs":"2,5,3,4","GroupName":"RefResource","RefId1":"ResultSettlement","RefId2":"OT","RefValueEN":"Other","RefValueCH":"其他","RefValueCS":"其他"}
				]'
		
		Output
			@ValidSettlementLogIDs - list of valid SettlementLogIDs
		
		Verify Steps
			- EXISTS in SettlementResultHist
			- IsTestFlag (NOT Failed Status but ignore valid List)
			- NOT Generating (KEEP Current Status but ignore valid List)
			- Invalid EventInfo (MatchID/HomeID..)
			- EXISTS in SettlementResultHistDetail
			- Invalid CustID
			- ActionType
			- Failed to Convert ActualResult/WrongResult to XML
			- ResourceData NOT EXISTS in RemotingRef
			- NOT match ResourceID between ActualResult and WrongResult
				+ For ActionType = 2 (CAL to Refund), WrongResult can NOT blank
				+ For ActionType = 3 (Refund to CAL), ActualResult can NOT blank
				+ For ActionType = 1 (CAL to CAL), ResourceID between ActualResult and WrongResult must be match 1:1
			
			- write #tmpRemotingRefData info if enable UATMode AND any returned NULL value
	
	Example:
		EXEC MessageNotification.dbo.MNC_ResultAmendment_GetSettlementLogIDs
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @LogUserID INT
		,@LogActionID SMALLINT
		,@StsGenerating TINYINT
		,@StsGenerated TINYINT
		,@StsGenFailed TINYINT
		,@ErrLogPrefix NVARCHAR(150) = ''
		,@InfLogPrefix NVARCHAR(150) = ''
		,@IsTestFlag BIT
		,@UATMode VARCHAR(5) = 'OFF'
		,@LogMode VARCHAR(500)
		,@ErrCode INT = 0
		,@ErrMsg NVARCHAR(2000) = ''
	
	/*
		Load setting
	*/
	SELECT @LogUserID = TRY_CONVERT(INT, VValue)
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 2 --ID of StarixIT
	
	SELECT @LogActionID = ActionID
	FROM LogAction WITH (NOLOCK)
	WHERE ActName = ISNULL(OBJECT_NAME(@@PROCID),'Unknown')
	
	SELECT @StsGenerating = StatusID
	FROM NotiStatus WITH (NOLOCK)
	WHERE Status = 'Generating'
	
	SELECT @StsGenFailed = StatusID
	FROM NotiStatus WITH (NOLOCK)
	WHERE Status = 'Failed to Generate'
	
	SELECT @StsGenerated = StatusID
	FROM NotiStatus WITH (NOLOCK)
	WHERE Status = 'Successfully Generated'
	
	SELECT @UATMode = VValue
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 10 --UATMode
	
	SELECT @LogMode = VValue
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 13 --LogMode
	
	SELECT @ErrLogPrefix = 'Error - ' + ISNULL(@Environment,'Environment NULL') + ' - '
	SELECT @InfLogPrefix = 'Info - ' + ISNULL(@Environment,'Environment NULL') + ' - '
	SELECT @Environment = ISNULL(@Environment,'UAT')
	
	INSERT INTO [Log] (
		ActionID
		,UserID
		,LogBef
	)
	SELECT @LogActionID
		,@LogUserID
		,@InfLogPrefix + 'Debug - Start [Generate Msg Noti process - Verify]'
						+ ' - @UATMode(' + ISNULL(@UATMode,'NULL') + ')'
						+ ' - @Environment(' + ISNULL(@Environment,'NULL') + ')'
						+ ' - @JSRemotingRef(' + ISNULL(@JSRemotingRef,'NULL') + ')'
	WHERE @LogMode = 'Debug'
	
	/*
		Filter data by UATMode
			If UATMode = OFF
			  + @Environment = LIVE => handle all data
			  + @Environment = UAT => return
			If UATMode = ON
			  + @Environment = LIVE => handle REAL data
			  + @Environment = UAT => handle TEST data
	*/
	IF @UATMode = 'ON' AND @Environment = 'LIVE' --REAL data only
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
	
	---create temp tables---	
	CREATE TABLE #tmpResourceRef (
		SettlementLogID INT
		,GroupName VARCHAR(50)
		,RefId1 VARCHAR(50)
		,RefId2 VARCHAR(50)
	)
	
	CREATE TABLE #tmpResourceRawData (
		SettlementLogID INT
		,AmendInfo VARCHAR(50)
		,ResourceID VARCHAR(50)
		,RefBettypeID VARCHAR(50)
		,HomeValue VARCHAR(50)
	)
	
	CREATE TABLE #tmpVerifyList (
		SettlementLogID INT
		,StatusID TINYINT
		,RHLog NVARCHAR(MAX) DEFAULT ''
	)
	
	CREATE TABLE #tmpRemotingRefData (
		SettlementLogID INT
		,GroupName VARCHAR(50)
		,RefId1 VARCHAR(50)
		,RefId2 VARCHAR(50)
		,RefValueEN NVARCHAR(500)
		,RefValueCH NVARCHAR(500)
		,RefValueCS NVARCHAR(500)
	)
	
	BEGIN TRY
		INSERT INTO #tmpRemotingRefData (
			SettlementLogID
			,GroupName
			,RefId1
			,RefId2
			,RefValueEN
			,RefValueCH
			,RefValueCS
		)
		SELECT DISTINCT TRY_CONVERT(INT, value) AS SettlementLogID
			,NULLIF(TRIM(GroupName), '') AS GroupName
			,NULLIF(TRIM(RefId1), '') AS RefId1
			,NULLIF(TRIM(RefId2), '') AS RefId2
			,NULLIF(TRIM(RefValueEN), '') AS RefValueEN
			,NULLIF(TRIM(RefValueCH), '') AS RefValueCH
			,NULLIF(TRIM(RefValueCS), '') AS RefValueCS
		FROM OPENJSON(@JSRemotingRef) WITH (
				SettlementLogIDs VARCHAR(MAX) '$.SettlementLogIDs'
				,GroupName VARCHAR(50) '$.GroupName'
				,RefId1 VARCHAR(50) '$.RefId1'
				,RefId2 VARCHAR(50) '$.RefId2'
				,RefValueEN NVARCHAR(500) '$.RefValueEN'
				,RefValueCH NVARCHAR(500) '$.RefValueCH'
				,RefValueCS NVARCHAR(500) '$.RefValueCS'
			)--OPENJSON case-sensitive
		CROSS APPLY STRING_SPLIT(SettlementLogIDs, ',')
	END TRY
	BEGIN CATCH
		
		SELECT @ValidSettlementLogIDs = '' --output
		
		INSERT INTO [Log] (
			ActionID
			,UserID
			,LogBef
		)
		SELECT @LogActionID
			,@LogUserID
			,@ErrLogPrefix + '[Generate Msg Noti process - Verify] - FAILED to Parse JSON Data'
							+ ' - @UATMode(' + ISNULL(@UATMode,'NULL') + ')'
							+ ' - @Environment(' + ISNULL(@Environment,'NULL') + ')'
							+ ' - @JSRemotingRef(' + ISNULL(@JSRemotingRef,'NULL') + ')'
							+ ' - ERROR_MESSAGE(' + ISNULL(@ErrMsg,'NULL') + ')'
		
	END CATCH
	
	/*
		Start to verfy info before generate message
	*/
	IF NOT EXISTS (SELECT 1 FROM #tmpRemotingRefData WHERE SettlementLogID IS NOT NULL)
	BEGIN
		SELECT @ValidSettlementLogIDs = ''
		
		INSERT INTO [Log] (
			ActionID
			,UserID
			,LogBef
		)
		SELECT @LogActionID
			,@LogUserID
			,@InfLogPrefix + '[Generate Msg Noti process - Verify] - HAVE NO Valid SettlementLogIDs'
							+ ' - @UATMode(' + ISNULL(@UATMode,'NULL') + ')'
							+ ' - @Environment(' + ISNULL(@Environment,'NULL') + ')'
							+ ' - @JSRemotingRef(' + ISNULL(@JSRemotingRef,'NULL') + ')'
		
		RETURN
	END
	
	--------------------prepare before Verify foreach SettlementLogID----------------------
	DECLARE @VerifySettleIDs VARCHAR(MAX)
	
	;WITH CTE_SettleID AS (
		SELECT DISTINCT SettlementLogID
		FROM #tmpRemotingRefData
		WHERE SettlementLogID IS NOT NULL
	)
	SELECT @VerifySettleIDs = ISNULL(STRING_AGG(CONVERT(VARCHAR(MAX),SettlementLogID),','),'')
	FROM CTE_SettleID
	
	BEGIN TRY
		DECLARE @JSResource NVARCHAR(MAX)
		
		/*
			---------#tmpResourceRef---------
		*/
		SELECT @JSResource = ''
			,@ErrCode = 0
			,@ErrMsg = ''
		
		EXEC MNC_ResultAmendment_JSParseResult
			@SettlementLogIDs = @VerifySettleIDs
			,@ParseAmendInfo = 'ALL'
			,@ParseTo = 'RemotingRef'
			,@OutJSResource = @JSResource OUTPUT
			,@ErrCode = @ErrCode OUTPUT
			,@ErrMsg = @ErrMsg OUTPUT
		
		INSERT INTO [Log] (
			ActionID
			,UserID
			,LogBef
		)
		SELECT @LogActionID
			,@LogUserID
			,@InfLogPrefix + 'Debug - [Generate Msg Noti process - Verify] - Parse SettlementLogID(' + ISNULL(@VerifySettleIDs,'NULL') + ') to RemotingRef format'
							+ ' - @JSResource(' + ISNULL(@JSResource,'NULL') + ')'
		WHERE @LogMode = 'Debug'
		
		--ParseResult Error
		IF @ErrCode <> 0
		BEGIN
			INSERT INTO [Log] (
				ActionID
				,UserID
				,LogBef
			)
			SELECT @LogActionID
				,@LogUserID
				,@ErrLogPrefix + '[Generate Msg Noti process - Verify] - FAILED parse SettlementLogID(' + ISNULL(@VerifySettleIDs,'NULL') + ') to RemotingRef format'
								+ ' - @UATMode(' + ISNULL(@UATMode,'NULL') + ')'
								+ ' - @Environment(' + ISNULL(@Environment,'NULL') + ')'
								+ ' - @JSRemotingRef(' + ISNULL(@JSRemotingRef,'NULL') + ')'
								+ ' - ERROR_MESSAGE(' + ISNULL(@ErrMsg,'NULL') + ')'
		END
		ELSE
		BEGIN
			------load data for ResourceRef
			INSERT INTO #tmpResourceRef (
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
			
			CREATE CLUSTERED INDEX CIX_tmpResourceRef ON #tmpResourceRef (SettlementLogID)
		END
		
		/*
			---------#tmpResourceRawData---------
		*/
		
		IF @ErrCode = 0
		BEGIN
			SELECT @JSResource = ''
				,@ErrCode = 0
				,@ErrMsg = ''
			
			EXEC MNC_ResultAmendment_JSParseResult
				@SettlementLogIDs = @VerifySettleIDs
				,@ParseAmendInfo = 'ActualResult,WrongResult'
				,@ParseTo = 'RawData'
				,@OutJSResource = @JSResource OUTPUT
				,@ErrCode = @ErrCode OUTPUT
				,@ErrMsg = @ErrMsg OUTPUT
		END
		
		--ParseResult Error
		IF @ErrCode <> 0
		BEGIN
			
			INSERT INTO [Log] (
				ActionID
				,UserID
				,LogBef
			)
			SELECT @LogActionID
				,@LogUserID
				,@ErrLogPrefix + '[Generate Msg Noti process - Verify] - FAILED parse SettlementLogID(' + ISNULL(@VerifySettleIDs,'NULL') + ') to RawData format'
								+ ' - @UATMode(' + ISNULL(@UATMode,'NULL') + ')'
								+ ' - @Environment(' + ISNULL(@Environment,'NULL') + ')'
								+ ' - @JSRemotingRef(' + ISNULL(@JSRemotingRef,'NULL') + ')'
								+ ' - ERROR_MESSAGE(' + ISNULL(@ErrMsg,'NULL') + ')'
		END
		ELSE
		BEGIN
			------load data for ResourceRawData
			INSERT INTO #tmpResourceRawData (
				SettlementLogID
				,AmendInfo
				,ResourceID
				,RefBettypeID
				,HomeValue
			)
			SELECT DISTINCT SettlementLogID
				,AmendInfo
				,ResourceID
				,RefBettypeID
				,HomeValue
			FROM OPENJSON(@JSResource) WITH (
					SettlementLogID INT '$.SettlementLogID'
					,AmendInfo VARCHAR(50) '$.AmendInfo'
					,ResourceID VARCHAR(50) '$.ResourceID'
					,RefBettypeID VARCHAR(50) '$.RefBettypeID'
					,HomeValue VARCHAR(50) '$.HomeValue'
				)--OPENJSON case-sensitive
			
			CREATE CLUSTERED INDEX CIX_tmpResourceRawData ON #tmpResourceRawData (SettlementLogID)
		END
	END TRY
	BEGIN CATCH
		SELECT @ValidSettlementLogIDs = '' --output
		
		INSERT INTO [Log] (
			ActionID
			,UserID
			,LogBef
		)
		SELECT @LogActionID
			,@LogUserID
			,@ErrLogPrefix + '[Generate Msg Noti process - Verify] - FAILED Parse SettlementLogID(' + ISNULL(@VerifySettleIDs,'NULL') + ') to RemotingRef/RawData format'
							+ ' - @UATMode(' + ISNULL(@UATMode,'NULL') + ')'
							+ ' - @Environment(' + ISNULL(@Environment,'NULL') + ')'
							+ ' - @JSRemotingRef(' + ISNULL(@JSRemotingRef,'NULL') + ')'
							+ ' - ERROR_MESSAGE(' + ISNULL(ERROR_MESSAGE(),'NULL') + ')'
		RETURN
	END CATCH
	
	;WITH CTE_SettleID AS (
		SELECT DISTINCT SettlementLogID
		FROM #tmpRemotingRefData
		WHERE SettlementLogID IS NOT NULL
	)
	INSERT INTO #tmpVerifyList (SettlementLogID, StatusID)
	SELECT DISTINCT TRY_CONVERT(INT, s.value)
		,sh.StatusID
	FROM STRING_SPLIT(@VerifySettleIDs, ',') AS s
		LEFT JOIN SettlementResultHist AS sh ON TRY_CONVERT(INT, s.value) = sh.SettlementLogID
	
	CREATE CLUSTERED INDEX CIX_tmpVerifyList ON #tmpVerifyList (SettlementLogID)
	
	--loop foreach SettlementLogID
	DECLARE @iSettleID INT
	
	SELECT @iSettleID = MIN(SettlementLogID)
	FROM #tmpVerifyList
	
	WHILE (@iSettleID IS NOT NULL)
	BEGIN TRY
		---------Start to verify----------------------------------------------------------
		
		--Check EXISTS SettlementResultHist
		IF NOT EXISTS (SELECT 1 FROM SettlementResultHist WHERE SettlementLogID = @iSettleID)
		BEGIN
			UPDATE #tmpVerifyList
			SET StatusID = @StsGenFailed
				,RHLog = 'NOT EXISTS in SettlementResultHist'
			WHERE SettlementLogID = @iSettleID
			
			SELECT @iSettleID = (SELECT MIN(SettlementLogID) FROM #tmpVerifyList WHERE SettlementLogID > @iSettleID)
			
			CONTINUE
		END
		
		--Check IsTestFlag (NOT Failed Status but ignore valid List)
		IF NOT EXISTS (SELECT 1 FROM SettlementResultHist WHERE SettlementLogID = @iSettleID AND ISNULL(@IsTestFlag,IsTest) = IsTest)
		BEGIN
			UPDATE v
			SET StatusID = 0
				,v.RHLog = v.RHLog + '@IsTestFlag('+ ISNULL(CONVERT(VARCHAR,@IsTestFlag),'both REAL & TEST') +') NOT match with SettlementResultHist.IsTest('+ ISNULL(CONVERT(VARCHAR,sh.IsTest),'NULL') +')'
			FROM #tmpVerifyList AS v
				INNER JOIN SettlementResultHist AS sh WITH (NOLOCK) ON v.SettlementLogID = sh.SettlementLogID
			WHERE v.SettlementLogID = @iSettleID
			
			SELECT @iSettleID = (SELECT MIN(SettlementLogID) FROM #tmpVerifyList WHERE SettlementLogID > @iSettleID)
			
			CONTINUE
		END
		
		--Check Generated
		IF EXISTS (SELECT 1 FROM NotiMapping WHERE SettlementLogID = @iSettleID)
		BEGIN
			UPDATE v
			SET v.StatusID = 0
				,v.RHLog = v.RHLog + 'SettlementLogID is Generated - EXISTS in NotiMapping'
			FROM #tmpVerifyList AS v
				INNER JOIN NotiMapping AS nm WITH (NOLOCK) ON v.SettlementLogID = nm.SettlementLogID
			WHERE v.SettlementLogID = @iSettleID
			
			SELECT @iSettleID = (SELECT MIN(SettlementLogID) FROM #tmpVerifyList WHERE SettlementLogID > @iSettleID)
			
			CONTINUE
		END
		
		--check for NOT Generating (KEEP Current Status but ignore valid List)
		IF NOT EXISTS (SELECT 1 FROM SettlementResultHist WHERE SettlementLogID = @iSettleID AND StatusID = @StsGenerating)
		BEGIN
			UPDATE #tmpVerifyList
			SET StatusID = 0
				,RHLog = RHLog + 'StatusID ('+ ISNULL(CONVERT(NVARCHAR,StatusID),'NULL') + ') - NOT Generating'
			WHERE SettlementLogID = @iSettleID
			
			SELECT @iSettleID = (SELECT MIN(SettlementLogID) FROM #tmpVerifyList WHERE SettlementLogID > @iSettleID)
			
			CONTINUE
		END
		
		--verify SettlementResultHistDetail
		IF NOT EXISTS (SELECT 1 FROM SettlementResultHistDetail WHERE SettlementLogID = @iSettleID)
		BEGIN
			UPDATE #tmpVerifyList
			SET StatusID = @StsGenerated
				,RHLog = RHLog + 'have NO affected TransID'
			WHERE SettlementLogID = @iSettleID
			
			SELECT @iSettleID = (SELECT MIN(SettlementLogID) FROM #tmpVerifyList WHERE SettlementLogID > @iSettleID)
			
			CONTINUE
		END
		
		--Invalid EventInfo (MatchID/LeagueID..)
		IF EXISTS (
			SELECT 1
			FROM SettlementResultHist AS sh WITH (NOLOCK)
				LEFT JOIN bodb02.dbo.match AS m WITH (NOLOCK) ON sh.MatchID = m.MatchID
				LEFT JOIN bodb02.dbo.match14 AS m14 WITH (NOLOCK) ON sh.MatchID = m14.MatchID
				LEFT JOIN bodb02.dbo.league AS l WITH (NOLOCK) ON ISNULL(m.LeagueID, m14.LeagueID) = l.LeagueID
			WHERE sh.SettlementLogID = @iSettleID
				AND (
					ISNULL(m.MatchID, m14.MatchID) IS NULL
					OR l.LeagueID IS NULL
				)
		)
		BEGIN
			;WITH CTE_LogTxt AS (
				SELECT @iSettleID AS SettleID
					,(CASE WHEN ISNULL(m.MatchID, m14.MatchID) IS NULL THEN 'MatchID(' + ISNULL(CONVERT(VARCHAR,sh.MatchID),'NULL') + ') NOT exits IN [match/match14] table'
							ELSE 'LeagueID(' + ISNULL(CONVERT(VARCHAR,ISNULL(m.LeagueID, m14.LeagueID)),'NULL') + ') NOT exits IN [league] table' END
					) AS LTxt
				FROM SettlementResultHist AS sh WITH (NOLOCK)
					LEFT JOIN bodb02.dbo.match AS m WITH (NOLOCK) ON sh.MatchID = m.MatchID
					LEFT JOIN bodb02.dbo.match14 AS m14 WITH (NOLOCK) ON sh.MatchID = m14.MatchID
					LEFT JOIN bodb02.dbo.league AS l WITH (NOLOCK) ON ISNULL(m.LeagueID, m14.LeagueID) = l.LeagueID
				WHERE sh.SettlementLogID = @iSettleID
					AND (
						ISNULL(m.MatchID, m14.MatchID) IS NULL
						OR l.LeagueID IS NULL
					)
			)
			UPDATE v
			SET v.RHLog = v.RHLog + 'Invalid EventInfo - ' + ISNULL(l.LTxt,'')
				,v.StatusID = @StsGenFailed
			FROM #tmpVerifyList AS v
				INNER JOIN CTE_LogTxt AS l ON v.SettlementLogID = l.SettleID
			
			SELECT @iSettleID = (SELECT MIN(SettlementLogID) FROM #tmpVerifyList WHERE SettlementLogID > @iSettleID)
			
			CONTINUE
		END
		
		--Invalid EventInfo (AwayID/HomeID..)
		IF EXISTS (
			SELECT 1
			FROM #tmpResourceRef AS rh WITH (NOLOCK)
				LEFT JOIN bodb02.dbo.team AS t WITH (NOLOCK) ON t.TeamID = ISNULL(TRY_CONVERT(INT,rh.RefId2),-1)
			WHERE rh.SettlementLogID = @iSettleID
				AND rh.RefId1 = 'TeamID'
				AND rh.GroupName = 'EventInfo'
				AND ( t.TeamID IS NULL
					OR (NOT EXISTS (
							SELECT 1
							FROM SettlementResultHist AS sh WITH (NOLOCK)
								LEFT JOIN bodb02.dbo.match AS m WITH (NOLOCK) ON sh.MatchID = m.MatchID
								LEFT JOIN bodb02.dbo.match14 AS m14 WITH (NOLOCK) ON sh.MatchID = m14.MatchID
								LEFT JOIN bodb02.dbo.team AS h WITH (NOLOCK) ON ISNULL(m.HomeID, m14.HomeID) = h.TeamID
							WHERE sh.SettlementLogID = @iSettleID
								AND h.TeamID = t.TeamID
						)
						AND NOT EXISTS (
							SELECT 1
							FROM SettlementResultHist AS sh WITH (NOLOCK)
								LEFT JOIN bodb02.dbo.match AS m WITH (NOLOCK) ON sh.MatchID = m.MatchID
								LEFT JOIN bodb02.dbo.match14 AS m14 WITH (NOLOCK) ON sh.MatchID = m14.MatchID
								LEFT JOIN bodb02.dbo.team AS a WITH (NOLOCK) ON ISNULL(m.AwayID, m14.AwayID) = a.TeamID
							WHERE sh.SettlementLogID = @iSettleID
								AND a.TeamID = t.TeamID
						)
					)
				)
		)
		BEGIN
			;WITH CTE_LogTxt AS (
				SELECT rh.SettlementLogID AS SettleID
					,(CASE WHEN t.TeamID IS NULL THEN 'TeamID(' + ISNULL(rh.RefId2,'NULL') + ') NOT EXISTS IN [team] table'
						ELSE 'TeamID(' + ISNULL(rh.RefId2,'NULL') + ') from JSParseResult is NOT matched with HomeID/AwayID of SettlementResultHist.MatchID' END
					) AS LTxt
				FROM #tmpResourceRef AS rh WITH (NOLOCK)
					LEFT JOIN bodb02.dbo.team AS t WITH (NOLOCK) ON t.TeamID = ISNULL(TRY_CONVERT(INT,rh.RefId2),-1)
				WHERE rh.SettlementLogID = @iSettleID
					AND rh.RefId1 = 'TeamID'
					AND rh.GroupName = 'EventInfo'
					AND ( t.TeamID IS NULL
						OR (NOT EXISTS (
								SELECT 1
								FROM SettlementResultHist AS sh WITH (NOLOCK)
									LEFT JOIN bodb02.dbo.match AS m WITH (NOLOCK) ON sh.MatchID = m.MatchID
									LEFT JOIN bodb02.dbo.match14 AS m14 WITH (NOLOCK) ON sh.MatchID = m14.MatchID
									LEFT JOIN bodb02.dbo.team AS h WITH (NOLOCK) ON ISNULL(m.HomeID, m14.HomeID) = h.TeamID
								WHERE sh.SettlementLogID = @iSettleID
									AND h.TeamID = t.TeamID --h.TeamID: team from SettlementResultHist.MatchID 
															--t.TeamID: team from JSParseResult
							)
							AND NOT EXISTS (
								SELECT 1
								FROM SettlementResultHist AS sh WITH (NOLOCK)
									LEFT JOIN bodb02.dbo.match AS m WITH (NOLOCK) ON sh.MatchID = m.MatchID
									LEFT JOIN bodb02.dbo.match14 AS m14 WITH (NOLOCK) ON sh.MatchID = m14.MatchID
									LEFT JOIN bodb02.dbo.team AS a WITH (NOLOCK) ON ISNULL(m.AwayID, m14.AwayID) = a.TeamID
								WHERE sh.SettlementLogID = @iSettleID
									AND a.TeamID = t.TeamID --a.TeamID: team from SettlementResultHist.MatchID 
															--t.TeamID: team from JSParseResult
							)
						)
					)
			)
			UPDATE v
			SET v.RHLog = v.RHLog + 'Invalid EventInfo - ' + ISNULL(l.LTxt,'')
				,v.StatusID = @StsGenFailed
			FROM #tmpVerifyList AS v
				INNER JOIN CTE_LogTxt AS l ON v.SettlementLogID = l.SettleID
			
			SELECT @iSettleID = (SELECT MIN(SettlementLogID) FROM #tmpVerifyList WHERE SettlementLogID > @iSettleID)
			
			CONTINUE
		END
		
		--Check Invalid CustID
		IF EXISTS (
			SELECT 1
			FROM SettlementResultHistDetail AS rhd WITH (NOLOCK)
				LEFT JOIN bodb02.dbo.Customer AS c WITH (NOLOCK) ON rhd.CustID = c.CustID
			WHERE rhd.SettlementLogID = @iSettleID
				AND c.CustID IS NULL
		)
		BEGIN
			;WITH CTE_LogTxt AS (
				SELECT @iSettleID AS SettleID
					,STRING_AGG(CONVERT(VARCHAR(MAX),CustID),',') AS LTxt
				FROM (
					SELECT DISTINCT ISNULL(CONVERT(VARCHAR,rhd.CustID),'NULL') AS CustID
					FROM SettlementResultHistDetail AS rhd WITH (NOLOCK)
						LEFT JOIN bodb02.dbo.Customer AS c WITH (NOLOCK) ON rhd.CustID = c.CustID
					WHERE rhd.SettlementLogID = @iSettleID
						AND c.CustID IS NULL
				) AS t
			)
			UPDATE v
			SET v.RHLog = v.RHLog + 'Invalid CustID(' + l.LTxt + ') OR TransID may NOT EXISTS IN bettrans/bettrans14'
				,v.StatusID = @StsGenFailed
			FROM #tmpVerifyList AS v
				INNER JOIN CTE_LogTxt AS l ON v.SettlementLogID = l.SettleID
			
			SELECT @iSettleID = (SELECT MIN(SettlementLogID) FROM #tmpVerifyList WHERE SettlementLogID > @iSettleID)
			
			CONTINUE
		END
		
		---Check ActionType---
		IF EXISTS (
			SELECT 1
			FROM SettlementResultHist WITH (NOLOCK)
			WHERE SettlementLogID = @iSettleID
				AND ActionType NOT IN (1,2,3) --1 (CAL to CAL) / 2 (CAL to Refund) / 3 (Refund to CAL)
		)
		BEGIN
			UPDATE #tmpVerifyList
			SET RHLog = RHLog + 'ActionType NOT IN (1,2,3)'
				,StatusID = @StsGenFailed
			WHERE SettlementLogID = @iSettleID
			
			SELECT @iSettleID = (SELECT MIN(SettlementLogID) FROM #tmpVerifyList WHERE SettlementLogID > @iSettleID)
			
			CONTINUE
		END
		
		--Failed to convert ActualResult/WrongResult to XML
		IF EXISTS (
			SELECT 1
			FROM SettlementResultHist WITH (NOLOCK)
			WHERE SettlementLogID = @iSettleID
				AND (
					CASE WHEN ActionType = 1 --(CAL to CAL)
								AND (TRY_CONVERT(XML, ActualResult) IS NULL OR TRY_CONVERT(XML, WrongResult) IS NULL) THEN 0 --ActualResult/WrongResult must NOT NULL
						WHEN ActionType = 2 --(CAL to Refund), WrongResult can NOT blank
								AND TRY_CONVERT(XML, WrongResult) IS NULL THEN 0 --WrongResult must NOT NULL
						WHEN ActionType = 3 --(Refund to CAL), ActualResult NOT blank
								AND TRY_CONVERT(XML, ActualResult) IS NULL THEN 0 --ActualResult must NOT NULL
						ELSE 1 END
				) = 0
		)
		BEGIN
			UPDATE #tmpVerifyList
			SET RHLog = RHLog + 'Failed to convert ActualResult/WrongResult to XML'
				,StatusID = @StsGenFailed
			WHERE SettlementLogID = @iSettleID
			
			SELECT @iSettleID = (SELECT MIN(SettlementLogID) FROM #tmpVerifyList WHERE SettlementLogID > @iSettleID)
			
			CONTINUE
		END
		
		--ResourceData NOT EXISTS in RemotingRef
		IF EXISTS (
			SELECT 1
			FROM #tmpResourceRef AS rs
				LEFT JOIN #tmpRemotingRefData AS rf
					ON rs.GroupName = rf.GroupName
						AND rs.RefId1 = rf.RefId1
						AND rs.RefId2 = rf.RefId2
			WHERE rs.SettlementLogID = @iSettleID
				AND rf.RefValueEN IS NULL
		)
		BEGIN
			;WITH CTE_LogTxt AS (
				SELECT @iSettleID AS SettleID
					,CONVERT(NVARCHAR(MAX),(
						SELECT DISTINCT t.GroupName
							,t.RefId1
							,t.RefId2
						FROM #tmpRemotingRefData AS t
						WHERE t.SettlementLogID = @iSettleID
						ORDER BY t.GroupName
							,t.RefId1
							,t.RefId2
						FOR JSON PATH
					)) AS RefTxt
					,CONVERT(NVARCHAR(MAX),(
						SELECT DISTINCT t.GroupName
							,t.RefId1
							,t.RefId2
						FROM #tmpResourceRef AS t
						WHERE t.SettlementLogID = @iSettleID
						ORDER BY t.GroupName
							,t.RefId1
							,t.RefId2
						FOR JSON PATH
					)) AS ResTxt
			)
			UPDATE v
			SET v.RHLog = v.RHLog + 'ResourceData NOT EXISTS in RemotingRef'
									+ ' - ResourceData('+ ISNULL(l.ResTxt,'NULL') + ')'
									+ ' - RemotingRef('+ ISNULL(l.RefTxt,'NULL') +')'
				,v.StatusID = @StsGenFailed
			FROM #tmpVerifyList AS v
				INNER JOIN CTE_LogTxt AS l ON v.SettlementLogID = l.SettleID
			
			SELECT @iSettleID = (SELECT MIN(SettlementLogID) FROM #tmpVerifyList WHERE SettlementLogID > @iSettleID)
			
			CONTINUE
		END
		
		/*
			NOT match ResourceID between ActualResult and WrongResult
				For ActionType = 2 (CAL to Refund), WrongResult can NOT blank
				For ActionType = 3 (Refund to CAL), ActualResult NOT blank
				For ActionType = 1 (CAL to CAL), ResourceID between ActualResult and WrongResult must be match 1:1
		*/
		--For ActionType = 2 (CAL to Refund), WrongResult can NOT blank
		IF EXISTS (
			SELECT 1
			FROM SettlementResultHist AS sh WITH (NOLOCK)
				LEFT JOIN #tmpResourceRawData AS r ON sh.SettlementLogID = r.SettlementLogID AND r.AmendInfo = 'WrongResult'
			WHERE sh.SettlementLogID = @iSettleID
				AND sh.ActionType = 2
				AND (r.SettlementLogID IS NULL
					OR r.HomeValue IS NULL
				)
		)
		BEGIN
			;WITH CTE_LogTxt AS (
				SELECT @iSettleID AS SettleID
					,CONVERT(NVARCHAR(MAX),(
						SELECT DISTINCT r.AmendInfo
							,r.ResourceID
							,r.RefBettypeID
							,r.HomeValue
						FROM #tmpResourceRawData AS r
						WHERE r.SettlementLogID = @iSettleID
						ORDER BY r.AmendInfo
							,r.ResourceID
							,r.RefBettypeID
							,r.HomeValue
						FOR JSON AUTO
					)) AS LTxt
			)
			UPDATE v
			SET v.RHLog = v.RHLog + 'Invalid [CAL to Refund], WrongResult NULL (' + ISNULL(l.LTxt,'NULL') + ')'
				,v.StatusID = @StsGenFailed
			FROM #tmpVerifyList AS v
				INNER JOIN CTE_LogTxt AS l ON v.SettlementLogID = l.SettleID
			
			SELECT @iSettleID = (SELECT MIN(SettlementLogID) FROM #tmpVerifyList WHERE SettlementLogID > @iSettleID)
			
			CONTINUE
		END
		
		--For ActionType = 3 (Refund to CAL), ActualResult can NOT blank
		IF EXISTS (
			SELECT 1
			FROM SettlementResultHist AS sh WITH (NOLOCK)
				LEFT JOIN #tmpResourceRawData AS r ON sh.SettlementLogID = r.SettlementLogID AND r.AmendInfo = 'ActualResult'
			WHERE sh.SettlementLogID = @iSettleID
				AND sh.ActionType = 3
				AND (r.SettlementLogID IS NULL
					OR r.HomeValue IS NULL
				)
		)
		BEGIN
			;WITH CTE_LogTxt AS (
				SELECT @iSettleID AS SettleID
					,CONVERT(NVARCHAR(MAX),(
						SELECT DISTINCT r.AmendInfo
							,r.ResourceID
							,r.RefBettypeID
							,r.HomeValue
						FROM #tmpResourceRawData AS r
						WHERE r.SettlementLogID = @iSettleID
						ORDER BY r.AmendInfo
							,r.ResourceID
							,r.RefBettypeID
							,r.HomeValue
						FOR JSON AUTO
					)) AS LTxt
			)
			UPDATE v
			SET v.RHLog = v.RHLog + 'Invalid [Refund to CAL], ActualResult NULL (' + ISNULL(l.LTxt,'NULL') + ')'
				,v.StatusID = @StsGenFailed
			FROM #tmpVerifyList AS v
				INNER JOIN CTE_LogTxt AS l ON v.SettlementLogID = l.SettleID
			
			SELECT @iSettleID = (SELECT MIN(SettlementLogID) FROM #tmpVerifyList WHERE SettlementLogID > @iSettleID)
			
			CONTINUE
		END
		
		--For ActionType = 1 (CAL to CAL), ResourceID between ActualResult and WrongResult must be match 1:1
		IF EXISTS (
			SELECT 1
			FROM SettlementResultHist AS sh WITH (NOLOCK)
			WHERE sh.SettlementLogID = @iSettleID
				AND sh.ActionType = 1
		)
		AND EXISTS (
			SELECT 1
			FROM (SELECT * FROM #tmpResourceRawData WHERE SettlementLogID = @iSettleID AND AmendInfo = 'WrongResult') AS w
				FULL OUTER JOIN (SELECT * FROM #tmpResourceRawData WHERE SettlementLogID = @iSettleID AND AmendInfo = 'ActualResult') AS a
					ON w.SettlementLogID = a.SettlementLogID
						AND a.ResourceID = w.ResourceID
						AND a.RefBettypeID = w.RefBettypeID
			WHERE a.HomeValue IS NULL
				OR w.HomeValue IS NULL
		)
		BEGIN
			;WITH CTE_LogTxt AS (
				SELECT DISTINCT @iSettleID AS SettleID
					,CONVERT(NVARCHAR(MAX),(
						SELECT DISTINCT t.AmendInfo
							,t.ResourceID
							,t.RefBettypeID
							,t.HomeValue
						FROM #tmpResourceRawData AS t
						WHERE t.SettlementLogID = ISNULL(w.SettlementLogID, a.SettlementLogID)
						ORDER BY t.AmendInfo
							,t.ResourceID
							,t.RefBettypeID
							,t.HomeValue
						FOR JSON AUTO
					)) AS LTxt
				FROM (SELECT * FROM #tmpResourceRawData WHERE SettlementLogID = @iSettleID AND AmendInfo = 'WrongResult') AS w
					FULL OUTER JOIN (SELECT * FROM #tmpResourceRawData WHERE SettlementLogID = @iSettleID AND AmendInfo = 'ActualResult') AS a
						ON w.SettlementLogID = a.SettlementLogID
							AND a.ResourceID = w.ResourceID
							AND a.RefBettypeID = w.RefBettypeID
				WHERE a.HomeValue IS NULL
					OR w.HomeValue IS NULL
			)
			UPDATE v
			SET v.RHLog = v.RHLog + 'Invalid [CAL to CAL], NOT match ResourceID 1:1 between ActualResult and WrongResult (' + ISNULL(l.LTxt,'NULL') + ')'
				,v.StatusID = @StsGenFailed
			FROM #tmpVerifyList AS v
				INNER JOIN CTE_LogTxt AS l ON v.SettlementLogID = l.SettleID
			
			SELECT @iSettleID = (SELECT MIN(SettlementLogID) FROM #tmpVerifyList WHERE SettlementLogID > @iSettleID)
			
			CONTINUE
		END
		
		/*
			write more info if enable UATMode
			
			write #tmpRemotingRefData if enable UATMode AND any returned NULL value
				- RefId2 IS NULL
				- English value IS NULL
				- match info IS NULL
		*/
		IF EXISTS (SELECT 1 FROM #tmpRemotingRefData WHERE SettlementLogID = @iSettleID AND (RefId2 IS NULL OR RefValueEN IS NULL) AND @LogMode = 'Debug')
		BEGIN
			UPDATE #tmpVerifyList
			SET RHLog = RHLog + 'RemotingRef Returned NULL value ('
							+ (SELECT CONVERT(NVARCHAR(MAX)
									,(SELECT ISNULL(GroupName,'NULL') AS GroupName
										,ISNULL(RefId1,'NULL') AS RefId1
										,ISNULL(RefId2,'NULL') AS RefId2
										,ISNULL(RefValueEN,'NULL') AS RefValueEN
										,ISNULL(RefValueCH,'NULL') AS RefValueCH
										,ISNULL(RefValueCS,'NULL') AS RefValueCS
									FROM #tmpRemotingRefData
									WHERE SettlementLogID = @iSettleID
									FOR JSON AUTO
									))
							)
							+')'
			WHERE SettlementLogID = @iSettleID
		END
		
		----reset for loop------
		SELECT @iSettleID = (SELECT MIN(SettlementLogID) FROM #tmpVerifyList WHERE SettlementLogID > @iSettleID)
	END TRY
	BEGIN CATCH
		
		--update Failed
		UPDATE #tmpVerifyList
		SET StatusID = @StsGenFailed
			,RHLog = RHLog + 'FAILED while Verifing SettlementResultHist - ERROR_MESSAGE(' + ISNULL(@ErrMsg,'NULL') + ')'
		WHERE SettlementLogID = @iSettleID
		
		----reset for loop------
		SELECT @iSettleID = (SELECT MIN(SettlementLogID) FROM #tmpVerifyList WHERE SettlementLogID > @iSettleID)
	END CATCH
	
	--return Valid as list
	SELECT @ValidSettlementLogIDs = ''
	SELECT @ValidSettlementLogIDs = ISNULL(STRING_AGG(CONVERT(VARCHAR(MAX),rh.SettlementLogID),','),'')
	FROM #tmpVerifyList AS rh
		INNER JOIN SettlementResultHist AS sh WITH (ROWLOCK,UPDLOCK) ON rh.SettlementLogID = sh.SettlementLogID
	WHERE rh.StatusID = @StsGenerating
		AND sh.StatusID = @StsGenerating
	
	/*
		Failed to Verify
	*/
	UPDATE sh
	SET sh.StatusID = rh.StatusID
		,sh.LastModifiedTime = GETDATE()
	FROM SettlementResultHist AS sh WITH (ROWLOCK,UPDLOCK)
		INNER JOIN #tmpVerifyList AS rh ON rh.SettlementLogID = sh.SettlementLogID
	WHERE sh.StatusID = @StsGenerating
		AND rh.SettlementLogID NOT IN (
			SELECT TRY_CONVERT(INT, value) AS SettlementLogID
			FROM STRING_SPLIT(@ValidSettlementLogIDs, ',')
		)
		AND rh.StatusID NOT IN (
			0 --ingore update status some case
			,@StsGenerating
		)
	
	/*
		write log for Changed [Successfully Generated] / [Failed to Generate] Status
	*/
	INSERT INTO [Log] (
		RefID
		,ActionID
		,UserID
		,LogBef
	)
	SELECT rh.SettlementLogID
		,@LogActionID
		,@LogUserID
		,CASE WHEN rh.StatusID = @StsGenFailed THEN @ErrLogPrefix + '[Generate Msg Noti process - Verify] - Changed SettlementLogID Status from [Generating] to [Failed to Generate] (' + rh.RHLog + ')'
			WHEN rh.StatusID = @StsGenerated THEN @InfLogPrefix + '[Generate Msg Noti process - Verify] - Changed SettlementLogID Status from [Generating] to [Successfully Generated] (' + rh.RHLog + ')'
			WHEN rh.StatusID = 0 THEN @InfLogPrefix + '[Generate Msg Noti process - Verify] - Ingore Generate(' + rh.RHLog + ')'
			ELSE @InfLogPrefix + '[Generate Msg Noti process - Verify] - Verify without error' + ISNULL('(' + NULLIF(TRIM(rh.RHLog),'') + ')','.') END
	FROM #tmpVerifyList AS rh
	WHERE rh.SettlementLogID NOT IN (
			SELECT TRY_CONVERT(INT, value) AS SettlementLogID
			FROM STRING_SPLIT(@ValidSettlementLogIDs, ',')
		)
	ORDER BY rh.SettlementLogID
	
	INSERT INTO [Log] (
		ActionID
		,UserID
		,LogBef
	)
	SELECT @LogActionID
		,@LogUserID
		,@InfLogPrefix + 'Debug - Return after verifying - @ValidSettlementLogIDs(' + ISNULL(@ValidSettlementLogIDs,'NULL') + ')'
	WHERE @LogMode = 'Debug'
	
	DROP TABLE IF EXISTS #tmpResourceRef
	DROP TABLE IF EXISTS #tmpResourceRawData
	DROP TABLE IF EXISTS #tmpVerifyList
	DROP TABLE IF EXISTS #tmpRemotingRefData
END
