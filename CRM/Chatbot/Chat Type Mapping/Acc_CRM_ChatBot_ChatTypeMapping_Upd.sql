/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_ChatBot_ChatTypeMapping_Upd]
	@ConversationGroupId	INT
	,@BotId					INT
	,@ConversationGroupName	NVARCHAR(1000) 
	,@RecipientTypeId       TINYINT
	,@HeadlineIds			VARCHAR(200) 
	,@RecipientIds			VARCHAR(200)
	,@LetstalkID			VARCHAR(200)
	,@LanguageId			INT	
	,@Remark				NVARCHAR(2000)
	,@UserId				INT
	,@ErrCode				INT = 0 OUTPUT
	,@ErrMsg				NVARCHAR(2000) = '' OUTPUT
AS
/*
Created: 20200810@Malcolm
Task :  Update personal/group chat mapping
DB: DBCRM/bodb_CRM
Original:
	Revisions:
		- 20200810@Malcolm: Initialize SPs [Redmine: #130544]
	Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @Existing_GroupName NVARCHAR(1000) = '',@NumberOfRecipients BIT = 0, @SourceId INT 

	CREATE TABLE  #Recipients  (ID INT PRIMARY KEY CLUSTERED)
	CREATE TABLE  #Headlines  (ID INT PRIMARY KEY CLUSTERED)

	CREATE TABLE #Tmp
	(
		ConversationGroupId		SMALLINT
		,ConversationId			VARCHAR(200)
		,ConversationGroupName	NVARCHAR(1000)
		,ChatTypeId				TINYINT
		,Creator				INT
		,CreatedDate			DATETIME
		,UpdatedDate			DATETIME
		,LanguageId				INT
		,Remark					NVARCHAR(2000)
		,IsActive				BIT
		,BotId					INT
		,RecipientId			INT
		,HeadlineId				INT
		,Type                   SMALLINT
	)

	INSERT INTO #Recipients(ID) 
	SELECT val
	FROM bodb02.dbo.f_StringSplit(@RecipientIds, ',')

	INSERT INTO #Headlines(ID) 
	SELECT val
	FROM bodb02.dbo.f_StringSplit(@HeadlineIds, ',')

	-- check validation
	SELECT TOP(1) @Existing_GroupName = ConversationGroupName 
	FROM dbo.crmConversationGroup g WITH(NOLOCK) 
	WHERE g.ConversationId = @LetstalkID AND g.ConversationGroupId <> @ConversationGroupId

	IF ISNULL(@Existing_GroupName,'') <> ''
	BEGIN
		SELECT @ErrCode = 101, @ErrMsg = 'The ' + @Existing_GroupName  +' has been set ' + @LetstalkID +' to receive notification!'
		RETURN
	END
	
	BEGIN TRY
		UPDATE dbo.crmConversationGroup WITH(ROWLOCK)
		SET ConversationGroupName = @ConversationGroupName
			,ConversationId = @LetstalkID
			,Remark = @Remark
			,UpdatedDate = GETDATE()
			,LanguageId = @LanguageId
		OUTPUT	deleted.ConversationId, 
				deleted.ConversationGroupName, 
				deleted.ChatTypeId, 
				deleted.UpdatedDate, 
				deleted.LanguageId, 
				deleted.Remark, 1
			INTO #Tmp 
			   (ConversationId, 
				ConversationGroupName, 
				ChatTypeId, 
				UpdatedDate, 
				LanguageId, 
				Remark, 
				Type)
		WHERE ConversationGroupId = @ConversationGroupId

		UPDATE dbo.crmConversationGroupBot WITH(ROWLOCK)
			SET BotId = @BotId
		OUTPUT deleted.BotId, 2
			INTO #Tmp(BotId, Type)
		WHERE ConversationGroupId = @ConversationGroupId

		DELETE dbo.crmConversationGroupRecipient WITH(ROWLOCK,UPDLOCK)
		OUTPUT deleted.RecipientId, 3
			INTO #Tmp(RecipientId, Type)
		WHERE ConversationGroupId = @ConversationGroupId 

		DELETE dbo.crmConversationGroupHeadline WITH(ROWLOCK,UPDLOCK)
		OUTPUT deleted.HeadlineId, 4
			INTO #Tmp(HeadlineId, Type)
		WHERE ConversationGroupId = @ConversationGroupId 	

		INSERT INTO dbo.crmConversationGroupRecipient
		(
			ConversationGroupId
			,RecipientId
		)
		SELECT 
			@ConversationGroupId,
			ID
		FROM #Recipients

		INSERT INTO dbo.crmConversationGroupHeadline
		(
			ConversationGroupId
			,HeadlineId
		)
		SELECT 
			@ConversationGroupId
			,ID
		FROM #Headlines
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR, @ErrMsg = ERROR_NUMBER()
		IF EXISTS(SELECT 1 FROM #Tmp WHERE Type = 1)
			UPDATE g
			SET g.ConversationGroupName = t.ConversationGroupName
				,g.ChatTypeId = t.ChatTypeId
				,g.ConversationId = t.ConversationId
				,g.Remark = t.Remark
				,g.UpdatedDate = t.UpdatedDate
				,g.LanguageId = t.LanguageId
			FROM dbo.crmConversationGroup g WITH(ROWLOCK)
				,#Tmp t
			WHERE t.Type = 1 AND g.ConversationGroupId = @ConversationGroupId

		IF EXISTS(SELECT 1 FROM #Tmp WHERE Type = 2)
			UPDATE b
				SET b.BotId = t.BotId
			FROM dbo.crmConversationGroupBot b WITH(ROWLOCK)
				,#Tmp t
			WHERE t.Type = 2 AND b.ConversationGroupId = @ConversationGroupId

		IF EXISTS(SELECT 1 FROM #Tmp WHERE Type = 3)
		BEGIN
			DELETE dbo.crmConversationGroupRecipient WITH(ROWLOCK, UPDLOCK)
			WHERE ConversationGroupId = @ConversationGroupId

			INSERT INTO dbo.crmConversationGroupRecipient
			(
				ConversationGroupId
				,RecipientId
			)
			SELECT 
				@ConversationGroupId
				,RecipientId
			FROM #Tmp
			WHERE Type = 3
		END
		
		IF EXISTS(SELECT 1 FROM #Tmp WHERE Type = 4)
		BEGIN
			DELETE dbo.crmConversationGroupHeadline WITH(ROWLOCK,UPDLOCK)
			WHERE ConversationGroupId = @ConversationGroupId 	

			INSERT INTO dbo.crmConversationGroupHeadline
			(
				ConversationGroupId
				,HeadlineId
			)
			SELECT 
				@ConversationGroupId
				,HeadlineId
			FROM #Tmp
			WHERE Type = 4
		END
		RETURN
	END CATCH

	-- Write Logs
	DROP TABLE #Headlines
	DROP TABLE #Recipients
	DROP TABLE #Tmp
	
END
GO

