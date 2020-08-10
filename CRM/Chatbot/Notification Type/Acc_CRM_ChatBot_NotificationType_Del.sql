USE bodb_CRM
GO

CREATE PROCEDURE [dbo].[Acc_CRM_ChatBot_NotificationType_Del]
	@UserId					INT
	,@NotificationTypeId	TINYINT
	,@ErrCode				INT = 0 OUTPUT
	,@ErrMsg				NVARCHAR(2000) = '' OUTPUT
AS

BEGIN
	SET NOCOUNT ON

	-- Check permission

	-- Check exists NotificationTypeId
	IF NOT EXISTS (SELECT 1 FROM dbo.crmNotificationType WITH (NOLOCK) WHERE NotificationTypeId = @NotificationTypeId)
	BEGIN
		SELECT @ErrCode = 101, @ErrMsg = 'The Notification Type does not exists, please check again!'
		RETURN
	END

	-- Delete process
	BEGIN TRY
		DELETE crmNotificationType WITH (ROWLOCK, UPDLOCK)
		WHERE NotificationTypeId = @NotificationTypeId
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = ERROR_NUMBER(), @ErrMsg = ERROR_MESSAGE()
		RETURN
	END CATCH

	-- Write log
END
GO