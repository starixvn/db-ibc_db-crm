/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20210728@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Update IncludeUUSCurrency [RedmineId : #157303]
*/
USE bodb_CRM
GO

UPDATE s
	SET s.Value = 0
FROM SystemSetting s WITH(ROWLOCK)
WHERE s.ServiceName IN  ('ChatBot - CWL', 'ChatBot - TOControl', 'ChatBot - AbnormalBets')  AND s.SettingName = 'IncludeUUSCurrency' 

