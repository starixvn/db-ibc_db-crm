/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20221222@Malcolm
	DB: DBCRM-bodb_CRM
	Task: create job to import notification [RedmineId : #179118]
*/


DECLARE @SystemId INT, @NotificationTypeId SMALLINT, @RecipientTypeId TINYINT

INSERT INTO dbo.crmSystem (SystemName)
VALUES ('CRM')

SELECT @SystemId = SystemId FROM dbo.crmSystem WITH(NOLOCK) WHERE SystemName = 'CRM'

INSERT INTO dbo.crmNotificationType (NotificationTypeName, SystemId)
VALUES ('Upload Announcement', @SystemId)

SELECT @NotificationTypeId = NotificationTypeId FROM dbo.crmNotificationType WITH(NOLOCK) WHERE NotificationTypeName = 'Upload Announcement'

INSERT INTO dbo.crmNotificationChatType (NotificationTypeId, ChatTypeId)
VALUES (@NotificationTypeId, 1), (@NotificationTypeId, 2)

SELECT @RecipientTypeId = RecipientTypeId FROM dbo.crmRecipientType WITH(NOLOCK) WHERE RecipientTypeName = 'PIC of headline'

INSERT INTO dbo.crmNotificationRecipientType (NotificationTypeId, RecipientTypeId)
VALUES (@NotificationTypeId, @RecipientTypeId)