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
		- 20201029@Percy: Change left join to outer apply [RedmineID: #144466]
		- 20201105@Percy: Try 5 times for duplicate primary key [RedmineID: #144466]
	
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
	
	INSERT INTO @tmpMessage (MessageId, RequestID)
	SELECT DISTINCT
		t.c.value('@MsgID[1]','int') MsgID,
		t.c.value('@ReqID[1]','int') ReqID
	FROM @xml.nodes('/ROOT/r') t(c)

	DECLARE @i TINYINT = 0, @maxTry TINYINT = 5, @msg VARCHAR(1024) = ''

	WHILE @i < @maxTry
	BEGIN
		BEGIN TRY
			INSERT INTO crmMessageImport (MessageId, RequestID, CreatedDate, isProcessed)
			SELECT t.MessageId, t.RequestID, GETDATE(), 0
			FROM @tmpMessage t
				OUTER APPLY (SELECT TOP 1 m.MessageId FROM crmMessageImport m WITH(NOLOCK) WHERE t.MessageId = m.MessageId AND t.RequestID = m.RequestID) m
			WHERE m.MessageId IS NULL
		END TRY
		BEGIN CATCH
			IF ERROR_NUMBER() = 2627 -- violation of primary key
				SET @i = @i + 1
			ELSE
				SET @i = @maxTry
			
			SET @msg = ERROR_MESSAGE()
		END CATCH

		IF @msg = ''
			BREAK
	END

	IF ISNULL(@msg, '') <> ''
	BEGIN
		RAISERROR(@msg, 16, 1)
		RETURN
	END
	
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