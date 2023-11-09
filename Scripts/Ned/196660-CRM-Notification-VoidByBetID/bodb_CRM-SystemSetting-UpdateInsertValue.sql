/*<info serverAlias="DBCRM-bodb_CRM"></info>*/

/*
Created: 20231109@Ned.Le
DB: DBCRM.bodb_CRM
Task: Insert new value on table SystemSetting
*/

USE bodb_CRM
GO

INSERT INTO dbo.SystemSetting (SettingName, Value, ServiceName, DataType) VALUES
('LastMsgTargetId', '0', 'ChatBot - AbnormalBets', 'Int32'),
('LastMsgTargetIdUAT', '0', 'ChatBot - AbnormalBets', 'Int32')
GO