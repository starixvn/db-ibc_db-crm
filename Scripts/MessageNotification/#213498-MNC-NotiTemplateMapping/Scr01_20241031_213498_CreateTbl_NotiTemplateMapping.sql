/*<info serverAlias="DBCRM-MessageNotification"></info>*/
/*
	Created: 20241031@Tacy
	Task: Create new table [NotiTemplateMapping] [Redmine: #213498]
	DB: DBCRM.MessageNotification
*/

USE MessageNotification
GO

/***** NotiTemplateMapping ****/
CREATE TABLE dbo.NotiTemplateMapping (
	ID SMALLINT IDENTITY(1,1) PRIMARY KEY
	,TemplateID SMALLINT NOT NULL
	,SportType SMALLINT NOT NULL
	,NotificationType TINYINT NOT NULL
	,ActionType TINYINT
	,MinAmended TINYINT
	,MaxAmended TINYINT
) ON [MNC] WITH (DATA_COMPRESSION = PAGE)
GO

CREATE NONCLUSTERED INDEX [IX_NotiTemplateMapping_SportType] ON dbo.NotiTemplateMapping (
	SportType ASC
	,NotificationType ASC
	,ActionType ASC
)
WITH (DATA_COMPRESSION = PAGE) ON [MNC]
GO