/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_ChatBot_AddBotToGroup_Ins] 
	@BotId				BIGINT
	,@BotName			NVARCHAR(200)
	,@ConversationId	VARCHAR(200)
	,@GroupName			NVARCHAR(1000)
	,@ChannelId			TINYINT
	,@UpdatedBy			VARCHAR(200) = ''
	,@Username			VARCHAR(32) = ''
	,@ErrCode			INT = 0 OUTPUT
	,@ErrMsg			NVARCHAR(MAX) = '' OUTPUT
	,@LoginIP			VARCHAR(45) = ''
AS
/*
	Created: 20200901@Oliver.Dang
	Task : User add Bot to Group by UI of telegram or letstalk (Use this function only for group, not for personal)
	DB: DBCRM/bodb_CRM
	Original:
		Revisions:
			- 20200901@Oliver: Initialize SPs [Redmine: #130544]
			- 20230508@Malcolm: Offer Telegram bot service for Headlines [RedmineId : #179119]

		Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @ConversationGroupId INT, @StarixIT INT = 10278938, @IsExistedGroup BIT = 1, @IsExistedBot BIT = 1, @NewValues NVARCHAR(MAX) = '', @IsExistedMapping BIT = 1

	BEGIN TRY
		IF NOT EXISTS (SELECT 1 FROM dbo.crmConversationBot b WITH (NOLOCK) WHERE b.BotId = @BotId AND b.ChannelId = @ChannelId)
		BEGIN
			INSERT INTO dbo.crmConversationBot (BotId, BotName, ChannelId)
			VALUES (@BotId, @BotName, @ChannelId)
			
			SELECT @IsExistedBot = 0
		END

		IF NOT EXISTS (SELECT 1 FROM dbo.crmConversationGroup cp WITH (NOLOCK) WHERE cp.ConversationId = @ConversationId AND cp.ChannelId = @ChannelId)
		BEGIN
			INSERT INTO dbo.crmConversationGroup (ConversationId, ConversationGroupName, ChatTypeId, Creator, CreatedDate, ChannelId, Username, IsActive, IsDeleted)
			VALUES (@ConversationId, @GroupName, 1, @StarixIT, GETDATE(), @ChannelId, @Username, 1, 0)

			SELECT @IsExistedGroup = 0
		END
		
		SELECT @ConversationGroupId = ConversationGroupId FROM dbo.crmConversationGroup WITH(NOLOCK) WHERE ConversationId = @ConversationId AND ChannelId = @ChannelId

		IF NOT EXISTS (SELECT 1 FROM dbo.crmConversationGroupBot WITH(NOLOCK) WHERE ConversationGroupId = @ConversationGroupId)
		BEGIN
			INSERT INTO dbo.crmConversationGroupBot (ConversationGroupId, BotId)
			VALUES (@ConversationGroupId, @BotId)

			SET @IsExistedMapping = 0
		END

	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR, @ErrMsg = '[Acc_CRM_ChatBot_AddBotToGroup_Ins]' + ERROR_MESSAGE()

		IF @IsExistedBot = 0
			DELETE dbo.crmConversationBot WITH(ROWLOCK, UPDLOCK) WHERE BotId = @BotId AND ChannelId = @ChannelId

		IF @IsExistedGroup = 0
			DELETE dbo.crmConversationGroup WITH(ROWLOCK, UPDLOCK) WHERE ConversationId = @ConversationId AND ChannelId = @ChannelId

		RETURN
	END CATCH

	IF @IsExistedMapping = 1
		RETURN
	
	SELECT @NewValues = CONVERT(NVARCHAR(MAX), 
						(
							SELECT 
								@ConversationGroupId AS '@ConversationGroupId'
								,@GroupName			 AS '@ConversationGroupName'
								,@BotId				 AS '@BotId'
								,@BotName            AS '@BotName' 
								,@ChannelId			 AS '@ChannelId'
								,ChannelName		 AS '@ChannelName'
								,@UpdatedBy			 AS '@UpdatedBy'
							FROM dbo.crmChannel WITH(NOLOCK)
							WHERE ChannelId = @ChannelId
							FOR XML PATH ('BotService'), ROOT('Acc_CRM_ChatBot_AddBotToGroup_Ins')
						))
	-- Write Logs
	EXEC dbo.WriteLog_UserLog_crmUserLog_RunSP
			@UserID = @StarixIT,
			@CustID = NULL,
			@ActionID = 1018,
			@IP = @LoginIP,
			@NewValues = @NewValues,
			@OldValues = '',
			@CustIds = NULL,
			@ReferenceIds = NULL
END
GO