/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20211125@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Update IncludeUUSCurrency [RedmineId : #163833]
*/
USE bodb_CRM
GO

UPDATE s
	SET s.Value = 0
FROM SystemSetting s WITH(ROWLOCK)
WHERE s.ServiceName IN  ('ChatBot - AbnormalBets')  AND s.SettingName = 'IncludeUUSCurrency' 

