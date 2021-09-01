/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20210831@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Update data [RedmineId : #151509]
*/
UPDATE s
	SET s.Value = 'Completed'
FROM SystemSetting s WITH(ROWLOCK)
WHERE ServiceName = 'ChatBot - ResultAmendment' and SettingName = 'JobStatusUAT'