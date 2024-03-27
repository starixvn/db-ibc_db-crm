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
		- 20200831@Johnson: Add requestID to check missing auto void request [redmine:#139158]
		- 20200811@Johnson: Add requestID to check missing auto void request [redmine:#139158]	
		- 20210705@Winfred: Integrate Abnormal Accounts [RedmineId : #157303]	
		- 20230131@Winfred: Scale Out for CRM [RedmineId : #181906]
	Param's Explanation:		
*/
BEGIN
	SET NOCOUNT ON
		
	SELECT DISTINCT a.MessageID, a.RequestID , b.UsernameList,b.CustIdList , b.VoidingHistoryCollectionId
	FROM dbo.crmAutoFeedbackInfo a WITH(NOLOCK)
	Left Join crmMessageImport b WITH(NOLOCK) ON a.MessageID = b.MessageID  AND a.RequestID = b.RequestID
	WHERE status IN ('initial','fail')
		AND retryCount < 5	
END	