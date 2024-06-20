/*<info serverAlias="DBSIG-bodb02" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE MNC_SettlResultHist_GetSessionByDate
	@Environment VARCHAR(20)
	,@FDTime DATETIME
	,@SiteDBGroupID SMALLINT
AS
/*
	Created: 20231213@Roy
	Task: Get data from Settlement ResultHistory
	DB: DBSIG.bodb02
	Revisions:
		20231121@Roy: CRM - Implement Message Notifications Center for Result Amendment of Cricket(#197621)
	
	Explanation:
		@Environment <> PROD, get only TEST Match
		@FDTime: timepoint to pull data
		@SiteDBGroupID: get from bodb02.dbo.SiteDBConfig
		
		Steps
			- Exec this SP foreach SiteDB
			- Parse SettlementResultHistory data to JSON
				+ Get all StatusID >= 2
			- Parse SettlementResultHistory_TicketDetails data to JSON
		
	Example:
		EXEC bodb02.dbo.MNC_SettlResultHist_GetSessionByDate @FDTime = '2024-01-04 08:46:00'
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @JSSettlResultHist NVARCHAR(MAX)
	
	CREATE TABLE #tmpJSData (
		ObjectName NVARCHAR(150)
		,JSONData NVARCHAR(MAX)
	)
	
	CREATE TABLE #tmpResultHist (
		SessionID VARCHAR(50)
		,MatchID INT
		,IsTest BIT
		,SeqNo SMALLINT
		,StatusID TINYINT
		,ActualResult VARCHAR(MAX)
		,WrongResult VARCHAR(MAX)
		,ActionType TINYINT
		,ResultType TINYINT
		,SportType INT
		,CreatedDate DATETIME
		,ExtraInfo VARCHAR(MAX)
	)
	
	CREATE TABLE #tmpResultHistDetail (
		SessionID VARCHAR(50)
		,SeqNo SMALLINT
		,Transid BIGINT
		,CustID INT
		,ExtraInfo_Before VARCHAR(MAX)
		,ExtraInfo_After VARCHAR(MAX)
	)
	
	CREATE TABLE #tmpBalanceNegativeHistory (
		LogID BIGINT
		,ExecDate DATETIME
		,MatchID INT
		,ActionID INT
		,CustID INT
		,GroupID INT
		,Balance MONEY
		,TotalBalance MONEY
		,Site VARCHAR(50)
		,SessionID VARCHAR(50)
	)
	
	;WITH CTE_ResultHist AS (
		SELECT DISTINCT sh.SessionID
			,sh.MatchID
			,l.IsTest
			,sh.SeqNo
			,sh.StatusID
			,sh.ActualResult
			,sh.WrongResult
			,sh.ActionType
			,sh.ResultType
			,sh.SportType
			,sh.CreatedDate
			,sh.ExtraInfo
		FROM SettlementResultHistory AS sh WITH (NOLOCK)
			LEFT JOIN bodb02.dbo.match AS m WITH (NOLOCK) ON sh.MatchID = m.MatchID
			LEFT JOIN bodb02.dbo.match14 AS m14 WITH (NOLOCK) ON sh.MatchID = m14.MatchID
			LEFT JOIN bodb02.dbo.league AS l WITH (NOLOCK) ON ISNULL(m.LeagueID, m14.LeagueID) = l.LeagueID
		WHERE sh.CreatedDate >= @FDTime
			AND ISNULL(sh.StatusID,0) >= 2 --[StatusID < 2] => not start Result Amendment steps
	)
	INSERT INTO #tmpResultHist (
		SessionID
		,MatchID
		,IsTest
		,SeqNo
		,StatusID
		,ActualResult
		,WrongResult
		,ActionType
		,ResultType
		,SportType
		,CreatedDate
		,ExtraInfo
	)
	SELECT SessionID
		,MatchID
		,IsTest
		,SeqNo
		,StatusID
		,ActualResult
		,WrongResult
		,ActionType
		,ResultType
		,SportType
		,CreatedDate
		,ExtraInfo
	FROM CTE_ResultHist
	WHERE (CASE WHEN ISNULL(@Environment,'UAT') = 'UAT' THEN 1 ELSE IsTest END) = IsTest --If @Environment = UAT, get only TEST League
	
	INSERT INTO #tmpResultHistDetail (
		SessionID
		,SeqNo
		,Transid
		,CustID
		,ExtraInfo_Before
		,ExtraInfo_After
	)
	SELECT DISTINCT d.SessionID
		,d.SeqNo
		,d.Transid
		,COALESCE(b.CustID, b14.CustID, -1) AS CustID
		,d.ExtraInfo_Before
		,d.ExtraInfo_After
	FROM SettlementResultHistory_TicketDetails AS d WITH (NOLOCK)
		INNER JOIN #tmpResultHist AS h ON d.SessionID = h.SessionID AND d.SeqNo = h.SeqNo
		LEFT JOIN bodb02.dbo.bettrans AS b WITH (NOLOCK) ON d.Transid = b.Transid
		LEFT JOIN bodb02.dbo.bettrans14 AS b14 WITH (NOLOCK) ON d.Transid = b14.Transid
	WHERE h.StatusID = 2 --2-Completed Result Amendment
	
	/*
		Currently, BalanceNegativeHistory mapped by SessionID
		
		BUT SettlementResultHistory break SessionID / SeqNo
		
		Paid Attention when handling SessionID / CustID
	*/
	INSERT INTO #tmpBalanceNegativeHistory (
		LogID
		,ExecDate
		,MatchID
		,ActionID
		,CustID
		,GroupID
		,Balance
		,TotalBalance
		,Site
		,SessionID
	)
	SELECT DISTINCT bn.LogID
		,bn.ExecDate
		,bn.MatchID
		,bn.ActionID
		,bn.CustID
		,bn.GroupID
		,bn.Balance
		,bn.TotalBalance
		,bn.Site
		,bn.SessionID
	FROM bodb02.dbo.BalanceNegativeHistory AS bn WITH (NOLOCK)
		INNER JOIN #tmpResultHistDetail AS d ON bn.SessionID = d.SessionID AND bn.CustID = d.CustID
		INNER JOIN #tmpResultHist AS rh ON d.SessionID = rh.SessionID AND d.SeqNo = rh.SeqNo AND bn.MatchID = rh.MatchID
	
	---prepare data
	INSERT INTO #tmpJSData (ObjectName, JSONData)
	SELECT 'SiteDBGroupID' AS ObjectName
		,CONVERT(NVARCHAR(MAX),@SiteDBGroupID) AS JSONData
	
	INSERT INTO #tmpJSData (ObjectName, JSONData)
	SELECT 'SettlementResultHistory' AS ObjectName
		,CONVERT(NVARCHAR(MAX),(
					SELECT *
					FROM #tmpResultHist
					FOR JSON AUTO
				)) AS JSONData
	
	INSERT INTO #tmpJSData (ObjectName, JSONData)
	SELECT 'SettlementResultHistory_TicketDetails' AS ObjectName
		,CONVERT(NVARCHAR(MAX),(
					SELECT *
					FROM #tmpResultHistDetail
					FOR JSON AUTO
				)) AS JSONData
	
	INSERT INTO #tmpJSData (ObjectName, JSONData)
	SELECT 'BalanceNegativeHistory' AS ObjectName
		,CONVERT(NVARCHAR(MAX),(
					SELECT *
					FROM #tmpBalanceNegativeHistory
					FOR JSON AUTO
				)) AS JSONData
	
	---convert data as JSON
	SELECT @JSSettlResultHist = CONVERT(NVARCHAR(MAX),(
				SELECT *
				FROM #tmpJSData
				FOR JSON AUTO
			))
	
	--return data
	SELECT @Environment AS Environment
		,@JSSettlResultHist AS JSSettlResultHist
	
	DROP TABLE #tmpResultHist
	DROP TABLE #tmpResultHistDetail
	DROP TABLE #tmpBalanceNegativeHistory
	DROP TABLE #tmpJSData
END
