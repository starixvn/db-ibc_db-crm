/*<info serverAlias="DBCRM-bodb_CRM"></info>*/
/*
	Created: 20210218@Malcolm
	DB: DBCRM-bodb_CRM
	Task: CRM - ChatBot - delete groups which are wrong [RedmineId : #150274]
*/
DECLARE @TmpGroup TABLE (GroupId INT)

INSERT INTO @TmpGroup(GroupId)
SELECT ConversationGroupId
FROM dbo.crmConversationGroup WITH(NOLOCK)
WHERE ConversationGroupName IN 
(
	'Tiger~~Frank'
	,'Headline-266HK (Boss)'
	,'Headline-II (Anton Boss)'
	,'Headline-M25RM (Sam Boss)'
	,'Headline-PKK (Ah Chai Boss)'
	,'Headline-QQMA (Ah Boy staff)'
	,'Headline-Wina (Sir Willius)'
	,'nova88_agent, ben, 247_notific'
)

DELETE dbo.crmConversationGroup WITH(ROWLOCK, UPDLOCK) WHERE ConversationGroupId IN (SELECT GroupId FROM @TmpGroup)

DELETE dbo.crmConversationGroupBot WITH(ROWLOCK, UPDLOCK) WHERE ConversationGroupId IN (SELECT GroupId FROM @TmpGroup)

DELETE dbo.crmConversationGroupRecipient WITH(ROWLOCK, UPDLOCK) WHERE ConversationGroupId IN (SELECT GroupId FROM @TmpGroup)

DELETE dbo.crmConversationGroupHeadline WITH(ROWLOCK, UPDLOCK) WHERE ConversationGroupId IN (SELECT GroupId FROM @TmpGroup)

DELETE dbo.crmNotificationGroup WITH(ROWLOCK, UPDLOCK) WHERE ConversationGroupId IN (SELECT GroupId FROM @TmpGroup)
