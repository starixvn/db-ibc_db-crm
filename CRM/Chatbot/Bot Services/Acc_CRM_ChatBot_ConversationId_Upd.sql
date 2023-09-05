/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_ChatBot_ConversationId_Upd] 
	@NewConversationId	NVARCHAR(200)
	,@OldConversationId NVARCHAR(200)
	,@ChannelId			TINYINT
	,@UpdatedBy			VARCHAR(200) = ''
	,@ErrCode			INT = 0 OUTPUT
	,@ErrMsg			NVARCHAR(MAX) = '' OUTPUT
	,@LoginIP			VARCHAR(45) = ''
AS
/*
	Created: 20230627@Malcolm
	Task :  User update conversationId for telegram group
	DB: DBCRM/bodb_CRM
	Original:
		Revisions:
			- 20230627@Malcolm: Initialize SPs [Redmine: #179119]
		Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @OldConversationGroupName NVARCHAR(1000) = '', @NewValues NVARCHAR(MAX) ='' , @OldValues NVARCHAR(MAX) = '', @StarixIT INT = 10278938

	IF ISNULL(@NewConversationId, '') = ISNULL(@OldConversationId, '')
		RETURN

	BEGIN TRY
		UPDATE dbo.crmConversationGroup WITH(ROWLOCK, UPDLOCK)
			SET ConversationId = @NewConversationId
		WHERE ConversationId = @OldConversationId AND ChannelId = @ChannelId  AND ChatTypeId = 1 AND IsDeleted = 0
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR, @ErrMsg = ERROR_MESSAGE()
		RETURN
	END CATCH

	SELECT @OldValues = CONVERT(NVARCHAR(MAX), (SELECT @OldConversationId AS '@ConversationId', @UpdatedBy AS '@UpdatedBy' FOR XML PATH('BotService'), ROOT('Acc_CRM_ChatBot_ConversationId_Upd')))
		  ,@NewValues = CONVERT(NVARCHAR(MAX), (SELECT @NewConversationId AS '@ConversationId', @UpdatedBy AS '@UpdatedBy' FOR XML PATH('BotService'), ROOT('Acc_CRM_ChatBot_ConversationId_Upd')))

    -- Write Logs
	EXEC dbo.WriteLog_UserLog_crmUserLog_RunSP
			@UserID = @StarixIT,
			@CustID = NULL,
			@ActionID = 1019,
			@IP = @LoginIP,
			@NewValues = @NewValues,
			@OldValues = @OldValues,
			@CustIds = NULL,
			@ReferenceIds = NULL
END
GO