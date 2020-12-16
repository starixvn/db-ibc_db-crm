/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20201216@Malcolm
	DB: DBCRM-bodb_CRM
	Task: DROP COLUMN MESSAGEID[RedmineId : #144265]
*/
USE bodb_CRM
GO

ALTER TABLE crmNotification
DROP COLUMN MessageId