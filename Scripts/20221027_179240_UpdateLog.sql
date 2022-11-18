/*<info serverAlias="DBCRM-bodb_CRM" ></info>*/

/*
	Created: 20221027@Malcolm
	DB: DBCRM-bodb_CRM
	Task: Update Remark [RedmineId : #179240]
*/
USE bodb_CRM
GO

UPDATE crmUserLog_RunSP WITH(ROWLOCK)
	SET NewValues = REPLACE(REPLACE(REPLACE(NewValues, 'ConversationGroupId', 'Id'),'ConversationGroupName', 'Name'), 'IsActive', 'Active')
	, OldValues = REPLACE(REPLACE(REPLACE(OldValues, 'ConversationGroupId', 'Id'),'ConversationGroupName', 'Name'), 'IsActive', 'Active')
WHERE ActionID IN (1009, 1010, 1008) AND LogDate < '2022-11-16'

UPDATE crmUserLog_RunSP WITH(ROWLOCK)
	SET NewValues = REPLACE(NewValues, 'IsActive', 'Active'), OldValues = REPLACE(OldValues, 'IsActive', 'Active')
WHERE ActionID = 1007 AND LogDate < '2022-11-16'

--Update status
UPDATE r
	SET r.NewValues = n.Value, r.OldValues = o.Value
FROM crmUserLog_RunSP r WITH(NOLOCK)
OUTER APPLY (
	SELECT CONVERT(XML, r.NewValues).value('(*/@Id)[1]', 'INT') AS '@Id'
		,CONVERT(XML, r.NewValues).value('(*/@Name)[1]', 'NVARCHAR(1000)') AS '@Name'
		,CONVERT(XML, r.NewValues).value('(*/@Active)[1]', 'BIT') AS '@Active'
	FOR XML PATH ('ConversationGroup'), ROOT('Acc_CRM_ChatBot_ChatTypeMappingStatus_Upd')
) AS n (Value)
OUTER APPLY (
	SELECT 
		CONVERT(XML, r.OldValues).value('(*/@Id)[1]', 'INT') AS '@Id'
		,CONVERT(XML, r.OldValues).value('(*/@Name)[1]', 'NVARCHAR(1000)') AS '@Name'
		,CONVERT(XML, r.OldValues).value('(*/@Active)[1]', 'BIT') AS '@Active'
	FOR XML PATH ('ConversationGroup'), ROOT('Acc_CRM_ChatBot_ChatTypeMappingStatus_Upd')
) AS o (Value)
WHERE ActionID = 1009 AND LogDate < '2022-11-16'

-- Update remark
UPDATE r
	SET r.NewValues = n.Value, r.OldValues = o.Value
FROM crmUserLog_RunSP r WITH(NOLOCK)
OUTER APPLY (
	SELECT
		CONVERT(XML, r.NewValues).value('(*/@Id)[1]', 'INT') AS '@Id'
		,CONVERT(XML, r.NewValues).value('(*/@Name)[1]', 'NVARCHAR(1000)') AS '@Name'
		,CONVERT(XML, r.NewValues).value('(*/@Remark)[1]', 'NVARCHAR(2000)') AS '@Remark'
	FOR XML PATH ('ConversationGroup'), ROOT('Acc_CRM_ChatBot_ChatTypeMappingRemark_Upd')
) AS n (Value)
OUTER APPLY (
	SELECT 
		CONVERT(XML, r.OldValues).value('(*/@Id)[1]', 'INT') AS '@Id'
		,CONVERT(XML, r.OldValues).value('(*/@Name)[1]', 'NVARCHAR(1000)') AS '@Name'
		,CONVERT(XML, r.OldValues).value('(*/@Remark)[1]', 'NVARCHAR(2000)') AS '@Remark'
	FOR XML PATH ('ConversationGroup'), ROOT('Acc_CRM_ChatBot_ChatTypeMappingRemark_Upd')
) AS o (Value)
WHERE ActionID = 1010 AND LogDate < '2022-11-16'

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
		,t.c.value('@Name', 'NVARCHAR(1000)') AS '@Name'
	FROM r1.XmlNewValues.nodes('//ConversationGroup/Bot') t(c)
	FOR XML PATH('Bot'), TYPE
) AS _NBot (Bot)
OUTER APPLY (
	SELECT t.c.value('@Id', 'INT')	AS '@Id'
		,t.c.value('@Name', 'NVARCHAR(200)') AS '@Name'
	FROM r1.XmlNewValues.nodes('//ConversationGroup/Language') t(c)
	FOR XML PATH ('Language'), TYPE
) AS _NLanguage(Language)
OUTER APPLY (
	SELECT t.c.value('@Id', 'INT')	AS '@Id'
		,t.c.value('@Name', 'NVARCHAR(200)') AS '@Name'
	FROM r1.XmlNewValues.nodes('//ConversationGroup/Recipient') t(c)
	FOR XML PATH('Recipient'), TYPE
) AS _NRecipient (Recipient)
OUTER APPLY (
	SELECT DISTINCT t.c.value('@RecipientTypeId', 'INT')	AS '@Id'
		,t.c.value('@RecipientTypeName', 'NVARCHAR(100)') AS '@Name'
	FROM r1.XmlNewValues.nodes('//ConversationGroup/Recipient') t(c)
	FOR XML PATH('RecipientType'), TYPE
) AS _NRecipientType (RecipientType)
OUTER APPLY (
	SELECT t.c.value('@Id', 'INT')	AS '@Id'
		,t.c.value('@Name', 'NVARCHAR(200)') AS '@Name'
	FROM r1.XmlNewValues.nodes('//ConversationGroup/Headline') t(c)
	FOR XML PATH('Headline'), TYPE
) AS _NHeadline (Headline)
OUTER APPLY (
	SELECT t.c.value('@Id', 'INT')	AS '@Id'
		,t.c.value('@Name', 'NVARCHAR(1000)') AS '@Name'
		,t.c.value('@LetstalkID', 'VARCHAR(200)') AS '@LetstalkID'
		,t.c.value('@Remark', 'NVARCHAR(2000)') AS '@Remark'
		,t.c.value('@IsTest', 'BIT') AS 'IsTest'
	FROM r1.XmlNewValues.nodes('//ConversationGroup') t(c)
	FOR XML PATH('ConversationGroup')
) AS _NConversationGroup(ConversationGroup)
OUTER APPLY (
	SELECT 
		CONVERT(XML, _NConversationGroup.ConversationGroup)
		,CONVERT(XML,_NBot.Bot)
		,CONVERT(XML,_NHeadline.Headline)
		,CONVERT(XML,_NRecipient.Recipient)
		,CONVERT(XML,_NRecipientType.RecipientType)
		,CONVERT(XML, _NLanguage.Language)
	FOR XML PATH('Acc_CRM_ChatBot_ChatTypeMapping_Upd')
) AS Nr(P)

