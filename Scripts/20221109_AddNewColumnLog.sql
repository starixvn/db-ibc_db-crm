/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20221109@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Update data [RedmineId : #179240]
*/

ALTER TABLE dbo.crmNotificationMsgLog
ALTER COLUMN ConversationId VARCHAR(2000)
GO

ALTER TABLE dbo.crmNotificationMsgLog
ALTER COLUMN NotificationId INT NULL
GO

ALTER TABLE dbo.crmNotificationMsgLog
ADD ReferenceId INT 
GO

ALTER TABLE dbo.crmNotificationMsgLog
ADD DataSource NVARCHAR(128)
GO

WHILE 1 = 1
BEGIN
	UPDATE TOP(2000) dbo.crmNotificationMsgLog
		SET DataSource = 'DBCRM.bodb_CRM.dbo.crmNotification', ReferenceId = CASE WHEN ReferenceId IS NULL THEN  NotificationId ELSE ReferenceId END
	WHERE DataSource IS NULL

	IF @@ROWCOUNT < 2000
	 RETURN
END

CREATE NONCLUSTERED INDEX IX_ReferenceId ON dbo.crmNotificationMsgLog (ReferenceId)
