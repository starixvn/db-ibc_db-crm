/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20220117@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Update IncludeUUSCurrency, job status [RedmineId : #167358]
*/
USE bodb_CRM
GO

UPDATE s
	SET s.Value = '0'
FROM SystemSetting s WITH(ROWLOCK)
WHERE s.ServiceName IN  ('ChatBot - AbnormalBets')  AND s.SettingName = 'IncludeUUSCurrency' 

UPDATE SystemSetting WITH(ROWLOCK)
 SET Value = 'running'
WHERE ServiceName IN  ('ChatBot - AbnormalBets') AND SettingName = 'JobStatusUAT'
 