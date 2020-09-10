/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_ChatBot_crmMessageImport_Upd]
	@MessageIds XML
AS

/*
	Created: 20200811@Percy
	DB: DBCRM-bodb_CRM
	Task: CRM - ChatBot - Update data on crmMessageImport

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

	UPDATE cm WITH (ROWLOCK)
	SET cm.IsChatBotProcessed = 1
	FROM dbo.crmMessageImport cm
		INNER JOIN #Messages m ON m.MessageId = cm.MessageId AND m.RequestId = cm.RequestId

	DELETE dbo.crmMessageImport WITH (ROWLOCK, UPDLOCK)
	WHERE IsProcessed = 1 AND IsChatBotProcessed = 1
		AND CreatedDate < DATEADD(MONTH, -1, GETDATE())
END
GO