/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_ArchivedAccount_AutoFBInfoUpd] 
	@LogFeedbackId 		INT,
	@Status 	VARCHAR(20),
	@Description VARCHAR(1000)
AS
/*
	Created: Winfred
	Task : CRM -Auto-generated FB to Headline for Archiving Dormant Accounts
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20221121@Winfred: CRM -Auto-generated FB to Headline for Archiving Dormant Accounts [redmine:#158258]
	
	Parameter's Explanation:

*/
BEGIN
	SET NOCOUNT ON
	
	SET NOCOUNT ON
	
	UPDATE crmServiceFeedbackInfo WITH(UPDLOCK,ROWLOCK)
	SET status = @status,
		RetryCount = CASE WHEN @status = 'fail' THEN retrycount + 1 ELSE retrycount END,
		Description = @Description,
		UpdateDate = GETDATE()
	WHERE LogFeedbackId  = @LogFeedbackId
		
END	