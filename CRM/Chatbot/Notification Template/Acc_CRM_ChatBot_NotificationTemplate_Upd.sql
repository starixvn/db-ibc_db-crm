USE bodb_CRM
GO

CREATE PROCEDURE [dbo].[Acc_CRM_ChatBot_NotificationTemplate_Upd]
	@UserId						INT
	,@NotificationTemplateId	SMALLINT
	,@NotificationTemplateName	NVARCHAR(1000) = NULL
	,@NotificationTypeId		TINYINT = NULL
	,@Title						NVARCHAR(2000) = NULL
	,@Content					XML = NULL
	,@ErrCode					INT = 0 OUTPUT
	,@ErrMsg					NVARCHAR(2000) = '' OUTPUT
AS

BEGIN
	SET NOCOUNT ON

	-- Check permission

	-- Check exists NotificationTemplateId
	IF NOT EXISTS (SELECT 1 FROM dbo.crmNotificationTemplate WITH (NOLOCK) WHERE NotificationTemplateId = @NotificationTemplateId)
	BEGIN
		SELECT @ErrCode = 101, @ErrMsg = 'The Notification Template does not exists, please check again!'
		RETURN
	END

	-- Check exists NotificationTemplateName
	IF EXISTS (SELECT 1 FROM dbo.crmNotificationTemplate WITH (NOLOCK) WHERE NotificationTemplateId <> @NotificationTemplateId AND NotificationTemplateName = @NotificationTemplateName)
	BEGIN
		SELECT @ErrCode = 101, @ErrMsg = 'The Notification Template Name is not available, please check again'
		RETURN
	END

	-- Update process
	BEGIN TRY
		UPDATE dbo.crmNotificationTemplate WITH (ROWLOCK)
		SET NotificationTemplateName	= ISNULL(@NotificationTemplateName, NotificationTemplateName)
			,NotificationTypeId			= ISNULL(@NotificationTypeId, NotificationTypeId)
			,Title						= ISNULL(@Title, Title)
			,Content					= ISNULL(@Content, Content)
		WHERE NotificationTemplateId = @NotificationTemplateId
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = ERROR_NUMBER(), @ErrMsg = ERROR_MESSAGE()
		RETURN
	END CATCH

	-- Write log
END
GO