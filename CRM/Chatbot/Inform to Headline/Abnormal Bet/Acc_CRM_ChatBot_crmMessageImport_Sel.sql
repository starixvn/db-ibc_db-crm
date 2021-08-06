/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_ChatBot_crmMessageImport_Sel]
	@BatchSize INT = 10
AS

/*
	Created: 20210701@Malcolm
	DB: DBCRM-bodb_CRM
	Task: CRM - ChatBot - Get data from crmMessageImport

	Revisions:
		- 20210701@Malcolm: Initialize SP [RedmineID: #157303]

	Param's Explanation:	
*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #Messages (MessageId INT, RequestId INT, UsernameList NVARCHAR(MAX), CustIdList VARCHAR(MAX))
	CREATE CLUSTERED INDEX CIX_Msg ON #Messages (MessageId, RequestId)

	INSERT INTO #Messages (MessageId, RequestId, UsernameList, CustIdList)
	SELECT MessageId, RequestId, UsernameList, CustIdList
	FROM dbo.crmMessageImport m WITH (NOLOCK)
	WHERE IsChatBotProcessed = 0
		AND NOT EXISTS (
			SELECT 1 FROM dbo.crmJobException e WITH (NOLOCK)
			WHERE m.RequestId = e.RequestId
				AND e.ServiceName = 'ChatBot - AbnormalBets'
		)

	;WITH CTE_Msg AS (
		SELECT TOP (@BatchSize) MessageId FROM #Messages GROUP BY MessageId ORDER BY MessageId
	)
	SELECT m.MessageId, m.RequestId, ISNULL(m.UsernameList, '') AS UsernameList, ISNULL(m.CustIdList, '') AS CustIdList
	FROM #Messages m
	WHERE EXISTS (SELECT 1 FROM CTE_Msg c WHERE m.MessageId = c.MessageId)

	DROP TABLE #Messages
END
GO