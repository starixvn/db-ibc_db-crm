/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_Chatbot_TOControlImport_Ins]
	@XML XML,
	@BatchSize INT = 10
AS

/*
	Created: 20201214@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Get SMAs which reach Company Turnover Control

	Revisions:
		- 20201214@Malcolm: Initialize SP [RedmineID: #130544]

	Param's Explanation:
		.@XML = <root><r CustId ="" MatchId ="" NotifiedPercentValue=""> </r><root/>

*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #Tmp (CustId INT, MatchId INT, NotifiedPercentValue TINYINT)

	INSERT INTO #Tmp (CustId, MatchId)
	SELECT 
		T.c.value('@CustId', 'INT')
		,T.c.value('@MatchId', 'INT')
		,T.c.value('@NotifiedPercentValue', 'TINYINT')
	FROM @XML.nodes('root/r') T(c)
	OPTION (OPTIMIZER FOR (@XML = NULL))

	INSERT INTO dbo.crmTOControlImport (CustId, MatchId, NotifiedPercentValue, IsNotified)
	SELECT t.CustId, t.MatchId, t.NotifiedPercentValue, 0
	FROM #Tmp t

	SELECT TOP(@BatchSize) LogId, CustId, MatchId, NotifiedPercentValue
	FROM dbo.crmTOControlImport WITH(NOLOCK)
	WHERE IsNotified = 0
	ORDER BY LogId 

	DROP TABLE #Tmp
END
GO