/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20201103@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Add system Settings For AbnormalBet[RedmineId : #144265]
*/
USE bodb_CRM
GO

INSERT INTO SystemSetting (SettingName, Value, ServiceName)
VALUES ('JobStatusUAT' ,'Completed' ,'ChatBot - AbnormalBets'),
	('IncludeUUSCurrency', '1', 'ChatBot - AbnormalBets')


