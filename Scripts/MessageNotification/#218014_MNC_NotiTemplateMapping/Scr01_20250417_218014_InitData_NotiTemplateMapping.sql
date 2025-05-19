/*<info serverAlias="DBCRM-MessageNotification"></info>*/
/*
	Created: 20250417@Dave
	Task: Init data - [NotiTemplateMapping] [Redmine: #218014]
	DB: DBCRM.MessageNotification
*/

USE MessageNotification
GO
/*NotiTemplateMapping*/
INSERT INTO NotiTemplateMapping 
		(		[TemplateID],	[SportType],	[NotificationType],	[ActionType],	[MinAmended],	[MaxAmended])
/*Badminton*/
SELECT	1,				9,				1,					2,				1,				2
UNION SELECT	1,				9,				1,					3,				1,				2
UNION SELECT	2,				9,				1,					2,				3,				99
UNION SELECT	2,				9,				1,					3,				3,				99
UNION SELECT	3,				9,				1,					1,				1,				1
UNION SELECT	4,				9,				1,					1,				2,				99
UNION SELECT	6,				9,				2,					NULL,			NULL,			NULL
/*Beach Volleyball*/
UNION SELECT	1,				45,				1,					2,				1,				2
UNION SELECT	1,				45,				1,					3,				1,				2
UNION SELECT	2,				45,				1,					2,				3,				99
UNION SELECT	2,				45,				1,					3,				3,				99
UNION SELECT	3,				45,				1,					1,				1,				1
UNION SELECT	4,				45,				1,					1,				2,				99
UNION SELECT	6,				45,				2,					NULL,			NULL,			NULL

