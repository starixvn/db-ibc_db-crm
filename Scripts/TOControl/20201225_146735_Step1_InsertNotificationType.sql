/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20201225@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Insert data [RedmineId : #146735]
*/
--Step 1
--Insert data
DECLARE @SystemId INT, @NotificationTypeId INT, @RecipientTypeId INT, @NotificationTemplateId INT

INSERT INTO dbo.crmSystem (SystemName)
VALUES ('Customer Management')

SELECT @SystemId = s.SystemId FROM dbo.crmSystem s WITH(NOLOCK) WHERE s.SystemName = 'Customer Management'

INSERT INTO  dbo.crmNotificationType (NotificationTypeName, SystemId)
VALUES ('Turnover Control Announcement', @SystemId)

SELECT @NotificationTypeId = NotificationTypeId FROM dbo.crmNotificationType  WITH(NOLOCK) WHERE NotificationTypeName = 'Turnover Control Announcement' AND SystemId = @SystemId

SELECT @RecipientTypeId = RecipientTypeId FROM dbo.crmRecipientType WITH(NOLOCK) WHERE RecipientTypeName = 'PIC of headline'

INSERT INTO dbo.crmNotificationRecipientType (NotificationTypeId, RecipientTypeId)
VALUES (@NotificationTypeId, @RecipientTypeId)

INSERT INTO dbo.crmNotificationChatType(NotificationTypeId, ChatTypeId)
VALUES (@NotificationTypeId, 1), (@NotificationTypeId, 2)

INSERT INTO dbo.crmNotificationTemplate (NotificationTemplateName, NotificationTypeId, Title)
VALUES ('Turnover Control Template', @NotificationTypeId, 'Turnover Control Template')

