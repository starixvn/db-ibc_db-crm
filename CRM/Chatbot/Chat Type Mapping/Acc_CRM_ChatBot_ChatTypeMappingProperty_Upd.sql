/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet,bodbExtAccNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_HeadlineUpd]
	@CustID			INT = 0,
	@Old_Headline   INT = 0,
	@New_Headline   INT = 0,
	@Username		VARCHAR(30) = '',
	@Case			INT = 0,
	@LoginIP		VARCHAR(20)='',
	@ErrCode		INT = 0 OUTPUT,
	@ErrMsg			NVARCHAR(4000) = '' OUTPUT,
	@UserID			INT
AS
/*
Created: 20200916@Malcolm
Task : 
DB: DBCRM/bodb_CRM
Original:

	Revisions:		
		- 20200916@Malcolm : Update chat Type mapping property[Redmine : #130544]

*/
BEGIN
	

	DECLARE @GroupId				INT,
			@NumberOfRecipient		INT,
			@NumberOfHeadline		INT,
			@HeadlineXML			XML, 
			@RecipientXML			XML,
			@LanguageXML			XML,
			@BotXML					XML,
			@MaxId					INT,
			@Id						INT,
			@LetstalkID				VARCHAR(200),
			@OldValues				NVARCHAR(MAX),
			@NewValues              NVARCHAR(MAX)

	DECLARE @TmpRecipient	TABLE (RecipientId INT)
	DECLARE @TmpGroup	TABLE (ConversationGroupId INT)
	DECLARE @TmpGroupHeadline TABLE (ConversationGroupId SMALLINT, HeadlineId INT)
	DECLARE @TmpGroupRecipient TABLE (ConversationGroupId SMALLINT, RecipientId INT)

	--Remove headline
	IF @Case = 2
	BEGIN
		DELETE cgh
		OUTPUT deleted.ConversationGroupId, deleted.HeadlineId
			INTO @TmpGroupHeadline(ConversationGroupId, HeadlineId)
		FROM dbo.crmConversationGroupHeadline cgh WITH(ROWLOCK, UPDLOCK)
		WHERE cgh.HeadlineId = @CustID

		DELETE cgr
		OUTPUT deleted.ConversationGroupId, deleted.RecipientId
			INTO @TmpGroupRecipient (ConversationGroupId, RecipientId)
		FROM dbo.crmConversationGroupRecipient cgr WITH(ROWLOCK, UPDLOCK)
		WHERE NOT EXISTS(
				SELECT 1
				FROM dbo.crmConversationGroupHeadline cgh WITH(NOLOCK)
					INNER JOIN @TmpGroupHeadline t ON t.ConversationGroupId = cgh.ConversationGroupId
				WHERE cgr.ConversationGroupId = cgh.ConversationGroupId
			)	

		--Deactive Group
		INSERT INTO @TmpGroup (ConversationGroupId)
		SELECT DISTINCT r.ConversationGroupId
		FROM @TmpGroupRecipient r 
		
		DECLARE cursor_TmpGroup_ CURSOR FOR SELECT ConversationGroupId FROM @TmpGroup

		OPEN cursor_TmpGroup_;

		FETCH NEXT FROM cursor_TmpGroup_ INTO @GroupId

		WHILE @@FETCH_STATUS = 0
		BEGIN
			EXEC  dbo.Acc_CRM_ChatBot_ChatTypeMappingStatus_Upd 
							@ConversationGroupId = @GroupId
							,@IsActive = 0
							,@UserId = @UserId		
							,@ErrCode = @ErrCode		
							,@ErrMsg = @ErrMsg		 	
							,@LoginIP = @LoginIP

			FETCH NEXT FROM Cursor_TmpGroup INTO @GroupId;
		END
	
	END
	-- Change Headline 
	IF @Case IN (3,4)
	BEGIN
		UPDATE cgh
			SET cgh.HeadlineId = @New_Headline
		OUTPUT deleted.ConversationGroupId, deleted.HeadlineId
			INTO @TmpGroupHeadline(ConversationGroupId, HeadlineId)
		FROM dbo.crmConversationGroupHeadline cgh WITH(ROWLOCK)
		WHERE cgh.HeadlineId = @Old_Headline

		--Get old recipients to write log
		INSERT INTO @TmpGroupRecipient (ConversationGroupId, RecipientId)
		SELECT cgr.ConversationGroupId, cgr.RecipientId
		FROM dbo.crmConversationGroupRecipient cgr WITH(NOLOCK)
		WHERE EXISTS(SELECT 1 FROM @TmpGroupHeadline tgh WHERE tgh.ConversationGroupId  = cgr.ConversationGroupId)

	END
	--remove direct accounts

	IF @Case = 1 AND @New_Headline <> 0
	BEGIN
		INSERT INTO @TmpRecipient (RecipientId)
		SELECT r.RecipientId 
		FROM dbo.crmPicManagement m WITH(NOLOCK) 
			INNER JOIN dbo.crmRecipient r WITH(NOLOCK) ON r.SourceId = m.PicID
		WHERE m.CustID = @CustID
			AND r.DataSource = 'bodb_CRM.dbo.crmPIC' 

		INSERT INTO @TmpGroup (ConversationGroupId)
		SELECT cgh.ConversationGroupId
		FROM dbo.crmConversationGroupHeadline cgh WITH(NOLOCK)
		WHERE cgh.HeadlineId = @New_Headline
	
		DELETE t
		FROM @TmpGroup t
		WHERE EXISTS(
				SELECT 1
				FROM dbo.crmConversationGroupRecipient cgr WITH(NOLOCK)
					LEFT JOIN @TmpRecipient p ON p.RecipientId = cgr.RecipientId
				WHERE p.RecipientId IS NULL AND cgr.ConversationGroupId = t.ConversationGroupId
			)

		DECLARE Cursor_TmpGroup CURSOR
		FOR SELECT ConversationGroupId FROM @TmpGroup

		OPEN Cursor_TmpGroup;

		FETCH NEXT FROM Cursor_TmpGroup INTO @GroupId

		WHILE @@FETCH_STATUS = 0
		BEGIN
			SELECT @NumberOfRecipient = COUNT(*) 
			FROM dbo.crmConversationGroupRecipient  cgr WITH(NOLOCK) 
			WHERE cgr.ConversationGroupId = @GroupId

			SELECT @NumberOfHeadline = COUNT(*)
			FROM dbo.crmConversationGroupHeadline cgh WITH(NOLOCK)
			WHERE cgh.ConversationGroupId = @GroupId

			IF NOT EXISTS(SELECT 1
					FROM dbo.crmPicManagement m WITH(NOLOCK)
						INNER JOIN dbo.crmRecipient r WITH(NOLOCK) ON r.SourceId = m.PicID
						INNER JOIN dbo.crmConversationGroupRecipient cgr WITH(NOLOCK) ON cgr.RecipientId = r.RecipientId
					WHERE cgr.ConversationGroupId = @GroupId AND r.DataSource = 'bodb_CRM.dbo.crmPIC'
					GROUP BY m.CustID
					HAVING COUNT(PicId) = @NumberOfRecipient)
			BEGIN
				IF @NumberOfHeadline = 1
				BEGIN
					DELETE cgr
					OUTPUT deleted.ConversationGroupId, deleted.RecipientId
						INTO @TmpGroupRecipient(ConversationGroupId, RecipientId)
					FROM dbo.crmConversationGroupRecipient cgr WITH(ROWLOCK, UPDLOCK)
					WHERE cgr.ConversationGroupId = @GroupId

					-- Deactive Group
					EXEC  dbo.Acc_CRM_ChatBot_ChatTypeMappingStatus_Upd 
							@ConversationGroupId = @GroupId
							,@IsActive = 0
							,@UserId = @UserId		
							,@ErrCode = @ErrCode		
							,@ErrMsg = @ErrMsg		 	
							,@LoginIP = @LoginIP	
				END

				DELETE dbo.crmConversationGroupHeadline WITH(ROWLOCK, UPDLOCK)
				OUTPUT deleted.ConversationGroupId, deleted.HeadlineId
					INTO @TmpGroupHeadline(ConversationGroupId, HeadlineId)
				WHERE ConversationGroupId = @GroupId
			END

			FETCH NEXT FROM Cursor_TmpGroup INTO @GroupId;
		END

		CLOSE Cursor_TmpGroup

		DEALLOCATE Cursor_TmpGroup
	END

	--- Write Log

	DECLARE Cursor_Group CURSOR FOR SELECT ConversationGroupId FROM @TmpGroupHeadline

	OPEN Cursor_Group;

	FETCH NEXT FROM Cursor_Group INTO @GroupId

	WHILE @@FETCH_STATUS = 0
	BEGIN
		SELECT @BotXML			= NULL,
			   @NewValues		= NULL,
			   @OldValues		= NULL,
			   @LanguageXML		= NULL, 			  
			   @HeadlineXML		= NULL, 
			   @RecipientXML	= NULL
			   
		--Both (Old/new values is unchanged)

		SELECT @LanguageXML = (
						SELECT t.LanguageId AS '@Id', s.SettingValue AS '@Name'
						FROM dbo.crmConversationGroup t WITH(NOLOCK)
							INNER JOIN dbo.crmSetting s WITH(NOLOCK) ON s.SettingID = t.LanguageId
						WHERE t.ConversationGroupId = @GroupId
						FOR XML PATH('Language'))

		SELECT @BotXML = (
						SELECT t.BotId AS '@Id', cb.BotName AS '@Name'
						FROM dbo.crmConversationGroupBot t WITH(NOLOCK)
							INNER JOIN dbo.crmConversationBot cb WITH(NOLOCK) ON cb.BotId = t.BotId
						WHERE t.ConversationGroupId = @GroupId
						FOR XML PATH('Bot'))

		-- Old Values
		SELECT @HeadlineXML = (
						SELECT  t.HeadlineId AS '@Id', 
								CASE WHEN  t.HeadlineId = 0 THEN 'Not Assigned Group' 
								ELSE c.username END AS '@Name'
						FROM @TmpGroupHeadline t
								LEFT JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON c.custid = t.HeadlineId
						WHERE t.ConversationGroupId = @GroupId
						FOR XML PATH('Headline'))

		IF EXISTS(SELECT 1 FROM @TmpGroupRecipient tgr WHERE tgr.ConversationGroupId = @GroupId)
		BEGIN
			SELECT @RecipientXML = (
						SELECT t.RecipientId AS '@Id', 
								 p.Username AS '@Name', 
								 r.RecipientTypeId AS '@RecipientTypeId', 
								 rt.RecipientTypeName AS '@RecipientTypeName'
						FROM @TmpGroupRecipient t
							INNER JOIN dbo.crmRecipient r WITH(NOLOCK) ON r.RecipientId = t.RecipientId
							INNER JOIN dbo.crmRecipientType rt WITH(NOLOCK) ON r.RecipientTypeId = rt.RecipientTypeId
 							INNER JOIN dbo.crmPIC p WITH(NOLOCK) ON p.PicID = r.SourceId
						WHERE t.ConversationGroupId = @GroupId AND r.DataSource = 'bodb_CRM.dbo.crmPIC'
						FOR XML PATH('Recipient'))
		END
		ELSE 
		BEGIN
			SELECT @RecipientXML = (
						SELECT t.RecipientId AS '@Id', 
								 p.Username AS '@Name', 
								 r.RecipientTypeId AS '@RecipientTypeId', 
								 rt.RecipientTypeName AS '@RecipientTypeName'
						FROM dbo.crmConversationGroupRecipient t
							INNER JOIN dbo.crmRecipient r WITH(NOLOCK) ON r.RecipientId = t.RecipientId
							INNER JOIN dbo.crmRecipientType rt WITH(NOLOCK) ON r.RecipientTypeId = rt.RecipientTypeId
 							INNER JOIN dbo.crmPIC p WITH(NOLOCK) ON p.PicID = r.SourceId
						WHERE t.ConversationGroupId = @GroupId AND r.DataSource = 'bodb_CRM.dbo.crmPIC'
						FOR XML PATH('Recipient'))
		END

		SELECT @OldValues =	CAST((SELECT t.ConversationGroupId AS '@Id',
								 t.ConversationGroupName AS '@Name',
								 t.ConversationId AS '@LetstalkID',
								 t.Remark AS '@Remark',
								 @BotXML,
								 @HeadlineXML,
								 @RecipientXML,
								 @LanguageXML
						FROM dbo.crmConversationGroup t
						WHERE t.ConversationGroupId = @GroupId
						FOR XML PATH('ConversationGroup'), ROOT('Acc_CRM_HeadlineUpd'))
					AS NVARCHAR(MAX))
		-- New Values

		SELECT @HeadlineXML= NULL, @RecipientXML = NULL

		SELECT @HeadlineXML = (
						SELECT  t.HeadlineId AS '@Id', 
								CASE WHEN  t.HeadlineId = 0 THEN 'Not Assigned Group' 
								ELSE c.username END AS '@Name'
						FROM dbo.crmConversationGroupHeadline t
								LEFT JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON c.custid = t.HeadlineId
						WHERE t.ConversationGroupId = @GroupId
						FOR XML PATH('Headline'))

		SELECT @RecipientXML = (
						SELECT t.RecipientId AS '@Id', 
								 p.Username AS '@Name', 
								 r.RecipientTypeId AS '@RecipientTypeId', 
								 rt.RecipientTypeName AS '@RecipientTypeName'
						FROM dbo.crmConversationGroupRecipient t
							INNER JOIN dbo.crmRecipient r WITH(NOLOCK) ON r.RecipientId = t.RecipientId
							INNER JOIN dbo.crmRecipientType rt WITH(NOLOCK) ON r.RecipientTypeId = rt.RecipientTypeId
 							INNER JOIN dbo.crmPIC p WITH(NOLOCK) ON p.PicID = r.SourceId
						WHERE t.ConversationGroupId = @GroupId AND r.DataSource = 'bodb_CRM.dbo.crmPIC'
						FOR XML PATH('Recipient'))

		SELECT @NewValues =	CAST((SELECT t.ConversationGroupId AS '@Id',
								 t.ConversationGroupName AS '@Name',
								 t.ConversationId AS '@LetstalkID',
								 t.Remark AS '@Remark',
								 @BotXML,
								 @HeadlineXML,
								 @RecipientXML,
								 @LanguageXML
						FROM dbo.crmConversationGroup t WITH(NOLOCK)
						WHERE t.ConversationGroupId = @GroupId
						FOR XML PATH('ConversationGroup'), ROOT('Acc_CRM_HeadlineUpd'))
					AS NVARCHAR(MAX))

		EXEC dbo.WriteLog_UserLog_crmUserLog_RunSP
			@UserID = @UserID,
			@CustID = @GroupId,
			@ActionID = 1008,
			@IP = @LoginIP,
			@NewValues = @NewValues,
			@OldValues = @OldValues

		FETCH NEXT FROM Cursor_Group INTO @GroupId
	END

END

GO