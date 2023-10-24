/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
/*
	Created: 20210731@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Add LogTabe [RedmineId: #151509]
*/

CREATE TABLE dbo.crmFeedbackReference
(
	FeedbackId INT
	,ReferenceId BIGINT
	,DataSource NVARCHAR(200)
	,CreatedDate DATETIME DEFAULT GETDATE()
) ON [Data]
GO 

CREATE CLUSTERED INDEX CIX_crmFeedbackReference ON crmFeedbackReference (DataSource, FeedbackId)  
GO

CREATE NONCLUSTERED INDEX IX_CreatedDate ON crmFeedbackReference (CreatedDate)
GO

CREATE NONCLUSTERED INDEX IX_ReferenceId ON crmFeedbackReference (ReferenceId)
GO

