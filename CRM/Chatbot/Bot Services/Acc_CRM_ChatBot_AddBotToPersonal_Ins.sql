/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_ChatBot_AddBotToPersonal_Ins] 
	@BotId				BIGINT
	,@BotName			NVARCHAR(200)
	,@ConversationId	VARCHAR(200)
	,@ChannelId			TINYINT
	,@Username			VARCHAR(32)
	,@UpdatedBy			VARCHAR(200) = ''
	,@ErrCode			INT = 0 OUTPUT
	,@ErrMsg			NVARCHAR(MAX) = '' OUTPUT
AS
/*
	Created: 20230523@Malcolm
	Task : Add Bot to personal
	DB: DBCRM/bodb_CRM
	Original:
		Revisions:
			- 20230523@Malcolm: Initialize SPs [Redmine: #179119]

		Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @ConversationGroupId INT = 0, @ChatType TINYINT = 2, @StarixIT INT = 10278938, @IsExistedGroup BIT = 1, @IsExistedBot BIT = 1, @NewValues NVARCHAR(MAX) = '', @IsExistedMapping BIT = 1

	IF @ChannelId = 2 AND ISNULL(@Username, '') = ''
		RETURN

	BEGIN TRY
		IF NOT EXISTS (SELECT 1 FROM dbo.crmConversationBot b WITH (NOLOCK) WHERE b.BotId = @BotId AND b.ChannelId = @ChannelId)
		BEGIN
			INSERT INTO dbo.crmConversationBot (BotId, BotName, ChannelId)
			VALUES (@BotId, @BotName, @ChannelId)
			
			SELECT @IsExistedBot = 0
		END

		IF NOT EXISTS (SELECT 1 FROM dbo.crmConversationPersonal cg WITH (NOLOCK) WHERE cg.ConversationId = @ConversationId AND cg.ChannelId = @ChannelId AND cg.Username = @Username)
		BEGIN
			INSERT INTO dbo.crmConversationPersonal (ConversationId, ChatTypeId, Creator, CreatedDate, ChannelId, Username)
			VALUES (@ConversationId, @ChatType, @StarixIT, GETDATE(), @ChannelId, @Username)

			SELECT @IsExistedGroup = 0
		END

		IF NOT EXISTS (SELECT 1 FROM dbo.crmConversationPersonalBot WITH(NOLOCK) WHERE ConversationId = @ConversationId AND ChannelId = @ChannelId AND BotId = @BotId)
		BEGIN
			INSERT INTO dbo.crmConversationPersonalBot (ConversationId, ChannelId, BotId)
			VALUES (@ConversationId, @ChannelId, @BotId)

			SET @IsExistedMapping = 0
		END

	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR, @ErrMsg = '[Acc_CRM_ChatBot_AddBotToPersonal_Ins]' + ERROR_MESSAGE()

		IF @IsExistedBot = 0
			DELETE dbo.crmConversationBot WITH(ROWLOCK, UPDLOCK) WHERE BotId = @BotId AND ChannelId = @ChannelId

		IF @IsExistedGroup = 0
			DELETE dbo.crmConversationPersonal WITH(ROWLOCK, UPDLOCK) WHERE ConversationId = @ConversationId AND ChannelId = @ChannelId 

		RETURN
	END CATCH
	
	IF @IsExistedMapping = 1
		RETURN

	SELECT @NewValues = CONVERT(NVARCHAR(MAX), 
						(
							SELECT 
								@BotId				 AS '@BotId'
								,@BotName            AS '@BotName' 
								,@ChannelId			 AS '@ChannelId'
								,@ConversationId     AS '@ConversationId'
								,ChannelName		 AS '@ChannelName'
								,@UpdatedBy			 AS '@UpdatedBy'
								,@Username			 AS '@Username'
							FROM dbo.crmChannel WITH(NOLOCK)
							WHERE ChannelId = @ChannelId
							FOR XML PATH ('BotService'), ROOT('Acc_CRM_ChatBot_AddBotToPersonal_Ins')
						))
	-- Write Logs
	EXEC dbo.WriteLog_UserLog_crmUserLog_RunSP
			@UserID = @StarixIT,
			@CustID = NULL,
			@ActionID = 1021,
			@NewValues = @NewValues,
			@OldValues = '',
			@CustIds = NULL,
			@ReferenceIds = NULL
END
GO