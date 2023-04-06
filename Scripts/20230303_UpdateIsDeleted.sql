/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20230303@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Update data [RedmineId : #179118]
*/

UPDATE crmConversationGroup WITH(ROWLOCK)
	SET isDeleted = 0 
WHERE isDeleted IS NULL AND ConversationGroupID in (1,2,3)