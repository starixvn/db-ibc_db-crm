/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/
/*
	Created: 20210906@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Insert data [RedmineId : #153119]
*/

ALTER TABLE crmConversationGroup
ADD IsTest BIT CONSTRAINT DF_crmConversationGroup_IsTest DEFAULT(NULL) 
GO

UPDATE crmConversationGroup WITH(ROWLOCK)
	SET IsTest = 1
WHERE ConversationGroupId IN
(
	SELECT cgr.ConversationGroupId
	FROM dbo.crmConversationGroupRecipient cgr WITH(NOLOCK)
		INNER JOIN dbo.crmRecipient r WITH(NOLOCK) ON r.RecipientId = cgr.RecipientId
		INNER JOIN dbo.crmRecipientType rt WITH(NOLOCK) ON rt.RecipientTypeId = r.RecipientTypeId
	WHERE rt.RecipientTypeName = 'Accounting PIC'
)
GO


