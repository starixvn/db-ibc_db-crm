/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_ChatBot_ChatTypeMapping_Ins]
	@BotId							BIGINT
	,@ConversationGroupName			NVARCHAR(1000) 
	,@ChatTypeId					TINYINT = NULL
	,@IsTest						BIT = NULL
	,@RecipientTypeId				TINYINT
	,@IgnoredNotificationTypeList	VARCHAR(MAX) = ''
	,@HeadlineIds					VARCHAR(MAX) 
	,@RecipientId					INT
	,@ConversationId				VARCHAR(200)
	,@LanguageId					INT	
	,@Remark						NVARCHAR(2000)
	,@UserId						INT
	,@Username						VARCHAR(32) = '' 
	,@ChannelId						TINYINT
	,@ErrCode						INT = 0 OUTPUT
	,@ErrMsg						NVARCHAR(2000) = '' OUTPUT
	,@LoginIP						VARCHAR(45) = ''
AS
/*
	Created: 20200810@Malcolm
	Task : CRM - Headline Notification - Chat Type Mapping - Insert Peronsal Chat Mapping
	DB: DBCRM/bodb_CRM
	Original:
		Revisions:
			- 20200810@Malcolm: Initialize SPs [Redmine: #130544]
			- 20201126@Malcolm: Change bodb02.dbo.f_StringSplit to dbo.f_CRM_strSplit [Redmine: #144265]
			- 20210811@Malcolm: check headline for Result Amendment [RedmineID: #151509]
			- 20221028@Malcolm: Exclude groups is deleted [RedmineId : #179240]
			- 20221222@Malcolm: Add Ignored notificationType list [RedmineId : #179118]
			- 20230508@Malcolm: Offer Telegram bot service for Headlines [RedmineId : #179119]
			
		Param's Explanation:
		
		@ConversationId = LetstalkId for Letstalk
						= Chat ID for telegram
		@Username : Username for telegram
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @ConversationGroupId INT = 0, @Existing_GroupName NVARCHAR(1000) = '', @NewValues NVARCHAR(MAX), @IgnoredNotificationTypeXML XML, @ChatTypeXML XML, @RecipientTypeXML XML
			,@HeadlineXML XML, @RecipientXML XML, @LanguageXML XML, @ConversationGroupXML XML, @ReferenceIds VARCHAR(MAX), @BotXML XML, @Existing_UserName VARCHAR(32) = ''

	DECLARE @HeadlineIdList TABLE (HeadlineID INT)	

	SELECT @ReferenceIds = CAST(@RecipientId AS VARCHAR(MAX))

	INSERT INTO @HeadlineIdList (HeadlineID)
	SELECT f.value
	FROM  STRING_SPLIT(@HeadlineIds, ',') f 
	WHERE f.value <> ''

	SELECT @Username = ISNULL(@Username, '') 

	IF @ChannelId = 2 AND @Username = ''	
	BEGIN
		SELECT @ErrMsg = 'Username is mandatory!', @ErrCode = 105
		RETURN
	END

	-- check validation
	SELECT TOP(1) @Existing_GroupName = g.ConversationGroupName, @Existing_UserName = Username
	FROM dbo.crmConversationGroup g WITH(NOLOCK) 
	WHERE g.ConversationId = @ConversationId AND g.ChannelId = @ChannelId AND g.IsDeleted = 0 

	IF ISNULL(@Existing_GroupName,'') <> ''
	BEGIN
		SELECT @ErrMsg = 'The '+ CASE @ChannelId WHEN 1 THEN 'Letstalk ID '
												 WHEN 2 THEN 'ChatID '
								 ELSE '' END
						 + @ConversationId  + 
						 + CASE @ChannelId WHEN 1 THEN ' has been set to receive notification already!'
										   WHEN 2 THEN  '(username: ' + @Existing_UserName + ')'+ ' has been set to receive notifications'
						   ELSE '' END
			  ,@ErrCode = 101
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
			,ChannelId
			,Username
		)
		VALUES
		(
			@ConversationId
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
			,@ChannelId
			,CASE WHEN @ChannelId = 2 THEN @Username ELSE '' END
		)

		SELECT @ConversationGroupId = SCOPE_IDENTITY()

		INSERT INTO dbo.crmConversationGroupBot (ConversationGroupId, BotId)
		VALUES (@ConversationGroupId, @BotId)

		INSERT INTO dbo.crmConversationGroupRecipient(ConversationGroupId, RecipientId)
		VALUES (@ConversationGroupId, @RecipientId)

		INSERT INTO dbo.crmConversationGroupHeadline (ConversationGroupId, HeadlineId)
		SELECT @ConversationGroupId, f.value
		FROM STRING_SPLIT(@HeadlineIds,',') f
		WHERE f.value <> ''

		INSERT INTO dbo.crmIgnoredNotificationType (ConversationGroupId, NotificationTypeId)
		SELECT @ConversationGroupId, f.value 
		FROM STRING_SPLIT(@IgnoredNotificationTypeList, ',') f
		WHERE f.value <> ''

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
			
			DELETE dbo.crmIgnoredNotificationType WITH(ROWLOCK, UPDLOCK)
			WHERE ConversationGroupId = @ConversationGroupId 
		END 

		RETURN
	END CATCH

	-- Write Logs

	SELECT @BotXML = (
				SELECT cb.BotId AS '@Id', cb.BotName AS '@Name'
				FROM  dbo.crmConversationBot cb WITH(NOLOCK) 
				WHERE cb.BotId = @BotId AND cb.ChannelId = @ChannelId
				FOR XML PATH('Bot'))

	SELECT @ChatTypeXML = (
				  SELECT @ChatTypeId AS '@Id', 
					     CASE WHEN @ChatTypeId = 1 THEN 'Group' 
					     ELSE 'Personal' END AS '@Name' 
				  FOR XML PATH('ChatType'))

	SELECT @RecipientTypeXML = (
				  SELECT rt.RecipientTypeId AS '@Id', rt.RecipientTypeName AS '@Name'
				  FROM dbo.crmRecipientType rt WITH(NOLOCK)
				  WHERE rt.RecipientTypeId = @RecipientTypeId
				  FOR XML PATH('RecipientType'))

	SELECT @HeadlineXML = (
				  SELECT  f.value AS '@Id', 
				  	   CASE WHEN f.value = 0 THEN 'Not Assigned Group' 
				  	   ELSE c.username END AS '@Name'
				  FROM STRING_SPLIT(@HeadlineIds, ',') f
				     LEFT JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON c.custid = f.value
				  WHERE f.value <> ''
				  FOR XML PATH('Headline'))

	SELECT @LanguageXML = (
				  SELECT @LanguageId AS '@Id', s.SettingValue AS '@Name'
				  FROM dbo.crmSetting s WITH(NOLOCK)
				  WHERE s.SettingID = @LanguageId
				  FOR XML PATH('Language'))

	SELECT @RecipientXML = (
				  SELECT r.RecipientId AS '@Id', p.Username AS '@Name'
				  FROM dbo.crmRecipient r WITH(NOLOCK)
				  	INNER JOIN dbo.crmPIC p WITH(NOLOCK) ON p.PicID = r.SourceId
				  WHERE r.RecipientId = @RecipientId AND r.DataSource = 'bodb_CRM.dbo.crmPIC'
				  FOR XML PATH('Recipient'))

	SELECT @IgnoredNotificationTypeXML = (
				  SELECT t.NotificationTypeId AS '@Id', t.NotificationTypeName AS '@Name'
				  FROM dbo.crmIgnoredNotificationType it WITH(NOLOCK)
					 INNER JOIN dbo.crmNotificationType t WITH(NOLOCK) ON t.NotificationTypeId = it.NotificationTypeId
				  WHERE it.ConversationGroupId = @ConversationGroupId
				  FOR XML PATH ('IgnoredNotificationType'))

	SELECT @ConversationGroupXML = (
				  SELECT @ConversationGroupId AS '@Id'
						,@ConversationGroupName AS '@Name'
						,CASE WHEN @ChannelId = 1 THEN @ConversationId ELSE NULL END AS '@LetstalkID'
						,CASE WHEN @ChannelId = 2 THEN @ConversationId ELSE NULL END AS '@ChatID'
						,CASE WHEN @ChannelId = 2 THEN @Username ELSE NULL END AS '@Username'
						,@Remark AS '@Remark'
						,@IsTest AS '@IsTest'
						,1  AS '@Active'
						,0  AS '@Deleted'
						,@ChannelId AS '@ChannelId'
						,ChannelName AS '@ChannelName'
				 FROM dbo.crmChannel WITH(NOLOCK)
				 WHERE ChannelId = @ChannelId
				 FOR XML PATH('ConversationGroup'))

	SELECT @NewValues = CONVERT(NVARCHAR(MAX), 
						(
							SELECT  
								@ConversationGroupXML
							    ,@ChatTypeXML
								,@RecipientTypeXML
								,@HeadlineXML
								,@RecipientXML
								,@LanguageXML
								,@BotXML
								,@IgnoredNotificationTypeXML
							FOR XML PATH('Acc_CRM_ChatBot_ChatTypeMapping_Ins')
						))

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

