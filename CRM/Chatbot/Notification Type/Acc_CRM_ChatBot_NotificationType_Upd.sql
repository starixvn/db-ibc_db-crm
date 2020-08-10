USE bodb_CRM
GO

CREATE PROCEDURE [dbo].[Acc_CRM_ChatBot_NotificationType_Upd]
	@UserId					INT
	,@NotificationTypeId	TINYINT
	,@NotificationTypeName	NVARCHAR(500)
	,@RecipientTypeId		TINYINT
	,@ChatTypeId			TINYINT
	,@SystemId				TINYINT
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

	-- Check exists NotificationTypeName
	IF EXISTS (SELECT 1 FROM dbo.crmNotificationType WITH (NOLOCK) WHERE NotificationTypeId <> @NotificationTypeId AND NotificationTypeName = @NotificationTypeName)
	BEGIN
		SELECT @ErrCode = 101, @ErrMsg = 'The Notification Type Name is not available, please check again!'
		RETURN
	END

	-- Update process
	BEGIN TRY
		UPDATE crmNotificationType WITH (ROWLOCK)
		SET NotificationTypeName	= ISNULL(@NotificationTypeName, NotificationTypeName)
			,RecipientTypeId		= ISNULL(@RecipientTypeId, RecipientTypeId)
			,ChatTypeId				= ISNULL(@ChatTypeId, ChatTypeId)
			,SystemId				= ISNULL(@SystemId, SystemId)
		WHERE NotificationTypeId = @NotificationTypeId
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = ERROR_NUMBER(), @ErrMsg = ERROR_MESSAGE()
		RETURN
	END CATCH

	-- Write log
END
GO