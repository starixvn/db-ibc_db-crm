/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_Chatbot_TOControlSMAInfo_Sel]
	@XML   XML
AS

/*
	Created: 20201214@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Get SMAs which reach Company Turnover Control

	Revisions:
		- 20201214@Malcolm: Initialize SP [RedmineID: #130544]

	Param's Explanation:
		.@XML = '<root><r LogId="" CustId ="" MatchId ="" MaxTurnOver="" NotifiedPercentValue=""> </r><root/>'

*/
BEGIN
	SET NOCOUNT ON

	IF ISNULL(@XML, '') = ''
	BEGIN
		RETURN
	END

	DECLARE @Result TABLE 
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
		Outstanding				MONEY,
		MaxTurnOver				MONEY,
		NotifiedPercentValue	INT,
		IsTest					BIT
	)

	INSERT INTO @Result (LogId, CustId, UserName, RoleId, MatchId, MaxTurnOver, NotifiedPercentValue)
	SELECT 
		T.c.value('@LogId', 'BIGINT') AS LogId
		,T.c.value('@CustId', 'INT')  AS CustId
		,T.c.value('@MatchId', 'INT') AS MatchId
		,T.c.value('@MaxTurnOver', 'MONEY') AS MaxTurnOver
		,T.c.value('@NotifiedPercentValue', 'INT') AS NotifiedPercentValue
	FROM @XML.nodes('root\r') T(c)
	OPTION (OPTIMIZER FOR (@XML = NULL))
	
	DECLARE @LastLogId BIGINT

	SELECT @LastLogId = MAX(LogId) FROM @Result

	-- Get Outstanding
	IF EXISTS(SELECT 1 FROM @Result WHERE RoleId = 4)
	BEGIN
		;WITH CTE AS (
			SELECT b.srecommend,  SUM(b.actual_stake) AS Outstanding
			FROM bodb02.dbo.bettrans b WITH(NOLOCK)
			WHERE EXISTS (SELECT TOP 1 1 FROM @Result r WHERE r.CustId = b.srecommend AND r.MatchId = b.matchid)
				AND b.statusID IN (0, 1)
		)
		UPDATE r
			SET r.Outstanding = e.Outstanding
		FROM @Result r
			INNER JOIN CTE e ON e.srecommend = r.CustId	 
	END

	IF EXISTS(SELECT 1 FROM @Result WHERE RoleId = 3)
	BEGIN
		;WITH CTE AS (
			SELECT b.mrecommend,  SUM(b.actual_stake) AS Outstanding
			FROM bodb02.dbo.bettrans b WITH(NOLOCK)
			WHERE EXISTS (SELECT TOP 1 1 FROM @Result r WHERE r.CustId = b.mrecommend AND r.MatchId = b.matchid)
				AND b.statusID IN (0, 1)
		)
		UPDATE r
			SET r.Outstanding = e.Outstanding
		FROM @Result r
			INNER JOIN CTE e ON e.mrecommend = r.CustId	 
	END

	IF EXISTS(SELECT 1 FROM @Result WHERE RoleId = 2)
	BEGIN
		;WITH CTE AS (
			SELECT b.recommend,  SUM(b.actual_stake) AS Outstanding
			FROM bodb02.dbo.bettrans b WITH(NOLOCK)
		    WHERE EXISTS (SELECT TOP 1 1 FROM @Result r WHERE r.CustId = b.recommend AND r.MatchId = b.matchid)
				AND b.statusID IN (0, 1)
		)
		UPDATE r
			SET r.Outstanding = e.Outstanding
		FROM @Result r
			INNER JOIN CTE e ON e.recommend = r.CustId	 
	END
	
	INSERT INTO dbo.crmTOControlOutstandingInfo (LogId, CustId, MatchId, Outstanding)
	SELECT t.LogId, t.CustId, t.MatchId, t.Outstanding
	FROM @Result t
	WHERE NOT EXISTS(SELECT TOP 1 1 FROM dbo.crmTOControlOutstandingInfo i WITH(NOLOCK) WHERE i.LogID = t.LogId)

	UPDATE r
		SET r.Outstanding = i.Outstanding
	FROM @Result r
		INNER JOIN dbo.crmTOControlOutstandingInfo i WITH(NOLOCK) ON i.LogID = r.LogId

	UPDATE r
		SET r.CurrencyName	= l.Currency
			,r.UserName		= l.Username
			,r.RoleId		= l.RoleId
			,r.Recommend	= l.recommend
			,r.Mrecommend	= l.mrecommend
			,r.Srecommend   = l.srecommend
			,r.IsTest		= CASE WHEN l.currency = 'UUS' THEN 1 ELSE 0 END
	FROM @Result r
	CROSS APPLY(
		SELECT TOP (1) c.Username , e.Currency , c.RoleId, c.recommend, c.mrecommend, c.srecommend
		FROM bodb02.dbo.Customer c WITH(NOLOCK)
			INNER JOIN bodb02.dbo.exchange e WITH(NOLOCK) ON e.ExchangeId = c.currency
		WHERE c.custid = r.CustId
	) AS l

	UPDATE r
		SET r.Sporttype = l.sporttype
			,r.LeagueId = l.leagueid
			,r.HomeId	= l.homeid
			,r.AwayId	= l.awayid
	FROM @Result r
	CROSS APPLY(
		SELECT TOP(1) m.sporttype, m.leagueid, m.homeid, m.awayid
		FROM bodb02.dbo.match m WITH(NOLOCK)
		WHERE m.matchid = r.MatchId
	) AS l

	SELECT
		LogId	
		,MatchId		
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
		,IsTest
	FROM @Result

END
GO