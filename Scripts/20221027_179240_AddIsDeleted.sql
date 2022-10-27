/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20221027@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Update Remark [RedmineId : #179240]
*/
USE bodb_CRM
GO

ALTER TABLE crmConversationGroup
ADD IsDeleted BIT CONSTRAINT DFF_crmConversationGroup_IsDeleted DEFAULT(0) WITH VALUES

