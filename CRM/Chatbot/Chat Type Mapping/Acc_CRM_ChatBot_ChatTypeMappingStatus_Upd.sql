/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_ChatBot_ChatTypeMappingStatus_Upd]
	@ConversationGroupId	SMALLINT
	,@IsActive				BIT
	,@UserId				INT
	,@ErrCode				INT = 0 OUTPUT
	,@ErrMsg				NVARCHAR(2000) = '' OUTPUT
	,@LoginIP				VARCHAR(45) = ''
AS
/*
	Created: 20200810@Malcolm
	Task : CRM - Headline Notification - Chat Type Mapping - Active - Checkbox
	DB: DBCRM/bodb_CRM
	Original:
		Revisions:
			- 20200810@Malcolm: Initialize SPs [Redmine: #130544]
			- 20221028@Malcolm: Change logs [RedmineId : #179240]
			- 20230508@Malcolm: Offer Telegram bot service for Headlines [RedmineId : #179119]

		Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @CustIds VARCHAR(1000), @OldValues NVARCHAR(MAX), @NewValues NVARCHAR(MAX),	@OldIsActive BIT, @ReferenceIds VARCHAR(1000), @ConversationGroupName NVARCHAR(1000)

	IF EXISTS (SELECT 1 FROM dbo.crmConversationGroup g WITH(NOLOCK) WHERE g.ConversationGroupId = @ConversationGroupId AND g.IsDeleted = 1)
	BEGIN
		SELECT @ErrCode = 101, @ErrMsg = 'The group has been deleted and cannot be updated.'
		RETURN
	END

	SELECT @OldIsActive = IsActive, @ConversationGroupName= ConversationGroupName FROM dbo.crmConversationGroup cg WITH(NOLOCK) WHERE cg.ConversationGroupId = @ConversationGroupId

	BEGIN TRY
		UPDATE dbo.crmConversationGroup WITH(ROWLOCK)
			SET IsActive = @IsActive
		WHERE ConversationGroupId = @ConversationGroupId
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR, @ErrMsg = ERROR_MESSAGE()
		RETURN
	END CATCH

	-- Write Logs

	SELECT @CustIds = STRING_AGG(CONVERT(VARCHAR(MAX), cgh.HeadlineId), ',') FROM dbo.crmConversationGroupHeadline cgh WITH(NOLOCK) WHERE cgh.ConversationGroupId = @ConversationGroupId

	SELECT @ReferenceIds = STRING_AGG(CONVERT(VARCHAR(MAX), cgr.RecipientId), ',') FROM dbo.crmConversationGroupRecipient cgr WITH(NOLOCK) WHERE cgr.ConversationGroupId = @ConversationGroupId

	SELECT @OldValues = CONVERT(NVARCHAR(MAX),
						(
							SELECT 
								@ConversationGroupId AS '@Id'
								,@ConversationGroupName AS '@Name'
								,@OldIsActive AS '@Active'
							FOR XML PATH('ConversationGroup'), ROOT('Acc_CRM_ChatBot_ChatTypeMappingStatus_Upd')
						))

	SELECT @NewValues = CONVERT(NVARCHAR(MAX), 
						(
							SELECT 
								@ConversationGroupId AS '@Id'
								,@ConversationGroupName AS '@Name'
								,@IsActive AS '@Active'
							FOR XML PATH('ConversationGroup'), ROOT('Acc_CRM_ChatBot_ChatTypeMappingStatus_Upd')
						))

	EXEC dbo.WriteLog_UserLog_crmUserLog_RunSP
			@UserID = @UserID,
			@CustID = NULL,
			@ActionID = 1009,
			@IP = @LoginIP,
			@NewValues = @NewValues,
			@OldValues = @OldValues,
			@CustIds = @CustIds,
			@ReferenceIds = @ReferenceIds
	
END
GO

