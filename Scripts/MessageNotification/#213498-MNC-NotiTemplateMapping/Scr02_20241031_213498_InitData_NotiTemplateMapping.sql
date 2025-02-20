/*<info serverAlias="DBCRM-MessageNotification"></info>*/
/*
	Created: 20241031@Tacy
	Task: Init data - new table [NotiTemplateMapping] [Redmine: #213498]
	DB: DBCRM.MessageNotification
*/

USE MessageNotification
GO

-- NotiTemplateMapping
INSERT INTO NotiTemplateMapping 
	([TemplateID], [SportType], [NotificationType], [ActionType], [MinAmended], [MaxAmended])
-- Cricket
	  SELECT 1,		50,		1,		2,		1,		2
UNION SELECT 1,		50,		1,		3,		1,		2
UNION SELECT 2,		50,		1,		2,		3,		99
UNION SELECT 2,		50,		1,		3,		3,		99
UNION SELECT 3,		50,		1,		1,		1,		1
UNION SELECT 4,		50,		1,		1,		2,		99
UNION SELECT 6,		50,		2,		NULL,		NULL,		NULL
-- Basketball
UNION SELECT 1,		2,		1,		2,		1,		2
UNION SELECT 1,		2,		1,		3,		1,		2
UNION SELECT 2,		2,		1,		2,		3,		99
UNION SELECT 2,		2,		1,		3,		3,		99
UNION SELECT 3,		2,		1,		1,		1,		1
UNION SELECT 4,		2,		1,		1,		2,		99
UNION SELECT 6,		2,		2,		NULL,		NULL,		NULL
-- E-Sports
UNION SELECT 1,		43,		1,		2,		1,		2
UNION SELECT 1,		43,		1,		3,		1,		2
UNION SELECT 2,		43,		1,		2,		3,		99
UNION SELECT 2,		43,		1,		3,		3,		99
UNION SELECT 3,		43,		1,		1,		1,		1
UNION SELECT 4,		43,		1,		1,		2,		99
UNION SELECT 6,		43,		2,		NULL,		NULL,		NULL
GO