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
	,@LoginIP				NVARCHAR(20) = ''
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

	DECLARE @Existing_GroupName NVARCHAR(1000) = '',@NumberOfRecipients BIT = 0, @SourceId INT, @NewValues NVARCHAR(MAX), 
			@OldValues NVARCHAR(MAX), @__ChatTypeXML XML, @__RecipientTypeXML XML, @__HeadlineXML XML, @__RecipientXML XML, 
			@__LanguageXML XML, @__BotXML XML, @CustIds VARCHAR(1000), @ReferenceIds VARCHAR(1000)

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

	SELECT @RecipientIds = STUFF((
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

	--Old Values
	SELECT @__BotXML = (
				SELECT t.BotId AS '@Id', cb.BotName AS '@Name'
				FROM #Tmp t
					INNER JOIN dbo.crmConversationBot cb WITH(NOLOCK) ON cb.BotId = t.BotId
				WHERE Type = 2 
				FOR XML PATH('Bot'))

	SELECT @__LanguageXML = (
				SELECT t.LanguageId AS '@Id', s.SettingValue AS '@Name'
				FROM #Tmp t 
					INNER JOIN dbo.crmSetting s WITH(NOLOCK) ON s.SettingID = t.LanguageId
				WHERE t.Type = 1 
				FOR XML PATH('Language'))

	SELECT @__RecipientXML = (
				SELECT t.RecipientId AS '@Id', 
	    				 p.Username AS '@Name', 
	    				 r.RecipientTypeId AS '@RecipientTypeId', 
	    				 rt.RecipientTypeName AS '@RecipientTypeName'
				FROM #Tmp t
					INNER JOIN dbo.crmRecipient r WITH(NOLOCK) ON r.RecipientId = t.RecipientId
					INNER JOIN dbo.crmRecipientType rt WITH(NOLOCK) ON r.RecipientTypeId = rt.RecipientTypeId
 					INNER JOIN dbo.crmPIC p WITH(NOLOCK) ON p.PicID = r.SourceId
				WHERE t.Type = 3 AND r.DataSource = 'bodb_CRM.dbo.crmPIC'
				FOR XML PATH('Recipient'))

	SELECT @__HeadlineXML =	(
				SELECT  t.HeadlineId AS '@Id', 
						CASE WHEN  t.HeadlineId = 0 THEN 'Not Assigned Group' 
						ELSE c.username END AS '@Name'
				FROM #Tmp t
						LEFT JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON c.custid = t.HeadlineId
				WHERE t.Type = 4
				FOR XML PATH('Headline'))

	SELECT @OldValues =	CAST((SELECT t.ConversationGroupId AS '@Id',
									 t.ConversationGroupName AS '@Name',
									 t.ConversationId AS '@LetstalkID',
									 t.Remark AS '@Remark',
									 @__BotXML,
									 @__HeadlineXML,
									 @__RecipientXML,
									 @__LanguageXML
							FROM #Tmp t
							WHERE t.Type = 1
							FOR XML PATH('ConversationGroup'), ROOT('Acc_CRM_ChatBot_ChatTypeMapping_Upd'))
						AS NVARCHAR(MAX))
	-- New values 

	SELECT @__BotXML = (
				SELECT cb.BotId AS '@Id', cb.BotName AS '@Name'
				FROM dbo.crmConversationBot cb WITH(NOLOCK)
				WHERE cb.BotId = @BotId
				FOR XML PATH('Bot'))

	SELECT @__RecipientXML = (
				SELECT  f.val					AS '@Id', 
						p.Username				AS '@Name', 
						r.RecipientTypeId		AS '@RecipientTypeId', 
						rt.RecipientTypeName	AS '@RecipientTypeName'
				FROM bodb02.dbo.f_StringSplit(@RecipientIds, ',') f
					INNER JOIN dbo.crmRecipient r WITH(NOLOCK) ON r.RecipientId  = f.val
					INNER JOIN dbo.crmRecipientType rt WITH(NOLOCK) ON rt.RecipientTypeId = r.RecipientTypeId
					INNER JOIN dbo.crmPIC p WITH(NOLOCK) ON p.PicID = r.SourceId
				WHERE r.DataSource = 'bodb_CRM.dbo.crmPIC'
				FOR XML PATH('Recipient'))

	SELECT @__LanguageXML = (
				SELECT  @LanguageId		AS '@Id', 
						s.SettingValue	AS '@Name'
				FROM dbo.crmSetting s WITH(NOLOCK)
				WHERE s.SettingID = @LanguageId
				FOR XML PATH ('Language'))

	SELECT @__HeadlineXML = (
				SELECT  f.val AS '@Id', 
						CASE WHEN  f.val = 0 THEN 'Not Assigned Group' 
						ELSE c.username END AS '@Name'
				FROM bodb02.dbo.f_StringSplit(@HeadlineIds, ',') f
					LEFT JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON c.custid = f.val
				FOR XML PATH('Headline'))

	SELECT @NewValues =	CAST((SELECT @ConversationGroupId AS '@Id',
									 @ConversationGroupName AS '@Name',
									 @LetstalkID AS '@LetstalkID',
									 @Remark AS '@Remark',
									 @__BotXML,
									 @__HeadlineXML,
									 @__RecipientXML,
									 @__LanguageXML
							FROM #Tmp t
							WHERE t.Type = 1
							FOR XML PATH('ConversationGroup'), ROOT('Acc_CRM_ChatBot_ChatTypeMapping_Upd'))
						AS NVARCHAR(MAX))  

	EXEC dbo.WriteLog_UserLog_crmUserLog_RunSP
			@UserID = @UserID,
			@CustID = NULL,
			@ActionID = 1008,
			@IP = @LoginIP,
			@NewValues = @NewValues,
			@CustIds = @CustIds,
			@ReferenceIds = @ReferenceIds

	DROP TABLE #Headlines
	DROP TABLE #Recipients
	DROP TABLE #Tmp
	
END
GO

