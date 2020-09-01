/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_KickOutBotFromGroup_Del] @BotId INT
	,@ConversationId NVARCHAR(200)
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(2000) = '' OUTPUT
AS
/*
Created: 20200901@Oliver.Dang
Task :  Update group name
DB: DBCRM/bodb_CRM
Original:
	Revisions:
		- 20200901@Oliver: Initialize SPs [Redmine: #130544]
	Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	BEGIN TRY
		IF (
				NOT EXISTS (
					SELECT 1
					FROM dbo.crmConversationGroup cg WITH (NOLOCK)
					INNER JOIN dbo.crmConversationGroupBot gb WITH (NOLOCK) ON cg.ConversationGroupId = gb.ConversationGroupId
					WHERE cg.ConversationId = @ConversationId
					)
				)
		BEGIN
			SELECT @ErrCode = 1
				,@ErrMsg = 'This group with ID: ' + @ConversationId + ' does not existed OR no relationship between group and bot ID ' + @BotId

			RETURN
		END

		DECLARE @ConversationGroupId INT = 0

		SELECT @ConversationGroupId = cg.ConversationGroupId
		FROM dbo.crmConversationGroup cg WITH (NOLOCK)
		WHERE cg.ConversationId = @ConversationId

		DELETE dbo.crmConversationGroupBot
		WITH (
				ROWLOCK
				,UPDLOCK
				)
		WHERE ConversationGroupId = @ConversationGroupId
			AND BotId = @BotId
	END TRY

	BEGIN CATCH
		SELECT @ErrCode = @@ERROR
			,@ErrMsg = ERROR_NUMBER()
	END CATCH
		-- Write Logs
END
GO