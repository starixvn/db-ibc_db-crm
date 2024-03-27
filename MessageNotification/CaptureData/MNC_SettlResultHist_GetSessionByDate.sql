/*<info serverAlias="DBACC-bodb02,DBSIG-bodb02" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE MNC_SettlResultHist_GetSessionByDate
	@Environment VARCHAR(5)
	,@FDTime DATETIME
	,@SiteDBGroupID SMALLINT
AS
/*
	Created: 20231213@Roy
	Task: Get data from Settlement ResultHistory
	DB: DBSIG.bodb02
	Revisions:
		20230515@Roy: CRM - Implement Message Notifications Center for Result Amendment of Cricket(#197621)
	
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
		SiteDBGroupID SMALLINT
		,SessionID VARCHAR(50)
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
	
	;WITH CTE_ResultHist AS (
		SELECT DISTINCT sh.SessionID
			,sh.MatchID
			,ISNULL(ISNULL(m.isTestMatch, m14.isTestMatch),0) AS IsTest
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
		WHERE sh.CreatedDate >= @FDTime
			AND ISNULL(sh.StatusID,0) >= 2 --[StatusID < 2] => not start Result Amendment steps
	)
	INSERT INTO #tmpResultHist (
		SiteDBGroupID
		,SessionID
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
	SELECT @SiteDBGroupID AS SiteDBGroupID
		,SessionID
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
	WHERE (CASE WHEN ISNULL(@Environment,'UAT') = 'UAT' THEN 1 ELSE IsTest END) = IsTest --If @Environment = UAT, get only TEST Match
	
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
	DROP TABLE #tmpJSData
END
