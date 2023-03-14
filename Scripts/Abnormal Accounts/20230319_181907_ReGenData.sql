/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
/*
	Created: 20230317@Malcolm
	DB: DBCRM-bodb_CRM 
	Task: Regen data for MessageId [RedmineId: #181906]

*/

INSERT INTO dbo.crmNotificationRefDetail (NotificationId, ReferenceId, DataSource)
SELECT NotificationId, ReferenceId, 'DBMSG.bodb_Message.dbo.Msg'
FROM dbo.crmNotification
WHERE ReferenceId IS NOT NULL AND DataSource = 'MessageId'
