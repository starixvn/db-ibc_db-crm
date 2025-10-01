/*<info serverAlias="DBCRM-MessageNotification"></info>*/
/*
	Created: 20250417@Dave
	Task: Init data - [NotiTemplateMapping] [Redmine: #227143]
	DB: DBCRM.MessageNotification
*/
USE [MessageNotification]
GO

DELETE FROM NotiTemplateMapping_UAT WHERE SportType = 1;
DELETE FROM NotiTemplateMapping WHERE SportType = 1;


/*NotiTemplateMapping*/
INSERT INTO NotiTemplateMapping ([TemplateID], [SportType], [NotificationType], [ActionType], [MinAmended], [MaxAmended])
VALUES(11, 1, 1, 5, 1, 99);

INSERT INTO NotiTemplateMapping ([TemplateID], [SportType], [NotificationType], [ActionType], [MinAmended], [MaxAmended])
VALUES(6, 1, 2, NULL, NULL, NULL);


SELECT * FROM NotiTemplateMapping WHERE SportType = 1;