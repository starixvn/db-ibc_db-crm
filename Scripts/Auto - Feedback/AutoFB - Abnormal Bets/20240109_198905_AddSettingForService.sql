/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
/*
	Created: 20210731@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Add Setting for service : AutoFB - AbnormalBets [RedmineId: #198905]
*/

INSERT INTO SystemSetting (SettingName, Value, ServiceName, DataType)
VALUES 
('BatchSize', '10', 'AutoFB - AbnormalBets', 'Int32')
,('IncludeUUSCurrency', '1', 'AutoFB - AbnormalBets', 'Boolean')
,('JobStatus', 'Completed', 'AutoFB - AbnormalBets', 'String')
,('JobStatusUAT', 'Completed', 'AutoFB - AbnormalBets', 'String')
,('LastVoidingHistoryCollectionId', '0', 'AutoFB - AbnormalBets', 'Int32')
,('LastVoidingHistoryCollectionIdUAT', '0', 'AutoFB - AbnormalBets', 'Int32')
,('LastRuntime', CONVERT(VARCHAR(20), GETDATE(), 120), 'AutoFB - AbnormalBets', 'DateTime')
,('LastRuntimeUAT', CONVERT(VARCHAR(20), GETDATE(), 120), 'AutoFB - AbnormalBets', 'DateTime')
,('ServiceFlag', '1', 'AutoFB - AbnormalBets', 'Boolean')

