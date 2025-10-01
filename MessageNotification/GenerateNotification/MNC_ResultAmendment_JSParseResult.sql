/*<info serverAlias="DBCRM-MessageNotification" executers="wsv_nap" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE MNC_ResultAmendment_JSParseResult
	@SettlementLogIDs VARCHAR(MAX)
	,@ParseAmendInfo VARCHAR(50) = 'ALL'
	,@ParseTo VARCHAR(50) = 'RemotingRef'
	,@Environment VARCHAR(10) = 'LIVE'
	,@OutJSResource NVARCHAR(MAX) OUTPUT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(2000) = '' OUTPUT
AS
/*
	Created: 20231213@Roy
	Task: Parse ActualResult/WrongResult from XML to table
	DB: DBCRM.MessageNotification
	Revisions:
		- 20231121@Roy: CRM - Implement Message Notifications Center for Result Amendment of Cricket(#197621)
		- 20241107@Tacy: CRM - Implement Message Notifications Center for Result Amendment of basketball and E-Sports [#212035]
		- 20250429@Dave: MNC - for Result Amendment of Tennis, Table Tennis, Badminton & Volleyball [RedmineID: #218014]
		- 20250616@Dave: CRM - Implement Message Notifications Center for Fast Market [RedmineID: #230646]

	
	Param's Explanation:
		@SettlementLogIDs: List of SettlementLogID
		@SportType: default 50 - Cricket
		@ParseAmendInfo: Specific data want to parse to JSON
						- ActualResult
						- WrongResult
						- SettleMatch
						- ALL (default) : SettleMatch,ActualResult,WrongResult
						- ResourceOrder
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
	
	/*
		Reset OUTPUT
	*/
	SELECT @ErrCode = 0
		,@ErrMsg = ''
		,@OutJSResource = ''
	
	/*
		Faced to Issues When Using Temporary Tables in Nested Stored Procedures
		
		Use Prefix #tmpJSParse in Nested SP instead of #tmp when using temporary table
		Make sure to use a different naming convention
	*/
	CREATE TABLE #tmpJSParseRemotingRef (
		SettlementLogID INT
		,GroupName NVARCHAR(50)
		,RefId1 NVARCHAR(50)
		,RefId2 NVARCHAR(50)
	)
	
	CREATE TABLE #tmpJSParseEventInfo (
		SettlementLogID INT
		,MatchID INT
		,SportType INT
		,HomeID INT
		,AwayID INT
		,LeagueID INT
	)
	
	CREATE TABLE #tmpJSParseResultInfo (
		SettlementLogID INT
		,AmendInfo NVARCHAR(50)
		,ResourceID NVARCHAR(50)
		,RefBettypeID NVARCHAR(50)
		,HomeValue NVARCHAR(50)
		,AwayValue NVARCHAR(50)
		,OtherInfo NVARCHAR(200)
		,TeamIDs NVARCHAR(200)
		,G NVARCHAR(50)
		,M NVARCHAR(50)
		,X NVARCHAR(50)
		,Y NVARCHAR(50)
		,O NVARCHAR(50)
		,GroupBT NVARCHAR(50)
		,Pos NVARCHAR(50)
		,ActionType TINYINT
		,ActionOnPos NVARCHAR(10)
	)
	
	CREATE TABLE #tmpJSParseResourceOrder (
		ID INT IDENTITY(1,1)
		,SettlementLogID INT
		,ResourceID NVARCHAR(50)
	)

	CREATE TABLE #tmpJSParseInputIDs (
		SettlementLogID INT
	)
	
	CREATE TABLE #tmpJSParseXML (
		SettlementLogID INT
		,ActualResultXML XML
		,WrongResultXML XML
		,ActionType TINYINT
	)

	--write more info if LogMode = Debug
	DECLARE @LogUserID INT
		,@LogActionID SMALLINT
	
	SELECT @LogUserID = TRY_CONVERT(INT, VValue)
	FROM MessageNotification.dbo.SystemSetting WITH (NOLOCK)
	WHERE VID = 2 --ID of StarixIT
	
	SELECT @LogActionID = ActionID
	FROM MessageNotification.dbo.LogAction WITH (NOLOCK)
	WHERE ActName = ISNULL(OBJECT_NAME(@@PROCID),'Unknown')
	
	INSERT INTO MessageNotification.dbo.UserLog (
		ActionID
		,UserID
		,LogBef
	)
	SELECT @LogActionID
		,@LogUserID
		,COMPRESS(N'Info - [Parse SettlementResultHist to JSON] - Start'
						+ ' - @SettlementLogIDs(' + ISNULL(@SettlementLogIDs,'NULL') + ')'
						+ ' - @ParseAmendInfo(' + ISNULL(@ParseAmendInfo,'NULL') + ')'
						+ ' - @ParseTo(' + ISNULL(@ParseTo,'NULL') + ')')
	
	/*
		Start to get data to Parse
		default @ParseAmendInfo = ALL
	*/
	SELECT @OutJSResource = ''
	
	IF ISNULL(CHARINDEX('SettleMatch',@ParseAmendInfo),0) = 0
		AND ISNULL(CHARINDEX('ActualResult',@ParseAmendInfo),0) = 0
		AND ISNULL(CHARINDEX('WrongResult',@ParseAmendInfo),0) = 0
		AND ISNULL(CHARINDEX('ResourceOrder',@ParseAmendInfo),0) = 0
	BEGIN
		SET @ParseAmendInfo = 'SettleMatch,ActualResult,WrongResult'
	END
	
	--Parse data only for Cricket
	INSERT INTO #tmpJSParseInputIDs (SettlementLogID)
	SELECT DISTINCT TRY_CONVERT(INT, value)
	FROM STRING_SPLIT(@SettlementLogIDs, ',')
	
	DELETE i
	FROM #tmpJSParseInputIDs AS i
		LEFT JOIN dbo.SettlementResultHist AS sh WITH (NOLOCK) ON sh.SettlementLogID = i.SettlementLogID
		OUTER APPLY dbo.f_MNC_ResultAmendment_SportSel(ISNULL(sh.SportType,0), @Environment) s
	WHERE sh.SettlementLogID IS NULL OR s.SportType IS NULL

	CREATE UNIQUE CLUSTERED INDEX CIX_tmpInputID ON #tmpJSParseInputIDs (SettlementLogID)
	/*
		Insert #tmpJSParseResultInfo with format
		----|---------------|-------------------|---------------|------------|---------------|----------------------|-----------|-------|-------|-------|-------|-------|-------|-------------|-------
			|SettlementLogID|AmendInfo			|ResourceID		|RefBettypeID|HomeValue	|AwayValue	|OtherInfo		|TeamIDs	|G		|X		|Y		|O		|GroupBT|  Pos	| ActionOnPos |
		----|---------------|-------------------|---------------|------------|----------|-----------|---------------|-----------|-------|-------|-------|-------|-------|-------|-------------|-------
			| 2				| SettleMatch		| MatchID		| (NULL)	 | (NULL) 	| (NULL)	| 79288043 		| (NULL) 	| (NULL)|(NULL)	|(NULL)	|(NULL)	|(NULL)	|(NULL)	|    (NULL)   |
			| 2				| SettleMatch		| SportType		| (NULL)	 | (NULL) 	| (NULL)	| 50	 		| (NULL) 	| (NULL)|(NULL)	|(NULL)	|(NULL)	|(NULL)	|(NULL)	|	 (NULL)   |
			| 2				| SettleMatch		| HomeID		| (NULL)	 | (NULL)	| (NULL)	| (NULL)		| 1103146	| (NULL)|(NULL)	|(NULL)	|(NULL)	|(NULL)	|(NULL)	|	 (NULL)   |
			| 2				| ActualResult		| 96621004		| 9662		 | 01		| (NULL)	| 20439,16776	| (NULL)	| 1		|(NULL)	|(NULL)	|(NULL)	|(NULL)	|(NULL)	|	 (NULL)   |
			| 2				| WrongResult		| 96621004		| 9662		 | 02		| (NULL)	| 20439,16776	| (NULL)	| 1		|(NULL)	|(NULL)	|(NULL)	|(NULL)	|(NULL)	|	 (NULL)   |
			| 70			| ActualResult		| 94841004		| 9484		 | 2		| (NULL)	| (NULL)		| (NULL)	| 1		| 4		|(NULL)	|(NULL)	|(NULL)	|(2)	|	 (CAL)    |
			| 70			| WrongResult		| 94841004		| 9484		 | 1		| (NULL)	| (NULL)		| (NULL)	| 1		| 4		|(NULL)	|(NULL)	|(NULL)	|(2)	|	(REFUND)  |
			| 134			| ActualResult		| 96711			| 96711		 | 06,05	| (NULL)	| (NULL)		| (NULL)	| 1		| (NULL)|(NULL)	|(NULL)	|(NULL)	|(0)	|	(REFUND)  |
			| 134			| WrongResult		| 96711			| 96711		 | 06		| (NULL)	| (NULL)		| (NULL)	| 1		| (NULL)|(NULL)	|(NULL)	|(NULL)	|(0)	|	 (CAL)    |
		----|---------------|-------------------|---------------|------------|----------|-----------|---------------|-----------|-------|-------|-------|-------|-------|-------|-------------|-------
	*/
	INSERT INTO #tmpJSParseEventInfo (
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
	FROM MessageNotification.dbo.SettlementResultHist AS sh WITH (NOLOCK)
		INNER JOIN #tmpJSParseInputIDs AS i ON sh.SettlementLogID = i.SettlementLogID
		LEFT JOIN bodb02.dbo.match AS m WITH (NOLOCK) ON sh.MatchID = m.MatchID
		LEFT JOIN bodb02.dbo.match14 AS m14 WITH (NOLOCK) ON sh.MatchID = m14.MatchID
	WHERE ISNULL(CHARINDEX('SettleMatch',@ParseAmendInfo),0) > 0
	
	--XML Result:
	INSERT INTO #tmpJSParseXML (SettlementLogID, ActualResultXML, WrongResultXML, ActionType)
	SELECT sh.SettlementLogID
		,TRY_CONVERT(XML, sh.ActualResult) AS ActualResultXML
		,TRY_CONVERT(XML, sh.WrongResult) AS WrongResultXML
		,sh.ActionType
	FROM MessageNotification.dbo.SettlementResultHist AS sh WITH (NOLOCK)
		INNER JOIN #tmpJSParseInputIDs AS i ON sh.SettlementLogID = i.SettlementLogID

	--ActualResult / WrongResult
	;WITH CTE_Actual AS (
		SELECT DISTINCT SettlementLogID
			,'ActualResult' AS AmendInfo
			,ActionType
			,NULLIF(TRIM(a.c.value('@Id', 'NVARCHAR(50)')), '') AS ResourceID
			,NULLIF(TRIM(a.c.value('@RefBettypeID', 'NVARCHAR(50)')), '') AS RefBettypeID
			,NULLIF(TRIM(a.c.value('@Home', 'NVARCHAR(50)')), '') AS HomeValue
			,NULLIF(TRIM(a.c.value('@Away', 'NVARCHAR(50)')), '') AS AwayValue
			,NULLIF(TRIM(a.c.value('@OtherInfo', 'NVARCHAR(MAX)')), '') AS OtherInfo
			,NULLIF(TRIM(a.c.value('@TeamIds', 'NVARCHAR(MAX)')), '') AS TeamIDs
			,NULLIF(TRIM(a.c.value('@G', 'NVARCHAR(50)')), '') AS G
			,NULLIF(TRIM(a.c.value('@M', 'NVARCHAR(50)')), '') AS M
			,NULLIF(TRIM(a.c.value('@X', 'NVARCHAR(50)')), '') AS X
			,NULLIF(TRIM(a.c.value('@Y', 'NVARCHAR(50)')), '') AS Y
			,NULLIF(TRIM(a.c.value('@O', 'NVARCHAR(50)')), '') AS O
			,NULLIF(TRIM(a.c.value('@GroupBetType', 'NVARCHAR(50)')), '') AS GroupBT
			,NULLIF(TRIM(a.c.value('@Pos', 'NVARCHAR(50)')), '') AS Pos
			,NULLIF(TRIM(a.c.value('@Action', 'NVARCHAR(10)')), '') AS ActionOnPos
		FROM #tmpJSParseXML
			OUTER APPLY ActualResultXML.nodes('root/r') a(c)
		WHERE ISNULL(CHARINDEX('ActualResult',@ParseAmendInfo),0) > 0
	)
	,CTE_Wrong AS (
		SELECT DISTINCT SettlementLogID
			,'WrongResult' AS AmendInfo
			,ActionType
			,NULLIF(TRIM(w.c.value('@Id', 'NVARCHAR(50)')), '') AS ResourceID
			,NULLIF(TRIM(w.c.value('@RefBettypeID', 'NVARCHAR(50)')), '') AS RefBettypeID
			,NULLIF(TRIM(w.c.value('@Home', 'NVARCHAR(50)')), '') AS HomeValue
			,NULLIF(TRIM(w.c.value('@Away', 'NVARCHAR(50)')), '') AS AwayValue
			,NULLIF(TRIM(w.c.value('@OtherInfo', 'NVARCHAR(MAX)')), '') AS OtherInfo
			,NULLIF(TRIM(w.c.value('@TeamIds', 'NVARCHAR(MAX)')), '') AS TeamIDs --Can value('(//*/@*[lower-case(local-name())="teamids"])[1]', 'INT') to ignore case-sensitive (low performance)
			,NULLIF(TRIM(w.c.value('@G', 'NVARCHAR(50)')), '') AS G
			,NULLIF(TRIM(w.c.value('@M', 'NVARCHAR(50)')), '') AS M
			,NULLIF(TRIM(w.c.value('@X', 'NVARCHAR(50)')), '') AS X
			,NULLIF(TRIM(w.c.value('@Y', 'NVARCHAR(50)')), '') AS Y
			,NULLIF(TRIM(w.c.value('@O', 'NVARCHAR(50)')), '') AS O
			,NULLIF(TRIM(w.c.value('@GroupBetType', 'NVARCHAR(50)')), '') AS GroupBT
			,NULLIF(TRIM(w.c.value('@Pos', 'NVARCHAR(50)')), '') AS Pos
			,NULLIF(TRIM(w.c.value('@Action', 'NVARCHAR(10)')), '') AS ActionOnPos
		FROM #tmpJSParseXML
			OUTER APPLY WrongResultXML.nodes('root/r') w(c)
		WHERE ISNULL(CHARINDEX('WrongResult',@ParseAmendInfo),0) > 0
	)
	INSERT INTO #tmpJSParseResultInfo (
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
		,O
		,GroupBT
		,Pos
		,ActionType
		,ActionOnPos
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
		,O
		,GroupBT
		,Pos
		,ActionType
		,ActionOnPos
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
		,O
		,GroupBT
		,Pos
		,ActionType
		,ActionOnPos
	FROM CTE_Wrong
	
	

	/*
		Start Parse data to format
		
		default @ParseTo = RemotingRef
	*/
	IF @ParseTo = 'RawData'
	BEGIN
		IF @ParseAmendInfo = 'ResourceOrder'
		BEGIN		
			--ResourceOrder
			--ActualResource
			INSERT INTO #tmpJSParseResourceOrder (
				SettlementLogID
				,ResourceID
			)
			SELECT SettlementLogID
				,NULLIF(TRIM(a.c.value('@Id', 'NVARCHAR(50)')), '') AS ResourceID
			FROM #tmpJSParseXML
				OUTER APPLY ActualResultXML.nodes('root/r') a(c)
			WHERE ISNULL(CHARINDEX('ResourceOrder',@ParseAmendInfo),0) > 0
	
			--WrongResource
			;WITH CTE_Wrong AS (
				SELECT SettlementLogID
					,NULLIF(TRIM(a.c.value('@Id', 'NVARCHAR(50)')), '') AS ResourceID
				FROM #tmpJSParseXML t
					OUTER APPLY ActualResultXML.nodes('root/r') a(c)
				WHERE ISNULL(CHARINDEX('ResourceOrder',@ParseAmendInfo),0) > 0
			)
			INSERT INTO #tmpJSParseResourceOrder (
				SettlementLogID
				,ResourceID
			)
			SELECT w.SettlementLogID, w.ResourceID
			FROM CTE_Wrong w
			LEFT JOIN #tmpJSParseResourceOrder o ON o.SettlementLogID=w.SettlementLogID
												AND o.ResourceID=w.ResourceID
			WHERE o.SettlementLogID IS NULL

			--return ResourceOrder
			SELECT @OutJSResource =
				CONVERT(NVARCHAR(MAX)
					,(
						SELECT *
						FROM #tmpJSParseResourceOrder
						ORDER BY ID
						FOR JSON AUTO
					)
				)
		END
		ELSE 
		BEGIN
			/*
				SettleMatch info
			*/
			--MatchID--
			INSERT INTO #tmpJSParseResultInfo (
				SettlementLogID
				,AmendInfo
				,ResourceID
				,OtherInfo
			)
			SELECT DISTINCT SettlementLogID
				,'SettleMatch' AS AmendInfo
				,'MatchID' AS ResourceID
				,MatchID AS OtherInfo
			FROM #tmpJSParseEventInfo
			WHERE MatchID IS NOT NULL
		
			--LeagueID--
			INSERT INTO #tmpJSParseResultInfo (
				SettlementLogID
				,AmendInfo
				,ResourceID
				,OtherInfo
			)
			SELECT DISTINCT SettlementLogID
				,'SettleMatch' AS AmendInfo
				,'LeagueID' AS ResourceID
				,LeagueID AS OtherInfo
			FROM #tmpJSParseEventInfo
			WHERE LeagueID IS NOT NULL
		
			--SportType--
			INSERT INTO #tmpJSParseResultInfo (
				SettlementLogID
				,AmendInfo
				,ResourceID
				,OtherInfo
			)
			SELECT DISTINCT SettlementLogID
				,'SettleMatch' AS AmendInfo
				,'SportType' AS ResourceID
				,SportType AS OtherInfo
			FROM #tmpJSParseEventInfo
			WHERE SportType IS NOT NULL
		
			--HomeID--
			INSERT INTO #tmpJSParseResultInfo (
				SettlementLogID
				,AmendInfo
				,ResourceID
				,TeamIDs
			)
			SELECT DISTINCT SettlementLogID
				,'SettleMatch' AS AmendInfo
				,'HomeID' AS ResourceID
				,HomeID AS TeamIDs
			FROM #tmpJSParseEventInfo
			WHERE HomeID IS NOT NULL
		
			--AwayID--
			INSERT INTO #tmpJSParseResultInfo (
				SettlementLogID
				,AmendInfo
				,ResourceID
				,TeamIDs
			)
			SELECT DISTINCT SettlementLogID
				,'SettleMatch' AS AmendInfo
				,'AwayID' AS ResourceID
				,AwayID AS TeamIDs
			FROM #tmpJSParseEventInfo
			WHERE AwayID IS NOT NULL

			--return SettleMatch + ActualResult + WrongResult
			SELECT @OutJSResource =
				CONVERT(NVARCHAR(MAX)
					,(
						SELECT *
						FROM #tmpJSParseResultInfo
						ORDER BY SettlementLogID
							,AmendInfo
							,ResourceID
							FOR JSON AUTO
					)
				)
		END

		--write log--
		INSERT INTO MessageNotification.dbo.UserLog (
			ActionID
			,UserID
			,LogBef
		)
		SELECT @LogActionID
			,@LogUserID
			,COMPRESS(N'Info - [Parse SettlementResultHist to JSON]'
				+ ' - @OutJSResource(' + ISNULL(@OutJSResource,'NULL') + ')')
	END
	ELSE
	BEGIN
		/*
			Insert #tmpJSParseRemotingRef with format
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
	/*--Resource{sport_name}--*/
		--<RefBettypeID>
		INSERT INTO #tmpJSParseRemotingRef (
			SettlementLogID
			,GroupName
			,RefId1
			,RefId2
		)
		SELECT DISTINCT SettlementLogID
			,'RefResource' AS GroupName
			,'Resource{sport_name}' AS RefId1
			,RefBettypeID AS RefId2
		FROM #tmpJSParseResultInfo
		WHERE RefBettypeID IS NOT NULL
		
		--<G> / <M> / <O>
		;WITH CTE_AffectedResult AS (
			SELECT SettlementLogID
				,'G' + G AS RefId2
			FROM #tmpJSParseResultInfo
			WHERE G IS NOT NULL

			UNION ALL

			SELECT SettlementLogID
				,'M' + M AS RefId2
			FROM #tmpJSParseResultInfo
			WHERE M IS NOT NULL
			
			UNION ALL

			SELECT SettlementLogID
				,O AS RefId2
			FROM #tmpJSParseResultInfo
			WHERE O IS NOT NULL
		)
		INSERT INTO #tmpJSParseRemotingRef (
			SettlementLogID
			,GroupName
			,RefId1
			,RefId2
		)
		SELECT DISTINCT ar.SettlementLogID
			,'RefResource' AS GroupName
			,'Resource{sport_name}' AS RefId1
			,ar.RefId2
		FROM CTE_AffectedResult AS ar
		
		--update: Resource{sport_name}
		UPDATE ref
		SET RefId1=REPLACE(RefId1,'{sport_name}', s.SuffixRefID)
		FROM #tmpJSParseRemotingRef ref
		INNER JOIN dbo.SettlementResultHist i ON i.SettlementLogID=ref.SettlementLogID
		CROSS APPLY dbo.f_MNC_ResultAmendment_SportSel(i.SportType, @Environment) s
		WHERE RefId1='Resource{sport_name}'
		
	/*--BetInfo-- for ActionType = 5*/
		--<ID>
		/*As Action Type = 5, ID = ResourceID = RefBettypeID*/
		INSERT INTO #tmpJSParseRemotingRef (
			SettlementLogID
			,GroupName
			,RefId1
			,RefId2
		)
		SELECT DISTINCT SettlementLogID
			,'BetType' AS GroupName
			,'BetTypeName' AS RefId1
			,ResourceID AS RefId2
		FROM #tmpJSParseResultInfo
		WHERE ActionType = 5

	/*--ResultSettlement--*/
		--<GroupBetType>
		INSERT INTO #tmpJSParseRemotingRef (
			SettlementLogID
			,GroupName
			,RefId1
			,RefId2
		)
		SELECT DISTINCT SettlementLogID
			,'RefResource' AS GroupName
			,'ResultSettlement' AS RefId1
			,'GBT' + GroupBT AS RefId2
		FROM #tmpJSParseResultInfo
		WHERE GroupBT IS NOT NULL

		--<HomeValue> / <AwayValue>
		;WITH CTE_HA AS (
			SELECT SettlementLogID
				,HomeValue AS RefId2
			FROM #tmpJSParseResultInfo
			WHERE HomeValue IS NOT NULL
			
			UNION ALL
			
			SELECT SettlementLogID
				,AwayValue AS RefId2
			FROM #tmpJSParseResultInfo
			WHERE AwayValue IS NOT NULL
		)
		,CTE_Result AS (
			SELECT SettlementLogID
				,value AS RefId2
			FROM CTE_HA
				CROSS APPLY STRING_SPLIT(RefId2, ',')
			WHERE NULLIF(TRIM(value), '') IS NOT NULL
		)
		INSERT INTO #tmpJSParseRemotingRef (
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
		WHERE ISNUMERIC(RefId2) = 0 --characters
			AND RefId2 NOT IN ('H','A') --for case Cricket » Early Result Types 3, Cricket » Early Result Types 8
		
		/*
			For GroupName=EventInfo
		*/
		--<TeamIDs>, <OtherInfo> (include HomeID/AwayID from AmendInfo.SettleMatch)
		;WITH CTE_TeamIDs AS (
			SELECT SettlementLogID
				,'TeamID' AS RefId1
				,value AS RefId2
			FROM #tmpJSParseResultInfo
				CROSS APPLY STRING_SPLIT(TeamIDs, ',')
				--AmendInfo = 'SettleMatch': HomeID/AwayID retrived from MatchID
				--AmendInfo IN ('ActualResult', 'WrongResult'): HomeID/AwayID retrived from ActualResult/WrongResult
			
			UNION ALL
			
			SELECT SettlementLogID
				,'TeamID' AS RefId1
				,value AS RefId2
			FROM #tmpJSParseResultInfo
				CROSS APPLY STRING_SPLIT(OtherInfo, ',')
			
			UNION ALL
			
			SELECT DISTINCT SettlementLogID
				,'TeamID' AS RefId1
				,CONVERT(NVARCHAR,HomeID) AS RefId2
			FROM #tmpJSParseEventInfo
			WHERE HomeID IS NOT NULL
			
			UNION ALL
			
			SELECT DISTINCT SettlementLogID
				,'TeamID' AS RefId1
				,CONVERT(NVARCHAR,AwayID) AS RefId2
			FROM #tmpJSParseEventInfo
			WHERE AwayID IS NOT NULL
		)
		INSERT INTO #tmpJSParseRemotingRef (
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
		INSERT INTO #tmpJSParseRemotingRef (
			SettlementLogID
			,GroupName
			,RefId1
			,RefId2
		)
		SELECT DISTINCT SettlementLogID
			,'EventInfo' AS GroupName
			,'SportType' AS RefId1
			,SportType AS RefId2
		FROM #tmpJSParseEventInfo
		WHERE SportType IS NOT NULL
		
		--LeagueID
		INSERT INTO #tmpJSParseRemotingRef (
			SettlementLogID
			,GroupName
			,RefId1
			,RefId2
		)
		SELECT DISTINCT SettlementLogID
			,'EventInfo' AS GroupName
			,'LeagueID' AS RefId1
			,LeagueID AS RefId2
		FROM #tmpJSParseEventInfo
		WHERE LeagueID IS NOT NULL

		--return--
		SELECT @OutJSResource =
			CONVERT(NVARCHAR(MAX)
				,(
					SELECT DISTINCT rf.SettlementLogID
						,rf.GroupName
						,rf.RefId1
						,rf.RefId2
					FROM #tmpJSParseRemotingRef AS rf
					ORDER BY rf.SettlementLogID
						,rf.GroupName
						,rf.RefId1
						,rf.RefId2
						FOR JSON AUTO
				)
			)
		
		--write log--
		INSERT INTO MessageNotification.dbo.UserLog (
			ActionID
			,UserID
			,LogBef
		)
		SELECT @LogActionID
			,@LogUserID
			,COMPRESS(N'Info - [Parse SettlementResultHist to JSON]'
				+ ' - @OutJSResource(' + ISNULL(@OutJSResource,'NULL') + ')')
	END
	
	--write log--
	INSERT INTO MessageNotification.dbo.UserLog (
		ActionID
		,UserID
		,LogBef
	)
	SELECT @LogActionID
		,@LogUserID
		,COMPRESS(N'Info - Debug - [Parse SettlementResultHist to JSON] Final'
						+ ' - tmpResultInfo('
								+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
											SELECT *
											FROM #tmpJSParseResultInfo
											FOR JSON PATH
										))
									),'NO ROW') + ')'
						+ ' - tmpEventInfo('
								+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
											SELECT *
											FROM #tmpJSParseEventInfo
											FOR JSON PATH
										))
									),'NO ROW') + ')'
						+ ' - tmpRemotingRef('
								+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
											SELECT *
											FROM #tmpJSParseRemotingRef
											FOR JSON PATH
										))
									),'NO ROW') + ')')
	FROM MessageNotification.dbo.SystemSetting WITH (NOLOCK)
	WHERE VID = 13 --LogMode
		AND VValue = 'Debug'
	
	DROP TABLE #tmpJSParseRemotingRef
	DROP TABLE #tmpJSParseEventInfo
	DROP TABLE #tmpJSParseResultInfo
