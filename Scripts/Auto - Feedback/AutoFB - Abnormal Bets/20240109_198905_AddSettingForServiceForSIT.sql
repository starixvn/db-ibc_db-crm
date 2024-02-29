/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
/*
	Created: 20210731@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Update Setting for service SIT: AutoFB - AbnormalBets [RedmineId: #198905]
*/

UPDATE SystemSetting
SET Value = '403'
WHERE ServiceName = 'AutoFB - AbnormalBets' 
	AND SettingName IN ('LastVoidingHistoryCollectionId', 'LastVoidingHistoryCollectionIdUAT')
