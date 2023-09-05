/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_ChatBot_KickOutBotFromGroup_Del] 
	@BotId				BIGINT
	,@ConversationId	NVARCHAR(200)
	,@ChannelId			TINYINT
	,@UpdatedBy			VARCHAR(200)
	,@ErrCode			INT = 0 OUTPUT
	,@ErrMsg			NVARCHAR(MAX) = '' OUTPUT
	,@LoginIP			VARCHAR(45) = ''
AS
/*
	Created: 20200901@Oliver.Dang
	Task :  KickOut Bot From Group
	DB: DBCRM/bodb_CRM
	Original:
		Revisions:
			- 20200901@Oliver: Initialize SPs [Redmine: #130544]
			- 20230508@Malcolm: Offer Telegram bot service for Headlines [RedmineId : #179119]

		Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @OldValues NVARCHAR(MAX) = '', @ConversationGroupId INT = 0, @StarixIT INT = 10278938

	SELECT @ConversationGroupId = cg.ConversationGroupId FROM dbo.crmConversationGroup cg WITH (NOLOCK) WHERE cg.ConversationId = @ConversationId AND cg.ChannelId = @ChannelId
	
	SELECT @OldValues = CONVERT(NVARCHAR(MAX), 
						(
							SELECT 
								g.ConversationGroupName AS '@ConversationGroupName'
								,g.ConversationGroupId	AS '@ConversationGroupId'
								,b.BotId				AS '@BotId'
								,b.BotName				AS '@BotName'
								,@UpdatedBy				AS '@UpdatedBy'
							FROM dbo.crmConversationGroupBot cgb WITH(NOLOCK)
								INNER JOIN dbo.crmConversationGroup g WITH(NOLOCK) ON g.ConversationGroupId = cgb.ConversationGroupId 
								INNER JOIN dbo.crmConversationBot b WITH(NOLOCK) ON b.BotId = cgb.BotId AND b.ChannelId = g.ChannelId
							WHERE cgb.ConversationGroupId = @ConversationGroupId AND cgb.BotId = @BotId AND b.ChannelId = @ChannelId
							FOR XML PATH ('BotService'), ROOT('Acc_CRM_ChatBot_KickOutBotFromGroup_Del')
						))
						
	BEGIN TRY
		DELETE dbo.crmConversationGroupBot WITH (ROWLOCK, UPDLOCK)
		WHERE ConversationGroupId = @ConversationGroupId AND BotId = @BotId
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR, @ErrMsg = '[Acc_CRM_ChatBot_KickOutBotFromGroup_Del]' + ERROR_MESSAGE()
		RETURN
	END CATCH
	
	-- Write Logs
	EXEC dbo.WriteLog_UserLog_crmUserLog_RunSP
			@UserID = @StarixIT,
			@CustID = NULL,
			@ActionID = 1020,
			@IP = @LoginIP,
			@NewValues = '',
			@OldValues = @OldValues,
			@CustIds = NULL,
			@ReferenceIds = NULL
END
GO