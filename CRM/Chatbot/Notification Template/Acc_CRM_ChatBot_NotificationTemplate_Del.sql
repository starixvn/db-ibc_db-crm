USE bodb_CRM
GO

CREATE PROCEDURE [dbo].[Acc_CRM_ChatBot_NotificationTemplate_Del]
	@UserId						INT
	,@NotificationTemplateId	SMALLINT
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

	-- Delete process
	BEGIN TRY
		DELETE dbo.crmNotificationTemplate WITH (ROWLOCK, UPDLOCK)
		WHERE NotificationTemplateId = @NotificationTemplateId
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = ERROR_NUMBER(), @ErrMsg = ERROR_MESSAGE()
		RETURN
	END CATCH

	-- Write log
END
GO