/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_ChatBot_ChatTypeMapping_Ins]
	@BotId					INT
	,@ConversationGroupName	NVARCHAR(1000) 
	,@ChatTypeId			TINYINT = NULL
	,@RecipientTypeId       TINYINT
	,@HeadlineIds			VARCHAR(200) 
	,@RecipientId			INT
	,@LetstalkID			VARCHAR(200)
	,@LanguageId			INT	
	,@Remark				NVARCHAR(2000)
	,@UserId				INT
	,@ErrCode				INT = 0 OUTPUT
	,@ErrMsg				NVARCHAR(2000) = '' OUTPUT
AS
/*
Created: 20200810@Malcolm
Task :  Insert Peronsal Chat Mapping
DB: DBCRM/bodb_CRM
Original:
	Revisions:
		- 20200810@Malcolm: Initialize SPs [Redmine: #130544]
	Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @ConversationGroupId INT = 0, @Existing_GroupName NVARCHAR(1000) = ''

	DECLARE @_HeadlineIds TABLE (HeadlineID INT)	

	INSERT INTO @_HeadlineIds (HeadlineID)
	SELECT f.val
	FROM  bodb02.dbo.f_StringSplit(@HeadlineIds, ',') f 

	-- check validation
	SELECT TOP(1) @Existing_GroupName = ConversationGroupName FROM dbo.crmConversationGroup g WITH(NOLOCK) WHERE g.ConversationId = @LetstalkID

	IF ISNULL(@Existing_GroupName,'') <> ''
	BEGIN
		SELECT @ErrCode = 101, @ErrMsg = 'The ' + @Existing_GroupName  +' has been set ' + @LetstalkID +' to receive notification!'
		RETURN
	END

	IF EXISTS (SELECT 1
			   FROM @_HeadlineIds h
		       WHERE NOT EXISTS(
					SELECT 1
					FROM dbo.crmRecipient r WITH(NOLOCK)
						INNER JOIN  dbo.crmPicManagement m  WITH(NOLOCK) ON m.PicID = r.SourceId 
					WHERE r.RecipientId = @RecipientId
						AND m.HeadlineID = h.HeadlineID
						AND r.DataSource = 'bodb_CRM.dbo.crmPIC'))
	BEGIN
		SELECT @ErrCode = 102, @ErrMsg = 'The relationship between headline and recipient do not exist.Please check again!'
		RETURN
	END
	
	BEGIN TRY
		INSERT INTO dbo.crmConversationGroup
		(
			ConversationId
			,ConversationGroupName
			,ChatTypeId
			,Creator
			,CreatedDate
			,UpdatedDate
			,LanguageId
			,Remark
			,IsActive
		)
		VALUES
		(
			@LetstalkID
			,@ConversationGroupName
			,@ChatTypeId
			,@UserId
			,GETDATE()
			,GETDATE()
			,@LanguageId
			,@Remark
			,1
		)

		SELECT @ConversationGroupId = SCOPE_IDENTITY()

		INSERT INTO dbo.crmConversationGroupBot
		(
			ConversationGroupId
			,BotId
		)
		VALUES 
		(
			@ConversationGroupId
			,@BotId
		)

		INSERT INTO dbo.crmConversationGroupRecipient
		(
			ConversationGroupId
			,RecipientId
		)
		VALUES
		(
			@ConversationGroupId
			,@RecipientId
		)

		INSERT INTO dbo.crmConversationGroupHeadline
		(
			ConversationGroupId
			,HeadlineId
		)
		SELECT 
			@ConversationGroupId
			,f.Val
		FROM bodb02.dbo.f_StringSplit(@HeadlineIds,',') f
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR, @ErrMsg = ERROR_NUMBER()

		IF @ConversationGroupId <> 0
		BEGIN
			DELETE dbo.crmConversationGroup WITH(ROWLOCK, UPDLOCK)
			WHERE ConversationGroupId = @ConversationGroupId

			DELETE dbo.crmConversationGroupBot WITH(ROWLOCK, UPDLOCK)
			WHERE ConversationGroupId = @ConversationGroupId

			DELETE dbo.crmConversationGroupRecipient WITH(ROWLOCK, UPDLOCK)
			WHERE ConversationGroupId = @ConversationGroupId
		END 

		RETURN
	END CATCH

	-- Write Logs
	
END
GO

