/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_ChatBot_ConversationGroup_Del]
	@ConversationGroupId	SMALLINT
	,@IsDeleted				BIT
	,@UserId				INT
	,@ErrCode				INT = 0 OUTPUT
	,@ErrMsg				NVARCHAR(2000) = '' OUTPUT
	,@LoginIP				VARCHAR(45) = ''
AS
/*
	Created: 20200810@Malcolm
	Task : CRM - Headline Notification - Chat Type Mapping - Action - Delete
	DB: DBCRM/bodb_CRM
	Original:
		Revisions:
			- 20200810@Malcolm: Initialize SPs [Redmine: #130544]
			- 20230508@Malcolm: Offer Telegram bot service for Headlines [RedmineId : #179119]

		Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @CustIds VARCHAR(1000), @OldValues NVARCHAR(MAX), @NewValues NVARCHAR(MAX),	@OldIsDeleted BIT, @IsActive BIT, @ReferenceIds VARCHAR(1000), @ConversationGroupName NVARCHAR(1000)

	SELECT @OldIsDeleted = IsDeleted, @ConversationGroupName= ConversationGroupName, @IsActive = IsActive
	FROM dbo.crmConversationGroup cg WITH(NOLOCK) 
	WHERE cg.ConversationGroupId = @ConversationGroupId

	IF @IsDeleted = @OldIsDeleted
		RETURN

	IF @IsActive = 1 AND @IsDeleted = 1
	BEGIN
		SELECT @ErrCode = 101, @ErrMsg = 'Group is active so cannot delete.'
		RETURN
	END

	BEGIN TRY
		UPDATE dbo.crmConversationGroup WITH(ROWLOCK)
			SET IsDeleted = @IsDeleted
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
							    ,@OldIsDeleted AS '@Deleted'
							FOR XML PATH('ConversationGroup'), ROOT('Acc_CRM_ChatBot_ConversationGroup_Del')
						))
	
	SELECT @NewValues = CONVERT(NVARCHAR(MAX), 
						(
							SELECT 
								@ConversationGroupId AS '@Id'
								,@ConversationGroupName AS '@Name'
								,@IsDeleted AS '@Deleted'
							FOR XML PATH('ConversationGroup'), ROOT('Acc_CRM_ChatBot_ConversationGroup_Del')
						))

	EXEC dbo.WriteLog_UserLog_crmUserLog_RunSP
			@UserID = @UserID,
			@CustID = NULL,
			@ActionID = 1011,
			@IP = @LoginIP,
			@NewValues = @NewValues,
			@OldValues = @OldValues,
			@CustIds = @CustIds,
			@ReferenceIds = @ReferenceIds
	
END
GO

