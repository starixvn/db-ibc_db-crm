/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20201103@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Add system Settings [RedmineId : #144265]
*/
USE bodb_CRM
GO

INSERT INTO SystemSetting (SettingName, Value, ServiceName)
VALUES ('JobStatusUAT' ,'Completed' ,'ChatBot - CWL'),
	('JobStatusPRO' ,'Completed' ,'ChatBot - CWL'),
	('LastLogIdUAT' ,'0' ,'ChatBot - CWL'),
	('LastLogIdPRO' ,'0' ,'ChatBot - CWL'),
	('JobStatusUAT' ,'Completed' ,'ChatBot - AbnormalBets'),
	('JobStatusPRO' ,'Completed' ,'ChatBot - AbnormalBets'),
	('LastLogIdUAT' ,'0' ,'ChatBot - AbnormalBets'),
	('LastLogIdPRO' ,'0' , 'ChatBot - AbnormalBets')


