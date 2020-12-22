/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_Chatbot_TOControlSMAInfo_Sel]
	@LastLogId BIGINT
	,@BatchSize INT = 10
AS

/*
	Created: 20201214@Malcolm
	DB: DBCUST-CustDB
	Task: Get SMAs which reach Company Turnover Control

	Revisions:
		- 20201214@Malcolm: Initialize SP [RedmineID: #130544]

	Param's Explanation:
		

*/
BEGIN
	SET NOCOUNT ON

	DECLARE @Result TABLE 
	(
		LogId			BIGINT, 
		CustId			INT, 
		Recommend		INT, 
		Mrecommend		INT, 
		Srecommend		INT, 
		MatchId			INT, 
		RoleId			TINYINT, 
		UserName		VARCHAR(30), 
		CurrencyName	NVARCHAR(50), 
		Sporttype		INT,
		LeagueId		INT,
		HomeId			INT,
		AwayId			INT,
		Outstanding		MONEY,
		IsTest			BIT
	)

	INSERT INTO @Result (LogId, CustId, MatchId, Outstanding)
	SELECT TOP(@BatchSize) LogID, CustID, Matchid, Outstanding
	FROM dbo.crmTOControlOutstandingInfo h WITH(NOLOCK)
	WHERE h.LogID > @LastLogId 

	UPDATE r
		SET r.CurrencyName	= l.Currency
			,r.UserName		= l.Username
			,r.RoleId		= l.RoleId
			,r.Recommend	= l.recommend
			,r.Mrecommend	= l.mrecommend
			,r.Srecommend   = l.srecommend
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
	
	UPDATE r
		 SET r.IsTest = CASE WHEN r.CurrencyName = 'UUS' THEN 1 ELSE 0 END
	FROM @Result r
	 
	SELECT
		LogId		
		,CustId		
		,Recommend	
		,Mrecommend	
		,Srecommend	
		,MatchId		
		,RoleId		
		,UserName	
		,CurrencyName
		,Sporttype	
		,LeagueId	
		,HomeId		
		,AwayId		
		,Outstanding	
		,IsTest
	FROM @Result

END
GO