/*<info serverAlias="DBCRM-bodbCRM"></info>*/
/*
	Created: 20200713@Percy
	DB: DBCRM-bodbCRM
	Task: Clean test data of PIC
	All new tables:
		1. crmPIC
		2. crmPICCommunication
		3. crmPICManagement
		4. crmPICHeadline
		5. crmUserLog_RunSP
*/
USE bodb_CRM
GO

TRUNCATE TABLE dbo.crmPIC
GO

TRUNCATE TABLE dbo.crmPICCommunication
GO

TRUNCATE TABLE dbo.crmPICManagement
GO

TRUNCATE TABLE dbo.crmPICHeadline
GO

TRUNCATE TABLE dbo.crmUserLog_RunSP
GO