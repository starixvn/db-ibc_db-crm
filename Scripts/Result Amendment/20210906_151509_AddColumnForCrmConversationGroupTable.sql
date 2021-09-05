/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/
/*
	Created: 20210906@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Insert data [RedmineId : #153119]
*/

ALTER TABLE crmConversationGroup
ADD TestingGroupType TINYINT CONSTRAINT DF_crmConversationGroup_TestingGroupType DEFAULT(2) 
GO

UPDATE crmConversationGroup WITH(ROWLOCK)
SET TestingGroupType = 2
GO
