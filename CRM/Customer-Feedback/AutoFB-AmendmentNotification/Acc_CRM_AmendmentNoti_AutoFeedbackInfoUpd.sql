/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_AmendmentNoti_AutoFeedbackInfoUpd] 
	@LogID 		INT,
	@Status 	VARCHAR(20),
	@Description VARCHAR(1000)
AS
/*
	Created: Winfred
	Task : import list customers reach Amendment Notification into CRM
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 202010303@Winfred: Initial sp [redmine:#147470]
	
	Parameter's Explanation:

*/
BEGIN
	SET NOCOUNT ON
	
	SET NOCOUNT ON
	
	UPDATE crmAmendmentNotiFeedbackInfo WITH(UPDLOCK,ROWLOCK)
	SET status = @status,
		RetryCount = CASE WHEN @status = 'fail' THEN retrycount + 1 ELSE retrycount END,
		Description = @Description,
		UpdatedTime = GETDATE()
	WHERE LogID  = @LogID
		
END	