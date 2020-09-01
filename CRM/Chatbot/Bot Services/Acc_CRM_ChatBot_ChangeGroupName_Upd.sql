/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_ChatBot_ChangeGroupName_Upd] @ConversationId NVARCHAR(200)
	,@DisplayName NVARCHAR(1000)
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

	IF (
			NOT EXISTS (
				SELECT 1
				FROM dbo.crmConversationGroup cg WITH (NOLOCK)
				WHERE cg.ConversationId = @ConversationId
				)
			)
	BEGIN
		SELECT @ErrCode = 1
			,@ErrMsg = '[Acc_CRM_ChatBot_ChangeGroupName_Upd] This group with ID: ' + @ConversationId + ' does not existed!'

		RETURN
	END

	UPDATE dbo.crmConversationGroup
	WITH (
			ROWLOCK
			,UPDLOCK
			)

	SET ConversationGroupName = @DisplayName
		,UpdatedDate = GETDATE()
	WHERE ConversationId = @ConversationId

	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrCode = @@ERROR
			,@ErrMsg = '[Acc_CRM_ChatBot_ChangeGroupName_Upd] The error occured. Cannot update name'
	END
			-- Write Logs
END
GO