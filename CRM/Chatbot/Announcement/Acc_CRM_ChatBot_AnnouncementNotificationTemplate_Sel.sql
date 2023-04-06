/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_ChatBot_AnnouncementNotificationTemplate_Sel]
AS
/*
	Created: 20221213@Malcolm
	Task :  Annoucement - Edit/Clone Annoucement - Notification template
	DB: DBCRM/bodb_CRM
	Original:
		Revisions:
			- 20221213@Malcolm: Initialize SPs [Redmine: #179118]
	Param's Explanation:

		
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @NotificationTypeId SMALLINT

	SELECT @NotificationTypeId = NotificationTypeId FROM dbo.crmNotificationType WITH(NOLOCK) WHERE NotificationTypeName = 'Upload Announcement'

	EXEC dbo.Acc_CRM_ChatBot_NotificationTemplate_Sel @NotificationTypeId = @NotificationTypeId
END
GO