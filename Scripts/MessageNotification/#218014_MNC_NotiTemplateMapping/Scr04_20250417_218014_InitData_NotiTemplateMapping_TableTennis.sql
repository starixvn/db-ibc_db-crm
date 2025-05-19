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
/*Table Tennis*/
SELECT	1,				18,				1,					2,				1,				2
UNION SELECT	1,				18,				1,					3,				1,				2
UNION SELECT	2,				18,				1,					2,				3,				99
UNION SELECT	2,				18,				1,					3,				3,				99
UNION SELECT	3,				18,				1,					1,				1,				1
UNION SELECT	4,				18,				1,					1,				2,				99
UNION SELECT	6,				18,				2,					NULL,			NULL,			NULL

