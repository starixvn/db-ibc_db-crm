/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20241111@Virgil
	DB: DBCRM/bodb_CRM
	Task: Insert data setting for Feedback [RedmineId : #210688]
*/
USE bodb_CRM
GO

DECLARE @ServiceName VARCHAR(100) = 'AutoFB - RebateRetention';
		
-- Starting LogSId
DECLARE @LastLogSId VARCHAR(MAX) = 
'<root>
	<r LastLogSID="0" SiteDBGroupId="3" ListPendingSIDs="" />
</root>';


INSERT INTO dbo.SystemSetting (SettingName, Value, ServiceName, DataType)
VALUES ('ServiceFlag', '1', @ServiceName, 'Boolean')
	,('LastLogSId', @LastLogSId, @ServiceName, 'XML')
	,('LastLogSIdUAT', @LastLogSId, @ServiceName, 'XML')
	,('IncludeUUSCurrency', '1', @ServiceName, 'Boolean')
	,('BatchSize', '1', @ServiceName, 'Int32')
	,('JobStatus', 'Completed', @ServiceName, 'String')
	,('JobStatusUAT', 'Completed', @ServiceName, 'String')
	,('LastRuntime', CONVERT(VARCHAR(50), GETDATE(), 120), @ServiceName, 'DateTime')
	,('LastRuntimeUAT', CONVERT(VARCHAR(50), GETDATE(), 120), @ServiceName, 'DateTime')




