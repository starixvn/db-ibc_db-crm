/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_Chatbot_TOControl_OutstandingInfo_Sel]
	@XML   XML
AS

/*
	Created: 20201214@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Get SMAs which reach Company Turnover Control

	Revisions:
		- 20201214@Malcolm: Initialize SP [RedmineID: #130544]

	Param's Explanation:
		.@XML = '<root><r LogId="" CustId ="" Username ="" RoleId ="" CurrencyName ="" MatchId ="" NotifiedPercentValue=""> </r><root/>'

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
		UserName				VARCHAR(30), 
		RoleId					TINYINT, 
		NotifiedPercentValue	TINYINT,
		MatchId					INT, 
		CurrencyName			NVARCHAR(50),
		Sporttype				INT,
		LeagueId				INT,
		HomeId					INT,
		AwayId					INT,
		Outstanding				MONEY
	)	

	INSERT INTO @Result (LogId, CustId, UserName, RoleId, NotifiedPercentValue, MatchId, CurrencyName)
	SELECT 
		T.c.value('@LogId', 'BIGINT')					AS LogId
		,T.c.value('@CustId', 'INT')					AS CustId
		,T.c.value('@Username', 'VARCHAR(30)')			AS UserName
		,T.c.value('@RoleId','TINYINT')					AS RoleId
		,T.c.value('@NotifiedPercentValue','TINYINT')	AS NotifiedPercentValue
		,T.c.value('@MatchId', 'INT')					AS MatchId
		,T.c.value('@CurrencyName', 'NVARCHAR(50)')		AS CurrencyName
	FROM @XML.nodes('root\r') T(c)
	OPTION (OPTIMIZER FOR (@XML = NULL))

	UPDATE r
		SET r.Sporttype = l.sporttype
			,r.LeagueId = l.leagueid
			,r.HomeId	= l.homeid
			,r.AwayId	= l.awayid
	FROM @Result r
	CROSS APPLY(
		SELECT TOP(1) m.sporttype, m.leagueid, m.homeid, m.awayid
		FROM dbo.match m WITH(NOLOCK)
		WHERE m.matchid = r.MatchId
	) AS l
	
	-- Get Outstanding
	IF EXISTS(SELECT 1 FROM @Result WHERE RoleId = 4)
	BEGIN
		;WITH CTE AS (
			SELECT b.srecommend,  SUM(b.actual_stake) AS Outstanding
			FROM bettrans b WITH(NOLOCK)
			WHERE b.srecommend IN (SELECT r.CustId FROM @Result r)
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
			FROM bettrans b WITH(NOLOCK)
			WHERE b.mrecommend IN (SELECT r.CustId FROM @Result r)
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
			FROM bettrans b WITH(NOLOCK)
			WHERE b.recommend IN (SELECT r.CustId FROM @Result r) 
				AND b.statusID IN (0, 1)
		)
		UPDATE r
			SET r.Outstanding = e.Outstanding
		FROM @Result r
			INNER JOIN CTE e ON e.recommend = r.CustId	 
	END
	
	SELECT 
		LogId,
		CustId, 
		UserName, 
		RoleId, 
		NotifiedPercentValue,
		MatchId, 
		CurrencyName, 
		Sporttype, 
		LeagueId, 
		HomeId, 
		AwayId, 
		Outstanding
	FROM @Result
END
GO