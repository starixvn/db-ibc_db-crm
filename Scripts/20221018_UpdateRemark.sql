/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20221018@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Update Remark 
*/
USE bodb_CRM
GO

UPDATE crmConversationGroup WITH(ROWLOCK)
	SET Remark = 'Headline LJ''s Staff (Erick) resigned'
WHERE ConversationGroupName = 'Baymax' AND ConversationGroupId = 134


UPDATE crmConversationGroup WITH(ROWLOCK)
	SET Remark = 'Headline RG1 (Personal LT change to LT Group)'
WHERE ConversationGroupName = 'JUVENTUS FC' AND ConversationGroupId = 184


