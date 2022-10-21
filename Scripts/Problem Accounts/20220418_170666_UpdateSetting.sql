/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20221021@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Update data [RedmineId : #153119]
*/
UPDATE Systemsetting WITH(ROWLOCK)
	SET Value = '1'
WHERE ServiceName = 'ChatBot - ProblemAccounts' AND SettingName IN ('IncludeUUSCurrency', 'IsSyncSettingsForUAT')