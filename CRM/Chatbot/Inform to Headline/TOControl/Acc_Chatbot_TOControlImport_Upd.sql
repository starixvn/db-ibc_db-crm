/*<info serverAlias="DBCUST-CustDB" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_Chatbot_TOControlImport_Upd]
	@XML XML
AS

/*
	Created: 20201214@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Get SMAs which reach Company Turnover Control

	Revisions:
		- 20201214@Malcolm: Initialize SP [RedmineID: #130544]

	Param's Explanation:
		.@XML = <root><r LogId=""> </r><root/>

*/
BEGIN
	SET NOCOUNT ON

	IF @XML IS NULL
	BEGIN
		RETURN
	END

	DECLARE @Tmp TABLE (LogId BIGINT)

	INSERT INTO @Tmp (LogId)
	SELECT 
		T.c.value('@LogId', 'BIGINT')
	FROM @XML.nodes('root/r') T(c)
	OPTION (OPTIMIZER FOR (@XML = NULL))

	UPDATE i
		SET i.IsNotified = 1
	FROM dbo.crmTOControlImport i WITH(ROWLOCK)
		INNER JOIN @Tmp t ON t.LogId = i.LogId

END
GO