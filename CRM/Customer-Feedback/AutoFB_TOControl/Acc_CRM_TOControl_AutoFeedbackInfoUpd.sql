/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_TOControl_AutoFeedbackInfoUpd]	
	@CustID		INT,	
	@MatchID	INT,
	@ProfileID	INT,
	@Status 	VARCHAR(20),
	@Description VARCHAR(1000)
AS
/*
	Created: 20201130@Johnson
	Task : update TOControl auto feedback info for each feedback
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20201130@Johnson: Initial sp [redmine:#145274]		
	Param's Explanation:				
*/
BEGIN
	SET NOCOUNT ON
	
	UPDATE crmTOControlFeedbackInfo WITH(UPDLOCK,ROWLOCK)
	SET status = @status,
		RetryCount = CASE WHEN @status = 'fail' THEN retrycount + 1 ELSE retrycount END,
		Description = @Description,
		UpdatedTime = GETDATE()
	WHERE CustID = @CustID
		AND MatchID = @MatchID
		AND ProfileID = @ProfileID
	
END	