/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_ChatBot_crmMessageImport_Ins]
	@MessageIds XML
AS

/*
	Created: 20200811@Percy
	DB: DBCRM-bodb_CRM
	Task: CRM - ChatBot - Insert data into crmMessageImport

	Revisions:
		- 20200811@Percy: Initialize SP [RedmineID: #130544]

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
	SELECT
		t.c.value('@MessageID', 'INT') AS MessageId
		,t.c.value('@RequestID', 'INT') AS RequestId
	FROM @MessageIds.nodes('root/r') AS t(c)
	OPTION (OPTIMIZE FOR (@MessageIds = NULL))

	INSERT INTO dbo.crmMessageImport (MessageId, RequestId, CreatedDate)
	SELECT m.MessageId, m.RequestId, GETDATE()
	FROM #Messages m
		LEFT JOIN dbo.crmMessageImport cm WITH (NOLOCK) ON m.MessageId = cm.MessageId AND m.RequestId = cm.RequestId
	WHERE cm.MessageId IS NULL

	SELECT MessageId, RequestId
	FROM dbo.crmMessageImport m WITH (NOLOCK)
	WHERE IsChatBotProcessed = 0
		AND NOT EXISTS (
			SELECT 1 FROM dbo.crmJobException e WITH (NOLOCK)
			WHERE m.RequestId = e.RequestId
				AND e.ServiceName = 'ChatBot - AbnormalBets'
		)
END
GO