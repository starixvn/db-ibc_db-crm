/*<info serverAlias="DBMSG-bodb_Message" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_Chatbot_AbnormalBets_Message_Sel]
	@Messages XML
AS

/*
	Created: 20200811@Percy
	DB: DBMSG-bodb_Message
	Task: CRM - ChatBot - Get Message Information

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
	FROM @Messages.nodes('root/r') AS t(c)
	OPTION (OPTIMIZE FOR (@Messages = NULL))

	-- Get messages
	SELECT t.RequestId, m.MessageId, m.Content_en, m.Content_cs, m.Content_th, m.Content_vn
	FROM dbo.Msg m WITH (NOLOCK)
		INNER JOIN #Messages t ON m.MessageId = t.MessageId
	WHERE m.msgtype = 1
		AND m.isbatch = 1
		AND m.MsgContentsType = 103
		AND m.Content_en LIKE '%@@%'
	ORDER BY m.MessageId
	OPTION (RECOMPILE)
	
	DROP TABLE #Messages
END
GO