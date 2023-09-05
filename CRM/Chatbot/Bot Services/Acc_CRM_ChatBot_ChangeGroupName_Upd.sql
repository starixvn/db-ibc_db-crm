/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_ChatBot_ChangeGroupName_Upd] 
	@ConversationId NVARCHAR(200)
	,@ChannelId		TINYINT
	,@DisplayName	NVARCHAR(1000)
	,@UpdatedBy		VARCHAR(200) = ''
	,@ErrCode		INT = 0 OUTPUT
	,@ErrMsg		NVARCHAR(MAX) = '' OUTPUT
	,@LoginIP		VARCHAR(45) = ''
AS
/*
	Created: 20200901@Oliver.Dang
	Task :  User update group name by UI of telegram or letstalk 
	DB: DBCRM/bodb_CRM
	Original:
		Revisions:
			- 20200901@Oliver: Initialize SPs [Redmine: #130544]
			- 20230508@Malcolm: Offer Telegram bot service for Headlines [RedmineId : #179119]
		Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @OldConversationGroupName NVARCHAR(1000) = '', @NewValues NVARCHAR(MAX) ='' , @OldValues NVARCHAR(MAX) = '', @StarixIT INT = 10278938

	IF NOT EXISTS (SELECT 1 FROM dbo.crmConversationGroup cg WITH (NOLOCK) WHERE cg.ConversationId = @ConversationId AND cg.ChannelId = @ChannelId)
	BEGIN
		SELECT @ErrCode = 1, @ErrMsg = '[Acc_CRM_ChatBot_ChangeGroupName_Upd] This group with ID: ' + @ConversationId + ' does not existed!'
		RETURN
	END
	
	BEGIN TRY
		UPDATE dbo.crmConversationGroup WITH (ROWLOCK, UPDLOCK)
			SET @OldConversationGroupName = ConversationGroupName, ConversationGroupName = @DisplayName, UpdatedDate = GETDATE()
		WHERE ConversationId = @ConversationId AND ChannelId = @ChannelId
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR, @ErrMsg = '[Acc_CRM_ChatBot_ChangeGroupName_Upd]' + ERROR_MESSAGE()
		RETURN
	END CATCH

	SELECT @OldValues = CONVERT(NVARCHAR(MAX), (SELECT @OldConversationGroupName AS '@ConversationGroupName', @UpdatedBy AS '@UpdatedBy' FOR XML PATH('BotService'), ROOT('Acc_CRM_ChatBot_ChangeGroupName_Upd')))
		  ,@NewValues = CONVERT(NVARCHAR(MAX), (SELECT @DisplayName AS '@ConversationGroupName', @UpdatedBy AS '@UpdatedBy' FOR XML PATH('BotService'), ROOT('Acc_CRM_ChatBot_ChangeGroupName_Upd')))

	IF @OldValues = @NewValues
		RETURN

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