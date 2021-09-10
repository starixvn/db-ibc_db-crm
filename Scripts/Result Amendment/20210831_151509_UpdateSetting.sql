/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20210831@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Update data [RedmineId : #151509]
*/
UPDATE s
	SET s.Value = '55513'
FROM SystemSetting s WITH(ROWLOCK)
WHERE ServiceName = 'ChatBot - ProblemAccounts' AND SettingName ='LastLogIdUAT'

UPDATE s
	SET s.Value = '0'
FROM SystemSetting s WITH(ROWLOCK)
WHERE ServiceName = 'ChatBot - ProblemAccounts' AND SettingName ='IncludeUUSCurrency'

UPDATE s
	SET s.Value = '1'
FROM SystemSetting s WITH(ROWLOCK)
WHERE ServiceName = 'ChatBot - ProblemAccounts' AND SettingName ='IsSyncSettingsForUAT'

--Result amenment
UPDATE s
	SET s.Value = CONVERT(VARCHAR(20), GETDATE(), 120)
FROM SystemSetting s WITH(ROWLOCK)
WHERE ServiceName = 'ChatBot - ResultAmendment' AND SettingName ='SubmitDateUAT'

UPDATE s
	SET s.Value = '0'
FROM SystemSetting s WITH(ROWLOCK)
WHERE ServiceName = 'ChatBot - ResultAmendment' AND SettingName ='SeqUAT'

UPDATE s
	SET s.Value = '1'
FROM SystemSetting s WITH(ROWLOCK)
WHERE ServiceName = 'ChatBot - ResultAmendment' AND SettingName ='IsSyncSettingsForUAT'

UPDATE s
	SET s.Value = '0'
FROM SystemSetting s WITH(ROWLOCK)
WHERE ServiceName = 'ChatBot - ResultAmendment' AND SettingName ='IncludeUUSCurrency'

