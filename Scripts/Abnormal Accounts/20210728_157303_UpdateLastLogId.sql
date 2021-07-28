/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20210728@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Update LastLogIdUAT [RedmineId : #157303]
*/

UPDATE SystemSetting WITH(ROWLOCK)
	SET Value = '71296'
WHERE ServiceName = 'ChatBot - CWL' AND SettingName = 'LastLogIdUAT'

UPDATE SystemSetting
	SET Value = '3761'
WHERE ServiceName = 'ChatBot - TOControl' AND SettingName = 'LastLogIdUAT'