/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20210428@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Create new tale to contain LogIds [RedmineId : #153119]
*/

CREATE TABLE dbo.crmNotificationReference 
(
	NotificationId INT,
	ReferenceId	   BIGINT,
	DataSource	   NVARCHAR(256),
	CONSTRAINT PK_crmNotificationReference PRIMARY KEY (DataSource, NotificationId, ReferenceId)
) ON [DATA]

CREATE INDEX ix_CRM_NotificationReference ON dbo.crmNotificationReference (DataSource, NotificationId, ReferenceId) ON [DATA]

