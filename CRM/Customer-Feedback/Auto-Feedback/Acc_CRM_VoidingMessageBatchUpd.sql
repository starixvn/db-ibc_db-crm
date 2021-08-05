/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_VoidingMessageBatchUpd]	
	@MessageIds VARCHAR(MAX) ,
	@Environment	VARCHAR(10) = 'LIVE'	
AS
/*
	Created: 20200612@Johnson
	Task : update status voiding messages 
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20200612@Johnson: Initial sp [redmine:#135719]		
		- 20200811@Johnson: Add requestID to check missing auto void request [redmine:#139158]
		- 20210705@Winfred: Integrate Abnormal Accounts [RedmineId : #157303]	
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
	
	IF @Environment = 'LIVE'
	BEGIN
		UPDATE cm
		SET isProcessed = 1		
		FROM crmMessageImport cm WITH(UPDLOCK,ROWLOCK)
			INNER JOIN @tmpMessage t ON cm.MessageID = t.MessageID
										AND cm.RequestID = t.RequestID
		WHERE isProcessed = 0
	END 
	ELSE
	BEGIN
		UPDATE cm
		SET IsProcessedUAT = 1		
		FROM crmMessageImport cm WITH(UPDLOCK,ROWLOCK)
			INNER JOIN @tmpMessage t ON cm.MessageID = t.MessageID
										AND cm.RequestID = t.RequestID
		WHERE IsProcessedUAT = 0
	END	
END	