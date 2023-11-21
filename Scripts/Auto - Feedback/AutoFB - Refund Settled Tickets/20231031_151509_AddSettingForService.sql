/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
/*
	Created: 20210731@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Add Setting for service : AutoFB - Refund Settled tickets [RedmineId: #151509]
*/

INSERT INTO SystemSetting (SettingName, Value, ServiceName, DataType)
VALUES 
('BatchSize', '10', 'AutoFB - Refund Settled tickets', 'Int32')
,('IncludeUUSCurrency', '1', 'AutoFB - Refund Settled tickets', 'Boolean')
,('JobStatus', 'Completed', 'AutoFB - Refund Settled tickets', 'String')
,('JobStatusUAT', 'Completed', 'AutoFB - Refund Settled tickets', 'String')
,('LastMsgTargetId', '0', 'AutoFB - Refund Settled tickets', 'Int32')
,('LastMsgTargetIdUAT', '0', 'AutoFB - Refund Settled tickets', 'Int32')
,('LastRuntime', CONVERT(VARCHAR(20), GETDATE(), 120), 'AutoFB - Refund Settled tickets', 'DateTime')
,('LastRuntimeUAT', CONVERT(VARCHAR(20), GETDATE(), 120), 'AutoFB - Refund Settled tickets', 'DateTime')
,('ServiceFlag', '1', 'AutoFB - Refund Settled tickets', 'Boolean')

