/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20210628@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Update Last logid [RedmineId : #157563]
*/
USE bodb_CRM
GO

UPDATE s
	SET s.Value = 1
FROM SystemSetting s WITH(ROWLOCK)
WHERE s.ServiceName = 'ChatBot - CWL'  AND s.SettingName = 'IncludeUUSCurrency' AND s.ID = 28
