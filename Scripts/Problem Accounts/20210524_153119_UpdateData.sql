/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20210524@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Update data [RedmineId : #153119]
*/
UPDATE s
	SET s.Value = '4850'
FROM SystemSetting s WITH(ROWLOCK)
WHERE ServiceName = 'ChatBot - ProblemAccounts' AND SettingName ='LastLogID'