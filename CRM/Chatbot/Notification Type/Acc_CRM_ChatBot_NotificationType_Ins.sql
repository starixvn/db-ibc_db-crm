USE bodb_CRM
GO

CREATE PROCEDURE [dbo].[Acc_CRM_ChatBot_NotificationType_Ins]
	@UserId					INT
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

	-- Check exists NotificationTypeName
	IF EXISTS (SELECT 1 FROM dbo.crmNotificationType WITH (NOLOCK) WHERE NotificationTypeName = @NotificationTypeName)
	BEGIN
		SELECT @ErrCode = 100, @ErrMsg = 'The Notification Type Name is not available, please check again!'
		RETURN
	END

	-- Insert process
	BEGIN TRY
		INSERT INTO dbo.crmNotificationType (NotificationTypeName, RecipientTypeId, ChatTypeId, SystemId)
		VALUES (@NotificationTypeName, @RecipientTypeId, @ChatTypeId, @SystemId)
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = ERROR_NUMBER(), @ErrMsg = ERROR_MESSAGE()
		RETURN
	END CATCH

	-- Write log
END
GO