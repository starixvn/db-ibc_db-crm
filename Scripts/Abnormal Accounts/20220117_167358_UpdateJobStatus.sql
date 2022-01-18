/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20220117@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Update IncludeUUSCurrency, job status [RedmineId : #167358]
*/
USE bodb_CRM
GO


-- ChatBot - CWL
UPDATE s
	SET s.Value = '0'
FROM SystemSetting s WITH(ROWLOCK)
WHERE s.ServiceName IN  ('ChatBot - CWL')  AND s.SettingName = 'IncludeUUSCurrency' 

UPDATE SystemSetting WITH(ROWLOCK)
 SET Value = 'running'
WHERE ServiceName IN  ('ChatBot - CWL') AND SettingName = 'JobStatusUAT'
 
UPDATE SystemSetting WITH(ROWLOCK)
 SET Value = '2022-01-18 00:00:00'
WHERE ServiceName IN  ('ChatBot - CWL') AND SettingName = 'LastRuntimeUAT'
-- ChatBot - ProblemAccounts
UPDATE s
	SET s.Value = '0'
FROM SystemSetting s WITH(ROWLOCK)
WHERE s.ServiceName IN  ('ChatBot - ProblemAccounts')  AND s.SettingName = 'IncludeUUSCurrency' 

UPDATE SystemSetting WITH(ROWLOCK)
 SET Value = 'running'
WHERE ServiceName IN  ('ChatBot - ProblemAccounts') AND SettingName = 'JobStatusUAT'
 
UPDATE SystemSetting WITH(ROWLOCK)
 SET Value = '2022-01-17 23:45:00'
WHERE ServiceName IN  ('ChatBot - ProblemAccounts') AND SettingName = 'LastRuntimeUAT'

UPDATE SystemSetting WITH(ROWLOCK)
 SET Value = '0'
WHERE ServiceName IN  ('ChatBot - ProblemAccounts') AND SettingName = 'IsSyncSettingsForUAT'

-- ChatBot - ResultAmendment
UPDATE s
	SET s.Value = '0'
FROM SystemSetting s WITH(ROWLOCK)
WHERE s.ServiceName IN  ('ChatBot - ResultAmendment')  AND s.SettingName = 'IncludeUUSCurrency' 

UPDATE SystemSetting WITH(ROWLOCK)
 SET Value = 'running'
WHERE ServiceName IN  ('ChatBot - ResultAmendment') AND SettingName = 'JobStatusUAT'
 
UPDATE SystemSetting WITH(ROWLOCK)
 SET Value = '2022-01-17 23:30:00'
WHERE ServiceName IN  ('ChatBot - ResultAmendment') AND SettingName = 'LastRuntimeUAT'

UPDATE SystemSetting WITH(ROWLOCK)
 SET Value = '0'
WHERE ServiceName IN  ('ChatBot - ResultAmendment') AND SettingName = 'IsSyncSettingsForUAT'

---ChatBot - TOControl
UPDATE s
	SET s.Value = '0'
FROM SystemSetting s WITH(ROWLOCK)
WHERE s.ServiceName IN  ('ChatBot - TOControl')  AND s.SettingName = 'IncludeUUSCurrency' 

UPDATE SystemSetting WITH(ROWLOCK)
 SET Value = 'running'
WHERE ServiceName IN  ('ChatBot - TOControl') AND SettingName = 'JobStatusUAT'
 
UPDATE SystemSetting WITH(ROWLOCK)
 SET Value = '2022-01-18 00:15:00'
WHERE ServiceName IN  ('ChatBot - TOControl') AND SettingName = 'LastRuntimeUAT'
