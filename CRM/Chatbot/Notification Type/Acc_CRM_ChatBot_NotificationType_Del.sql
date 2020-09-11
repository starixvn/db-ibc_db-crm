/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_ChatBot_NotificationType_Del]
	@UserId					INT
	,@NotificationTypeId	SMALLINT
	,@NotificationTypeName	NVARCHAR(500)
	,@ErrCode				INT = 0 OUTPUT
	,@ErrMsg				NVARCHAR(2000) = '' OUTPUT
AS
/*
Created: 20200810@Malcolm
Task :  Delete a new notification type
DB: DBCRM/bodb_CRM
Original:
	Revisions:
		- 20200810@Malcolm: Initialize SPs [Redmine: #130544]
	Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @Tmp TABLE 
	(
		NotificationTypeId		SMALLINT
		,NotificationTypeName	NVARCHAR(500)
		,SystemId				TINYINT
		,RecipientTypeId		TINYINT
		,ChatTypeId				TINYINT
		,Type                   TINYINT
	)

	CREATE TABLE #NotificationTemplate(NotificationTemplateId INT)
	DECLARE @MsgContentsType XML

	SELECT @MsgContentsType = CAST(Value AS XML)
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'NotificationTemplate'

	INSERT INTO #NotificationTemplate(NotificationTemplateId)
	SELECT  T.c.value('@NotificationTemplateID', 'INT')
	FROM @MsgContentsType.nodes('/root/r') T(c)

	-- Check permission

	-- Check exists NotificationTypeId
	IF NOT EXISTS (SELECT 1 FROM dbo.crmNotificationType WITH (NOLOCK) WHERE NotificationTypeId = @NotificationTypeId)
	BEGIN
		SELECT @ErrCode = 101, @ErrMsg = @NotificationTypeName + ' has been deleted. Please check!'
		RETURN
	END

	IF EXISTS(SELECT 1 FROM dbo.crmNotification n WITH(NOLOCK) WHERE n.NotificationTypeId = @NotificationTypeId)
	BEGIN
		SELECT @ErrCode = 102, @ErrMsg = 'Unable to delete the notification type because one or many assigned notification(s) exist(s)'
		RETURN
	END

	IF EXISTS(SELECT 1 FROM dbo.crmNotificationTemplate n WITH(NOLOCK) WHERE n.NotificationTypeId = @NotificationTypeId)
	BEGIN
		SELECT @ErrCode = 103, @ErrMsg = 'Unable to delete the notification type because one or many assigned notification(s) exist(s)'
		RETURN
	END

	IF EXISTS(SELECT 1 FROM #NotificationTemplate WHERE NotificationTemplateId = @NotificationTypeId)
	BEGIN
		SELECT @ErrCode = 102, @ErrMsg = 'This is the system template, so you cannot delete it.'
		RETURN
	END

	-- Delete process
	BEGIN TRY

		DELETE dbo.crmNotificationRecipientType WITH(ROWLOCK, UPDLOCK)
		OUTPUT deleted.NotificationTypeId, deleted.RecipientTypeId, 1
			INTO @Tmp(NotificationTypeId, RecipientTypeId, Type)
		WHERE NotificationTypeId = @NotificationTypeId

		DELETE dbo.crmNotificationChatType WITH(ROWLOCK, UPDLOCK)
		OUTPUT deleted.ChatTypeId, deleted.NotificationTypeId, 2
			INTO @Tmp(ChatTypeId, NotificationTypeId, Type)
		WHERE NotificationTypeId = @NotificationTypeId

		DELETE dbo.crmNotificationType WITH (ROWLOCK, UPDLOCK)
		OUTPUT deleted.NotificationTypeId, deleted.NotificationTypeName, deleted.SystemId, 3
			INTO @Tmp(NotificationTypeId,NotificationTypeName,SystemId, Type)
		WHERE NotificationTypeId = @NotificationTypeId

	END TRY
	BEGIN CATCH
		SELECT @ErrCode = ERROR_NUMBER(), @ErrMsg = ERROR_MESSAGE()
		IF EXISTS(SELECT 1 FROM @Tmp WHERE Type = 1)
			INSERT INTO dbo.crmNotificationRecipientType
			(
				NotificationTypeId,
				RecipientTypeId
			)
			SELECT 
				NotificationTypeId, 
				RecipientTypeId
			FROM @Tmp
			WHERE Type = 1

		IF EXISTS(SELECT 1 FROM @Tmp WHERE Type = 2)
			INSERT INTO dbo.crmNotificationChatType
			(
				ChatTypeId, 
				NotificationTypeId
			)
			SELECT 
				ChatTypeId, 
				NotificationTypeId
			FROM @Tmp
			WHERE Type = 2
		RETURN
	END CATCH

	DROP TABLE #NotificationTemplate
	-- Write log
END
GO