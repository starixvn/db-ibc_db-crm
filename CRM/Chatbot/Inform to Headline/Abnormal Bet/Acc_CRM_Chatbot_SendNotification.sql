/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_Chatbot_SendNotification]
AS

/*
	Created: 20200811@Percy
	DB: DBCRM-bodb_CRM
	Task: CRM - ChatBot - Send Notification

	Revisions:
		- 20200811@Percy: Initialize SP [RedmineID: #130544]
		- 20221222@Malcolm: Get file name [RedmineID: #179118]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @SendNotifications TABLE (NotificationId INT, Content NVARCHAR(MAX), ConversationGroupId SMALLINT, ChatTypeId TINYINT, BotId INT, ConversationId VARCHAR(200))
	DECLARE @Notifications TABLE (NotificationId INT, ConversationGroupId SMALLINT)

	INSERT INTO @Notifications (NotificationId, ConversationGroupId)
	SELECT n.NotificationId, ng.ConversationGroupId
	FROM dbo.crmNotification n WITH (NOLOCK)
		INNER JOIN dbo.crmNotificationGroup ng WITH (NOLOCK) ON n.NotificationId = ng.NotificationId
	WHERE n.Status IN ('Planned', 'Sending')
		AND ng.Status IN ('Planned', 'Retrying')

	IF @@ROWCOUNT = 0
		GOTO Result

	UPDATE ng WITH (ROWLOCK)
	SET ng.Status = 'Sending'
	OUTPUT DELETED.NotificationId, DELETED.ConversationGroupId INTO @SendNotifications (NotificationId, ConversationGroupId)
	FROM dbo.crmNotificationGroup ng
		INNER JOIN @Notifications n ON n.NotificationId = ng.NotificationId AND n.ConversationGroupId = ng.ConversationGroupId
	WHERE ng.Status IN ('Planned', 'Retrying')

	IF @@ROWCOUNT = 0
		GOTO Result

	UPDATE n WITH (ROWLOCK)
	SET n.Status = 'Sending'
	FROM dbo.crmNotification n
	WHERE EXISTS (SELECT 1 FROM @Notifications t WHERE n.NotificationId = t.NotificationId)
		AND n.Status IN ('Planned', 'Sending')

	UPDATE sn
	SET sn.Content = n.Content
		,sn.ChatTypeId = ng.ChatTypeId
		,sn.BotId = ng.BotId
		,sn.ConversationId = ng.ConversationId
	FROM @SendNotifications sn
		CROSS APPLY (
			SELECT n.Content
			FROM dbo.crmNotification n WITH (NOLOCK)
			WHERE n.NotificationId = sn.NotificationId
		) n
		CROSS APPLY
		(
			SELECT cg.ChatTypeId, cgb.BotId, cg.ConversationId
			FROM dbo.crmConversationGroup cg WITH (NOLOCK)
				LEFT JOIN dbo.crmConversationGroupBot cgb WITH (NOLOCK) ON cg.ConversationGroupId = cgb.ConversationGroupId
			WHERE cg.ConversationGroupId = sn.ConversationGroupId
		) ng

	Result:
		SELECT s.NotificationId, s.Content, s.ConversationGroupId, s.ChatTypeId, s.BotId, s.ConversationId, ISNULL(a.FileName, '') AS FileName, a.AnnouncementId 
		FROM @SendNotifications s
			LEFT JOIN dbo.crmAnnouncementNotification an WITH(NOLOCK) ON an.NotificationId = s.NotificationId
			LEFT JOIN dbo.crmAnnouncement a WITH(NOLOCK) ON a.AnnouncementId = an.AnnouncementId 
END
GO