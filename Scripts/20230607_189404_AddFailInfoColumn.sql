/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20221109@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Update data [RedmineId : #179240]
*/

ALTER TABLE dbo.crmNotificationGroup 
ADD FailInfo XML DEFAULT NULL