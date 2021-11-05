/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20211115@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Update data [RedmineId : #164235]
*/
--Result amenment
UPDATE s
	SET s.Value = '0'
FROM SystemSetting s WITH(ROWLOCK)
WHERE ServiceName = 'ChatBot - ResultAmendment' AND SettingName ='IsSyncSettingsForUAT'

UPDATE s
	SET s.Value = '0'
FROM SystemSetting s WITH(ROWLOCK)
WHERE ServiceName = 'ChatBot - ResultAmendment' AND SettingName ='IncludeUUSCurrency'