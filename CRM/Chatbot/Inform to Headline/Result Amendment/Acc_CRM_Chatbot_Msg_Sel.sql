/*<info serverAlias="DBMSG-bodb_Message" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_Chatbot_Msg_Sel]
	@Messages XML
AS

/*
	Created: 20210801@Malcolm
	DB: DBMSG-bodb_Message
	Task: CRM - ChatBot - Get Message Information

	Revisions:
		- 20210801@Malcolm: Initialize SP [RedmineID: #151509]

	Param's Explanation:
		@Messages:
			<root>
				<r MessageID="1"/>
				<r MessageID="1"/>
				<r MessageID="3"/>
			</root>
*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #Messages (MessageId INT)
	INSERT INTO  #Messages (MessageId)
	SELECT
		t.c.value('@MessageId', 'INT') AS MessageId
	FROM @Messages.nodes('root/r') AS t(c)
	OPTION (OPTIMIZE FOR (@Messages = NULL))

	-- Get messages
	SELECT	
		m.MessageId
		,m.Content_en
		,CASE WHEN ISNULL(m.Content_cs,'') = '' THEN m.Content_en ELSE m.Content_cs END AS [Content_cs]
		,CASE WHEN ISNULL(m.Content_th,'') = '' THEN m.Content_en ELSE m.Content_th END AS [Content_th]
		,CASE WHEN ISNULL(m.Content_vn,'') = '' THEN m.Content_en ELSE m.Content_vn END AS [Content_vn]
	FROM dbo.Msg m WITH (NOLOCK)
	WHERE EXISTS (SELECT 1 FROM #Messages t WHERE m.MessageId = t.MessageId)
	
	DROP TABLE #Messages
END
GO