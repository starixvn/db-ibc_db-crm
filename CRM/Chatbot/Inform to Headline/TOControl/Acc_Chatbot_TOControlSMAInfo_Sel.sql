/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_Chatbot_TOControlSMAInfo_Sel]
	@XML   XML
AS

/*
	Created: 20201214@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Get SMAs which reach Company Turnover Control

	Revisions:
		- 20201214@Malcolm: Initialize SP [RedmineID: #146735]

	Param's Explanation:
		.@XML = '<root><r LogId="1" CustId="1" MatchId="1"></r></root>'

*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #Result  
	(
		LogId					BIGINT, 
		CustId					INT, 
		Recommend				INT, 
		Mrecommend				INT, 
		Srecommend				INT, 
		MatchId					INT, 
		RoleId					TINYINT, 
		UserName				VARCHAR(30), 
		CurrencyName			NVARCHAR(50), 
		Sporttype				INT,
		LeagueId				INT,
		HomeId					INT,
		AwayId					INT,
		Outstanding				MONEY
	)

	INSERT INTO #Result (LogId, CustId, MatchId)
	SELECT 
		T.c.value('@LogId', 'BIGINT') AS LogId
		,T.c.value('@CustId', 'INT')  AS CustId
		,T.c.value('@MatchId', 'INT') AS MatchId
	FROM @XML.nodes('root/r') T(c)
	OPTION (OPTIMIZE FOR (@XML = NULL))
	
	DECLARE @LastLogId BIGINT

	SELECT @LastLogId = MAX(LogId) FROM #Result
	
	UPDATE r
		SET r.CurrencyName	= l.Currency
			,r.UserName		= l.Username
			,r.RoleId		= l.RoleId
			,r.Recommend	= l.recommend
			,r.Mrecommend	= l.mrecommend
			,r.Srecommend   = l.srecommend
	FROM #Result r
	CROSS APPLY(
		SELECT TOP (1) c.Username , e.Currency , c.RoleId, c.recommend, c.mrecommend, c.srecommend
		FROM bodb02.dbo.Customer c WITH(NOLOCK)
			INNER JOIN bodb02.dbo.exchange e WITH(NOLOCK) ON e.ExchangeId = c.currency
		WHERE c.custid = r.CustId
	) AS l

	CREATE CLUSTERED INDEX IX_Result ON #Result(RoleId, CustId, MatchId)

	-- Get Outstanding
	IF EXISTS(SELECT 1 FROM #Result WHERE RoleId = 4)
	BEGIN
		;WITH CTE AS (
			SELECT b.srecommend, b.matchid,  SUM(b.actual_stake) AS Outstanding
			FROM bodb02.dbo.bettrans b WITH(NOLOCK)
			WHERE EXISTS (SELECT TOP 1 1 FROM #Result r WHERE r.CustId = b.srecommend AND r.MatchId = b.matchid AND r.RoleId = 4)
				AND b.statusID IN (0, 1)
			GROUP BY b.srecommend, b.matchid
		)
		UPDATE r
			SET r.Outstanding = e.Outstanding
		FROM #Result r
			INNER JOIN CTE e ON e.srecommend = r.CustId	AND e.matchid = r.MatchId 
		WHERE r.RoleId = 4
	END

	IF EXISTS(SELECT 1 FROM #Result WHERE RoleId = 3)
	BEGIN
		;WITH CTE AS (
			SELECT b.mrecommend, b.matchid,  SUM(b.actual_stake) AS Outstanding
			FROM bodb02.dbo.bettrans b WITH(NOLOCK)
			WHERE EXISTS (SELECT TOP 1 1 FROM #Result r WHERE r.CustId = b.mrecommend AND r.MatchId = b.matchid AND r.RoleId = 3)
				AND b.statusID IN (0, 1)
			GROUP BY b.mrecommend, b.matchid
		)
		UPDATE r
			SET r.Outstanding = e.Outstanding
		FROM #Result r
			INNER JOIN CTE e ON e.mrecommend = r.CustId	AND e.matchid = r.MatchId
		WHERE r.RoleId = 3
	END

	IF EXISTS(SELECT 1 FROM #Result WHERE RoleId = 2)
	BEGIN
		;WITH CTE AS (
			SELECT b.recommend, b.matchid,  SUM(b.actual_stake) AS Outstanding
			FROM bodb02.dbo.bettrans b WITH(NOLOCK)
		    WHERE EXISTS (SELECT TOP 1 1 FROM #Result r WHERE r.CustId = b.recommend AND r.MatchId = b.matchid AND r.RoleId = 2)
				AND b.statusID IN (0, 1)
			GROUP BY b.recommend, b.matchid
		)
		UPDATE r
			SET r.Outstanding = e.Outstanding
		FROM #Result r
			INNER JOIN CTE e ON e.recommend = r.CustId AND e.matchid = r.MatchId
		WHERE r.RoleId = 2
	END
	
	INSERT INTO dbo.crmTOControlOutstandingInfo (LogId, CustId, MatchId, Outstanding)
	SELECT t.LogId, t.CustId, t.MatchId, ISNULL(t.Outstanding,0)
	FROM #Result t
	WHERE NOT EXISTS(SELECT TOP 1 1 FROM dbo.crmTOControlOutstandingInfo i WITH(NOLOCK) WHERE i.LogID = t.LogId)

	UPDATE r
		SET r.Outstanding = i.Outstanding
	FROM #Result r
		INNER JOIN dbo.crmTOControlOutstandingInfo i WITH(NOLOCK) ON i.LogID = r.LogId

	UPDATE r
		SET r.Sporttype = l.sporttype
			,r.LeagueId = l.leagueid
			,r.HomeId	= l.homeid
			,r.AwayId	= l.awayid
	FROM #Result r
	CROSS APPLY(
		SELECT TOP(1) m.sporttype, m.leagueid, m.homeid, m.awayid
		FROM bodb02.dbo.match m WITH(NOLOCK)
		WHERE m.matchid = r.MatchId
	) AS l

	SELECT
		LogId	
		,CustId	
		,UserName	
		,Recommend	
		,Mrecommend	
		,Srecommend		
		,CurrencyName
		,RoleId				
		,Sporttype	
		,LeagueId	
		,HomeId		
		,AwayId		
		,Outstanding
	FROM #Result

	DROP TABLE #Result

END
GO