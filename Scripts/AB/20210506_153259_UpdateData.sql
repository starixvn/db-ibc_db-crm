/*<info serverAlias="DBCRM-bodbCRM"></info>*/
/*
	Created: 20210505@Malcolm
	DB: DBCRM-bodbCRM
	Task: update data [RedmineId : 153259]
*/
USE bodb_CRM
GO
UPDATE SystemSetting WITH(ROWLOCK)
	SET Value = '1'
WHERE ServiceName = 'ChatBot - AbnormalBets' AND SettingName = 'IncludeUUSCurrency'