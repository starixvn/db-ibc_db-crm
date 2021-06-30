/*<info serverAlias="DBCRM-bodb_CRM"></info>*/
/*
	Created: 20210629@Malcolm
	DB: DBCRM.bodb_CRM
	Task: Add new column [RedmineId : #157303]
*/

ALTER TABLE crmMessageImport
ADD UsernameList NVARCHAR(MAX)

ALTER TABLE crmMessageImport
ADD CustIdList VARCHAR(MAX)

