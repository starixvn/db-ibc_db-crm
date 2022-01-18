/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20220112@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Add system Settings For Job [RedmineId : #167358]
*/
USE bodb_CRM
GO
INSERT INTO dbo.SystemSetting (SettingName, Value, ServiceName)
VALUES 
	('LastRuntime', CONVERT(VARCHAR(20), GETDATE(), 120), 'ChatBot - AbnormalBets')
	,('LastRuntime', CONVERT(VARCHAR(20), GETDATE(), 120), 'ChatBot - CWL')
	,('LastRuntime', CONVERT(VARCHAR(20), GETDATE(), 120), 'ChatBot - ProblemAccounts')
	,('LastRuntime', CONVERT(VARCHAR(20), GETDATE(), 120), 'ChatBot - ResultAmendment')
	,('LastRuntime', CONVERT(VARCHAR(20), GETDATE(), 120), 'ChatBot - TOControl')
	,('LastRuntimeUAT', CONVERT(VARCHAR(20), GETDATE(), 120), 'ChatBot - AbnormalBets')
	,('LastRuntimeUAT', CONVERT(VARCHAR(20), GETDATE(), 120), 'ChatBot - CWL')
	,('LastRuntimeUAT', CONVERT(VARCHAR(20), GETDATE(), 120), 'ChatBot - ProblemAccounts')
	,('LastRuntimeUAT', CONVERT(VARCHAR(20), GETDATE(), 120), 'ChatBot - ResultAmendment')
	,('LastRuntimeUAT', CONVERT(VARCHAR(20), GETDATE(), 120), 'ChatBot - TOControl')