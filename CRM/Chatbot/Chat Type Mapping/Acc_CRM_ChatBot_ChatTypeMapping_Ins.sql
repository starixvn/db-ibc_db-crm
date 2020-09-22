/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_ChatBot_ChatTypeMapping_Ins]
	@BotId					INT
	,@ConversationGroupName	NVARCHAR(1000) 
	,@ChatTypeId			TINYINT = NULL
	,@RecipientTypeId       TINYINT
	,@HeadlineIds			VARCHAR(1000) 
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
	Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @ConversationGroupId INT = 0, @Existing_GroupName NVARCHAR(1000) = '',@NewValues NVARCHAR(MAX),
			@__ChatTypeXML XML, @__RecipientTypeXML XML, @__HeadlineXML XML, @__RecipientXML XML, @__LanguageXML XML,
			@ReferenceIds VARCHAR(1000), @__BotXML XML

	DECLARE @_HeadlineIds TABLE (HeadlineID INT)	

	SELECT @ReferenceIds = CAST(@RecipientId AS VARCHAR(1000))

	INSERT INTO @_HeadlineIds (HeadlineID)
	SELECT f.val
	FROM  bodb02.dbo.f_StringSplit(@HeadlineIds, ',') f 

	-- check validation
	SELECT TOP(1) @Existing_GroupName = ConversationGroupName FROM dbo.crmConversationGroup g WITH(NOLOCK) WHERE g.ConversationId = @LetstalkID

	IF ISNULL(@Existing_GroupName,'') <> ''
	BEGIN
		SELECT @ErrCode = 101, @ErrMsg = 'The Letstalk ID ' + @LetstalkID  +' has been set to receive notification already!'
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
				  FROM bodb02.dbo.f_StringSplit(@HeadlineIds, ',') f
				     LEFT JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON c.custid = f.Id
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

	SELECT @NewValues = CAST((SELECT  @ConversationGroupId AS '@Id',
									  @ConversationGroupName AS '@Name',
									  @LetstalkID AS '@LetstalkID',
									  @Remark AS '@Remark',
									  1  AS '@IsActive',
									  @__ChatTypeXML,
									  @__RecipientTypeXML,
									  @__HeadlineXML,
									  @__RecipientXML,
									  @__LanguageXML,
									  @__BotXML
							 FOR XML PATH('ConversationGroup'), ROOT('Acc_CRM_ChatBot_ChatTypeMapping_Ins')
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

