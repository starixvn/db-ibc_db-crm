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
		- 20200604@Johnson: update retryCount after process done [redmine:]
	Param's Explanation:		
*/
BEGIN
	SET NOCOUNT ON
		
	SELECT DISTINCT MessageID 
	FROM dbo.crmAutoFeedbackInfo WITH(NOLOCK)
	WHERE status IN ('initial','fail')
		AND retryCount < 5	
END	