/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_AutoFeedbackInfoUpd]	
	@MessageID 	VARCHAR(MAX)	= '' ,	
	@RequestIDs	VARCHAR(100),
	@Custids 	VARCHAR(MAX),
	@Status 	VARCHAR(20),
	@Description VARCHAR(1000),
	@Environment	VARCHAR(10) = 'LIVE'
AS
/*
	Created: 20200519@Johnson
	Task : update auto feedback info for each feedback
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20200519@Johnson: Initial sp [redmine:#134220]
		- 20200604@Johnson: update retrycount when fail [redmine:#135337]
		- 20200612@Johnson: enhance to check missing feedback [redmine:#135719]
		- 20200811@Johnson: Add requestID to check missing auto void request [redmine:#139158]	
		- 20210705@Winfred: Integrate Abnormal Accounts [RedmineId : #157303]
		- 20230131@Winfred: Scale Out for CRM [RedmineId : #181906]
	Param's Explanation:		
		- @custids: list custids for each feedback
		- @RequestIDs : void requestid of this msg
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @tmpCust TABLE (custid INT)	
	DECLARE @tmpRequest TABLE (RequestID INT)	
	
	INSERT INTO @tmpCust(custid)
	SELECT val 
	FROM dbo.f_CRM_strSplit(@Custids,',')
	
	INSERT INTO @tmpRequest(requestID)
	SELECT val 
	FROM dbo.f_CRM_strSplit(@RequestIDs,',')
	
	UPDATE crmAutoFeedbackInfo WITH(UPDLOCK,ROWLOCK)
	SET status = @status,
		RetryCount = CASE WHEN @status = 'fail' THEN retrycount + 1 ELSE retrycount END,
		Description = @Description,
		UpdatedTime = GETDATE()
	WHERE MessageID IN (SELECT value FROM string_split(@MessageID, ',') WHERE value <> '')
		AND RequestID IN (SELECT RequestID FROM @tmpRequest)
		AND custid IN (SELECT custid FROM @tmpCust)
	
	IF @Environment = 'LIVE'
	BEGIN
		UPDATE crmMessageImport WITH(UPDLOCK,ROWLOCK)
		SET isProcessed = 1		
		WHERE MessageID  IN (SELECT value FROM string_split(@MessageID, ',') WHERE value <> '')
			AND RequestID IN (SELECT RequestID FROM @tmpRequest)
			AND isProcessed = 0
	END
	ELSE
	BEGIN
		UPDATE crmMessageImport WITH(UPDLOCK,ROWLOCK)
		SET IsProcessedUAT = 1		
		WHERE MessageID  IN (SELECT value FROM string_split(@MessageID, ',') WHERE value <> '')
			AND RequestID IN (SELECT RequestID FROM @tmpRequest)
			AND IsProcessedUAT = 0
	END
	
END	