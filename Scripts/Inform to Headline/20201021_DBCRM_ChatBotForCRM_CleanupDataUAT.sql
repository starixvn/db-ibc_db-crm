/*<info serverAlias="DBCRM-bodb_CRM"></info>*/

/*
	Created: 20201021@Percy
	DB: DBCRM-bodb_CRM
	Task: Chatbot for CRM - Clean up testing data on UAT
*/

use bodb_CRM
go

truncate table dbo.crmConversationBot
go
truncate table dbo.crmConversationGroup
go
truncate table dbo.crmConversationGroupBot
go
truncate table dbo.crmConversationGroupHeadline
go
truncate table dbo.crmConversationGroupRecipient
go
truncate table dbo.crmNotification
go
truncate table dbo.crmNotificationGroup
go
truncate table dbo.crmNotificationHeadline
go
truncate table dbo.crmNotificationMsgLog
go
truncate table dbo.crmNotificationRecipient
go

--crmNotificationChatType
--crmNotificationRecipientType
--crmNotificationTemplate
--crmNotificationTemplateContent
--crmNotificationType
--crmRecipient
--crmRecipientType