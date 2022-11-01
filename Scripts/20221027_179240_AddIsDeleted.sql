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

INSERT INTO crmLogActionType (ActionTypeID, ActionTypeName)
VALUES (5, 'Chat Type Mapping')

UPDATE crmLogAction WITH(ROWLOCK)
	SET ActionTypeID = 5
WHERE SpName IN ('Acc_CRM_ChatBot_ChatTypeMapping_Ins','Acc_CRM_ChatBot_ChatTypeMapping_Upd','Acc_CRM_ChatBot_ChatTypeMappingStatus_Upd','Acc_CRM_ChatBot_ChatTypeMappingRemark_Upd')

INSERT INTO crmLogAction (ActionID, SPName, ActionNameEN, IsInternal, ExcludedForCn88, ActionTypeID)
VALUES (1011, 'Acc_CRM_ChatBot_ConversationGroup_Del', 'Delete conversation group', 0, 1, 5)

UPDATE crmUserLog_RunSP WITH(ROWLOCK)
	SET NewValues = REPLACE(REPLACE(REPLACE(NewValues, 'ConversationGroupId', 'Id'),'ConversationGroupName', 'Name'), 'IsActive', 'Active')
	, OldValues = REPLACE(REPLACE(REPLACE(OldValues, 'ConversationGroupId', 'Id'),'ConversationGroupName', 'Name'), 'IsActive', 'Active')
WHERE ActionID IN (1009, 1010, 1008)

UPDATE crmUserLog_RunSP WITH(ROWLOCK)
	SET NewValues = REPLACE(NewValues, 'IsActive', 'Active'), OldValues = REPLACE(OldValues, 'IsActive', 'Active')
WHERE ActionID = 1007

UPDATE r
	SET r.NewValues = CONVERT(VARCHAR(MAX), nr.p) , r.OldValues = CONVERT(VARCHAR(MAX), OLr.P)
FROM crmUserLog_RunSP r WITH(ROWLOCK)
OUTER APPLY (
	SELECT CONVERT(XML, NewValues) AS XmlNewValues
) AS r1
OUTER APPLY ( 
	SELECT CONVERT(XML, OldValues) AS XmlOldValues
) AS r2
OUTER APPLY (
	SELECT t.c.value('@Id', 'INT')	AS '@Id'
		,t.c.value('@Name', 'VARCHAR(200)') AS '@Name'
	FROM r1.XmlNewValues.nodes('//ConversationGroup/Bot') t(c)
	FOR XML PATH('Bot'), TYPE
) AS _NBot (Bot)
OUTER APPLY (
	SELECT t.c.value('@Id', 'INT')	AS '@Id'
		,t.c.value('@Name', 'VARCHAR(200)') AS '@Name'
	FROM r1.XmlNewValues.nodes('//ConversationGroup/Language') t(c)
	FOR XML PATH ('Language'), TYPE
) AS _NLanguage(Language)
OUTER APPLY (
	SELECT t.c.value('@Id', 'INT')	AS '@Id'
		,t.c.value('@Name', 'VARCHAR(200)') AS '@Name'
	FROM r1.XmlNewValues.nodes('//ConversationGroup/Recipient') t(c)
	FOR XML PATH('Recipient'), TYPE
) AS _NRecipient (Recipient)
OUTER APPLY (
	SELECT DISTINCT t.c.value('@RecipientTypeId', 'INT')	AS '@Id'
		,t.c.value('@RecipientTypeName', 'VARCHAR(200)') AS '@Name'
	FROM r1.XmlNewValues.nodes('//ConversationGroup/Recipient') t(c)
	FOR XML PATH('RecipientType'), TYPE
) AS _NRecipientType (RecipientType)
OUTER APPLY (
	SELECT t.c.value('@Id', 'INT')	AS '@Id'
		,t.c.value('@Name', 'VARCHAR(200)') AS '@Name'
	FROM r1.XmlNewValues.nodes('//ConversationGroup/Headline') t(c)
	FOR XML PATH('Headline'), TYPE
) AS _NHeadline (Headline)
OUTER APPLY (
	SELECT t.c.value('@Id', 'INT')	AS Id
		,t.c.value('@Name', 'VARCHAR(200)') AS [Name]
		,t.c.value('@LetstalkID', 'VARCHAR(200)') AS LetstalkID
		,t.c.value('@Remark', 'VARCHAR(200)') AS Remark
		,t.c.value('@IsTest', 'VARCHAR(200)') AS IsTest
	FROM r1.XmlNewValues.nodes('//ConversationGroup') t(c)
) AS _NConversationGroup (Id, Name, LetstalkID, Remark, IsTest)
OUTER APPLY (
	SELECT 
		_NConversationGroup.Id AS '@Id'
		,_NConversationGroup.Name AS '@Name'
		,_NConversationGroup.LetstalkID AS '@LetstalkID'
		,_NConversationGroup.Remark AS '@Remark'
		,_NConversationGroup.IsTest AS '@IsTest'
		,CONVERT(XML,_NBot.Bot)
		,CONVERT(XML,_NHeadline.Headline)
		,CONVERT(XML,_NRecipient.Recipient)
		,CONVERT(XML,_NRecipientType.RecipientType)
		,CONVERT(XML, _NLanguage.Language)
	FOR XML PATH('ConversationGroup'), ROOT('Acc_CRM_ChatBot_ChatTypeMapping_Upd')

) AS Nr(P)

