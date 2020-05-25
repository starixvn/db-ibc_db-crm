/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_AutoFeedbackInfoIns]	
	@xml XML
AS
/*
	Created: 20200518@Johnson
	Task : store abnormal tickets info into CRM to tracking
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20200518@Johnson: Initial sp [redmine:#134220]
	Param's Explanation:		
		- @xml = <ROOT>
						<r msgid="100" custid="1" hl="100" related="1" event="A -vs- B" />
						<r msgid="100" custid="2" hl="100" related="2" event="A -vs- B" />
					</ROOT>	
*/
BEGIN
	SET NOCOUNT ON
		
	DECLARE @tmpCust TABLE (MessageID INT, event VARCHAR(500), custid INT, headlineID INT, relatedCustid INT)
		
	INSERT INTO @tmpCust(MessageID,custid,HeadlineID,relatedCustid,event)
	SELECT t.c.value('@msgid[1]','int') msgid,		
		t.c.value('@custid[1]','int') custid,
		t.c.value('@hl[1]','int') hl,
		t.c.value('@related[1]','int') related,
		t.c.value('@event[1]','varchar(500)') event
	FROM @xml.nodes('/ROOT/r') t(c)	
	
	--insert feedback info for new messages
	INSERT INTO crmAutoFeedbackInfo(MessageID,custid,HeadlineID,relatedCustid,eventInfo,status,CreatedDate,retryCount)
	SELECT t.MessageID, t.custid, t.HeadlineID, t.relatedCustid, t.event,'initial', GETDATE(), 0
	FROM @tmpCust t
		LEFT JOIN crmAutoFeedbackInfo c WITH(NOLOCK) ON t.MessageID = c.MessageID
													AND t.custid = c.custid
	WHERE c.custid IS NULL	
	
	--get all msg & custid with status = 'initial'
	SELECT c.MessageID, c.custid
	FROM crmAutoFeedbackInfo c WITH(NOLOCK)
		INNER JOIN @tmpCust t ON c.MessageID = t.MessageID
								AND c.custid = t.custid
	WHERE status = 'initial'	
		AND retryCount <= 5
END	