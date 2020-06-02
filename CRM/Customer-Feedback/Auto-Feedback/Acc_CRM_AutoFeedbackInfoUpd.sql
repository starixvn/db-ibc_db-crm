/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_AutoFeedbackInfoUpd]	
	@MessageID 	INT,
	@Custids 	VARCHAR(MAX),
	@Status 	VARCHAR(20),
	@Description VARCHAR(1000)
AS
/*
	Created: 20200519@Johnson
	Task : update auto feedback info for each feedback
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20200519@Johnson: Initial sp [redmine:#134220]
	Param's Explanation:		
		- @custids: list custids for each feedback
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @tmpCust TABLE (custid INT)
	
	INSERT INTO @tmpCust(custid)
	SELECT val 
	FROM dbo.f_CRM_strSplit(@Custids,',')
	
	UPDATE crmAutoFeedbackInfo WITH(UPDLOCK,ROWLOCK)
	SET status = @status,
		Description = @Description,
		UpdatedTime = GETDATE()
	WHERE MessageID = @MessageID
		AND custid IN (SELECT custid FROM @tmpCust)
END	