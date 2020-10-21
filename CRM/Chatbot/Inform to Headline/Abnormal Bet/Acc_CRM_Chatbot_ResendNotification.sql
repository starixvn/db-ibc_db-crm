/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_Chatbot_ResendNotification]
	@UserId				INT
	,@NotificationIds	VARCHAR(MAX)
	,@ErrCode			INT = 0 OUTPUT
	,@ErrMsg			VARCHAR(2000) = '' OUTPUT
AS

/*
	Created: 20200811@Percy
	DB: DBCRM-bodb_CRM
	Task: CRM - ChatBot - Resend Notification

	Revisions:
		- 20200811@Percy: Initialize SP [RedmineID: #130544]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @NotSendNotifications VARCHAR(MAX)
	DECLARE @SendNotifications TABLE (NotificationId INT)

	DECLARE @Notifications TABLE (NotificationId INT)
	INSERT INTO @Notifications (NotificationId)
	SELECT DISTINCT val FROM dbo.f_CRM_strSplit(@NotificationIds, ',')

	DECLARE @NotificationGroups TABLE (NotificationId INT, ConversationGroupId SMALLINT)
	INSERT INTO @NotificationGroups (NotificationId, ConversationGroupId)
	SELECT n.NotificationId, ng.ConversationGroupId
	FROM @Notifications t
		INNER JOIN dbo.crmNotification n WITH (NOLOCK) ON t.NotificationId = n.NotificationId
		INNER JOIN dbo.crmNotificationGroup ng WITH (NOLOCK) ON n.NotificationId = ng.NotificationId
	WHERE n.Status = 'Error'
		AND ng.Status NOT IN ('Planned')

	UPDATE n WITH (ROWLOCK)
	SET n.Status = 'Sending', n.Sender = @UserId
	OUTPUT DELETED.NotificationId INTO @SendNotifications (NotificationId)
	FROM dbo.crmNotification n
	WHERE EXISTS (SELECT 1 FROM @Notifications t WHERE n.NotificationId = t.NotificationId)
		AND n.Status = 'Error'

	IF @@ROWCOUNT <> 0
	BEGIN
		UPDATE ng WITH (ROWLOCK)
		SET ng.Status = 'Retrying', ng.RetryTime = 0
		FROM dbo.crmNotificationGroup ng
			INNER JOIN @NotificationGroups n ON n.NotificationId = ng.NotificationId AND n.ConversationGroupId = ng.ConversationGroupId
		WHERE ng.Status = 'Error'
	END

	SELECT @NotSendNotifications = COALESCE(@NotSendNotifications + ', ', '') + CONVERT(VARCHAR(20), n.NotificationId)
	FROM @Notifications n
		LEFT JOIN @SendNotifications sn ON n.NotificationId = sn.NotificationId
	WHERE sn.NotificationId IS NULL

	IF ISNULL(@NotSendNotifications, '') <> ''
	BEGIN
		SELECT @ErrCode = 101, @ErrMsg = 'You cannot resend these Notifications which are being resent: ' + @NotSendNotifications
		RETURN
	END
END
GO