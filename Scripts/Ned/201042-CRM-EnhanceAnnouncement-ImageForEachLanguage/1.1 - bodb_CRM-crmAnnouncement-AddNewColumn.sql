/*<info serverAlias="DBCRM-bodb_CRM"></info>*/

/*
Created: 20240509@Ned.Le
DB: DBCRM.bodb_CRM
Task: Add new column UploadFileType to table crmAnnouncement
*/

USE bodb_CRM
GO

ALTER TABLE dbo.crmAnnouncement ADD UploadFileType VARCHAR(10)
GO

UPDATE a
SET a.UploadFileType = 'All'
FROM dbo.crmAnnouncement a WITH (UPDLOCK, TABLOCK)
GO