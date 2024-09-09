/*<info serverAlias="DBCRM-bodb_CRM" executers="wsv_nap" isFunction="0" isNested="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE [dbo].[Acc_CRM_ChatBot_ChatTypeMapping_Upd]
	@ConversationGroupId			INT
	,@BotId							BIGINT
	,@ConversationGroupName			NVARCHAR(1000) 
	,@IgnoredNotificationTypeList	VARCHAR(MAX) = ''
	,@RecipientTypeId				TINYINT
	,@HeadlineIds					VARCHAR(MAX) 
	,@RecipientIds					VARCHAR(MAX)
	,@ConversationId				VARCHAR(200)
	,@LanguageId					INT	
	,@Remark						NVARCHAR(2000)
	,@UserId						INT
	,@Username						VARCHAR(32) = NULL 
	,@IsTest						BIT = NULL
	,@ErrCode						INT = 0 OUTPUT
	,@ErrMsg						NVARCHAR(2000) = '' OUTPUT
	,@LoginIP						VARCHAR(45) = ''
	,@IsAuto						BIT = 0
AS
/*
	Created: 20200810@Malcolm
	Task : CRM - Headline Notification - Chat Type Mapping - Action - Edit
	DB: DBCRM/bodb_CRM
	Original:
		Revisions:
			- 20200810@Malcolm: Initialize SPs [Redmine: #130544]
			- 20201126@Malcolm: Change bodb02.dbo.f_StringSplit to dbo.f_CRM_strSplit [Redmine: #144265]
			- 20210906@Malcolm: Add IsTest for Accounting pic [RedmineID: #151509]
			- 20221028@Malcolm: Exclude groups is deleted [RedmineId: #179240]
			- 20221222@Malcolm: Add Ignored notificationType list [RedmineId : #179118]
			- 20230508@Malcolm: Offer Telegram bot service for Headlines [RedmineId : #179119]
            - 20240909@Ned.Le: Hotfix - CRM - PIC management - To fix the Error due to having space in Letstalk ID [HotFix #210467]
			
		Param's Explanation:
		
		@ConversationId = LetstalkId for Letstalk
						= Chat ID for telegram
		@Username : Username of telegram accounts
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @Existing_GroupName NVARCHAR(1000) = '',@NumberOfRecipients BIT = 0, @SourceId INT, @NewValues NVARCHAR(MAX), 
			@OldValues NVARCHAR(MAX), @__ChatTypeXML XML, @__RecipientTypeXML XML, @__HeadlineXML XML, @__RecipientXML XML, @__IgnoredNotificationType XML,
			@__LanguageXML XML, @__BotXML XML, @__ConversationGroup XML, @__ChannelXML XML,@CustIds VARCHAR(1000), @ReferenceIds VARCHAR(1000), @ChannelId TINYINT,
			@ChatType TINYINT, @Existing_UserName VARCHAR(32) = ''

    -- Trim data for input parameter @ConversationId
    SELECT @ConversationId = TRIM(@ConversationId)

	IF ISNULL(@IsAuto,0) = 1
	BEGIN
		IF EXISTS (SELECT 1 FROM dbo.crmConversationGroup g WITH(NOLOCK) WHERE g.ConversationGroupId = @ConversationGroupId AND g.IsDeleted = 1)
		BEGIN
			SELECT @ErrCode = 0, @ErrMsg = ''
			RETURN
		END

		SELECT @ConversationGroupName = CASE WHEN @ConversationGroupName IS NULL THEN cg.ConversationGroupName ELSE @ConversationGroupName END
			   ,@ConversationId		  = CASE WHEN @ConversationId IS NULL THEN cg.ConversationId ELSE @ConversationId END
			   ,@LanguageId			  = CASE WHEN @LanguageId IS NULL THEN cg.LanguageId ELSE @LanguageId END
			   ,@Remark				  = CASE WHEN @Remark IS NULL THEN cg.Remark ELSE @Remark END
			   ,@RecipientTypeId	  = 0
			   ,@Username			  = CASE WHEN @Username IS NULL THEN Username ELSE @Username END
			   ,@IsTest				  = cg.IsTest
		FROM dbo.crmConversationGroup cg WITH(NOLOCK)
		WHERE cg.ConversationGroupId = @ConversationGroupId

		SELECT @IgnoredNotificationTypeList = 
		(
			SELECT ISNULL(STRING_AGG(CONVERT(VARCHAR(20), NotificationTypeId), ','), '')
			FROM dbo.crmIgnoredNotificationType WITH(NOLOCK) 
			WHERE ConversationGroupId = @ConversationGroupId
		)

		SELECT @BotId = CASE WHEN @BotId IS NULL THEN cgb.BotId ELSE @BotId END
		FROM dbo.crmConversationGroupBot cgb WITH(NOLOCK)
		WHERE cgb.ConversationGroupId = @ConversationGroupId

		IF @RecipientIds IS NULL
		BEGIN
			SELECT @RecipientIds= STUFF((
							SELECT ',' + CONVERT(VARCHAR(20), cgr.RecipientId)
							FROM dbo.crmConversationGroupRecipient cgr WITH(NOLOCK)
							WHERE cgr.ConversationGroupId = @ConversationGroupId
							FOR XML PATH('')), 1,1, '')
		END

		IF @HeadlineIds IS NULL
		BEGIN	
			SELECT @HeadlineIds= STUFF((
							SELECT ',' + CONVERT(VARCHAR(20),cgh.HeadlineId)
							FROM dbo.crmConversationGroupHeadline cgh WITH(NOLOCK)
							WHERE cgh.ConversationGroupId = @ConversationGroupId
							FOR XML PATH('')), 1,1, '')
		END

	END
	ELSE 
	BEGIN
		IF EXISTS (SELECT 1 FROM dbo.crmConversationGroup g WITH(NOLOCK) WHERE g.ConversationGroupId = @ConversationGroupId AND g.IsDeleted = 1)
		BEGIN
			SELECT @ErrCode = 101, @ErrMsg = 'The group has been deleted and cannot be updated.'
			RETURN
		END
	END

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
		,BotId					BIGINT
		,RecipientId			INT
		,HeadlineId				INT
		,NotificationTypeId		SMALLINT
		,IsTest					BIT
		,Username				VARCHAR(32)
		,Type                   SMALLINT
	)

	INSERT INTO #Recipients(ID) 
	SELECT value
	FROM STRING_SPLIT(@RecipientIds, ',')
	WHERE value <> ''

	INSERT INTO #Headlines(ID) 
	SELECT value
	FROM STRING_SPLIT(@HeadlineIds, ',')
	WHERE value <> ''

	-- check validation
	SELECT @ChannelId = ChannelId, @ChatType = ChatTypeId FROM dbo.crmConversationGroup g WITH(NOLOCK) WHERE g.ConversationGroupId = @ConversationGroupId

	SET @Username = ISNULL(@Username, '')

	IF @ChatType = 2 AND @ChannelId = 2 AND @Username = '' AND @IsAuto = 0
	BEGIN
		SELECT @ErrMsg = 'Username is mandatory', @ErrCode = 101
		RETURN
	END

	IF @ChannelId = 1 OR @ChatType = 1
		SET @Username = ''

	SELECT TOP(1) @Existing_GroupName = g.ConversationGroupName, @Existing_UserName = Username
	FROM dbo.crmConversationGroup g WITH(NOLOCK) 
	WHERE g.ConversationId = @ConversationId AND g.ConversationGroupId <> @ConversationGroupId AND g.IsDeleted = 0

	IF ISNULL(@Existing_GroupName,'') <> '' AND ISNULL(@IsAuto,0) = 0
	BEGIN
		SELECT  @ErrMsg = 'The ' + CASE @ChannelId WHEN 1 THEN 'Letstalk ID :' 
												   WHEN 2 THEN 'ChatID '
								   ELSE '' END 
								 + @ConversationId 
								 + CASE @ChannelId WHEN 1 THEN ' has been set to receive notification already!'
												   WHEN 2 THEN  '(username: ' + @Existing_UserName + ')'+ ' has been set to receive notifications'
								   ELSE '' END
		        ,@ErrCode = 101
		RETURN
	END

	SELECT @ReferenceIds = STUFF((
				SELECT ','  + CONVERT(VARCHAR(20), M.A) 
				FROM (
					SELECT DISTINCT cgr.RecipientId 
					FROM dbo.crmConversationGroupRecipient cgr WITH(NOLOCK) 
					WHERE cgr.ConversationGroupId = @ConversationGroupId
					UNION SELECT ID	FROM #Recipients) AS M(A)
				FOR XML PATH('')),1,1,'')

	SELECT @CustIds = STUFF((
				SELECT ','  + CONVERT(VARCHAR(20), M.A) 
				FROM (
					SELECT DISTINCT cgh.HeadlineId 
					FROM dbo.crmConversationGroupHeadline cgh WITH(NOLOCK) 
					WHERE cgh.ConversationGroupId = @ConversationGroupId
					UNION SELECT ID	FROM #Headlines) AS M(A)
				FOR XML PATH('')),1,1,'')
	
	BEGIN TRY
		UPDATE dbo.crmConversationGroup WITH(ROWLOCK)
		SET ConversationGroupName = @ConversationGroupName
			,ConversationId = @ConversationId
			,Remark = @Remark
			,UpdatedDate = GETDATE()
			,LanguageId = @LanguageId
			,IsTest = @IsTest
			,Username = @Username
		OUTPUT	deleted.ConversationId
				,deleted.ConversationGroupName
				,deleted.ChatTypeId
				,deleted.UpdatedDate
				,deleted.LanguageId
				,deleted.Remark
				,deleted.IsTest
				,deleted.Username
				,1
			INTO #Tmp 
			(
				ConversationId 
				,ConversationGroupName
				,ChatTypeId 
				,UpdatedDate 
				,LanguageId
				,Remark
				,IsTest
				,Username
				,Type		
			)
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

		DELETE dbo.crmIgnoredNotificationType WITH(ROWLOCK, UPDLOCK)
		OUTPUT deleted.NotificationTypeId, 5
			INTO #Tmp (NotificationTypeId, Type)
		WHERE ConversationGroupId = @ConversationGroupId

		INSERT INTO dbo.crmConversationGroupRecipient (ConversationGroupId, RecipientId)
		SELECT @ConversationGroupId, ID
		FROM #Recipients

		INSERT INTO dbo.crmConversationGroupHeadline (ConversationGroupId, HeadlineId)
		SELECT @ConversationGroupId, ID
		FROM #Headlines

		INSERT INTO dbo.crmIgnoredNotificationType (ConversationGroupId, NotificationTypeId)
		SELECT DISTINCT @ConversationGroupId, f.value
		FROM STRING_SPLIT(@IgnoredNotificationTypeList, ',') f
		WHERE f.value <> ''

	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR, @ErrMsg = ERROR_NUMBER()
		IF EXISTS(SELECT 1 FROM #Tmp t WHERE t.Type = 1)
			UPDATE g
			SET g.ConversationGroupName = t.ConversationGroupName
				,g.ChatTypeId = t.ChatTypeId
				,g.ConversationId = t.ConversationId
				,g.Remark = t.Remark
				,g.UpdatedDate = t.UpdatedDate
				,g.LanguageId = t.LanguageId
				,g.IsTest = t.IsTest
				,g.Username = t.Username
			FROM dbo.crmConversationGroup g WITH(ROWLOCK)
				,#Tmp t
			WHERE t.Type = 1 AND g.ConversationGroupId = @ConversationGroupId

		IF EXISTS(SELECT 1 FROM #Tmp t WHERE t.Type = 2)
			UPDATE b
				SET b.BotId = t.BotId
			FROM dbo.crmConversationGroupBot b WITH(ROWLOCK)
				,#Tmp t
			WHERE t.Type = 2 AND b.ConversationGroupId = @ConversationGroupId

		IF EXISTS(SELECT 1 FROM #Tmp t WHERE t.Type = 3)
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
				,t.RecipientId
			FROM #Tmp t
			WHERE t.Type = 3
		END
		
		IF EXISTS(SELECT 1 FROM #Tmp t WHERE t.Type = 4)
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
			FROM #Tmp t
			WHERE t.Type = 4
		END

		IF EXISTS (SELECT 1 FROM #Tmp t WHERE t.Type = 5)
		BEGIN
			DELETE dbo.crmIgnoredNotificationType WITH(ROWLOCK, UPDLOCK)
			WHERE ConversationGroupId = @ConversationGroupId

			INSERT INTO dbo.crmIgnoredNotificationType (ConversationGroupId, NotificationTypeId)
			SELECT @ConversationGroupId, t.NotificationTypeId
			FROM #Tmp t
			WHERE t.Type = 5
		END
		RETURN
	END CATCH

	-- Write Logs

	--Old Values
	SELECT @__BotXML = (
				SELECT t.BotId AS '@Id', cb.BotName AS '@Name'
				FROM #Tmp t
					INNER JOIN dbo.crmConversationBot cb WITH(NOLOCK) ON cb.BotId = t.BotId AND cb.ChannelId = @ChannelId
				WHERE t.Type = 2 
				FOR XML PATH('Bot'))

	SELECT @__LanguageXML = (
				SELECT t.LanguageId AS '@Id', s.SettingValue AS '@Name'
				FROM #Tmp t 
					INNER JOIN dbo.crmSetting s WITH(NOLOCK) ON s.SettingID = t.LanguageId
				WHERE t.Type = 1 
				FOR XML PATH('Language'))

	SELECT @__RecipientXML = (
				SELECT t.RecipientId AS '@Id', p.Username AS '@Name'
				FROM #Tmp t
					INNER JOIN dbo.crmRecipient r WITH(NOLOCK) ON r.RecipientId = t.RecipientId
 					INNER JOIN dbo.crmPIC p WITH(NOLOCK) ON p.PicID = r.SourceId
				WHERE t.Type = 3 AND r.DataSource = 'bodb_CRM.dbo.crmPIC'
				FOR XML PATH('Recipient'))

	SELECT @__RecipientTypeXML = (
				SELECT DISTINCT r.RecipientTypeId AS '@Id', rt.RecipientTypeName AS '@Name'
				FROM #Tmp t
					INNER JOIN dbo.crmRecipient r WITH(NOLOCK) ON r.RecipientId = t.RecipientId
					INNER JOIN dbo.crmRecipientType rt WITH(NOLOCK) ON r.RecipientTypeId = rt.RecipientTypeId
 					INNER JOIN dbo.crmPIC p WITH(NOLOCK) ON p.PicID = r.SourceId
				WHERE t.Type = 3 AND r.DataSource = 'bodb_CRM.dbo.crmPIC'
				FOR XML PATH('RecipientType'))

	SELECT @__HeadlineXML =	(
				SELECT  t.HeadlineId AS '@Id', 
						CASE WHEN  t.HeadlineId = 0 THEN 'Not Assigned Group' 
						ELSE c.username END AS '@Name'
				FROM #Tmp t
					LEFT JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON c.custid = t.HeadlineId
				WHERE t.Type = 4
				FOR XML PATH('Headline'))

	SELECT @__IgnoredNotificationType = (
				SELECT t.NotificationTypeId AS '@Id', nt.NotificationTypeName AS '@Name'
				FROM #Tmp t
					INNER JOIN dbo.crmNotificationType nt WITH(NOLOCK) ON nt.NotificationTypeId = t.NotificationTypeId
				WHERE t.[Type] = 5
				FOR XML PATH('IgnoredNotificationType'))

	SELECT @__ConversationGroup = (
		SELECT 
				@ConversationGroupId AS '@Id'
				,t.ConversationGroupName AS '@Name'
				,CASE WHEN @ChannelId = 1 THEN t.ConversationId ELSE NULL END AS '@LetstalkID'
				,CASE WHEN @ChannelId = 2 THEN t.ConversationId ELSE NULL END AS '@ChatID'
				,t.Remark AS '@Remark'
				,t.IsTest AS '@IsTest'
				,CASE WHEN @ChannelId = 2 AND @ChatType = 2 THEN t.Username ELSE NULL END AS '@Username'
		FROM #Tmp t
		WHERE t.Type = 1
		FOR XML PATH('ConversationGroup')
			  
	)

	SELECT @OldValues =	CAST((SELECT @__ConversationGroup
									 ,@__BotXML
									 ,@__HeadlineXML
									 ,@__RecipientXML
									 ,@__RecipientTypeXML
									 ,@__LanguageXML
									 ,@__IgnoredNotificationType
							FOR XML PATH('Acc_CRM_ChatBot_ChatTypeMapping_Upd'))
						AS NVARCHAR(MAX))
	-- New values 
	SELECT @__BotXML = NULL, @__RecipientXML = NULL, @__RecipientTypeXML = NULL, @__LanguageXML = NULL, @__HeadlineXML = NULL, @__ConversationGroup = NULL, @__IgnoredNotificationType = NULL

	SELECT @__BotXML = (
				SELECT cb.BotId AS '@Id', cb.BotName AS '@Name'
				FROM dbo.crmConversationBot cb WITH(NOLOCK)
				WHERE cb.BotId = @BotId
				FOR XML PATH('Bot'))

	SELECT @__RecipientXML = (
				SELECT  f.value AS '@Id', p.Username AS '@Name'
				FROM STRING_SPLIT(@RecipientIds, ',') f
					INNER JOIN dbo.crmRecipient r WITH(NOLOCK) ON r.RecipientId = CONVERT(INT, f.value)
					INNER JOIN dbo.crmPIC p WITH(NOLOCK) ON p.PicID = r.SourceId
				WHERE r.DataSource = 'bodb_CRM.dbo.crmPIC'
					AND f.value <> ''
				FOR XML PATH('Recipient'))

	SELECT @__RecipientTypeXML = (
				SELECT DISTINCT r.RecipientTypeId AS '@Id', rt.RecipientTypeName AS '@Name'
				FROM dbo.crmConversationGroupRecipient t WITH(NOLOCK)
					INNER JOIN dbo.crmRecipient r WITH(NOLOCK) ON r.RecipientId = t.RecipientId
					INNER JOIN dbo.crmRecipientType rt WITH(NOLOCK) ON r.RecipientTypeId = rt.RecipientTypeId
 					INNER JOIN dbo.crmPIC p WITH(NOLOCK) ON p.PicID = r.SourceId
				WHERE t.ConversationGroupId = @ConversationGroupId AND r.DataSource = 'bodb_CRM.dbo.crmPIC'
				FOR XML PATH('RecipientType'))

	SELECT @__LanguageXML = (
				SELECT  @LanguageId		AS '@Id', 
						s.SettingValue	AS '@Name'
				FROM dbo.crmSetting s WITH(NOLOCK)
				WHERE s.SettingID = @LanguageId
				FOR XML PATH ('Language'))

	SELECT @__HeadlineXML = (
				SELECT  f.value AS '@Id', 
						CASE WHEN  f.value = 0 THEN 'Not Assigned Group' 
						ELSE c.username END AS '@Name'
				FROM STRING_SPLIT(@HeadlineIds, ',') f
					LEFT JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON c.custid = CONVERT(INT, f.value)
				WHERE f.value <> ''
				FOR XML PATH('Headline'))

	SELECT @__IgnoredNotificationType = (
				SELECT f.value AS'@Id', nt.NotificationTypeName AS '@Name'
				FROM STRING_SPLIT(@IgnoredNotificationTypeList, ',') f
					INNER JOIN dbo.crmNotificationType nt WITH(NOLOCK) ON nt.NotificationTypeId = CONVERT(SMALLINT, f.value)
				WHERE f.value <> ''
				FOR XML PATH('IgnoredNotificationType'))

	SELECT @__ConversationGroup = (
		SELECT 
				@ConversationGroupId AS '@Id'
				,@ConversationGroupName AS '@Name'
				,CASE WHEN @ChannelId = 1 THEN @ConversationId ELSE NULL END AS '@LetstalkID'
				,CASE WHEN @ChannelId = 2 THEN @ConversationId ELSE NULL END AS '@ChatID'
				,CASE WHEN @ChannelId = 2 AND @ChatType = 2 THEN @Username ELSE NULL END AS '@Username'
				,@Remark AS '@Remark'
				,@IsTest AS '@IsTest'
		FOR XML PATH('ConversationGroup')  
	)

	SELECT @NewValues =	CAST((SELECT @__ConversationGroup,
									 @__BotXML,
									 @__HeadlineXML,
									 @__RecipientXML,
									 @__RecipientTypeXML,
									 @__LanguageXML,
									 @__IgnoredNotificationType
							FROM #Tmp t
							WHERE t.Type = 1
							FOR XML PATH('Acc_CRM_ChatBot_ChatTypeMapping_Upd'))
						AS NVARCHAR(MAX))  

	EXEC dbo.WriteLog_UserLog_crmUserLog_RunSP
			@UserID = @UserID,
			@CustID = NULL,
			@ActionID = 1008,
			@IP = @LoginIP,
			@NewValues = @NewValues,
			@OldValues = @OldValues,
			@CustIds = @CustIds,
			@ReferenceIds = @ReferenceIds

	DROP TABLE #Headlines
	DROP TABLE #Recipients
	DROP TABLE #Tmp
	
END
GO

