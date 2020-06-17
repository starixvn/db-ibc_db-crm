/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_VoidingMessageIns]	
	@MessageIds VARCHAR(MAX) = '',
	@BatchSize 	INT 
AS
/*
	Created: 20200612@Johnson
	Task : import voiding messages into CRM and return list msgID need to create FB
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20200612@Johnson: Initial sp [redmine:#135719]		
	Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON
		
	DECLARE @tmpMessage TABLE (MessageId INT)
		
	INSERT INTO @tmpMessage (MessageId)
	SELECT val
	FROM f_CRM_strSplit(@MessageIds,',')
	
	INSERT INTO crmMessageImport(MessageId,CreatedDate,isProcessed)
	SELECT t.MessageId, GETDATE(), 0
	FROM @tmpMessage t
		LEFT JOIN crmMessageImport m WITH(NOLOCK) ON t.MessageId = m.MessageId
	WHERE m.MessageId IS NULL	
	
	--Get top new messages
	SELECT TOP (@BatchSize) MessageId
	FROM crmMessageImport WITH(NOLOCK)
	WHERE isProcessed = 0		
	ORDER BY MessageId ASC
END
GO	