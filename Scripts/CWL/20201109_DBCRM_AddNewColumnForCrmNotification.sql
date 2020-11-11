/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20201109@Malcolm
	DB: DBCRM-bodb_CRM
	Task: All new colums into crmNotification table
*/
USE bodb_CRM
GO

ALTER TABLE dbo.crmNotification 
ADD ReferenceId BIGINT, DataSource NVARCHAR(128)

CREATE NONCLUSTERED INDEX [IX_ReferenceId] ON [dbo].[crmNotification]
(
	[ReferenceId] ASC,
	[NotificationId] ASC
) ON [DataChatBot]
GO



