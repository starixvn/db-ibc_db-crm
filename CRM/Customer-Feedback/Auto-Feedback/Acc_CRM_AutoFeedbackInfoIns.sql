/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_AutoFeedbackInfoIns]	
	@xml XML,
	@Environment	VARCHAR(10) = 'LIVE'
AS
/*
	Created: 20200518@Johnson
	Task : store abnormal tickets info into CRM to tracking
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20200518@Johnson: Initial sp [redmine:#134220]
		- 20210705@Winfred: Integrate Abnormal Accounts [RedmineId : #157303]
		- 20220817@Winfred: Don't generate feedback for those ignored accounts [redmine:#173914]
	Param's Explanation:		
		- @xml = <ROOT>
						<r msgid="100" reqid="1" custid="1" hl="100" related="1" event="A -vs- B" IssueTypeId = "13" />
						<r msgid="100" reqid="1" custid="2" hl="100" related="2" event="A -vs- B" IssueTypeId = "13" />
					</ROOT>	
*/
BEGIN
	SET NOCOUNT ON
		
	DECLARE @tmpCust TABLE (MessageID INT, RequestID INT, event VARCHAR(500), custid INT, headlineID INT, relatedCustid INT,IssueTypeId TINYINT)
	DECLARE @tmpIgnoreCust TABLE (MessageID INT, RequestID INT)
		
	INSERT INTO @tmpCust(MessageID,RequestID,custid,HeadlineID,relatedCustid,event,IssueTypeId)
	SELECT t.c.value('@msgid[1]','int') msgid,
		t.c.value('@reqid[1]','int') reqid,	
		t.c.value('@custid[1]','int') custid,
		t.c.value('@hl[1]','int') hl,
		t.c.value('@related[1]','int') related,
		t.c.value('@event[1]','varchar(500)') event,
		t.c.value('@IssueTypeId[1]','TINYINT') IssueTypeId
	FROM @xml.nodes('/ROOT/r') t(c)	
		
	--insert feedback info for new messages not exists
	INSERT INTO crmAutoFeedbackInfo(MessageID,RequestID,custid,HeadlineID,relatedCustid,eventInfo,status,CreatedDate,retryCount,IssueTypeId,Environment)
	SELECT t.MessageID, t.RequestID, t.custid, t.HeadlineID, t.relatedCustid, t.event,
	'initial' [status],  
	GETDATE(), 0,t.IssueTypeId,@Environment
	FROM @tmpCust t
		LEFT JOIN crmAutoFeedbackInfo c WITH(NOLOCK) ON t.MessageID = c.MessageID
													AND t.RequestID = c.RequestID
													AND t.custid = c.custid
													AND t.headlineID = c.HeadlineID
	WHERE c.custid IS NULL 
	
	UPDATE fb 
	SET status = 'ignore',UpdatedTime = GETDATE()
	OUTPUT DELETED.MessageID,DELETED.RequestID INTO @tmpIgnoreCust(MessageID,RequestID)
	FROM crmAutoFeedbackInfo fb  WITH(UPDLOCK,ROWLOCK)
		INNER JOIN crmCustomer c WITH(NOLOCK) ON fb.HeadlineID = c.custid
	WHERE status IN ('initial','fail') AND retryCount < 5  AND c.Ignored = 1
	
	UPDATE mi 
	SET mi.IsProcessed = 1,
		mi.IsProcessedUAT = 1
	FROM crmMessageImport mi  WITH(UPDLOCK,ROWLOCK)
	INNER JOIN @tmpIgnoreCust t ON mi.MessageID = t.MessageID AND mi.RequestID = t.RequestID
	WHERE IsProcessed = 0 OR IsProcessedUAT = 0

	--get all msg & custid with status = 'initial'
	SELECT c.MessageID, c.RequestID, c.custid 
	FROM crmAutoFeedbackInfo c WITH(NOLOCK)
		INNER JOIN @tmpCust t ON c.MessageID = t.MessageID
								AND c.RequestID = t.RequestID
								AND c.custid = t.custid
								AND c.headlineID = t.HeadlineID
	WHERE status IN ('initial','fail')	
		AND retryCount < 5 
	
END	