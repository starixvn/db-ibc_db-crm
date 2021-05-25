/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_ProblemAccount_AutoFeedbackInfoUpd]	
	@LogID 		VARCHAR(1000),
	@Status 	VARCHAR(20),
	@Description VARCHAR(1000)
AS
/*
	Created: 20210512@Johnson
	Task : update problem account auto feedback info for each feedback
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20210512@Johnson: Initial sp [redmine:#142194]		
	Param's Explanation:				
*/
BEGIN
	SET NOCOUNT ON
	
	UPDATE crmProblemAccountFeedbackInfo WITH(UPDLOCK,ROWLOCK)
	SET status = @status,
		RetryCount = CASE WHEN @status = 'fail' THEN retrycount + 1 ELSE retrycount END,
		Description = @Description,
		UpdatedTime = GETDATE()
	WHERE LogID IN (SELECT val FROM dbo.f_CRM_strSplit(@LogID,','))
	
END	