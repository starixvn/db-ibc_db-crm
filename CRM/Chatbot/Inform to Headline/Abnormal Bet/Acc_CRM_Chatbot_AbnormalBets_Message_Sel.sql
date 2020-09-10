/*<info serverAlias="DBMSG-bodb_Message" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_Chatbot_AbnormalBets_Message_Sel]
	@Messages	XML
	,@BatchSize	INT
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

	-- Get top new messages
	DECLARE @tblMessage TABLE (MessageId INT, Content_en NVARCHAR(4000), Content_cs NVARCHAR(4000), Content_th NVARCHAR(4000), Content_vn NVARCHAR(4000))
	INSERT INTO @tblMessage (MessageId, Content_en, Content_cs, Content_th, Content_vn)
	SELECT TOP (@BatchSize) m.MessageId, m.Content_en, m.Content_cs, m.Content_th, m.Content_vn
	FROM dbo.Msg m WITH (NOLOCK)
	WHERE m.msgtype = 1
		AND m.isbatch = 1
		AND m.MsgContentsType = 103
		AND m.Content_en LIKE '%@@%'
		AND EXISTS (SELECT 1 FROM #Messages t WHERE m.MessageId = t.MessageId)
	ORDER BY m.MessageId
	OPTION (RECOMPILE)

	SELECT t.RequestId, m.MessageId, m.Content_en, m.Content_cs, m.Content_th, m.Content_vn
	FROM @tblMessage m
		INNER JOIN #Messages t ON m.MessageId = t.MessageId
	
	DROP TABLE #Messages
END
GO