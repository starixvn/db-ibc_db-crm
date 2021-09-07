/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20210909@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Update data [RedmineId : #151509]
*/

UPDATE s
	SET s.Value = '1'
FROM SystemSetting s WITH(ROWLOCK)
WHERE ServiceName = 'ChatBot - ProblemAccounts' AND SettingName ='IncludeUUSCurrency'

UPDATE s
	SET s.Value = '1'
FROM SystemSetting s WITH(ROWLOCK)
WHERE ServiceName = 'ChatBot - ProblemAccounts' AND SettingName ='IsSyncSettingsForUAT'

--Result amenment
UPDATE s
	SET s.Value = '1'
FROM SystemSetting s WITH(ROWLOCK)
WHERE ServiceName = 'ChatBot - ResultAmendment' AND SettingName ='IsSyncSettingsForUAT'

UPDATE s
	SET s.Value = '1'
FROM SystemSetting s WITH(ROWLOCK)
WHERE ServiceName = 'ChatBot - ResultAmendment' AND SettingName ='IncludeUUSCurrency'