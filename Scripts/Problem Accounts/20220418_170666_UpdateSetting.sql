/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20220418@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Update data [RedmineId : #170666]
*/
UPDATE Systemsetting WITH(ROWLOCK)
	SET Value = '0'
WHERE ServiceName = 'ChatBot - ProblemAccounts' AND SettingName IN ('IncludeUUSCurrency', 'IsSyncSettingsForUAT')