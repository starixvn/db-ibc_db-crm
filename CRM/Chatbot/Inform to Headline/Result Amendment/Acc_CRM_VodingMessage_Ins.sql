/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_VodingMessage_Ins]
	@Message XML
AS
/*
Created: 20210811@Malcolm
Task :  Get message
DB: DBCRM/bodb_CRM
Original:
	Revisions:
		- 20210811@Malcolm: Initialize SPs [Redmine: #151509]
	Param's Explanation:
	 @Message
			<root>
				<r MessageId="1" MsgTargetId="" BetTransId=""/>
			</root>
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @MaxRetry INT = 5, @msg NVARCHAR(MAX) = '', @Id INT = 0
	CREATE TABLE #Message (MessageId INT, MsgTargetId INT, BetTransId VARCHAR(MAX))

	INSERT INTO #Message (MessageId, MsgTargetId, BetTransId)
	SELECT 
		t.c.value('@MessageId', 'INT') AS MessageId
		,t.c.value('@MsgTargetId', 'INT') AS MsgTargetId
		,t.c.value('@BetTransId','VARCHAR(MAX)') AS BetTransId
	FROM @Message.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@Message = NULL))

	WHILE @Id < @MaxRetry
	BEGIN
		SET @msg = ''

		BEGIN TRY
			INSERT INTO dbo.crmVoidingMessage (MessageId, MsgTargetId, BetTransId)
			SELECT m.MessageId, m.MsgTargetId, m.BetTransId
			FROM #Message m 
			WHERE NOT EXISTS (SELECT TOP 1 1 FROM dbo.crmVoidingMessage vm WITH(NOLOCK) WHERE vm.MessageId = m.MessageId AND vm.MsgTargetId = m.MsgTargetId)
		END TRY
		BEGIN CATCH
			IF @@ERROR = 2627
			BEGIN
				SET @Id = @Id + 1
			END
			ELSE 
				SET @Id = @MaxRetry
			SET @msg = ERROR_MESSAGE()
		END CATCH
		
		IF @msg = ''
			BREAK
	END

	IF @msg <> ''
		PRINT(@msg)

	DROP TABLE #Message
END
GO

