/*<info serverAlias="DBCRM-MessageNotification"></info>*/
/*
	Created: 20250417@Dave
	Task: Init data - [NotiTemplateMapping] [Redmine: #227143]
	DB: DBCRM.MessageNotification
*/
USE [MessageNotification]
GO

CREATE TABLE dbo.NotiTemplateMapping_UAT (
	TemplateID SMALLINT NOT NULL
	,SportType SMALLINT NOT NULL
	,NotificationType TINYINT NOT NULL
	,ActionType TINYINT
	,MinAmended TINYINT
	,MaxAmended TINYINT
) ON [MNC] WITH (DATA_COMPRESSION = PAGE)
GO

