/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_ChatBot_NotificationType_Ins]
	@UserId					INT
	,@NotificationTypeName	NVARCHAR(500)
	,@RecipientTypeIds		VARCHAR(200)
	,@ChatTypeIds			VARCHAR(200)
	,@SystemId				TINYINT
	,@ErrCode				INT = 0 OUTPUT
	,@ErrMsg				NVARCHAR(2000) = '' OUTPUT
AS
/*
Created: 20200810@Malcolm
Task :  insert a new notification type
DB: DBCRM/bodb_CRM
Original:
	Revisions:
		- 20200810@Malcolm: Initialize SPs [Redmine: #130544]
	Param's Explanation:
		
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @NotificationTypeId TINYINT = 0
	-- Check permission

	-- Check exists NotificationTypeName
	IF EXISTS (SELECT 1 FROM dbo.crmNotificationType WITH (NOLOCK) WHERE NotificationTypeName = @NotificationTypeName)
	BEGIN
		SELECT @ErrCode = 100, @ErrMsg = 'The Notification Type Name exists. Please check again!'
		RETURN
	END

	-- Insert process
	BEGIN TRY
		INSERT INTO dbo.crmNotificationType (NotificationTypeName, SystemId)
		VALUES (@NotificationTypeName, @SystemId)

		SELECT @NotificationTypeId = SCOPE_IDENTITY();

		INSERT INTO dbo.crmNotificationRecipientType
		(
			NotificationTypeId,
			RecipientTypeId
		)
		SELECT @NotificationTypeId,
			   val
		FROM bodb02.dbo.f_SplitString(@RecipientTypeIds,',')

		INSERT INTO dbo.crmNotificationChatType
		(
			NotificationTypeId,
			ChatTypeId
		)
		SELECT 
			@NotificationTypeId,
			val 
		FROM bodb02.dbo.f_SplitString(@ChatTypeIds,',')

	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR, @ErrMsg = ERROR_MESSAGE()

		IF @NotificationTypeId <> 0
		BEGIN
		    DELETE dbo.crmNotificationType WITH(ROWLOCK, UPDLOCK)
			WHERE NotificationTypeId = @NotificationTypeId

			DELETE dbo.crmNotificationRecipientType WITH(ROWLOCK, UPDLOCK)
			WHERE NotificationTypeId = @NotificationTypeId

			DELETE dbo.crmNotificationChatType WITH(ROWLOCK, UPDLOCK)
			WHERE NotificationTypeId = @NotificationTypeId
		END

		RETURN
		
	END CATCH

	-- Write log
END
GO