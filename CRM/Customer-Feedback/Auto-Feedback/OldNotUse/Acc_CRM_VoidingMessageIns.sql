ALTER PROCEDURE [dbo].[Acc_CRM_VoidingMessageIns]	
	@MessageIds VARCHAR(MAX) = '',
	@BatchSize 	INT  ,
	@Environment	VARCHAR(10) = 'LIVE',
	@LastDateUAT DATETIME 
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
		- 20210705@Winfred: Integrate Abnormal Accounts [RedmineId : #157303]
		- 20230131@Winfred: Scale Out for CRM [RedmineId : #181906]
	
	Param's Explanation:
		- @MessageIds = '<ROOT>
						<r VoidingHistoryCollectionId="1" MsgID="123" ReqID="1" UsernameList="member1,member2,member3" CustIdList=""/>
						<r VoidingHistoryCollectionId="1" MsgID="123" ReqID="2" UsernameList="member1,member2,member3" CustIdList=""/>
						<r VoidingHistoryCollectionId="1" MsgID="345" ReqID="1" UsernameList="member1,member2,member3" CustIdList=""/>
						</ROOT>'
*/
BEGIN
	SET NOCOUNT ON
		
	DECLARE @tmpMessage TABLE (VoidingHistoryCollectionId INT,MessageId INT, RequestID INT, UsernameList NVARCHAR(MAX), CustIdList VARCHAR(MAX))
	DECLARE @xml XML = CAST(@MessageIds AS XML)	
	
	INSERT INTO @tmpMessage (VoidingHistoryCollectionId ,MessageId, RequestID, UsernameList, CustIdList)
	SELECT DISTINCT
		t.c.value('@VoidingHistoryCollectionId[1]','int') VoidingHistoryCollectionId,
		t.c.value('@MsgID[1]','int') MsgID,
		t.c.value('@ReqID[1]','int') ReqID,
		t.c.value('@UsernameList[1]', 'NVARCHAR(MAX)') AS UsernameList,
		t.c.value('@CustIdList[1]', 'VARCHAR(MAX)') AS CustIdList
	FROM @xml.nodes('/ROOT/r') t(c)

	DECLARE @i TINYINT = 0, @maxTry TINYINT = 5, @msg VARCHAR(1024) = ''

	WHILE @i < @maxTry
	BEGIN
		SET @msg = ''
		BEGIN TRY
			INSERT INTO crmMessageImport (VoidingHistoryCollectionId ,MessageId, RequestID, CreatedDate, IsProcessed ,IsProcessedUAT, UsernameList, CustIdList)
			SELECT t.VoidingHistoryCollectionId, t.MessageId, t.RequestID, GETDATE(), 
			0 AS isProcessed, 
			0 AS IsProcessedUAT ,UsernameList, CustIdList
			FROM @tmpMessage t
				OUTER APPLY (SELECT TOP 1 m.MessageId FROM crmMessageImport m WITH(NOLOCK) WHERE t.MessageId = m.MessageId AND t.RequestID = m.RequestID ) m
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
		SELECT DISTINCT TOP (@BatchSize) VoidingHistoryCollectionId
		FROM crmMessageImport WITH(NOLOCK)
		WHERE ((isProcessed = 0 AND  @Environment = 'LIVE') OR( @Environment <> 'LIVE' AND IsProcessedUAT = 0 AND CreatedDate >= @LastDateUAT)) 		
		ORDER BY VoidingHistoryCollectionId ASC
	)
	SELECT VoidingHistoryCollectionId, MessageId, RequestID,ISNULL(UsernameList, '') AS UsernameList, ISNULL(CustIdList, '') AS CustIdList
	FROM crmMessageImport c WITH(NOLOCK)
	WHERE VoidingHistoryCollectionId IN (SELECT VoidingHistoryCollectionId FROM tmp)
		AND ((isProcessed = 0 AND  @Environment = 'LIVE') OR( @Environment <> 'LIVE' AND IsProcessedUAT = 0 AND CreatedDate >= @LastDateUAT)) 
END
GO	