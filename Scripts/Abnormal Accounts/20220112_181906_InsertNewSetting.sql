/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
/*
	Created: 20210701@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Insert setting for ChatBot - AbnormalBets

*/
INSERT INTO dbo.SystemSetting (SettingName, Value, ServiceName, DataType)
VALUES ('LastVoidingHistoryCollectionId', '0', 'ChatBot - AbnormalBets', 'Int32')
	   ,('LastVoidingHistoryCollectionIdUAT', '0', 'ChatBot - AbnormalBets', 'Int32')