/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_VoidingMessageBatchUpd]	
	@MessageIds VARCHAR(MAX) 	
AS
/*
	Created: 20200612@Johnson
	Task : update status voiding messages 
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
	
	UPDATE crmMessageImport WITH(UPDLOCK,ROWLOCK)
	SET isProcessed = 1		
	WHERE MessageID IN (SELECT MessageID FROM @tmpMessage)
		AND isProcessed = 0
END	