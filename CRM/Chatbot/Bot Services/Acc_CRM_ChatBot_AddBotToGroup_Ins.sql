/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_ChatBot_AddBotToGroup_Ins] @BotId INT
	,@BotName NVARCHAR(200)
	,@ConversationId NVARCHAR(200)
	,@GroupName NVARCHAR(1000)
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(2000) = '' OUTPUT
AS
/*
Created: 20200901@Oliver.Dang
Task :  Add bot tp group
DB: DBCRM/bodb_CRM
Original:
	Revisions:
		- 20200901@Oliver: Initialize SPs [Redmine: #130544]
	Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @ConversationGroupId INT = 0
		,@GroupChatType INT = 1
		,@StarixIT INT = 10278938
		,@IsExistedGroup INT = 0

	IF (
			NOT EXISTS (
				SELECT 1
				FROM dbo.crmConversationBot b WITH (NOLOCK)
				WHERE b.BotId = @BotId
				)
			)
	BEGIN
		INSERT INTO dbo.crmConversationBot (
			BotId
			,BotName
			)
		VALUES (
			@BotId
			,@BotName
			)
	END

	IF (
			NOT EXISTS (
				SELECT 1
				FROM dbo.crmConversationGroup cg WITH (NOLOCK)
				WHERE cg.ConversationId = @ConversationId
				)
			)
	BEGIN
		INSERT INTO dbo.crmConversationGroup (
			ConversationId
			,ConversationGroupName
			,ChatTypeId
			,Creator
			,CreatedDate
			,IsActive
			)
		VALUES (
			@ConversationId
			,@GroupName
			,@GroupChatType
			,@StarixIT
			,GETDATE()
			,1
			)

		SELECT @ConversationGroupId = SCOPE_IDENTITY()
	END
	ELSE
	BEGIN
		SELECT @ConversationGroupId = cg.ConversationGroupId
			,@IsExistedGroup = 1
		FROM dbo.crmConversationGroup cg WITH (NOLOCK)
		WHERE cg.ConversationId = @ConversationId
	END

	BEGIN
		INSERT INTO dbo.crmConversationGroupBot (
			ConversationGroupId
			,BotId
			)
		VALUES (
			@ConversationGroupId
			,@BotId
			)
	END

	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrCode = @@ERROR
			,@ErrMsg = '[Acc_CRM_ChatBot_AddBotToGroup_Ins] The errors occurred.'

		IF @ConversationGroupId <> 0
		BEGIN
			DELETE dbo.crmConversationGroup
			WITH (
					ROWLOCK
					,UPDLOCK
					)
			WHERE ConversationGroupId = @ConversationGroupId
				AND @IsExistedGroup = 1

			DELETE dbo.crmConversationGroupBot
			WITH (
					ROWLOCK
					,UPDLOCK
					)
			WHERE ConversationGroupId = @ConversationGroupId
		END
	END
	-- Write Logs
END
GO