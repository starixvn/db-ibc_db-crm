/*<info serverAlias="DBCRM-bodbCRM"></info>*/
/*
	Created: 20210627@Malcolm
	DB: DBCRM-bodbCRM
	Task: update data [RedmineId : 157303]
*/
USE bodb_CRM
GO
ALTER TABLE crmMessageImport
ADD Usernames NVARCHAR(MAX) 


