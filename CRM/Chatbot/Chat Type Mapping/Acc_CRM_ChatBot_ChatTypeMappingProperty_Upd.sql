/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet,bodbExtAccNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_ChatBot_ChatTypeMappingProperty_Upd]
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
			@OldValues				NVARCHAR(MAX),
			@NewValues              NVARCHAR(MAX),
			@HeadlineIds			VARCHAR(1000), 
			@RecipientIds			VARCHAR(1000)

	DECLARE @TmpHeadline TABLE (ConversationGroupId SMALLINT, HeadlineId INT)
	DECLARE @TmpRecipient TABLE (ConversationGroupId SMALLINT, RecipientId INT)
	DECLARE @TmpGroupStatus	TABLE (ConversationGroupId INT)

	--Remove headline
	IF @Case = 2
	BEGIN
		INSERT INTO @TmpHeadline(ConversationGroupId, HeadlineId)
		SELECT cgh.ConversationGroupId, cgh.HeadlineId	
		FROM dbo.crmConversationGroupHeadline cgh WITH(NOLOCK)
		WHERE cgh.HeadlineId = @CustID

		INSERT INTO @TmpRecipient (ConversationGroupId, RecipientId)	
		SELECT DISTINCT cgr.ConversationGroupId, cgr.RecipientId
		FROM dbo.crmConversationGroupRecipient cgr WITH(NOLOCK)
			INNER JOIN @TmpHeadline h ON h.ConversationGroupId = cgr.ConversationGroupId
		WHERE NOT EXISTS(
				SELECT 1
				FROM dbo.crmConversationGroupHeadline cgh WITH(NOLOCK)
					INNER JOIN @TmpHeadline t ON t.ConversationGroupId = cgh.ConversationGroupId
				WHERE cgr.ConversationGroupId = cgh.ConversationGroupId AND cgh.HeadlineId <> @CustID
		)	
		--Deactive Group
		INSERT INTO @TmpGroupStatus (ConversationGroupId)
		SELECT DISTINCT g.ConversationGroupId
		FROM dbo.crmConversationGroup g WITH(NOLOCK)
		WHERE EXISTS(
				SELECT 1 
				FROM @TmpRecipient t 
				WHERE t.ConversationGroupId = g.ConversationGroupId
		) AND g.IsActive = 1
	END
	-- Change Headline 
	IF @Case IN (3,4)
	BEGIN
		
		INSERT INTO @TmpHeadline(ConversationGroupId, HeadlineId)
		SELECT cgh.ConversationGroupId, cgh.HeadlineId
		FROM dbo.crmConversationGroupHeadline cgh WITH(NOLOCK)
		WHERE cgh.HeadlineId = @Old_Headline

	END
	--remove direct accounts

	IF @Case = 1 AND @New_Headline = 0
	BEGIN
		
		INSERT INTO @TmpHeadline (ConversationGroupId, HeadlineId)
		SELECT cgh.ConversationGroupId, cgh.HeadlineId
		FROM dbo.crmConversationGroupHeadline cgh WITH(NOLOCK)
		WHERE cgh.HeadlineId = @Old_Headline

		;WITH CTE AS (
			SELECT cgr.ConversationGroupId ,cgh.HeadlineId, cpm.CustId  ,COUNT(cpm.custid) AS NoOfCustId,MAX (m.NoOfRecipient) AS NoOfRecipient
			FROM dbo.crmConversationGroupRecipient cgr
				INNER JOIN dbo.crmConversationGroupHeadline cgh ON cgh.ConversationGroupId = cgr.ConversationGroupId
				INNER JOIN dbo.crmRecipient r ON r.RecipientId = cgr.RecipientId
				LEFT JOIN dbo.crmPICManagement cpm ON cpm.HeadlineId = cgh.HeadlineId AND cpm.PicId = r.SourceId
				CROSS APPLY(
					SELECT COUNT(RecipientId) AS NoOfRecipient
					FROM dbo.crmConversationGroupRecipient cg
					WHERE cg.ConversationGroupId = cgr.ConversationGroupId
				) AS M(NoOfRecipient)
			WHERE EXISTS (SELECT 1 FROM @TmpHeadline g WHERE cgr.ConversationGroupId = g.ConversationGroupId)
			GROUP BY   cgr.ConversationGroupId, cgh.HeadlineId, cpm.CustId
			HAVING MAX (m.NoOfRecipient) = COUNT(cpm.CustId)
		)
		DELETE t
		FROM @TmpHeadline t
		WHERE EXISTS(
				SELECT 1 
				FROM CTE e 
				WHERE e.ConversationGroupId = t.ConversationGroupId 
					AND e.HeadlineId = t.HeadlineId
		)

		INSERT INTO @TmpRecipient (ConversationGroupId, RecipientId)
		SELECT DISTINCT cgr.ConversationGroupId, cgr.RecipientId
		FROM dbo.crmConversationGroupRecipient cgr WITH(NOLOCK)
			INNER JOIN @TmpHeadline h ON h.ConversationGroupId = cgr.ConversationGroupId
		WHERE NOT EXISTS(
			SELECT 1
			FROM dbo.crmConversationGroupHeadline cgh WITH(NOLOCK)
				LEFT JOIN @TmpHeadline t ON t.ConversationGroupId = cgh.ConversationGroupId AND  t.HeadlineId = cgh.HeadlineId
			WHERE t.HeadlineId IS NULL AND cgr.ConversationGroupId = cgh.ConversationGroupId
		)
	
		INSERT INTO @TmpGroupStatus (ConversationGroupId)
		SELECT g.ConversationGroupId
		FROM dbo.crmConversationGroup g WITH(NOLOCK)
		WHERE EXISTS (
				SELECT 1
				FROM @TmpRecipient t
				WHERE t.ConversationGroupId = g.ConversationGroupId
		) AND g.IsActive = 1
	END

	--- Write Log

	DECLARE Cursor_Group CURSOR FOR SELECT ConversationGroupId FROM @TmpHeadline

	OPEN Cursor_Group;

	FETCH NEXT FROM Cursor_Group INTO @GroupId

	WHILE @@FETCH_STATUS = 0
	BEGIN
		SELECT @RecipientIds = NULL, @HeadlineIds = NULL

		SELECT @HeadlineIds = STUFF((SELECT ',' + CONVERT(VARCHAR(20), cgh.HeadlineId)
									 FROM dbo.crmConversationGroupHeadline cgh WITH(NOLOCK)
									 WHERE cgh.ConversationGroupId = @GroupId 
										AND NOT EXISTS(
											SELECT 1
											FROM @TmpHeadline t
											WHERE t.HeadlineId = cgh.HeadlineId
										)
									 FOR XML PATH('')),1,1,'')

		IF @HeadlineIds IS NULL
		BEGIN
			SELECT @HeadlineIds = ''
		END

		IF @Case IN (3, 4)
		BEGIN
			IF @HeadlineIds LIKE '%,%' 
			BEGIN
				SELECT @HeadlineIds = @HeadlineIds + ',' + CONVERT(VARCHAR(20), @New_Headline)
			END
			ELSE
			BEGIN
				SELECT @HeadlineIds = CONVERT(VARCHAR(20), @New_Headline)
			END
		END

		IF EXISTS(SELECT 1 FROM @TmpRecipient h WHERE h.ConversationGroupId = @GroupId)
		BEGIN
			SELECT @RecipientIds = ''
		END

		EXEC dbo.Acc_CRM_ChatBot_ChatTypeMapping_Upd
				@ConversationGroupId = @GroupId
				,@BotId = NULL			
				,@ConversationGroupName	= NULL
				,@RecipientTypeId  = NULL 
				,@HeadlineIds = @HeadlineIds		
				,@RecipientIds	= @RecipientIds		
				,@LetstalkID = NULL
				,@LanguageId = NULL		
				,@Remark = NULL			
				,@UserId = @UserId	
				,@ErrCode = @ErrCode				
				,@ErrMsg = @ErrMsg			
				,@LoginIP = @LoginIP			
				,@IsAuto = 1
		IF @ErrCode <> 0
		BEGIN
			INSERT INTO dbo.crmConversationGroupRecipient (ConversationGroupId, RecipientId)
			SELECT t.ConversationGroupId, t.RecipientId
			FROM @TmpRecipient t
			WHERE NOT EXISTS(
				SELECT 1
				FROM dbo.crmConversationGroupRecipient cgr WITH(NOLOCK)
				WHERE cgr.ConversationGroupId = t.ConversationGroupId AND cgr.RecipientId = t.RecipientId
			)

			INSERT INTO dbo.crmConversationGroupHeadline(ConversationGroupId, HeadlineId)
			SELECT t.ConversationGroupId, t.HeadlineId
			FROM @TmpHeadline t
			WHERE NOT EXISTS(
				SELECT 1
				FROM dbo.crmConversationGroupHeadline cgh WITH(NOLOCK)
				WHERE cgh.ConversationGroupId = t.ConversationGroupId AND cgh.HeadlineId = t.HeadlineId
			)

			UPDATE cg
				SET cg.IsActive = 1
			FROM dbo.crmConversationGroup cg WITH(ROWLOCK)
			WHERE EXISTS(SELECT 1 FROM @TmpGroupStatus t WHERE t.ConversationGroupId = cg.ConversationGroupId)

			IF @Case IN (3, 4)
			BEGIN
				DELETE cgh
				FROM dbo.crmConversationGroupHeadline cgh WITH(ROWLOCK, UPDLOCK)
					INNER JOIN @TmpHeadline h ON h.ConversationGroupId = cgh.ConversationGroupId
				WHERE cgh.HeadlineId = @Old_Headline
			END

			RETURN
		END

		IF EXISTS(SELECT 1 FROM @TmpGroupStatus t WHERE t.ConversationGroupId = @GroupId)
		BEGIN
			EXEC  dbo.Acc_CRM_ChatBot_ChatTypeMappingStatus_Upd 
					@ConversationGroupId = @GroupId
					,@IsActive			 = 0
					,@UserId			 = @UserId		
					,@ErrCode            = @ErrCode		
					,@ErrMsg             = @ErrMsg		 	
					,@LoginIP            = @LoginIP	

			IF @ErrCode <> 0
			BEGIN
				INSERT INTO dbo.crmConversationGroupRecipient (ConversationGroupId, RecipientId)
				SELECT t.ConversationGroupId, t.RecipientId
				FROM @TmpRecipient t
				WHERE NOT EXISTS(
					SELECT 1
					FROM dbo.crmConversationGroupRecipient cgr WITH(NOLOCK)
					WHERE cgr.ConversationGroupId = t.ConversationGroupId AND cgr.RecipientId = t.RecipientId
				)

				INSERT INTO dbo.crmConversationGroupHeadline(ConversationGroupId, HeadlineId)
				SELECT t.ConversationGroupId, t.HeadlineId
				FROM @TmpHeadline t
				WHERE NOT EXISTS(
					SELECT 1
					FROM dbo.crmConversationGroupHeadline cgh WITH(NOLOCK)
					WHERE cgh.ConversationGroupId = t.ConversationGroupId AND cgh.HeadlineId = t.HeadlineId
				)

				UPDATE cg
					SET cg.IsActive = 1
				FROM dbo.crmConversationGroup cg WITH(ROWLOCK)
				WHERE EXISTS(SELECT 1 FROM @TmpGroupStatus t WHERE t.ConversationGroupId = cg.ConversationGroupId)

				IF @Case IN (3, 4)
				BEGIN
					DELETE cgh
					FROM dbo.crmConversationGroupHeadline cgh WITH(ROWLOCK, UPDLOCK)
						INNER JOIN @TmpHeadline h ON h.ConversationGroupId = cgh.ConversationGroupId
					WHERE cgh.HeadlineId = @Old_Headline
				END
				RETURN
			END
		END

		FETCH NEXT FROM Cursor_Group INTO @GroupId;
	END

	CLOSE Cursor_Group

	DEALLOCATE Cursor_Group

END
GO