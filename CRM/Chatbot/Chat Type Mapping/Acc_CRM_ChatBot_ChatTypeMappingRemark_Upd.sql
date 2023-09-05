/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_ChatBot_ChatTypeMappingRemark_Upd]
	@ConversationGroupId	SMALLINT
	,@Remark				NVARCHAR(2000)
	,@UserId				INT
	,@ErrCode				INT = 0 OUTPUT
	,@ErrMsg				NVARCHAR(2000) = '' OUTPUT
	,@LoginIP				VARCHAR(45) = ''
AS
/*
	Created: 20221019@Malcolm
	Task : CRM - Headline Notification - Chat Type Mapping - Remark - Edit
	DB: DBCRM/bodb_CRM
	Original:
		Revisions:
			- 20221019@Malcolm: Initialize SPs [Redmine: #179240]
			- 20221028@Malcolm: Change logs [RedmineId : #179240]
			- 20230508@Malcolm: Offer Telegram bot service for Headlines [RedmineId : #179119]

		Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @CustIds VARCHAR(MAX), @OldValues NVARCHAR(MAX), @NewValues NVARCHAR(MAX), @OldRemark NVARCHAR(2000), @ReferenceIds VARCHAR(MAX), @ConversationGroupName NVARCHAR(1000)

	SELECT @OldRemark = Remark, @ConversationGroupName = ConversationGroupName FROM dbo.crmConversationGroup cg WITH(NOLOCK) WHERE cg.ConversationGroupId = @ConversationGroupId

	IF EXISTS (SELECT 1 FROM dbo.crmConversationGroup g WITH(NOLOCK) WHERE g.ConversationGroupId = @ConversationGroupId AND g.IsDeleted = 1)
	BEGIN
		SELECT @ErrCode = 101, @ErrMsg = 'The group has been deleted and cannot be updated.'
		RETURN
	END

	IF ISNULL(@Remark, '') = ISNULL(@OldRemark, '')
		RETURN

	BEGIN TRY
		UPDATE dbo.crmConversationGroup WITH(ROWLOCK)
			SET Remark = @Remark
		WHERE ConversationGroupId = @ConversationGroupId
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR, @ErrMsg = ERROR_MESSAGE()
		RETURN
	END CATCH

	-- Write Logs
	SELECT @CustIds = STRING_AGG (CONVERT(VARCHAR(50), g.HeadlineId), ',') FROM dbo.crmConversationGroupHeadline g WITH(NOLOCK) WHERE g.ConversationGroupId = @ConversationGroupId
	SELECT @ReferenceIds = STRING_AGG (CONVERT(VARCHAR(50), g.RecipientId), ',') FROM dbo.crmConversationGroupRecipient g WITH(NOLOCK) WHERE g.ConversationGroupId = @ConversationGroupId
	SELECT @OldValues = CONVERT(NVARCHAR(MAX),
						(
							SELECT 
								@ConversationGroupId AS '@Id'
								,@ConversationGroupName AS '@Name' 
								,@OldRemark AS '@Remark'
							FOR XML PATH('ConversationGroup'), ROOT('Acc_CRM_ChatBot_ChatTypeMappingRemark_Upd')
						))

	SELECT @NewValues = CONVERT(NVARCHAR(MAX), 
						(
							SELECT 
								@ConversationGroupId AS '@Id'
								,@ConversationGroupName AS '@Name' 
								,@Remark AS '@Remark'
							  FOR XML PATH('ConversationGroup'), ROOT('Acc_CRM_ChatBot_ChatTypeMappingRemark_Upd')
						))

	EXEC dbo.WriteLog_UserLog_crmUserLog_RunSP
			@UserID = @UserID,
			@CustID = NULL,
			@ActionID = 1010,
			@IP = @LoginIP,
			@NewValues = @NewValues,
			@OldValues = @OldValues,
			@CustIds = @CustIds,
			@ReferenceIds = @ReferenceIds
	
END
GO