END TRY
BEGIN CATCH
	SELECT @ErrCode = @@ERROR --output for web
		,@ErrMsg = ERROR_MESSAGE() --output for web
	
	INSERT INTO MessageNotification.dbo.UserLog (
		ActionID
		,UserID
		,LogBef
	)
	SELECT (SELECT ActionID FROM MessageNotification.dbo.LogAction WITH (NOLOCK) WHERE ActName = ISNULL(OBJECT_NAME(@@PROCID),'Unknown')) AS ActionID
		,(SELECT TRY_CONVERT(INT, VValue) FROM MessageNotification.dbo.SystemSetting WITH (NOLOCK) WHERE VID = 2) AS UserID --ID of StarixIT
		,COMPRESS(N'Error - FAILED [Parse SettlementResultHist to JSON]'
			+ ' - @SettlementLogIDs(' + ISNULL(@SettlementLogIDs,'NULL') + ')'
			+ ' - @ParseAmendInfo(' + ISNULL(@ParseAmendInfo,'NULL') + ')'
			+ ' - @ParseTo(' + ISNULL(@ParseTo,'NULL') + ')'
			+ ' - @OutJSResource(' + ISNULL(@OutJSResource,'NULL') + ')'
			+ ' - ERROR_MESSAGE(' + ISNULL(@ErrMsg,'NULL') + ')')
END CATCH
