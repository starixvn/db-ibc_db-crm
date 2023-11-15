/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/

/*
Created: 20231115@Ned.Le
DB: DBCRM.bodb_CRM
Task: Insert new value on table SystemSetting
*/

USE bodb_CRM
GO

DECLARE @MaxMsgTargetId INT
SELECT  @MaxMsgTargetId = MAX(MsgTargetId) FROM DBMSG.bodb_Message.dbo.MsgTarget WITH (NOLOCK)

INSERT INTO dbo.SystemSetting (SettingName, Value, ServiceName, DataType) VALUES
('BatchSize', '10', 'AutoFB - Void by BetID', 'Int32'),
('IncludeUUSCurrency', '1', 'AutoFB - Void by BetID', 'Boolean'),
('JobStatus', 'Completed', 'AutoFB - Void by BetID', 'String'),
('JobStatusUAT', 'Completed', 'AutoFB - Void by BetID', 'String'),
('LastMsgTargetId', CAST(@MaxMsgTargetId AS VARCHAR(50)), 'AutoFB - Void by BetID', 'Int32'),
('LastMsgTargetIdUAT', CAST(@MaxMsgTargetId AS VARCHAR(50)), 'AutoFB - Void by BetID', 'Int32'),
('LastRuntime', CONVERT(VARCHAR(20), GETDATE(), 120), 'AutoFB - Void by BetID', 'DateTime'),
('LastRuntimeUAT', CONVERT(VARCHAR(20), GETDATE(), 120), 'AutoFB - Void by BetID', 'DateTime'),
('ServiceFlag', '1', 'AutoFB - Void by BetID', 'Boolean')
GO