--Old XML
OUTER APPLY (
	SELECT t.c.value('@Id', 'INT')	AS '@Id'
		,t.c.value('@Name', 'NVARCHAR(1000)') AS '@Name'
	FROM r2.XmlOldValues.nodes('//ConversationGroup/Bot') t(c)
	FOR XML PATH('Bot'), TYPE
) AS _OBot (Bot)
OUTER APPLY (
	SELECT t.c.value('@Id', 'INT')	AS '@Id'
		,t.c.value('@Name', 'NVARCHAR(200)') AS '@Name'
	FROM r2.XmlOldValues.nodes('//ConversationGroup/Language') t(c)
	FOR XML PATH ('Language'), TYPE
) AS _OLanguage(Language)
OUTER APPLY (
	SELECT t.c.value('@Id', 'INT')	AS '@Id'
		,t.c.value('@Name', 'NVARCHAR(200)') AS '@Name'
	FROM r2.XmlOldValues.nodes('//ConversationGroup/Recipient') t(c)
	FOR XML PATH('Recipient'), TYPE
) AS _ORecipient (Recipient)
OUTER APPLY (
	SELECT DISTINCT t.c.value('@RecipientTypeId', 'INT')	AS '@Id'
		,t.c.value('@RecipientTypeName', 'NVARCHAR(100)') AS '@Name'
	FROM r2.XmlOldValues.nodes('//ConversationGroup/Recipient') t(c)
	FOR XML PATH('RecipientType'), TYPE
) AS _ORecipientType (RecipientType)
OUTER APPLY (
	SELECT t.c.value('@Id', 'INT')	AS '@Id'
		,t.c.value('@Name', 'NVARCHAR(200)') AS '@Name'
	FROM r2.XmlOldValues.nodes('//ConversationGroup/Headline') t(c)
	FOR XML PATH('Headline'), TYPE
) AS _OHeadline (Headline)
OUTER APPLY (
	SELECT t.c.value('@Id', 'INT')	AS '@Id'
		,t.c.value('@Name', 'NVARCHAR(1000)') AS '@Name'
		,t.c.value('@LetstalkID', 'VARCHAR(200)') AS '@LetstalkID'
		,t.c.value('@Remark', 'NVARCHAR(2000)') AS '@Remark'
		,t.c.value('@IsTest', 'BIT') AS '@IsTest'
	FROM r2.XmlOldValues.nodes('//ConversationGroup') t(c)
	FOR XML PATH('ConversationGroup')
) AS _OConversationGroup (ConversationGroup)
OUTER APPLY (
	SELECT 
		CONVERT(XML, _OConversationGroup.ConversationGroup)
		,CONVERT(XML,_OBot.Bot)
		,CONVERT(XML,_OHeadline.Headline)
		,CONVERT(XML,_ORecipient.Recipient)
		,CONVERT(XML,_ORecipientType.RecipientType)
		,CONVERT(XML, _OLanguage.Language)
	FOR XML PATH('Acc_CRM_ChatBot_ChatTypeMapping_Upd')
) AS OLr(P)
WHERE ActionID = 1008 AND LogDate < '2022-11-16'
