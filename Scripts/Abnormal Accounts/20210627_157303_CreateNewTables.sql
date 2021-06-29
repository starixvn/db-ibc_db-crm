/*<info serverAlias="DBCRM-bodb_CRM"></info>*/
/*
	Created: 20210629@Malcolm
	DB: DBCRM.bodb_CRM
	Task: Create new tables [RedmineId : #157303]
*/

ALTER TABLE crmMessageImport
ADD UsernameList NVARCHAR(MAX)

ALTER TABLE crmMessageImport
ADD CustIdList VARCHAR(MAX)

