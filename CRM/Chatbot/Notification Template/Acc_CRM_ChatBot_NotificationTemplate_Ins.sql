USE bodb_CRM
GO

CREATE PROCEDURE [dbo].[Acc_CRM_ChatBot_NotificationTemplate_Ins]
	@UserId						INT
	,@NotificationTemplateName	NVARCHAR(1000) = NULL
	,@NotificationTypeId		TINYINT = NULL
	,@Title						NVARCHAR(2000)
	,@Content					XML
	,@ErrCode					INT = 0 OUTPUT
	,@ErrMsg					NVARCHAR(2000) = '' OUTPUT
AS

BEGIN
	SET NOCOUNT ON

	-- Check permission

	-- Check exists NotificationTemplateName
	IF EXISTS (SELECT 1 FROM dbo.crmNotificationTemplate WITH (NOLOCK) WHERE NotificationTemplateName = @NotificationTemplateName)
	BEGIN
		SELECT @ErrCode = 100, @ErrMsg = 'The Notification Template Name is not available, please check again'
		RETURN
	END

	-- Insert process
	BEGIN TRY
		INSERT INTO dbo.crmNotificationTemplate (NotificationTemplateName, NotificationTypeId, Title, Content)
		VALUES (@NotificationTemplateName, @NotificationTypeId, @Title, @Content)
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = ERROR_NUMBER(), @ErrMsg = ERROR_MESSAGE()
		RETURN
	END CATCH

	-- Write log
END
GO