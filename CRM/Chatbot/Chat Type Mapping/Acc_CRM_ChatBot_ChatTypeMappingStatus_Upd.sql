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
	Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @__IsActive BIT, 
			@__ConversationGroupName NVARCHAR(1000),
			@OldValues NVARCHAR(MAX), 
			@NewValues NVARCHAR(MAX)

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

	SELECT @OldValues = CAST((SELECT @__IsActive AS '@IsActive', 
									 @ConversationGroupId AS '@ConversationGroupId', 
									 @__ConversationGroupName AS '@ConversationGroupName' 
							 FOR XML PATH('Acc_CRM_ChatBot_ChatTypeMappingStatus_Upd')) AS NVARCHAR(MAX))

	SELECT @NewValues = CAST((SELECT @IsActive AS '@IsActive', 
									 @ConversationGroupId AS '@ConversationGroupId', 
									 @__ConversationGroupName AS '@ConversationGroupName'  
							  FOR XML PATH('Acc_CRM_ChatBot_ChatTypeMappingStatus_Upd')) AS NVARCHAR(MAX))

	EXEC dbo.WriteLog_UserLog_crmUserLog_RunSP
			@UserID = @UserID,
			@CustID = @ConversationGroupId,
			@ActionID = 1009,
			@IP = @LoginIP,
			@NewValues = @NewValues
	
END
GO

