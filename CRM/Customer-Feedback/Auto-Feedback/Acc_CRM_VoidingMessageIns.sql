/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_VoidingMessageIns]	
	@MessageIds VARCHAR(MAX) = '',
	@BatchSize 	INT 
AS
/*
	Created: 20200612@Johnson
	Task : import voiding messages into CRM and return list msgID need to create FB
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20200612@Johnson: Initial sp [redmine:#135719]		
		- 20200811@Johnson: Add requestID to check missing auto void request [redmine:#139158]	
	Param's Explanation:
		- @MessageIds = '<ROOT>
						<r MsgID="123" ReqID="1" />
						<r MsgID="123" ReqID="2" />
						<r MsgID="345" ReqID="1" />
						</ROOT>'
*/
BEGIN
	SET NOCOUNT ON
		
	DECLARE @tmpMessage TABLE (MessageId INT, RequestID INT)
	DECLARE @xml XML = CAST(@MessageIds AS XML)	
	
	INSERT INTO @tmpMessage (MessageId,RequestID)
	SELECT t.c.value('@MsgID[1]','int') MsgID,
		t.c.value('@ReqID[1]','int') ReqID
	FROM @xml.nodes('/ROOT/r') t(c)								
	
	INSERT INTO crmMessageImport(MessageId,RequestID,CreatedDate,isProcessed)
	SELECT t.MessageId, t.RequestID, GETDATE(), 0
	FROM @tmpMessage t
		LEFT JOIN crmMessageImport m WITH(NOLOCK) ON t.MessageId = m.MessageId
													AND t.RequestID = m.RequestID
	WHERE m.MessageId IS NULL	
	
	--Get top new messages
	;WITH tmp AS 
	(	
		SELECT DISTINCT TOP (@BatchSize) MessageId
		FROM crmMessageImport WITH(NOLOCK)
		WHERE isProcessed = 0		
		ORDER BY MessageId ASC
	)
	SELECT MessageId, RequestID
	FROM crmMessageImport c WITH(NOLOCK)
	WHERE MessageId IN (SELECT MessageId FROM tmp)
		AND isProcessed = 0
END
GO	