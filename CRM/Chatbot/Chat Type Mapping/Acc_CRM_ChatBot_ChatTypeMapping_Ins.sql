/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_ChatBot_ChatTypeMapping_Ins]
	@BotId					INT
	,@ConversationGroupName	NVARCHAR(1000) 
	,@ChatTypeId			TINYINT = NULL
	,@IsTest			    BIT = NULL
	,@RecipientTypeId       TINYINT
	,@HeadlineIds			VARCHAR(MAX) 
	,@RecipientId			INT
	,@LetstalkID			VARCHAR(200)
	,@LanguageId			INT	
	,@Remark				NVARCHAR(2000)
	,@UserId				INT
	,@ErrCode				INT = 0 OUTPUT
	,@ErrMsg				NVARCHAR(2000) = '' OUTPUT
	,@LoginIP				NVARCHAR(20) = ''
AS
/*
	Created: 20200810@Malcolm
	Task :  Insert Peronsal Chat Mapping
	DB: DBCRM/bodb_CRM
	Original:
		Revisions:
			- 20200810@Malcolm: Initialize SPs [Redmine: #130544]
			- 20201126@Malcolm: Change bodb02.dbo.f_StringSplit to dbo.f_CRM_strSplit [Redmine: #144265]
			- 20210811@Malcolm: check headline for Result Amendment [RedmineID: #151509]
			- 20221028@Malcolm: Exclude groups is deleted [RedmineId : #179240]
		Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @ConversationGroupId INT = 0, @Existing_GroupName NVARCHAR(1000) = '',@NewValues NVARCHAR(MAX),
			@__ChatTypeXML XML, @__RecipientTypeXML XML, @__HeadlineXML XML, @__RecipientXML XML, @__LanguageXML XML, @__ConversationGroup XML,
			@ReferenceIds VARCHAR(1000), @__BotXML XML

	DECLARE @_HeadlineIds TABLE (HeadlineID INT)	

	SELECT @ReferenceIds = CAST(@RecipientId AS VARCHAR(1000))

	INSERT INTO @_HeadlineIds (HeadlineID)
	SELECT f.val
	FROM  dbo.f_CRM_strSplit(@HeadlineIds, ',') f 
	WHERE f.val <> ''

	-- check validation
	SELECT TOP(1) @Existing_GroupName = g.ConversationGroupName FROM dbo.crmConversationGroup g WITH(NOLOCK) WHERE g.ConversationId = @LetstalkID AND g.IsDeleted = 0

	IF ISNULL(@Existing_GroupName,'') <> ''
	BEGIN
		SELECT @ErrCode = 101, @ErrMsg = 'The Letstalk ID ' + @LetstalkID  +' has been set to receive notification already!'
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
			,IsTest
			,IsActive
			,IsDeleted
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
			,@IsTest
			,1
			,0
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
		FROM dbo.f_CRM_strSplit(@HeadlineIds,',') f
		WHERE f.val <> ''
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

	SELECT @__BotXML = (
				SELECT cb.BotId AS '@Id', cb.BotName AS '@Name'
				FROM  dbo.crmConversationBot cb WITH(NOLOCK) 
				WHERE cb.BotId = @BotId
				FOR XML PATH('Bot'))

	SELECT @__ChatTypeXML = (
				  SELECT @ChatTypeId AS '@Id', 
					     CASE WHEN @ChatTypeId = 1 THEN 'Group' 
					     ELSE 'Personal' END AS '@Name' 
				  FOR XML PATH('ChatType'))

	SELECT @__RecipientTypeXML = (
				  SELECT rt.RecipientTypeId AS '@Id', rt.RecipientTypeName AS '@Name'
				  FROM dbo.crmRecipientType rt WITH(NOLOCK)
				  WHERE rt.RecipientTypeId = @RecipientTypeId
				  FOR XML PATH('RecipientType'))

	SELECT @__HeadlineXML = (
				  SELECT  f.val AS '@Id', 
				  	   CASE WHEN f.val = 0 THEN 'Not Assigned Group' 
				  	   ELSE c.username END AS '@Name'
				  FROM dbo.f_CRM_strSplit(@HeadlineIds, ',') f
				     LEFT JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON c.custid = f.val
				  WHERE f.val <> ''
				  FOR XML PATH('Headline'))

	SELECT @__LanguageXML = (
				  SELECT @LanguageId AS '@Id', s.SettingValue AS '@Name'
				  FROM dbo.crmSetting s WITH(NOLOCK)
				  WHERE s.SettingID = @LanguageId
				  FOR XML PATH('Language'))

	SELECT @__RecipientXML = (
				  SELECT r.RecipientId AS '@Id', p.Username AS '@Name'
				  FROM dbo.crmRecipient r WITH(NOLOCK)
				  	INNER JOIN dbo.crmPIC p WITH(NOLOCK) ON p.PicID = r.SourceId
				  WHERE r.RecipientId = @RecipientId AND r.DataSource = 'bodb_CRM.dbo.crmPIC'
				  FOR XML PATH('Recipient'))

	SELECT @__ConversationGroup = (
				  SELECT @ConversationGroupId AS '@Id'
						,@ConversationGroupName AS '@Name'
						,@LetstalkID AS '@LetstalkID'
						,@Remark AS '@Remark'
						,@IsTest AS '@IsTest'
						,1  AS '@Active'
						,0  AS '@Deleted'
				 FOR XML PATH('ConversationGroup'))

	SELECT @NewValues = CAST((SELECT  @__ConversationGroup
									  ,@__ChatTypeXML
									  ,@__RecipientTypeXML
									  ,@__HeadlineXML
									  ,@__RecipientXML
									  ,@__LanguageXML
									  ,@__BotXML
							 FOR XML PATH('Acc_CRM_ChatBot_ChatTypeMapping_Ins')
						) AS NVARCHAR(MAX))

	EXEC dbo.WriteLog_UserLog_crmUserLog_RunSP
			@UserID = @UserID,
			@CustID = NULL,
			@ActionID = 1007,
			@IP = @LoginIP,
			@NewValues = @NewValues,
			@CustIds = @HeadlineIds,
			@ReferenceIds = @ReferenceIds
END
GO

