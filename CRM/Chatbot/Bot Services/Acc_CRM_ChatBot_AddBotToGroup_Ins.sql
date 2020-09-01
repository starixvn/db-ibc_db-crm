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

	BEGIN TRY
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

			INSERT INTO dbo.crmConversationGroupBot (
				ConversationGroupId
				,BotId
				)
			VALUES (
				@ConversationGroupId
				,@BotId
				)
		END
	END TRY

	BEGIN CATCH
		SELECT @ErrCode = @@ERROR
			,@ErrMsg = ERROR_NUMBER()

		IF @ConversationGroupId <> 0
		BEGIN
			DELETE dbo.crmConversationGroup
			WITH (
					ROWLOCK
					,UPDLOCK
					)
			WHERE ConversationGroupId = @ConversationGroupId

			DELETE dbo.crmConversationGroupBot
			WITH (
					ROWLOCK
					,UPDLOCK
					)
			WHERE ConversationGroupId = @ConversationGroupId
		END
	END CATCH
		-- Write Logs
END
GO