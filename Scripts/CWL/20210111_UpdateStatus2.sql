/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20210111@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Update Last logid- Phase 2 [RedmineId : #157563]
*/
USE bodb_CRM
GO
UPDATE SystemSetting with(rowlock)
	set Value = 'Completed'
where ServiceName in ('ChatBot - AbnormalBets', 'ChatBot - TOControl', 'ChatBot - ResultAmendment', 'ChatBot - ProblemAccounts')
AND SettingName = 'JobStatus'