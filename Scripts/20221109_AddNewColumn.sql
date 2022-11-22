/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20221109@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Update data [RedmineId : #179240]
*/

ALTER TABLE dbo.crmNotificationReference
ADD CreatedDate DATETIME NULL
GO

ALTER TABLE crmNotificationReference
ADD CONSTRAINT [DF_crmNotificationReference_CreatedDate]  DEFAULT (GETDATE()) FOR [CreatedDate]
GO

CREATE NONCLUSTERED INDEX [IX_NotificationId] ON dbo.crmNotificationReference(NotificationId)
GO

WHILE 1 = 1
BEGIN
	UPDATE TOP(2000) dbo.crmNotificationReference WITH(ROWLOCK, UPDLOCK)
		SET CreatedDate = GETDATE()
	WHERE CreatedDate IS NULL

	IF @@ROWCOUNT = 0
		BREAK
	
END

CREATE NONCLUSTERED INDEX [IX_CreatedDate] ON dbo.crmNotificationReference(CreatedDate)
GO
