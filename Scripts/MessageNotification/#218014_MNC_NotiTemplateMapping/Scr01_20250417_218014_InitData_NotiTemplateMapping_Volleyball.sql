/*<info serverAlias="DBCRM-MessageNotification"></info>*/
/*
	Created: 20250417@Dave
	Task: Init data - [NotiTemplateMapping] [Redmine: #227143]
	DB: DBCRM.MessageNotification
*/

USE MessageNotification
GO
/*NotiTemplateMapping*/
INSERT INTO NotiTemplateMapping 
		(		[TemplateID],	[SportType],	[NotificationType],	[ActionType],	[MinAmended],	[MaxAmended])
/*Volleyball*/
SELECT	1,				6,				1,					2,				1,				2
UNION SELECT	1,				6,				1,					3,				1,				2
UNION SELECT	2,				6,				1,					2,				3,				99
UNION SELECT	2,				6,				1,					3,				3,				99
UNION SELECT	3,				6,				1,					1,				1,				1
UNION SELECT	4,				6,				1,					1,				2,				99
UNION SELECT	6,				6,				2,					NULL,			NULL,			NULL

