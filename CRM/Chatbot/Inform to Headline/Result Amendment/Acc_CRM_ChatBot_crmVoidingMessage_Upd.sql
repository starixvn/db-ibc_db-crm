/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_ChatBot_crmVoidingMessage_Upd]
	@Messages XML
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
				<r MessageId=1 MsgTargetId=1 />
				<r MessageId=1 MsgTargetId=2 />
				<r MessageId=3 MsgTargetId=2 />
			</root>
*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #Messages (MessageId INT, MsgTargetId INT)
	INSERT INTO  #Messages (MessageId, MsgTargetId)
	SELECT
		t.c.value('@MessageId', 'INT') AS MessageId
		,t.c.value('@MsgTargetId', 'INT') AS RequestId
	FROM @Messages.nodes('root/r') AS t(c)
	OPTION (OPTIMIZE FOR (@Messages = NULL))

	UPDATE cm WITH (ROWLOCK)
	SET cm.IsChatBotProcessed = 1
	FROM dbo.crmVoidingMessage cm
		INNER JOIN #Messages m ON m.MessageId = cm.MessageId AND m.MsgTargetId = cm.MsgTargetId

	DELETE dbo.crmVoidingMessage WITH (ROWLOCK, UPDLOCK)
	WHERE IsProcessed = 1 AND IsChatBotProcessed = 1
		AND CreatedDate < DATEADD(MONTH, -1, GETDATE())

	DROP TABLE #Messages
END
GO