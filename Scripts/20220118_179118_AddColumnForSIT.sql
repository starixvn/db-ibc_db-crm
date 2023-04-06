/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20220117@Malcolm
	DB: DBCRM-bodb_CRM
	Task: add New Column [RedmineId : #179118]
*/
USE bodb_CRM
GO

ALTER TABLE crmConversationGroup
ADD IsDeleted BIT
GO

ALTER TABLE crmConversationGroup
ADD CONSTRAINT DFF_crmConversationGroup_IsDeleted  DEFAULT (0) FOR IsDeleted
GO



