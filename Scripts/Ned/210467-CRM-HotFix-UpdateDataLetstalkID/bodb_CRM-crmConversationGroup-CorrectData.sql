/*<info serverAlias="DBCRM-bodb_CRM"></info>*/

/*
Created: 20240909@Ned.Le
DB: DBCRM.bodb_CRM
Task: Correct data for column ConverstationId in table crmConversationGroup
*/


USE bodb_CRM
GO

UPDATE a
SET a.ConversationId = TRIM(ConversationId)
FROM dbo.crmConversationGroup a WITH (UPDLOCK, TABLOCK)
WHERE a.ConversationGroupId = 260
GO