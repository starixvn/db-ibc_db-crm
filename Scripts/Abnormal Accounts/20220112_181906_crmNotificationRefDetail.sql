/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
/*
	Created: 20230317@Malcolm
	DB: DBCRM-bodb_CRM 
	Task: Add new table [RedmineId: #181906]

*/

CREATE TABLE dbo.crmNotificationRefDetail
(
	NotificationId INT NOT NULL
	,ReferenceId BIGINT NOT NULL
	,DataSource NVARCHAR(256)
	,CreatedDate DATETIME DEFAULT GETDATE()
) ON [DATA]
GO

CREATE CLUSTERED INDEX CIX_NotificationId ON dbo.crmNotificationRefDetail (NotificationId)
GO

CREATE NONCLUSTERED INDEX IX_ReferenceId_DataSource ON dbo.crmNotificationRefDetail (ReferenceId, DataSource)
GO