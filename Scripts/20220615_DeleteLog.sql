/*<info serverAlias="DBCRM-bodb_CRM"></info>*/
/*
	Created: 20210428@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Clear log
*/

TRUNCATE TABLE dbo.crmNotificationReference
GO

ALTER TABLE dbo.crmNotificationReference
DROP CONSTRAINT PK_crmNotificationReference
GO

ALTER TABLE dbo.crmNotificationReference
ADD CreatedDate DATETIME DEFAULT GETDATE()

ALTER TABLE dbo.crmNotificationReference 
ADD CONSTRAINT PK_crmNotificationReference PRIMARY KEY NONCLUSTERED 
(
	NotificationId ASC
) ON [DATA]
GO

CREATE CLUSTERED INDEX CIX_CreatedDate ON dbo.crmNotificationReference (CreatedDate)
GO