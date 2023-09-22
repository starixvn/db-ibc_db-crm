/*<info serverAlias="DBCRM-bodb_CRM"></info>*/

/*
Created: 20230922@Ned.Le
DB: DBCRM.bodb_CRM
Task: Add new column Remark to table crmSettingRelation
*/

USE bodb_CRM
GO

ALTER TABLE dbo.crmSettingRelation ADD Remark NVARCHAR(MAX)
GO