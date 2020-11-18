/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_WinLimit_AutoFeedbackInfoUpd]	
	@LogID 		BIGINT,		
	@Status 	VARCHAR(20),
	@Description VARCHAR(1000)
AS
/*
	Created: 20201020@Johnson
	Task : update winlimit auto feedback info for each feedback
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20201020@Johnson: Initial sp [redmine:#142194]		
	Param's Explanation:		
		- @LogID: LogID of feedback info		
*/
BEGIN
	SET NOCOUNT ON
	
	UPDATE crmWinlimitFeedbackInfo WITH(UPDLOCK,ROWLOCK)
	SET status = @status,
		RetryCount = CASE WHEN @status = 'fail' THEN retrycount + 1 ELSE retrycount END,
		Description = @Description,
		UpdatedTime = GETDATE()
	WHERE LogID = @LogID
END	
GO

