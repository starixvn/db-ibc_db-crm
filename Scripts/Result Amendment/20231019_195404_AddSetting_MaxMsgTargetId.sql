/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20231019@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Update data [RedmineId : #195404]
*/
--Result amenment

INSERT INTO SystemSetting (SettingName, Value, ServiceName, DataType)
VALUES ('MaxMsgTargetId', '0', 'ChatBot - ResultAmendment', 'Int32')
,('MaxMsgTargetIdUAT', '0', 'ChatBot - ResultAmendment', 'Int32')
