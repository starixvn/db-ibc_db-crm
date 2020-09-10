/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_Chatbot_SendNotification]
AS

/*
	Created: 20200811@Percy
	DB: DBCRM-bodb_CRM
	Task: CRM - ChatBot - Send Notification

	Revisions:
		- 20200811@Percy: Initialize SP [RedmineID: #130544]
*/

BEGIN
	SET NOCOUNT ON

	SELECT DISTINCT n.NotificationId, n.Content, ng.ConversationGroupId, cg.ChatTypeId, cgb.BotId, cg.ConversationId
	FROM dbo.crmNotification n WITH (NOLOCK)
		INNER JOIN dbo.crmNotificationGroup ng WITH (NOLOCK) ON n.NotificationId = ng.NotificationId
		INNER JOIN dbo.crmConversationGroup cg WITH (NOLOCK) ON ng.ConversationGroupId = cg.ConversationGroupId
		LEFT JOIN dbo.crmConversationGroupBot cgb WITH (NOLOCK) ON cg.ConversationGroupId = cgb.ConversationGroupId
	WHERE n.Status IN ('Planned', 'Sending')
		AND ng.Status IN ('Planned', 'Retrying')
END
GO