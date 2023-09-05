/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_ChatBot_NotificationList_Upd]
	@NotificationId			INT 
	,@Remark  				NVARCHAR(2000) = ''
	,@UserId				INT
	,@ErrCode				INT = 0 OUTPUT
	,@ErrMsg				NVARCHAR(2000) = '' OUTPUT
AS
/*
	Created: 20200810@Malcolm
	Task : CRM - Headline Notification - Notification List - View Detail (For notification with status as error) - Resolve (Update remarks of notification list)
	DB: DBCRM/bodb_CRM
	Original:
	Revisions:
		- 20200810@Malcolm: Initialize SPs [Redmine: #130544]
		- 20230508@Malcolm: Offer Telegram bot service for Headlines [RedmineId : #179119]
	Param's Explanation:
		
*/

BEGIN
	SET NOCOUNT ON

	BEGIN TRY
		UPDATE dbo.crmNotification WITH(ROWLOCK)
		SET ResolvedRemark = @Remark, Status = 'Resolved', ResolvedBy = @UserId
		WHERE NotificationId = @NotificationId
			AND Status = 'Error'

		UPDATE dbo.crmNotificationGroup WITH(ROWLOCK)
		SET Status = 'Resolved'
		WHERE NotificationId = @NotificationId
			AND Status = 'Error'
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR, @ErrMsg = ERROR_MESSAGE()
	END CATCH
END
GO