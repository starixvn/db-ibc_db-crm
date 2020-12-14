/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_Chatbot_TOControlImport_Upd]
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
		.@XML = <root><r CustId ="" MatchId =""> </r><root/>

*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #Tmp (CustId INT, MatchId INT)

	INSERT INTO #Tmp (CustId, MatchId)
	SELECT 
		T.c.value('@CustId', 'INT')
		,T.c.value('@MatchId', 'INT')
	FROM @XML.nodes('root/r') T(c)
	OPTION (OPTIMIZER FOR (@XML = NULL))

	MERGE dbo.crmTOControlImport AS TARGET
	USING #Tmp AS SOURCE
		ON (TARGET.CustId = SOURCE.CustId AND TARGET.MatchId = SOURCE.MatchId)
	WHEN MATCHED THEN UPDATE SET  TARGET.IsNotified = 0
	WHEN NOT MATCHED BY TARGET THEN INSERT (CustId, MatchId, IsNotified) VALUES (SOURCE.CustId, SOURCE.MatchId, 0);
	
	SELECT TOP(@BatchSize) CustId, MatchId
	FROM dbo.crmTOControlImport WITH(NOLOCK)

	DROP TABLE #Tmp
END
GO