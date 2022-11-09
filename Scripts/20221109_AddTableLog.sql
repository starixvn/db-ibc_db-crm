/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20221109@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Update data [RedmineId : #179240]
*/

CREATE TABLE [dbo].[crmChatBot_UserLog_RunSP](
	LogId				BIGINT IDENTITY(1,1) ,
	UserId				INT NULL,
	SPName				VARCHAR(50) NULL,
	LogDate				DATETIME NULL,
	CustId				INT NULL,
	ActionId			INT NULL,
	TrackingNewValues	NVARCHAR(MAX) NULL,
	Duration			INT NULL,
	Doing				NVARCHAR(MAX) NULL,
	TrackingOldValues	NVARCHAR(MAX) NULL,
	CONSTRAINT [PK_crmChatBot_UserLog_RunSP] PRIMARY KEY NONCLUSTERED 
	(
		LogId
	)
)
GO

CREATE CLUSTERED INDEX CIX_LogDate_ActionId ON [crmChatBot_UserLog_RunSP] (LogDate, ActionId)
GO

ALTER TABLE [dbo].[crmChatBot_UserLog_RunSP] ADD  CONSTRAINT [DF_crmChatBot_UserLog_RunSP]  DEFAULT (GETDATE()) FOR LogDate
GO

ALTER TABLE dbo.crmNotificationReference
ADD CreatedDate DATETIME DEFAULT(GETDATE()) WITH VALUES 
GO

CREATE NONCLUSTERED INDEX [IX_CreatedDate] ON dbo.crmNotificationReference(CreatedDate)
GO

CREATE NONCLUSTERED INDEX [IX_NotificationId] ON dbo.crmNotificationReference(NotificationId)
GO