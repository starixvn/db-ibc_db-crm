/*<info serverAlias="DBCRM-bodb_CRM"></info>*/

/*
Created: 20231109@Ned.Le
DB: DBCRM.bodb_CRM
Task: Insert new value on table SystemSetting
*/

USE bodb_CRM
GO

DECLARE @MaxMsgTargetId INT
SELECT  @MaxMsgTargetId = MAX(MsgTargetId) FROM DBMSG.bodb_Message.dbo.MsgTarget WITH (NOLOCK)

INSERT INTO dbo.SystemSetting (SettingName, Value, ServiceName, DataType) VALUES
('LastMsgTargetId', CAST(@MaxMsgTargetId AS VARCHAR(50)), 'ChatBot - AbnormalBets', 'Int32'),
('LastMsgTargetIdUAT', CAST(@MaxMsgTargetId AS VARCHAR(50)), 'ChatBot - AbnormalBets', 'Int32')
GO