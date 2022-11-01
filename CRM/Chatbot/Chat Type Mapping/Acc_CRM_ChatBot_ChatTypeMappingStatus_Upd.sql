/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_ChatBot_ChatTypeMappingStatus_Upd]
	@ConversationGroupId	SMALLINT
	,@IsActive				BIT
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
		- 20221028@Malcolm: Change logs [RedmineId : #179240]
	Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @CustIds					VARCHAR(1000),
			@OldValues					NVARCHAR(MAX), 
			@NewValues					NVARCHAR(MAX),	
			@__IsActive					BIT,
			@ReferenceIds				VARCHAR(1000),
			@__ConversationGroupName	NVARCHAR(1000)

	SELECT @__IsActive = IsActive
		   ,@__ConversationGroupName= ConversationGroupName 
	FROM dbo.crmConversationGroup cg WITH(NOLOCK) 
	WHERE cg.ConversationGroupId = @ConversationGroupId

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


	SELECT @OldValues = CAST((SELECT @ConversationGroupId AS '@Id', 
									 @__ConversationGroupName AS '@Name',
									 @__IsActive AS '@Active'
							 FOR XML PATH('ConversationGroup'), ROOT('Acc_CRM_ChatBot_ChatTypeMappingStatus_Upd')) AS NVARCHAR(MAX))

	SELECT @NewValues = CAST((SELECT @ConversationGroupId AS '@Id', 
									 @__ConversationGroupName AS '@Name',
									 @IsActive AS '@Active'
							  FOR XML PATH('ConversationGroup'), ROOT('Acc_CRM_ChatBot_ChatTypeMappingStatus_Upd')) AS NVARCHAR(MAX))

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

