/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20220117@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Update IncludeUUSCurrency [RedmineId : #167358]
*/
USE bodb_CRM
GO

-- ChatBot - CWL
UPDATE s
	SET s.Value = '1'
FROM SystemSetting s WITH(ROWLOCK)
WHERE s.ServiceName IN  ('ChatBot - CWL')  AND s.SettingName = 'IncludeUUSCurrency' 

-- ChatBot - ProblemAccounts
UPDATE s
	SET s.Value = '1'
FROM SystemSetting s WITH(ROWLOCK)
WHERE s.ServiceName IN  ('ChatBot - ProblemAccounts')  AND s.SettingName = 'IncludeUUSCurrency' 

UPDATE SystemSetting WITH(ROWLOCK)
 SET Value = '1'
WHERE ServiceName IN  ('ChatBot - ProblemAccounts') AND SettingName = 'IsSyncSettingsForUAT'

-- ChatBot - ResultAmendment
UPDATE s
	SET s.Value = '1'
FROM SystemSetting s WITH(ROWLOCK)
WHERE s.ServiceName IN  ('ChatBot - ResultAmendment')  AND s.SettingName = 'IncludeUUSCurrency' 

UPDATE SystemSetting WITH(ROWLOCK)
 SET Value = '1'
WHERE ServiceName IN  ('ChatBot - ResultAmendment') AND SettingName = 'IsSyncSettingsForUAT'

---ChatBot - TOControl
UPDATE s
	SET s.Value = '1'
FROM SystemSetting s WITH(ROWLOCK)
WHERE s.ServiceName IN  ('ChatBot - TOControl')  AND s.SettingName = 'IncludeUUSCurrency' 

--Abnormal Bet
UPDATE s
	SET s.Value = 1
FROM SystemSetting s WITH(ROWLOCK)
WHERE s.ServiceName IN  ('ChatBot - AbnormalBets')  AND s.SettingName = 'IncludeUUSCurrency' 


