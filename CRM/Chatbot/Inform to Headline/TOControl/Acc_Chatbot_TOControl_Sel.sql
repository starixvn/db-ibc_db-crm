/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_Chatbot_TOControl_Sel]
	@LastDatetime   DATETIME
	,@BatchSize		INT = 10
AS

/*
	Created: 20201214@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Get SMAs which reach Company Turnover Control

	Revisions:
		- 20201214@Malcolm: Initialize SP [RedmineID: #130544]

	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #Result 
	(
		CustId			INT, 
		MatchId			INT, 
		RoleId			TINYINT, 
		UserName		VARCHAR(30), 
		CurrencyName	VARCHAR(30)
	)

	INSERT INTO #Result (CustId, MatchId)
	SELECT CustID, matchid FROM TOControl_Setting WHERE IsGroupHeadLine = 0 AND NotifiedPercentValue > 60 AND ModifiedDatePercentValue > @LastDatetime

	UPDATE r
		SET r.CurrencyName	= l.CurrencyName
			,r.UserName		= l.Username
			,r.RoleId		= l.RoleId
	FROM #Result r
	CROSS APPLY(
		SELECT TOP 1 Username , e.Currency , RoleId 
		FROM dbo.Customer c WITH(NOLOCK)
			INNER JOIN dbo.exchange e WITH(NOLOCK) ON e.ExchangeId = c.currency
		WHERE c.custid = r.CustId
	) AS l(Username, CurrencyName, RoleId)
	
	SELECT 
		CustId		
		,MatchId		
		,RoleId		
		,UserName	
		,CurrencyName
	FROM #Result

END
GO