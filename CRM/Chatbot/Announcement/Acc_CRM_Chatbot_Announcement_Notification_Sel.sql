/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_Chatbot_Announcement_Notification_Sel]
AS
/*
	Created: 20230607@Malcolm
	DB: DBCRM-bodb_CRM
	Task: CRM - ChatBot - Send Notification of Announcement

	Revisions:
		- 20230607@Malcolm: Initialize SP [RedmineID: #189408]

	Param's Explanation:

*/

BEGIN
	SET NOCOUNT ON

	DECLARE @SendNotifications TABLE (NotificationId INT, Content NVARCHAR(MAX), ConversationGroupId SMALLINT, ChatTypeId TINYINT, BotId BIGINT, ConversationId VARCHAR(200)
		,IsOnlyRetryImage BIT, ErrImages NVARCHAR(2000))

	DECLARE @Notifications TABLE (NotificationId INT, ConversationGroupId SMALLINT)

	INSERT INTO @Notifications (NotificationId, ConversationGroupId)
	SELECT n.NotificationId, ng.ConversationGroupId
	FROM dbo.crmNotification n WITH (NOLOCK)
		INNER JOIN dbo.crmNotificationGroup ng WITH (NOLOCK) ON n.NotificationId = ng.NotificationId
		INNER JOIN dbo.crmAnnouncementNotification an WITH(NOLOCK) ON an.NotificationId = n.NotificationId
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
		,sn.IsOnlyRetryImage = n.IsOnlyRetryImage
		,sn.ErrImages = n.ErrImages
	FROM @SendNotifications sn
		CROSS APPLY (
			SELECT n.Content, t.c.value('@IsOnlyRetryImage', 'BIT') AS IsOnlyRetryImage, t.c.value('@ErrImages', 'NVARCHAR(2000)') AS ErrImages
			FROM dbo.crmNotification n WITH (NOLOCK)
				INNER JOIN dbo.crmNotificationGroup ng WITH(NOLOCK) ON ng.NotificationId = n.NotificationId
				OUTER APPLY ng.FailInfo.nodes('root/r') t(c)
			WHERE n.NotificationId = sn.NotificationId
		) n
		CROSS APPLY
		(
			SELECT cg.ChatTypeId, cgb.BotId, cg.ConversationId, cg.LanguageId
			FROM dbo.crmConversationGroup cg WITH (NOLOCK)
				LEFT JOIN dbo.crmConversationGroupBot cgb WITH (NOLOCK) ON cg.ConversationGroupId = cgb.ConversationGroupId
			WHERE cg.ConversationGroupId = sn.ConversationGroupId
		) ng

	Result:
		SELECT s.NotificationId, s.Content, s.ConversationGroupId, s.ChatTypeId, s.BotId, s.ConversationId, ISNULL(a.FileName, '') AS FileName, a.AnnouncementId, s.IsOnlyRetryImage, s.ErrImages
		FROM @SendNotifications s
			LEFT JOIN dbo.crmAnnouncementNotification an WITH(NOLOCK) ON an.NotificationId = s.NotificationId
			LEFT JOIN dbo.crmAnnouncement a WITH(NOLOCK) ON a.AnnouncementId = an.AnnouncementId 
END
GO