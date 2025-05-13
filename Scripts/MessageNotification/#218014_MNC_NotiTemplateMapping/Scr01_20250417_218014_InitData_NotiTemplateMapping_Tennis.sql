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
/*Tennis*/
SELECT			1,				5,				1,					2,				1,				2
UNION SELECT	1,				5,				1,					3,				1,				2
UNION SELECT	2,				5,				1,					2,				3,				99
UNION SELECT	2,				5,				1,					3,				3,				99
UNION SELECT	3,				5,				1,					1,				1,				1
UNION SELECT	4,				5,				1,					1,				2,				99
UNION SELECT	6,				5,				2,					NULL,			NULL,			NULL