/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_ChatBot_ChatTypeMappingRemark_Upd]
	@ConversationGroupId	SMALLINT
	,@Remark				NVARCHAR(2000)
	,@UserId				INT
	,@ErrCode				INT = 0 OUTPUT
	,@ErrMsg				NVARCHAR(2000) = '' OUTPUT
	,@LoginIP				NVARCHAR(20) = ''
AS
/*
	Created: 20221019@Malcolm
	Task :  Update Remark of group chat mapping
	DB: DBCRM/bodb_CRM
	Original:
		Revisions:
			- 20221019@Malcolm: Initialize SPs [Redmine: #179240]
		Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @CustIds VARCHAR(MAX), @OldValues NVARCHAR(MAX), @NewValues NVARCHAR(MAX), @OldRemark NVARCHAR(2000), @ReferenceIds VARCHAR(MAX), @ConversationGroupName NVARCHAR(1000)

	SELECT @OldRemark = Remark, @ConversationGroupName = ConversationGroupName FROM dbo.crmConversationGroup cg WITH(NOLOCK) WHERE cg.ConversationGroupId = @ConversationGroupId

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
								@OldRemark AS '@Remark'
							    ,@ConversationGroupId AS '@ConversationGroupId'
								,@ConversationGroupName AS '@ConversationGroupName' 
							FOR XML PATH('Acc_CRM_ChatBot_ChatTypeMappingRemark_Upd')
						))

	SELECT @NewValues = CONVERT(NVARCHAR(MAX), 
						(
							SELECT 
								@Remark AS '@Remark'
								,@ConversationGroupId AS '@ConversationGroupId'
								,@ConversationGroupName AS '@ConversationGroupName'  
							  FOR XML PATH('Acc_CRM_ChatBot_ChatTypeMappingRemark_Upd')
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

