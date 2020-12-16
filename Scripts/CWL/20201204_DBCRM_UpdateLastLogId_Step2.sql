/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20201204@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Update Last logid [RedmineId : #144265]
*/
USE bodb_CRM
GO

DECLARE @LastLogID BIGINT

SELECT @LastLogID = LastLogId FROM OPENQUERY (DBCUST, 'SELECT Max(logid) AS LastLogId FROM CustDB.dbo.WinLimit_CustGameMonitoring_History') 

UPDATE s WITH(ROWLOCK)
	SET Value = CONVERT(VARCHAR(50), @LastLogID)
FROM SystemSetting s
WHERE (SettingName = 'LastLogID' AND ServiceName = 'ChatBot - CWL')
	OR (SettingName = 'LastLogIdUAT' AND ServiceName = 'ChatBot - CWL')

