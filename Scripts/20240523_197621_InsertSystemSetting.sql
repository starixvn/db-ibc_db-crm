/*<info serverAlias="DBCRM-bodb_CRM" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
/*
	Created: 20240523@Luke
	DB: DBCRM-bodb_CRM
	Task: Add Setting for service : AutoFB - MessageNotificationCenter [Redmine: #197621]
*/
USE bodb_CRM
GO

INSERT INTO dbo.SystemSetting (SettingName, Value, ServiceName, DataType)
VALUES 
('BatchSize', '10', 'AutoFB - MessageNotificationCenter', 'Int32')
,('IncludeUUSCurrency', '1', 'AutoFB - MessageNotificationCenter', 'Boolean')
,('JobStatus', 'Completed', 'AutoFB - MessageNotificationCenter', 'String')
,('JobStatusUAT', 'Completed', 'AutoFB - MessageNotificationCenter', 'String')
,('LastMsgTargetId', '0', 'AutoFB - MessageNotificationCenter', 'Int32')
,('LastMsgTargetIdUAT', '0', 'AutoFB - MessageNotificationCenter', 'Int32')
,('LastRuntime', CONVERT(VARCHAR(20), GETDATE(), 120), 'AutoFB - MessageNotificationCenter', 'DateTime')
,('LastRuntimeUAT', CONVERT(VARCHAR(20), GETDATE(), 120), 'AutoFB - MessageNotificationCenter', 'DateTime')
,('ServiceFlag', '1', 'AutoFB - MessageNotificationCenter', 'Boolean')