--Old XML
OUTER APPLY (
	SELECT t.c.value('@Id', 'INT')	AS '@Id'
		,t.c.value('@Name', 'VARCHAR(200)') AS '@Name'
	FROM r2.XmlOldValues.nodes('//ConversationGroup/Bot') t(c)
	FOR XML PATH('Bot'), TYPE
) AS _OBot (Bot)
OUTER APPLY (
	SELECT t.c.value('@Id', 'INT')	AS '@Id'
		,t.c.value('@Name', 'VARCHAR(200)') AS '@Name'
	FROM r2.XmlOldValues.nodes('//ConversationGroup/Language') t(c)
	FOR XML PATH ('Language'), TYPE
) AS _OLanguage(Language)
OUTER APPLY (
	SELECT t.c.value('@Id', 'INT')	AS '@Id'
		,t.c.value('@Name', 'VARCHAR(200)') AS '@Name'
	FROM r2.XmlOldValues.nodes('//ConversationGroup/Recipient') t(c)
	FOR XML PATH('Recipient'), TYPE
) AS _ORecipient (Recipient)
OUTER APPLY (
	SELECT DISTINCT t.c.value('@RecipientTypeId', 'INT')	AS '@Id'
		,t.c.value('@RecipientTypeName', 'VARCHAR(200)') AS '@Name'
	FROM r2.XmlOldValues.nodes('//ConversationGroup/Recipient') t(c)
	FOR XML PATH('RecipientType'), TYPE
) AS _ORecipientType (RecipientType)
OUTER APPLY (
	SELECT t.c.value('@Id', 'INT')	AS '@Id'
		,t.c.value('@Name', 'VARCHAR(200)') AS '@Name'
	FROM r2.XmlOldValues.nodes('//ConversationGroup/Headline') t(c)
	FOR XML PATH('Headline'), TYPE
) AS _OHeadline (Headline)
OUTER APPLY (
	SELECT t.c.value('@Id', 'INT')	AS Id
		,t.c.value('@Name', 'VARCHAR(200)') AS [Name]
		,t.c.value('@LetstalkID', 'VARCHAR(200)') AS LetstalkID
		,t.c.value('@Remark', 'VARCHAR(200)') AS Remark
		,t.c.value('@IsTest', 'VARCHAR(200)') AS IsTest
	FROM r2.XmlOldValues.nodes('//ConversationGroup') t(c)
) AS _OConversationGroup (Id, Name, LetstalkID, Remark, IsTest)
OUTER APPLY (
	SELECT 
		_OConversationGroup.Id AS '@Id'
		,_OConversationGroup.Name AS '@Name'
		,_OConversationGroup.LetstalkID AS '@LetstalkID'
		,_OConversationGroup.Remark AS '@Remark'
		,_OConversationGroup.IsTest AS '@IsTest'
		,CONVERT(XML,_OBot.Bot)
		,CONVERT(XML,_OHeadline.Headline)
		,CONVERT(XML,_ORecipient.Recipient)
		,CONVERT(XML,_ORecipientType.RecipientType)
		,CONVERT(XML, _OLanguage.Language)
	FOR XML PATH('ConversationGroup'), ROOT('Acc_CRM_ChatBot_ChatTypeMapping_Upd')

) AS OLr(P)
WHERE ActionID = 1008
