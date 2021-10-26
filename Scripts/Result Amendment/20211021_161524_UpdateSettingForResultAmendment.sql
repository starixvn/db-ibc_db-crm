/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20211021@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Update data [RedmineId : #161524]
*/
--Result amenment
UPDATE s
	SET s.Value = '1'
FROM SystemSetting s WITH(ROWLOCK)
WHERE ServiceName = 'ChatBot - ResultAmendment' AND SettingName ='IsSyncSettingsForUAT'

UPDATE s
	SET s.Value = '1'
FROM SystemSetting s WITH(ROWLOCK)
WHERE ServiceName = 'ChatBot - ResultAmendment' AND SettingName ='IncludeUUSCurrency'