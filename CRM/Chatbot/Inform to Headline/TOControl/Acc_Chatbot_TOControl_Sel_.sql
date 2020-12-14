/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_Chatbot_TOControl_Sel]
	@XML   XML
AS

/*
	Created: 20201214@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Get SMAs which reach Company Turnover Control

	Revisions:
		- 20201214@Malcolm: Initialize SP [RedmineID: #130544]

	Param's Explanation:
		.@XML = <root><r CustId ="" Username ="" RoleId ="" CurrencyName ="" MatchId =""> </r><root/>

*/
BEGIN
	SET NOCOUNT ON

	IF ISNULL(@XML, '') = ''
	BEGIN
		RETURN
	END

	CREATE TABLE #Result 
	(
		CustId			INT, 	
		UserName		VARCHAR(30), 
		RoleId			TINYINT, 
		MatchId			INT, 
		CurrencyName	VARCHAR(30),
		Sporttype		INT,
		LeagueId		INT,
		HomeId			INT,
		AwayId			INT
	)	

	INSERT INTO #Result (CustId, UserName, RoleId, MatchId, CurrencyName)
	SELECT 
		T.c.value('@CustId', 'INT') AS CustId
		,T.c.value('@Username', 'VARCHAR(30)')
		,T.c.value('@RoleId','TINYINT')
		,T.c.value('@MatchId', 'INT')
		,T.c.value('@CurrencyName', 'VARCHAR(20)')
	FROM @XML.nodes('root\r') T(c)
	OPTION (OPTIMIZER FOR (@XML = NULL))

	UPDATE r
		SET r.Sporttype = l.sporttype
			,r.LeagueId = l.leagueid
			,r.HomeId	= l.homeid
			,r.AwayId	= l.awayid
	FROM #Result r
	CROSS APPLY(
		SELECT TOP(1) m.sporttype, m.leagueid, m.homeid, m.awayid
		FROM dbo.match m WITH(NOLOCK)
		WHERE m.matchid = r.MatchId
	) AS l

	SELECT 
		CustId, 
		UserName, 
		RoleId, 
		MatchId, 
		CurrencyName, 
		Sporttype, 
		LeagueId, 
		HomeId, 
		AwayId	
	FROM #Result
END
GO