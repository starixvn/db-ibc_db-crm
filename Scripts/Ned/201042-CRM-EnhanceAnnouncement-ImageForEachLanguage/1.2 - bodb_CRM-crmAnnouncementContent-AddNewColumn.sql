/*<info serverAlias="DBCRM-bodb_CRM"></info>*/

/*
Created: 20240325@Ned.Le
DB: DBCRM.bodb_CRM
Task: Add new column FileName to table crmAnnouncementContent
*/

USE bodb_CRM
GO

ALTER TABLE dbo.crmAnnouncementContent ADD FileName NVARCHAR(2000)
GO