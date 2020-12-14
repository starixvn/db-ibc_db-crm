/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_Chatbot_TOControl_Sel]
	@Xml XML
AS

/*
	Created: 20201214@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Get SMAs which reach Company Turnover Control

	Revisions:
		- 20201214@Malcolm: Initialize SP [RedmineID: #130544]

	Param's Explanation:
		.@Xml = <root><r CustId ="" MatchId ="" NotifiedPercentValue=""/><root/>

*/
BEGIN
	SET NOCOUNT ON

	DECLARE @Result TABLE (CustId INT, MatchId INT, NotifiedPercentValue TINYINT,RoleId TINYINT, UserName VARCHAR(30), CurrencyName NVARCHAR(50))

	INSERT INTO @Result (CustId, MatchId, NotifiedPercentValue)
	SELECT 
		T.c.value('@CustId', 'INT')
		,T.c.value('@MatchId', 'INT')
		,T.c.value('@NotifiedPercentValue', 'TINYINT')
	FROM @Xml.nodes('root/r') T(c)
	OPTION (OPTIMIZER FOR (@Xml = NULL))

	UPDATE r
		SET r.CurrencyName	= l.Currency
			,r.UserName		= l.Username
			,r.RoleId		= l.RoleId
	FROM @Result r
	CROSS APPLY(
		SELECT TOP (1) Username , e.Currency , RoleId 
		FROM dbo.Customer c WITH(NOLOCK)
			INNER JOIN dbo.exchange e WITH(NOLOCK) ON e.ExchangeId = c.currency
		WHERE c.custid = r.CustId
	) AS l
	
	SELECT CustId ,MatchId ,NotifiedPercentValue ,RoleId ,UserName ,CurrencyName FROM @Result

END
GO