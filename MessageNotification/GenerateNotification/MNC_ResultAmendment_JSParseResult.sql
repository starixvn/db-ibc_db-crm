/*<info serverAlias="DBCRM-MessageNotification" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE MNC_ResultAmendment_JSParseResult
	@SettlementLogIDs VARCHAR(MAX)
	,@ParseAmendInfo VARCHAR(50) = 'ALL'
	,@ParseTo VARCHAR(50) = 'RemotingRef'
	,@OutJSResource NVARCHAR(MAX) OUTPUT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(2000) = '' OUTPUT
AS
/*
	Created: 20231213@Roy
	Task: Parse ActualResult/WrongResult from XML to table
	DB: DBCRM.MessageNotification
	Revisions:
		20231121@Roy: CRM - Implement Message Notifications Center for Result Amendment of Cricket(#197621)
	
	Param's Explanation:
		@SettlementLogIDs: List of SettlementLogID
		@SportType: default 50 - Cricket
		@ParseAmendInfo: Specific data want to parse to JSON
						- ActualResult
						- WrongResult
						- SettleMatch
						- ALL (default)
		@ParseTo: target format
				- RemotingRef
				- RawData
		
		Output
			@OutJSResource - parse to JSON
	
	Example:
		EXEC MessageNotification.dbo.MNC_ResultAmendment_JSParseResult
*/
BEGIN TRY
	SET NOCOUNT ON
	
	CREATE TABLE #tmpRemotingRef (
		SettlementLogID INT
		,GroupName VARCHAR(50)
		,RefId1 VARCHAR(50)
		,RefId2 VARCHAR(50)
	)
	
	CREATE TABLE #tmpEventInfo (
		SettlementLogID INT
		,MatchID INT
		,SportType INT
		,HomeID INT
		,AwayID INT
		,LeagueID INT
	)
	
	CREATE TABLE #tmpResultInfo (
		SettlementLogID INT
		,AmendInfo VARCHAR(50)
		,ResourceID VARCHAR(50)
		,RefBettypeID VARCHAR(50)
		,HomeValue VARCHAR(50)
		,AwayValue VARCHAR(50)
		,OtherInfo VARCHAR(200)
		,TeamIDs VARCHAR(200)
		,G VARCHAR(50)
		,M VARCHAR(50)
		,X VARCHAR(50)
		,Y VARCHAR(50)
	)
	
	CREATE TABLE #tmpInputIDs (
		SettlementLogID INT
	)
	CREATE CLUSTERED INDEX CIX_tmpInputID ON #tmpInputIDs (SettlementLogID)
	
	--write more info if LogMode = Debug
	DECLARE @LogUserID INT
		,@LogActionID SMALLINT
	
	SELECT @LogUserID = TRY_CONVERT(INT, VValue)
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 2 --ID of StarixIT
	
	SELECT @LogActionID = ActionID
	FROM LogAction WITH (NOLOCK)
	WHERE ActName = ISNULL(OBJECT_NAME(@@PROCID),'Unknown')
	
	INSERT INTO [Log] (
		ActionID
		,UserID
		,LogBef
	)
	SELECT @LogActionID
		,@LogUserID
		,'Info - Debug - Start [Parse SettlementResultHist to JSON]'
						+ ' - @SettlementLogIDs(' + ISNULL(@SettlementLogIDs,'NULL') + ')'
						+ ' - @ParseAmendInfo(' + ISNULL(@ParseAmendInfo,'NULL') + ')'
						+ ' - @ParseTo(' + ISNULL(@ParseTo,'NULL') + ')'
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 13 --LogMode
		AND VValue = 'Debug'
	
	/*
		Start to get data to Parse
		default @ParseAmendInfo = ALL
	*/
	
	SELECT @OutJSResource = ''
	
	IF ISNULL(CHARINDEX('SettleMatch',@ParseAmendInfo),0) = 0
		AND ISNULL(CHARINDEX('ActualResult',@ParseAmendInfo),0) = 0
		AND ISNULL(CHARINDEX('WrongResult',@ParseAmendInfo),0) = 0
	BEGIN
		SET @ParseAmendInfo = 'SettleMatch,ActualResult,WrongResult'
	END
	
	--Parse data only for Cricket
	INSERT INTO #tmpInputIDs (SettlementLogID)
	SELECT DISTINCT sh.SettlementLogID
	FROM SettlementResultHist AS sh WITH (NOLOCK)
	WHERE sh.SettlementLogID IN (SELECT TRY_CONVERT(INT,value) FROM STRING_SPLIT(@SettlementLogIDs, ','))
		AND sh.SportType = 50 --Cricket, need modify for others sport
	
	/*
		Insert #tmpResultInfo with format
		----|---------------|-------------------|---------------|------------|---------------|----------------------|-----------|-------|-------|-------
			|SettlementLogID|AmendInfo			|ResourceID		|RefBettypeID|HomeValue	|AwayValue	|OtherInfo		|TeamIDs	|G		|X		|Y
		----|---------------|-------------------|---------------|------------|----------|-----------|---------------|-----------|-------|-------|-------
			| 2				| SettleMatch		| MatchID		| (NULL)	 | (NULL) 	| (NULL)	| 79288043 		| (NULL) 	| (NULL)|(NULL)	|(NULL)
			| 2				| SettleMatch		| SportType		| (NULL)	 | (NULL) 	| (NULL)	| 50	 		| (NULL) 	| (NULL)|(NULL)	|(NULL)
			| 2				| SettleMatch		| HomeID		| (NULL)	 | (NULL)	| (NULL)	| (NULL)		| 1103146	| (NULL)|(NULL)	|(NULL)
			| 2				| ActualResult		| 96621004		| 9662		 | 01		| (NULL)	| 20439,16776	| (NULL)	| 1		|(NULL)	|(NULL)
			| 2				| WrongResult		| 96621004		| 9662		 | 02		| (NULL)	| 20439,16776	| (NULL)	| 1		|(NULL)	|(NULL)
			| 70			| ActualResult		| 94841004		| 9484		 | 2		| (NULL)	| (NULL)		| (NULL)	| 1		| 4		|(NULL)
			| 70			| WrongResult		| 94841004		| 9484		 | 1		| (NULL)	| (NULL)		| (NULL)	| 1		| 4		|(NULL)
			| 134			| ActualResult		| 96711			| 96711		 | 06,05	| (NULL)	| (NULL)		| (NULL)	| 1		| (NULL)|(NULL)
			| 134			| WrongResult		| 96711			| 96711		 | 06		| (NULL)	| (NULL)		| (NULL)	| 1		| (NULL)|(NULL)
		----|---------------|-------------------|---------------|------------|----------|-----------|---------------|-----------|-------|-------|--------
	*/
	INSERT INTO #tmpEventInfo (
		SettlementLogID
		,MatchID
		,SportType
		,HomeID
		,AwayID
		,LeagueID
	)
	SELECT sh.SettlementLogID
		,ISNULL(m.MatchID, m14.MatchID) AS MatchID
		,sh.SportType
		,ISNULL(m.HomeID, m14.HomeID) AS HomeID
		,ISNULL(m.AwayID, m14.AwayID) AS AwayID
		,ISNULL(m.LeagueID, m14.LeagueID) AS LeagueID
	FROM SettlementResultHist AS sh WITH (NOLOCK)
		INNER JOIN #tmpInputIDs AS i ON sh.SettlementLogID = i.SettlementLogID
		LEFT JOIN bodb02.dbo.match AS m WITH (NOLOCK) ON sh.MatchID = m.MatchID
		LEFT JOIN bodb02.dbo.match14 AS m14 WITH (NOLOCK) ON sh.MatchID = m14.MatchID
	WHERE ISNULL(CHARINDEX('SettleMatch',@ParseAmendInfo),0) > 0
	
	--MatchID--
	INSERT INTO #tmpResultInfo (
		SettlementLogID
		,AmendInfo
		,ResourceID
		,OtherInfo
	)
	SELECT DISTINCT SettlementLogID
		,'SettleMatch' AS AmendInfo
		,'MatchID' AS ResourceID
		,MatchID AS OtherInfo
	FROM #tmpEventInfo
	WHERE MatchID IS NOT NULL
	
	--LeagueID--
	INSERT INTO #tmpResultInfo (
		SettlementLogID
		,AmendInfo
		,ResourceID
		,OtherInfo
	)
	SELECT DISTINCT SettlementLogID
		,'SettleMatch' AS AmendInfo
		,'LeagueID' AS ResourceID
		,LeagueID AS OtherInfo
	FROM #tmpEventInfo
	WHERE LeagueID IS NOT NULL
	
	--SportType--
	INSERT INTO #tmpResultInfo (
		SettlementLogID
		,AmendInfo
		,ResourceID
		,OtherInfo
	)
	SELECT DISTINCT SettlementLogID
		,'SettleMatch' AS AmendInfo
		,'SportType' AS ResourceID
		,SportType AS OtherInfo
	FROM #tmpEventInfo
	WHERE SportType IS NOT NULL
	
	--HomeID--
	INSERT INTO #tmpResultInfo (
		SettlementLogID
		,AmendInfo
		,ResourceID
		,TeamIDs
	)
	SELECT DISTINCT SettlementLogID
		,'SettleMatch' AS AmendInfo
		,'HomeID' AS ResourceID
		,HomeID AS TeamIDs
	FROM #tmpEventInfo
	WHERE HomeID IS NOT NULL
	
	--AwayID--
	INSERT INTO #tmpResultInfo (
		SettlementLogID
		,AmendInfo
		,ResourceID
		,TeamIDs
	)
	SELECT DISTINCT SettlementLogID
		,'SettleMatch' AS AmendInfo
		,'AwayID' AS ResourceID
		,AwayID AS TeamIDs
	FROM #tmpEventInfo
	WHERE AwayID IS NOT NULL
	
	--ActualResult / WrongResult
	;WITH CTE_XML AS (
		SELECT sh.SettlementLogID
			,TRY_CONVERT(XML, sh.ActualResult) AS ActualResultXML
			,TRY_CONVERT(XML, sh.WrongResult) AS WrongResultXML
		FROM SettlementResultHist AS sh WITH (NOLOCK)
			INNER JOIN #tmpInputIDs AS i ON sh.SettlementLogID = i.SettlementLogID
	)
	,CTE_Actual AS (
		SELECT DISTINCT SettlementLogID
			,'ActualResult' AS AmendInfo
			,NULLIF(TRIM(a.c.value('@Id', 'VARCHAR(50)')), '') AS ResourceID
			,NULLIF(TRIM(a.c.value('@RefBettypeID', 'VARCHAR(50)')), '') AS RefBettypeID
			,NULLIF(TRIM(a.c.value('@Home', 'VARCHAR(50)')), '') AS HomeValue
			,NULLIF(TRIM(a.c.value('@Away', 'VARCHAR(50)')), '') AS AwayValue
			,NULLIF(TRIM(a.c.value('@OtherInfo', 'VARCHAR(MAX)')), '') AS OtherInfo
			,NULLIF(TRIM(a.c.value('@TeamIds', 'VARCHAR(MAX)')), '') AS TeamIDs
			,NULLIF(TRIM(a.c.value('@G', 'VARCHAR(50)')), '') AS G
			,NULLIF(TRIM(a.c.value('@M', 'VARCHAR(50)')), '') AS M
			,NULLIF(TRIM(a.c.value('@X', 'VARCHAR(50)')), '') AS X
			,NULLIF(TRIM(a.c.value('@Y', 'VARCHAR(50)')), '') AS Y
		FROM CTE_XML
			OUTER APPLY ActualResultXML.nodes('root/r') a(c)
		WHERE ISNULL(CHARINDEX('ActualResult',@ParseAmendInfo),0) > 0
	)
	,CTE_Wrong AS (
		SELECT DISTINCT SettlementLogID
			,'WrongResult' AS AmendInfo
			,NULLIF(TRIM(w.c.value('@Id', 'VARCHAR(50)')), '') AS ResourceID
			,NULLIF(TRIM(w.c.value('@RefBettypeID', 'VARCHAR(50)')), '') AS RefBettypeID
			,NULLIF(TRIM(w.c.value('@Home', 'VARCHAR(50)')), '') AS HomeValue
			,NULLIF(TRIM(w.c.value('@Away', 'VARCHAR(50)')), '') AS AwayValue
			,NULLIF(TRIM(w.c.value('@OtherInfo', 'VARCHAR(MAX)')), '') AS OtherInfo
			,NULLIF(TRIM(w.c.value('@TeamIds', 'VARCHAR(MAX)')), '') AS TeamIDs --Can value('(//*/@*[lower-case(local-name())="teamids"])[1]', 'INT') to ignore case-sensitive (low performance)
			,NULLIF(TRIM(w.c.value('@G', 'VARCHAR(50)')), '') AS G
			,NULLIF(TRIM(w.c.value('@M', 'VARCHAR(50)')), '') AS M
			,NULLIF(TRIM(w.c.value('@X', 'VARCHAR(50)')), '') AS X
			,NULLIF(TRIM(w.c.value('@Y', 'VARCHAR(50)')), '') AS Y
		FROM CTE_XML
			OUTER APPLY WrongResultXML.nodes('root/r') w(c)
		WHERE ISNULL(CHARINDEX('WrongResult',@ParseAmendInfo),0) > 0
	)
	INSERT INTO #tmpResultInfo (
		SettlementLogID
		,AmendInfo
		,ResourceID
		,RefBettypeID
		,HomeValue
		,AwayValue
		,OtherInfo
		,TeamIDs
		,G
		,M
		,X
		,Y
	)
	SELECT SettlementLogID
		,AmendInfo
		,ResourceID
		,RefBettypeID
		,HomeValue
		,AwayValue
		,OtherInfo
		,TeamIDs
		,G
		,M
		,X
		,Y
	FROM CTE_Actual
	
	UNION ALL
	
	SELECT SettlementLogID
		,AmendInfo
		,ResourceID
		,RefBettypeID
		,HomeValue
		,AwayValue
		,OtherInfo
		,TeamIDs
		,G
		,M
		,X
		,Y
	FROM CTE_Wrong
	
	/*
		Start Parse data to format
		
		default @ParseTo = RemotingRef
	*/
	IF @ParseTo = 'RawData'
	BEGIN
		SELECT @OutJSResource =
			CONVERT(NVARCHAR(MAX)
				,(
					SELECT *
					FROM #tmpResultInfo
					ORDER BY SettlementLogID
						,AmendInfo
						,ResourceID
						FOR JSON AUTO
				)
			)
		
		--write log--
		INSERT INTO [Log] (
			ActionID
			,UserID
			,LogBef
		)
		SELECT @LogActionID
			,@LogUserID
			,'Info - [Parse SettlementResultHist to JSON]'
				+ ' - @SettlementLogIDs(' + ISNULL(@SettlementLogIDs,'NULL') + ')'
				+ ' - @ParseAmendInfo(' + ISNULL(@ParseAmendInfo,'NULL') + ')'
				+ ' - @ParseTo(' + ISNULL(@ParseTo,'NULL') + ')'
				+ ' - @OutJSResource(' + ISNULL(@OutJSResource,'NULL') + ')'
	END
	ELSE
	BEGIN
		/*
			Insert #tmpRemotingRef with format
			----|---------------|---------------|-------------------|---------------
				|SettlementLogID|GroupName		|RefId1				|RefId2
			----|---------------|---------------|-------------------|---------------
				| 1				| RefResource	| ResourceCricket	| G1
				| 1				| RefResource	| ResourceCricket	| G1
				| 1				| EventInfo		| SportType			| 50
				| 2				| EventInfo		| TeamID			| 16776
			----|---------------|---------------|-------------------|---------------
			
			For GroupName=RefResource
		*/
		--<RefBettypeID>
		INSERT INTO #tmpRemotingRef (
			SettlementLogID
			,GroupName
			,RefId1
			,RefId2
		)
		SELECT DISTINCT SettlementLogID
			,'RefResource' AS GroupName
			,'ResourceCricket' AS RefId1
			,RefBettypeID AS RefId2
		FROM #tmpResultInfo
		WHERE RefBettypeID IS NOT NULL
		
		--For <G>, get both G & M ResourceId
		;WITH CTE_G AS (
			SELECT 'M' AS RefId2
			UNION
			SELECT 'G' AS RefId2
		)
		,CTE_AffectedResult AS (
			SELECT SettlementLogID
				,G AS tG
			FROM #tmpResultInfo
			WHERE G IS NOT NULL

			UNION

			SELECT SettlementLogID
				,M AS tG
			FROM #tmpResultInfo
			WHERE M IS NOT NULL
		)
		INSERT INTO #tmpRemotingRef (
			SettlementLogID
			,GroupName
			,RefId1
			,RefId2
		)
		SELECT DISTINCT ar.SettlementLogID
			,'RefResource' AS GroupName
			,'ResourceCricket' AS RefId1
			,g.RefId2 + ar.tG AS RefId2
		FROM CTE_G AS g
			,CTE_AffectedResult AS ar
		
		--<HomeValue> / <AwayValue>
		;WITH CTE_HA AS (
			SELECT SettlementLogID
				,HomeValue AS RefId2
			FROM #tmpResultInfo
			WHERE HomeValue IS NOT NULL
			
			UNION ALL
			
			SELECT SettlementLogID
				,AwayValue AS RefId2
			FROM #tmpResultInfo
			WHERE AwayValue IS NOT NULL
		)
		,CTE_Result AS (
			SELECT SettlementLogID
				,value AS RefId2
			FROM CTE_HA
				CROSS APPLY STRING_SPLIT(RefId2, ',')
			WHERE NULLIF(TRIM(value), '') IS NOT NULL
		)
		INSERT INTO #tmpRemotingRef (
			SettlementLogID
			,GroupName
			,RefId1
			,RefId2
		)
		SELECT DISTINCT SettlementLogID
			,'RefResource' AS GroupName
			,'ResultSettlement' AS RefId1
			,RefId2
		FROM CTE_Result
		WHERE RefId2 LIKE '%[a-zA-Z][a-zA-Z]%' --characters
			AND RefId2 NOT IN ('H','A') --for case Cricket » Early Result Types 3, Cricket » Early Result Types 8
		
		/*
			For GroupName=EventInfo
		*/
		--<TeamIDs>, <OtherInfo> (include HomeID/AwayID from AmendInfo.SettleMatch)
		;WITH CTE_TeamIDs AS (
			SELECT SettlementLogID
				,'TeamID' AS RefId1
				,value AS RefId2
			FROM #tmpResultInfo
				CROSS APPLY STRING_SPLIT(TeamIDs, ',')
				--AmendInfo = 'SettleMatch': HomeID/AwayID retrived from MatchID
				--AmendInfo IN ('ActualResult', 'WrongResult'): HomeID/AwayID retrived from ActualResult/WrongResult
			
			UNION ALL
			
			SELECT SettlementLogID
				,'TeamID' AS RefId1
				,value AS RefId2
			FROM #tmpResultInfo
				CROSS APPLY STRING_SPLIT(OtherInfo, ',')
			WHERE AmendInfo <> 'SettleMatch'
		)
		INSERT INTO #tmpRemotingRef (
			SettlementLogID
			,GroupName
			,RefId1
			,RefId2
		)
		SELECT DISTINCT SettlementLogID
			,'EventInfo' AS GroupName
			,RefId1
			,RefId2
		FROM CTE_TeamIDs
		WHERE NULLIF(TRIM(RefId2), '') IS NOT NULL
	
		--SportType
		INSERT INTO #tmpRemotingRef (
			SettlementLogID
			,GroupName
			,RefId1
			,RefId2
		)
		SELECT DISTINCT SettlementLogID
			,'EventInfo' AS GroupName
			,ResourceID AS RefId1
			,OtherInfo AS RefId2
		FROM #tmpResultInfo
		WHERE ResourceID = 'SportType'
		
		--LeagueID
		INSERT INTO #tmpRemotingRef (
			SettlementLogID
			,GroupName
			,RefId1
			,RefId2
		)
		SELECT DISTINCT SettlementLogID
			,'EventInfo' AS GroupName
			,ResourceID AS RefId1
			,OtherInfo AS RefId2
		FROM #tmpResultInfo
		WHERE ResourceID = 'LeagueID'
		
		--return--
		SELECT @OutJSResource =
			CONVERT(NVARCHAR(MAX)
				,(
					SELECT DISTINCT rf.SettlementLogID
						,rf.GroupName
						,rf.RefId1
						,rf.RefId2
					FROM #tmpRemotingRef AS rf
					ORDER BY rf.SettlementLogID
						,rf.GroupName
						,rf.RefId1
						,rf.RefId2
						FOR JSON AUTO
				)
			)
		
		--write log--
		INSERT INTO [Log] (
			ActionID
			,UserID
			,LogBef
		)
		SELECT @LogActionID
			,@LogUserID
			,'Info - [Parse SettlementResultHist to JSON]'
				+ ' - @SettlementLogIDs(' + ISNULL(@SettlementLogIDs,'NULL') + ')'
				+ ' - @ParseAmendInfo(' + ISNULL(@ParseAmendInfo,'NULL') + ')'
				+ ' - @ParseTo(' + ISNULL(@ParseTo,'NULL') + ')'
				+ ' - @OutJSResource(' + ISNULL(@OutJSResource,'NULL') + ')'
	END
	
	DROP TABLE #tmpRemotingRef
	DROP TABLE #tmpEventInfo
	DROP TABLE #tmpResultInfo
END TRY
BEGIN CATCH
	SELECT @ErrCode = @@ERROR --output for web
		,@ErrMsg = ERROR_MESSAGE() --output for web
	
	INSERT INTO [Log] (
		ActionID
		,UserID
		,LogBef
	)
	SELECT (SELECT ActionID FROM LogAction WITH (NOLOCK) WHERE ActName = ISNULL(OBJECT_NAME(@@PROCID),'Unknown')) AS ActionID
		,(SELECT TRY_CONVERT(INT, VValue) FROM SystemSetting WITH (NOLOCK) WHERE VID = 2) AS UserID --ID of StarixIT
		,'Error - FAILED [Parse SettlementResultHist to JSON]'
			+ ' - @SettlementLogIDs(' + ISNULL(@SettlementLogIDs,'NULL') + ')'
			+ ' - @ParseAmendInfo(' + ISNULL(@ParseAmendInfo,'NULL') + ')'
			+ ' - @ParseTo(' + ISNULL(@ParseTo,'NULL') + ')'
			+ ' - @OutJSResource(' + ISNULL(@OutJSResource,'NULL') + ')'
			+ ' - ERROR_MESSAGE(' + ISNULL(@ErrMsg,'NULL') + ')'
END CATCH