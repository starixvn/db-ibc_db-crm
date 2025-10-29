/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20251021@Dave
	DB: DBCRM-bodb_CRM
	Task: CWL - Headline requests only trigger notifications under specific settings [RedmineId: #239736]
*/
USE bodb_CRM
GO


INSERT INTO dbo.SystemSetting(SettingName, Value, ServiceName, DataType)
SELECT SettingName + 'UAT', Value, ServiceName, DataType
FROM dbo.SystemSetting WITH (NOLOCK)
WHERE ServiceName = 'WinLimitFB'
	AND SettingName IN ('LastRuntime','LastLogID');


INSERT INTO dbo.SystemSetting(SettingName, Value, ServiceName, DataType)
SELECT SettingName + 'UAT', 'Completed', ServiceName, DataType
FROM dbo.SystemSetting WITH (NOLOCK)
WHERE ServiceName = 'WinLimitFB'
	AND SettingName = 'JobStatus';

SELECT SettingName, Value, ServiceName, DataType
FROM dbo.SystemSetting WITH (NOLOCK)
WHERE ServiceName = 'WinLimitFB'
	AND SettingName IN ('LastRuntimeUAT','LastLogIDUAT','JobStatusUAT');