/*<info serverAlias="DBCRM-MessageNotification" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE MNC_ResultAmendment_GetSettlementLogIDs
	@Environment VARCHAR(5)
	,@JSRemotingRef NVARCHAR(MAX)
	,@ValidSettlementLogIDs VARCHAR(MAX) OUTPUT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(2000) = '' OUTPUT
AS
/*
	Created: 20231213@Roy
	Task: get valid SettlementLogIDs and return it as list
	DB: DBCRM.MessageNotification
	Revisions:
		20230515@Roy: CRM - Implement Message Notifications Center for Result Amendment of Cricket(#197621)
	
	Param's Explanation:
		@Environment
			If UATMode = OFF
			  + @Environment = PRD => handle all data
			  + @Environment = UAT => return
			If UATMode = ON
			  + @Environment = PRD => handle REAL data
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
		,@JSResource NVARCHAR(MAX)
	
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
	WHERE VID = 11 --UATMode
	
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
		SELECT @ValidSettlementLogIDs = ''
		
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
	
	CREATE TABLE #tmpVerifyInfo (
		ID INT IDENTITY(1, 1) PRIMARY KEY
		,SettlementLogID INT
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
		SELECT DISTINCT value AS SettlementLogID
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
		SELECT @ErrCode = @@ERROR --output for web
			,@ErrMsg = ERROR_MESSAGE() --output for web
		
		SELECT @ValidSettlementLogIDs = '' --output
		
		INSERT INTO [Log] (
			ActionID
			,UserID
			,LogBef
		)
		SELECT @LogActionID
			,@LogUserID
			,@ErrLogPrefix + 'FAILED to Parse JSON Data - ERROR_MESSAGE('
								+ ISNULL(@ErrMsg,'NULL')
								+ ') with @JSRemotingRef = ('
								+ ISNULL(@JSRemotingRef,'NULL')
								+ ')'
		
	END CATCH
	/*
		Start to verfy info before generate message
	*/
	IF NOT EXISTS (SELECT 1 FROM #tmpRemotingRefData)
		OR EXISTS (SELECT 1 FROM #tmpRemotingRefData WHERE SettlementLogID IS NULL)
	BEGIN
		SELECT @ValidSettlementLogIDs = ''
			,@ErrCode = 1 --output for web
			,@ErrMsg = 'Invalid data @JSRemotingRef (' + ISNULL(@JSRemotingRef,'NULL') + ')' --output for web
		
		INSERT INTO [Log] (
			ActionID
			,UserID
			,LogBef
		)
		SELECT @LogActionID
			,@LogUserID
			,@ErrLogPrefix + 'Invalid data @JSRemotingRef (' + ISNULL(@JSRemotingRef,'NULL') + ')'
	END
	
	;WITH CTE_SettleID AS (
		SELECT DISTINCT SettlementLogID
		FROM #tmpRemotingRefData
		WHERE SettlementLogID IS NOT NULL
	)
	INSERT INTO #tmpVerifyInfo (SettlementLogID, StatusID)
	SELECT DISTINCT s.SettlementLogID
		,sh.StatusID
	FROM CTE_SettleID AS s
		LEFT JOIN SettlementResultHist AS sh ON s.SettlementLogID = sh.SettlementLogID
	ORDER BY s.SettlementLogID
	
	--loop foreach SettlementLogID
	DECLARE @iLoop INT = 1
		,@SettleID INT
	
	WHILE (1=1)
	BEGIN TRY
		SELECT @SettleID = SettlementLogID
		FROM #tmpVerifyInfo
		WHERE ID = @iLoop
		
		IF NOT EXISTS (SELECT 1 FROM #tmpVerifyInfo WHERE ID = @iLoop)
			BREAK
		
		--Check EXISTS SettlementResultHist
		IF NOT EXISTS (SELECT 1 FROM SettlementResultHist WHERE SettlementLogID = @SettleID)
		BEGIN
			UPDATE #tmpVerifyInfo
			SET StatusID = @StsGenFailed
				,RHLog = 'NOT EXISTS in SettlementResultHist'
			WHERE ID = @iLoop
			
			SELECT @iLoop = @iLoop + 1
			
			CONTINUE
		END
		
		--Check IsTestFlag (NOT Failed Status but ignore valid List)
		IF NOT EXISTS (SELECT 1 FROM SettlementResultHist WHERE SettlementLogID = @SettleID AND ISNULL(@IsTestFlag,IsTest) = IsTest)
		BEGIN
			UPDATE v
			SET StatusID = 0
				,v.RHLog = v.RHLog + '@IsTestFlag('+ ISNULL(CONVERT(VARCHAR,@IsTestFlag),'NULL') +' - By Environment('+@Environment+')/UATMode('+@UATMode+')) NOT match with IsTest('+ ISNULL(CONVERT(VARCHAR,sh.IsTest),'NULL') +')'
			FROM #tmpVerifyInfo AS v
				INNER JOIN SettlementResultHist AS sh WITH (NOLOCK) ON v.SettlementLogID = sh.SettlementLogID
			WHERE v.ID = @iLoop
			
			SELECT @iLoop = @iLoop + 1
			
			CONTINUE
		END
		
		--Check Generated
		IF EXISTS (SELECT 1 FROM NotiMapping WHERE SettlementLogID = @SettleID)
		BEGIN
			UPDATE v
			SET StatusID = 0
				,v.RHLog = v.RHLog + 'SettlementLogID is Generated - EXISTS in NotiMapping'
			FROM #tmpVerifyInfo AS v
				INNER JOIN NotiMapping AS nm WITH (NOLOCK) ON v.SettlementLogID = nm.SettlementLogID
			WHERE v.ID = @iLoop
			
			SELECT @iLoop = @iLoop + 1
			
			CONTINUE
		END
		
		--check for NOT Generating (KEEP Current Status but ignore valid List)
		IF NOT EXISTS (SELECT 1 FROM SettlementResultHist WHERE SettlementLogID = @SettleID AND StatusID = @StsGenerating)
		BEGIN
			UPDATE #tmpVerifyInfo
			SET StatusID = 0
				,RHLog = RHLog + 'StatusID ('+ ISNULL(CONVERT(NVARCHAR,StatusID),'NULL') + ') - NOT Generating'
			WHERE ID = @iLoop
			
			SELECT @iLoop = @iLoop + 1
			
			CONTINUE
		END
		
		--Invalid EventInfo (MatchID/HomeID..)
		IF EXISTS (
			SELECT 1
			FROM SettlementResultHist AS sh WITH (NOLOCK)
				LEFT JOIN bodb02.dbo.match AS m WITH (NOLOCK) ON sh.MatchID = m.MatchID
				LEFT JOIN bodb02.dbo.match14 AS m14 WITH (NOLOCK) ON sh.MatchID = m14.MatchID
				LEFT JOIN bodb02.dbo.team AS h WITH (NOLOCK) ON ISNULL(m.HomeID, m14.HomeID) = h.TeamID
				LEFT JOIN bodb02.dbo.team AS a WITH (NOLOCK) ON ISNULL(m.AwayID, m14.AwayID) = a.TeamID
				LEFT JOIN bodb02.dbo.league AS l WITH (NOLOCK) ON ISNULL(m.LeagueID, m14.LeagueID) = l.LeagueID
			WHERE sh.SettlementLogID = @SettleID
				AND (
					ISNULL(m.MatchID, m14.MatchID) IS NULL
					OR h.TeamID IS NULL
					OR a.TeamID IS NULL
					OR l.LeagueID IS NULL
				)
		)
		BEGIN
			;WITH CTE_LogTxt AS (
				SELECT @iLoop AS ID
					,(CASE WHEN ISNULL(m.MatchID, m14.MatchID) IS NULL THEN 'MatchID(' + CONVERT(VARCHAR,sh.MatchID) + ') NOT exits IN match/match14'
							WHEN h.TeamID IS NULL THEN 'HomeID(' + ISNULL(CONVERT(VARCHAR,COALESCE(m.HomeID,m14.HomeID)),'NULL') + ') NOT exits IN team'
							WHEN a.TeamID IS NULL THEN 'AwayID(' + ISNULL(CONVERT(VARCHAR,COALESCE(m.AwayID,m14.AwayID)),'NULL') + ') NOT exits IN team'
							WHEN l.LeagueID IS NULL THEN 'LeagueID(' + ISNULL(CONVERT(VARCHAR,COALESCE(m.LeagueID, m14.LeagueID)),'NULL') + ') NOT exits IN league'
					END
					) AS LTxt
				FROM SettlementResultHist AS sh WITH (NOLOCK)
					LEFT JOIN bodb02.dbo.match AS m WITH (NOLOCK) ON sh.MatchID = m.MatchID
					LEFT JOIN bodb02.dbo.match14 AS m14 WITH (NOLOCK) ON sh.MatchID = m14.MatchID
					LEFT JOIN bodb02.dbo.team AS h WITH (NOLOCK) ON ISNULL(m.HomeID, m14.HomeID) = h.TeamID
					LEFT JOIN bodb02.dbo.team AS a WITH (NOLOCK) ON ISNULL(m.AwayID, m14.AwayID) = a.TeamID
					LEFT JOIN bodb02.dbo.league AS l WITH (NOLOCK) ON ISNULL(m.LeagueID, m14.LeagueID) = l.LeagueID
				WHERE sh.SettlementLogID = @SettleID
					AND (
						ISNULL(m.MatchID, m14.MatchID) IS NULL
							OR h.TeamID IS NULL
							OR a.TeamID IS NULL
							OR l.LeagueID IS NULL
					)
			)
			UPDATE v
			SET v.RHLog = v.RHLog + 'Invalid EventInfo - ' + ISNULL(l.LTxt,'')
				,v.StatusID = @StsGenFailed
			FROM #tmpVerifyInfo AS v
				INNER JOIN CTE_LogTxt AS l ON v.ID = l.ID
			
			SELECT @iLoop = @iLoop + 1
			
			CONTINUE
		END
		
		--check for EXISTS in SettlementResultHistDetail
		IF NOT EXISTS (SELECT 1 FROM SettlementResultHistDetail WHERE SettlementLogID = @SettleID)
		BEGIN
			UPDATE #tmpVerifyInfo
			SET StatusID = @StsGenerated
				,RHLog = RHLog + 'have NO affected TransID'
			WHERE ID = @iLoop
			
			SELECT @iLoop = @iLoop + 1
			
			CONTINUE
		END
		
		--Check Invalid CustID
		IF EXISTS (
			SELECT 1
			FROM SettlementResultHistDetail AS rhd WITH (NOLOCK)
				LEFT JOIN bodb02.dbo.Customer AS c WITH (NOLOCK) ON rhd.CustID = c.CustID
			WHERE rhd.SettlementLogID = @SettleID
				AND c.CustID IS NULL
		)
		BEGIN
			;WITH CTE_IC AS (
				SELECT @iLoop AS ID
					,STRING_AGG(CONVERT(VARCHAR(MAX),CustID),',') AS FText
				FROM (
					SELECT DISTINCT ISNULL(CONVERT(VARCHAR,rhd.CustID),'NULL') AS CustID
					FROM SettlementResultHistDetail AS rhd WITH (NOLOCK)
						LEFT JOIN bodb02.dbo.Customer AS c WITH (NOLOCK) ON rhd.CustID = c.CustID
					WHERE rhd.SettlementLogID = @SettleID
						AND c.CustID IS NULL
				) AS t
			)
			UPDATE v
			SET v.RHLog = v.RHLog + 'Invalid CustID(' + c.FText + ')'
				,v.StatusID = @StsGenFailed
			FROM #tmpVerifyInfo AS v
				INNER JOIN CTE_IC AS c ON v.ID = c.ID
			
			SELECT @iLoop = @iLoop + 1
			
			CONTINUE
		END
		
		---Check ActionType---
		IF EXISTS (
			SELECT 1
			FROM SettlementResultHist WITH (NOLOCK)
			WHERE SettlementLogID = @SettleID
				AND ActionType NOT IN (1,2,3) --1 (CAL to CAL) / 2 (CAL to Refund) / 3 (Refund to CAL)
		)
		BEGIN
			UPDATE #tmpVerifyInfo
			SET RHLog = RHLog + 'ActionType NOT IN (1,2,3)'
				,StatusID = @StsGenFailed
			WHERE ID = @iLoop
			
			SELECT @iLoop = @iLoop + 1
			
			CONTINUE
		END
		
		--Failed to convert ActualResult/WrongResult to XML
		IF EXISTS (
			SELECT 1
			FROM SettlementResultHist WITH (NOLOCK)
			WHERE SettlementLogID = @SettleID
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
			UPDATE #tmpVerifyInfo
			SET RHLog = RHLog + 'Failed to convert ActualResult/WrongResult to XML'
				,StatusID = @StsGenFailed
			WHERE ID = @iLoop
			
			SELECT @iLoop = @iLoop + 1
			
			CONTINUE
		END
		
		/*
			Parse ALL as RemotingRef
		*/
		TRUNCATE TABLE #tmpResourceRef
		
		SET @JSResource = ''
		EXEC MNC_ResultAmendment_JSParseResult
			@SettlementLogIDs = @SettleID
			,@ParseAmendInfo = 'ALL'
			,@ParseTo = 'RemotingRef'
			,@OutJSResource = @JSResource OUTPUT
			,@ErrCode = @ErrCode OUTPUT
			,@ErrMsg = @ErrMsg OUTPUT
		
		--ParseResult Error
		IF @ErrCode <> 0
		BEGIN
			
			UPDATE v
			SET v.RHLog = v.RHLog + 'FAILED parse SettlementLogID(' + CONVERT(VARCHAR,@SettleID) + ') to RemotingRef format before verify ResourceData'
				,v.StatusID = @StsGenFailed
			FROM #tmpVerifyInfo AS v
			WHERE v.ID = @iLoop
			
			SELECT @iLoop = @iLoop + 1
			
			CONTINUE
		END
		
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
		
		UPDATE STATISTICS #tmpResourceRef
		
		--ResourceData NOT EXISTS in RemotingRef
		IF EXISTS (
			SELECT 1
			FROM #tmpResourceRef AS rs
				LEFT JOIN #tmpRemotingRefData AS rf
					ON rs.GroupName = rf.GroupName
						AND rs.RefId1 = rf.RefId1
						AND rs.RefId2 = rf.RefId2
			WHERE rf.RefValueEN IS NULL
		)
		BEGIN
			;WITH CTE_LogTxt AS (
				SELECT @iLoop AS ID
					,CONVERT(NVARCHAR(MAX),(
						SELECT DISTINCT t.GroupName
							,t.RefId1
							,t.RefId2
						FROM #tmpRemotingRefData AS t
						WHERE t.SettlementLogID = @SettleID
						ORDER BY t.GroupName
							,t.RefId1
							,t.RefId2
						FOR JSON AUTO
					)) AS RefTxt
					,CONVERT(NVARCHAR(MAX),(
						SELECT DISTINCT t.GroupName
							,t.RefId1
							,t.RefId2
						FROM #tmpResourceRef AS t
							LEFT JOIN #tmpRemotingRefData AS rf
								ON t.GroupName = rf.GroupName
									AND t.RefId1 = rf.RefId1
									AND t.RefId2 = rf.RefId2
						WHERE rf.RefValueEN IS NULL
						ORDER BY t.GroupName
							,t.RefId1
							,t.RefId2
						FOR JSON AUTO
					)) AS ResTxt
			)
			UPDATE v
			SET v.RHLog = v.RHLog + 'ResourceData NOT EXISTS in RemotingRef; ResourceData('+ ISNULL(l.ResTxt,'') + '); RemotingRef('+ ISNULL(l.RefTxt,'') +')'
				,v.StatusID = @StsGenFailed
			FROM #tmpVerifyInfo AS v
				INNER JOIN CTE_LogTxt AS l ON v.ID = l.ID
			
			SELECT @iLoop = @iLoop + 1
			
			CONTINUE
		END
		
		/*
			Parse ActualResult / WrongResult as RawData
		*/
		TRUNCATE TABLE #tmpResourceRawData
		SET @JSResource = ''
		
		EXEC MNC_ResultAmendment_JSParseResult
			@SettlementLogIDs = @SettleID
			,@ParseAmendInfo = 'ActualResult,WrongResult'
			,@ParseTo = 'RawData'
			,@OutJSResource = @JSResource OUTPUT
			,@ErrCode = @ErrCode OUTPUT
			,@ErrMsg = @ErrMsg OUTPUT
		
		--ParseResult Error
		IF @ErrCode <> 0
		BEGIN
			
			UPDATE v
			SET v.RHLog = v.RHLog + 'FAILED parse SettlementLogID(' + CONVERT(VARCHAR,@SettleID) + ') to RawData format before verify ActualResult/WrongResult'
				,v.StatusID = @StsGenFailed
			FROM #tmpVerifyInfo AS v
			WHERE v.ID = @iLoop
			
			SELECT @iLoop = @iLoop + 1
			
			CONTINUE
		END
		
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
		
		UPDATE STATISTICS #tmpResourceRawData
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
			WHERE sh.SettlementLogID = @SettleID
				AND sh.ActionType = 2
				AND (r.SettlementLogID IS NULL
					OR r.HomeValue IS NULL
				)
		)
		BEGIN
			;WITH CTE_C2R AS (
				SELECT DISTINCT @iLoop AS ID
					,CONVERT(NVARCHAR(MAX),(
						SELECT DISTINCT t.AmendInfo
							,t.ResourceID
							,t.RefBettypeID
							,t.HomeValue
						FROM #tmpResourceRawData AS t
						ORDER BY t.AmendInfo
							,t.ResourceID
							,t.RefBettypeID
							,t.HomeValue
						FOR JSON AUTO
					)) AS LTxt
			)
			UPDATE v
			SET v.RHLog = v.RHLog + 'Invalid [CAL to Refund], WrongResult NULL (' + ISNULL(c.LTxt,'') + ')'
				,v.StatusID = @StsGenFailed
			FROM #tmpVerifyInfo AS v
				INNER JOIN CTE_C2R AS c ON v.ID = c.ID
			
			SELECT @iLoop = @iLoop + 1
			
			CONTINUE
		END
		
		--For ActionType = 3 (Refund to CAL), ActualResult can NOT blank
		IF EXISTS (
			SELECT 1
			FROM SettlementResultHist AS sh WITH (NOLOCK)
				LEFT JOIN #tmpResourceRawData AS r ON sh.SettlementLogID = r.SettlementLogID AND r.AmendInfo = 'ActualResult'
			WHERE sh.SettlementLogID = @SettleID
				AND sh.ActionType = 3
				AND (r.SettlementLogID IS NULL
					OR r.HomeValue IS NULL
				)
		)
		BEGIN
			;WITH CTE_R2C AS (
				SELECT DISTINCT @iLoop AS ID
					,CONVERT(NVARCHAR(MAX),(
						SELECT DISTINCT t.AmendInfo
							,t.ResourceID
							,t.RefBettypeID
							,t.HomeValue
						FROM #tmpResourceRawData AS t
						ORDER BY t.AmendInfo
							,t.ResourceID
							,t.RefBettypeID
							,t.HomeValue
						FOR JSON AUTO
					)) AS LTxt
			)
			UPDATE v
			SET v.RHLog = v.RHLog + 'Invalid [Refund to CAL], ActualResult NULL (' + ISNULL(c.LTxt,'') + ')'
				,v.StatusID = @StsGenFailed
			FROM #tmpVerifyInfo AS v
				INNER JOIN CTE_R2C AS c ON v.ID = c.ID
			
			SELECT @iLoop = @iLoop + 1
			
			CONTINUE
		END
		
		--For ActionType = 1 (CAL to CAL), ResourceID between ActualResult and WrongResult must be match 1:1
		IF EXISTS (
			SELECT 1
			FROM SettlementResultHist AS sh WITH (NOLOCK)
			WHERE sh.SettlementLogID = @SettleID
				AND sh.ActionType = 1
		)
		AND EXISTS (
			SELECT 1
			FROM #tmpResourceRawData AS w
				FULL OUTER JOIN #tmpResourceRawData AS a
					ON w.SettlementLogID = a.SettlementLogID
						AND a.ResourceID = w.ResourceID
						AND a.RefBettypeID = w.RefBettypeID
						AND a.AmendInfo = 'ActualResult'
						AND w.AmendInfo = 'WrongResult'
			WHERE a.HomeValue IS NULL
				OR w.HomeValue IS NULL
		)
		BEGIN
			;WITH CTE_C2C AS (
				SELECT DISTINCT @iLoop AS ID
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
				FROM #tmpResourceRawData AS w
					FULL OUTER JOIN #tmpResourceRawData AS a
						ON w.SettlementLogID = a.SettlementLogID
							AND a.AmendInfo = 'ActualResult'
							AND w.AmendInfo = 'WrongResult'
							AND a.ResourceID = w.ResourceID
							AND a.RefBettypeID = w.RefBettypeID
				WHERE a.HomeValue IS NULL
					OR w.HomeValue IS NULL
			)
			UPDATE v
			SET v.RHLog = v.RHLog + 'Invalid [CAL to CAL], NOT match ResourceID 1:1 between ActualResult and WrongResult (' + ISNULL(c.LTxt,'') + ')'
				,v.StatusID = @StsGenFailed
			FROM #tmpVerifyInfo AS v
				INNER JOIN CTE_C2C AS c ON v.ID = c.ID
			
			SELECT @iLoop = @iLoop + 1
			
			CONTINUE
		END
		
		/*
			write more info if enable UATMode
			
			write #tmpRemotingRefData if enable UATMode AND any returned NULL value
				- RefId2 IS NULL
				- English value IS NULL
				- match info IS NULL
		*/
		IF EXISTS (SELECT 1 FROM #tmpRemotingRefData WHERE SettlementLogID = @SettleID AND (RefId2 IS NULL OR RefValueEN IS NULL) AND @UATMode = 'ON') 
		BEGIN
			UPDATE #tmpVerifyInfo
			SET RHLog = RHLog + 'RemotingRef Returned NULL value ('
							+ (SELECT CONVERT(NVARCHAR(MAX)
									,(SELECT ISNULL(GroupName,'NULL') AS GroupName
										,ISNULL(RefId1,'NULL') AS RefId1
										,ISNULL(RefId2,'NULL') AS RefId2
										,ISNULL(RefValueEN,'NULL') AS RefValueEN
										,ISNULL(RefValueCH,'NULL') AS RefValueCH
										,ISNULL(RefValueCS,'NULL') AS RefValueCS
									FROM #tmpRemotingRefData
									WHERE SettlementLogID = @SettleID
									FOR JSON AUTO
									))
							)
							+')'
			WHERE ID = @iLoop
		END
		
		----reset for loop------
		SELECT @iLoop = @iLoop + 1
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR --output for web
			,@ErrMsg = ERROR_MESSAGE() --output for web
		
		--update Failed
		UPDATE #tmpVerifyInfo
		SET StatusID = @StsGenFailed
			,RHLog = RHLog + 'FAILED while Verifing SettlementResultHist - ERROR_MESSAGE(' + ISNULL(@ErrMsg,'NULL') + ')'
		WHERE ID = @iLoop
		
		----reset for loop------
		SELECT @iLoop = @iLoop + 1
	END CATCH
	
	--return Valid as list
	SELECT @ValidSettlementLogIDs = ''
	SELECT @ValidSettlementLogIDs = ISNULL(STRING_AGG(CONVERT(VARCHAR(MAX),rh.SettlementLogID),','),'')
	FROM #tmpVerifyInfo AS rh
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
		INNER JOIN #tmpVerifyInfo AS rh ON rh.SettlementLogID = sh.SettlementLogID
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
		,CASE WHEN rh.StatusID = @StsGenFailed THEN @ErrLogPrefix + 'Changed SettlementLogID Status from [Generating] to [Failed to Generate] - ' + rh.RHLog
			WHEN rh.StatusID = @StsGenerated THEN @InfLogPrefix + 'Changed SettlementLogID Status from [Generating] to [Successfully Generated] - ' + rh.RHLog
			ELSE @InfLogPrefix + 'Verify without error and start to generate message' + rh.RHLog END
	FROM #tmpVerifyInfo AS rh
	WHERE rh.SettlementLogID NOT IN (
			SELECT TRY_CONVERT(INT, value) AS SettlementLogID
			FROM STRING_SPLIT(@ValidSettlementLogIDs, ',')
		)
	ORDER BY rh.SettlementLogID
	
	DROP TABLE #tmpResourceRef
	DROP TABLE #tmpResourceRawData
	DROP TABLE #tmpVerifyInfo
	DROP TABLE #tmpRemotingRefData
END
