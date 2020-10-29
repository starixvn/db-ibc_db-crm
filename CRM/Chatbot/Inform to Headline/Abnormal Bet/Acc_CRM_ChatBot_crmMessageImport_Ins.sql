/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_ChatBot_crmMessageImport_Ins]
	@Messages XML
	,@BatchSize INT = 10
AS

/*
	Created: 20200811@Percy
	DB: DBCRM-bodb_CRM
	Task: CRM - ChatBot - Insert data into crmMessageImport

	Revisions:
		- 20200811@Percy: Initialize SP [RedmineID: #130544]
		- 20201029@Percy: Change left join to outer apply [RedmineID: #144466]

	Param's Explanation:
		@Messages:
			<root>
				<r MessageID=1 RequestID=1 />
				<r MessageID=1 RequestID=2 />
				<r MessageID=3 RequestID=2 />
			</root>
*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #Messages (MessageId INT, RequestId INT)
	INSERT INTO  #Messages (MessageId, RequestId)
	SELECT DISTINCT
		t.c.value('@MessageID', 'INT') AS MessageId
		,t.c.value('@RequestID', 'INT') AS RequestId
	FROM @Messages.nodes('root/r') AS t(c)
	OPTION (OPTIMIZE FOR (@Messages = NULL))

	INSERT INTO dbo.crmMessageImport (MessageId, RequestId, CreatedDate)
	SELECT m.MessageId, m.RequestId, GETDATE()
	FROM #Messages m
		OUTER APPLY (SELECT TOP 1 cm.MessageId FROM dbo.crmMessageImport cm WITH (NOLOCK) WHERE m.MessageId = cm.MessageId AND m.RequestId = cm.RequestId) cm
	WHERE cm.MessageId IS NULL

	-- Return messages
	TRUNCATE TABLE #Messages

	CREATE CLUSTERED INDEX CIX_Msg ON #Messages (MessageId, RequestId)

	INSERT INTO #Messages (MessageId, RequestId)
	SELECT MessageId, RequestId
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
	SELECT m.MessageId, m.RequestId
	FROM #Messages m
	WHERE EXISTS (SELECT 1 FROM CTE_Msg c WHERE m.MessageId = c.MessageId)

	DROP TABLE #Messages
END
GO