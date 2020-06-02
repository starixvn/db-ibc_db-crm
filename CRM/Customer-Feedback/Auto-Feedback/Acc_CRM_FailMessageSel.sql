/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_FailMessageSel]		
AS
/*
	Created: 20200519@Johnson
	Task : get list messageid fail for creating fb
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20200519@Johnson: Initial sp [redmine:#134220]
	Param's Explanation:		
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @tmpMessage TABLE (MessageID INT)
	
	INSERT INTO @tmpMessage(MessageID)
	SELECT DISTINCT MessageID 
	FROM dbo.crmAutoFeedbackInfo WITH(NOLOCK)
	WHERE status IN ('initial','fail')
		AND retryCount < 5
	
	UPDATE c
	SET status = 'initial',
		retryCount = retryCount + 1
	FROM dbo.crmAutoFeedbackInfo c WITH(UPDLOCK,ROWLOCK)
	WHERE MessageID IN (SELECT MessageID FROM @tmpMessage)
		AND status IN ('initial','fail')
		AND retryCount < 5
	
	SELECT MessageID
	FROM @tmpMessage
END	