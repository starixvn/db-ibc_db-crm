/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_ChatBot_ConversationGroup_Del]
	@ConversationGroupId	SMALLINT
	,@IsDeleted				BIT
	,@UserId				INT
	,@ErrCode				INT = 0 OUTPUT
	,@ErrMsg				NVARCHAR(2000) = '' OUTPUT
	,@LoginIP				NVARCHAR(20) = ''
AS
/*
	Created: 20200810@Malcolm
	Task :  Update Status of group chat mapping
	DB: DBCRM/bodb_CRM
	Original:
		Revisions:
			- 20200810@Malcolm: Initialize SPs [Redmine: #130544]
		Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @CustIds					VARCHAR(1000),
			@OldValues					NVARCHAR(MAX), 
			@NewValues					NVARCHAR(MAX),	
			@__IsDeleted				BIT,
			@__IsActive					BIT,
			@ReferenceIds				VARCHAR(1000),
			@__ConversationGroupName	NVARCHAR(1000)

	SELECT @__IsDeleted = IsDeleted, @__ConversationGroupName= ConversationGroupName, @__IsActive = IsActive
	FROM dbo.crmConversationGroup cg WITH(NOLOCK) 
	WHERE cg.ConversationGroupId = @ConversationGroupId

	IF @IsDeleted = @__IsDeleted
		RETURN

	IF @__IsActive = 1 AND @IsDeleted = 1
	BEGIN
		SELECT @ErrCode = 101, @ErrMsg = 'Group is active so can''t delete.'
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
	SELECT @CustIds = STUFF((
				SELECT ','  + CONVERT(VARCHAR(20), cgh.HeadlineId)
				FROM dbo.crmConversationGroupHeadline cgh WITH(NOLOCK)
				WHERE cgh.ConversationGroupId = @ConversationGroupId
				FOR XML PATH('')),1,1,'')

	SELECT @ReferenceIds = STUFF((
				SELECT ','  + CONVERT(VARCHAR(20), cgr.RecipientId)
				FROM dbo.crmConversationGroupRecipient cgr WITH(NOLOCK)
				WHERE cgr.ConversationGroupId = @ConversationGroupId
				FOR XML PATH('')),1,1,'')


	SELECT @OldValues = CAST((SELECT @__IsDeleted AS '@Deleted' FOR XML PATH('Acc_CRM_ChatBot_ChatTypeMappingStatus_Upd')) AS NVARCHAR(MAX))

	SELECT @NewValues = CAST((SELECT @IsDeleted AS '@Deleted'   FOR XML PATH('Acc_CRM_ChatBot_ChatTypeMappingStatus_Upd')) AS NVARCHAR(MAX))

	EXEC dbo.WriteLog_UserLog_crmUserLog_RunSP
			@UserID = @UserID,
			@CustID = @ConversationGroupId,
			@ActionID = 1011,
			@IP = @LoginIP,
			@NewValues = @NewValues,
			@OldValues = @OldValues,
			@CustIds = @CustIds,
			@ReferenceIds = @ReferenceIds
	
END
GO

