/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_PICStatusUpd]
	@PicID		INT,
	@IsActive	BIT,
	@LoginIP	VARCHAR(20)='',
	@UserID		INT,
	@ErrCode	INT = 0 OUTPUT,
	@ErrMsg		NVARCHAR(4000) = '' OUTPUT
AS
/*
	Created: 20200506@Malcolm
	Task :  CRM - Staff/Boss Management of headline
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20200506@Malcolm: Update status of PIC [Redmine: #108739]
		- 20200723@Malcolm : change logs [RedmineId : #137144]
		- 20200921@Malcolm : Update chat type mapping when deactive Pic Status[RedmineId : #130544] 
		- 20230508@Malcolm: Offer Telegram bot service for Headlines [RedmineId : #179119]
		
	Param's Explanation:
	
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @OldValues NVARCHAR(MAX) = '', @NewValues NVARCHAR(MAX) = '', @Old_IsActive BIT = 0, @PicName NVARCHAR(200) = '',
			@RemovedPICs NVARCHAR(MAX), @OldDirectAccounts XML, @OldHeadlines XML , @___GroupId INT, @RecipientIds VARCHAR(1000),
			@HeadlineIds VARCHAR(1000), @RecipientId INT = NULL, @Username VARCHAR(32) = NULL, @ConversationId VARCHAR(200) = NULL
			
	DECLARE @___HeadlineXML			XML, 
			@___RecipientXML		XML,
			@___LanguageXML			XML,
			@___BotXML				XML,
			@___Count				INT,
			@___Id					INT

	DECLARE @TmpHeadline TABLE (ConversationGroupId INT, HeadlineId INT)

	DECLARE @TmpRecipient TABLE (ConversationGroupId INT, RecipientId INT)

	DECLARE @TmpGroupStatus TABLE (ConversationGroupId INT)

	SELECT @Old_IsActive = IsActive, @PicName =Username FROM dbo.crmPIC WITH(NOLOCK) WHERE PicID = @PicID

	DECLARE @TmpLog TABLE (HeadlineID INT, CustID INT, PicID INT, Type INT)

	SELECT @IsActive = ISNULL(@IsActive,0)

	SELECT @RecipientId = r.RecipientId
	FROM dbo.crmPIC p WITH(NOLOCK)
		INNER JOIN dbo.crmRecipient r WITH(NOLOCK) ON r.SourceId = p.PicID
	WHERE r.DataSource = 'bodb_CRM.dbo.crmPIC' AND p.PicID = @PicID

	IF @IsActive = 0
	BEGIN
		SELECT	@OldDirectAccounts  =   (SELECT c.custid AS '@Id', c.username AS '@Name'
										 FROM dbo.crmPicManagement m WITH(NOLOCK)
											 INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON m.CustID = c.custid
										 WHERE PicID = @PicID
										 FOR XML PATH('DirectAccount'))

		SELECT @OldHeadlines =	(SELECT c.custid AS '@Id', c.username AS '@Name'
								FROM dbo.crmPICDefault d WITH(NOLOCK)
									 INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON d.HeadlineID = c.custid
								WHERE d.PicID = @PicID
								FOR XML PATH('Headline'))
		BEGIN TRY
			DELETE t
			OUTPUT deleted.HeadlineID, deleted.CustID, deleted.PicID, 1
				INTO @TmpLog (HeadlineID, CustID, PicID, Type)
			FROM dbo.crmPicManagement t WITH(ROWLOCK, UPDLOCK)
			WHERE t.PicID = @PicID

			DELETE t
			OUTPUT deleted.HeadlineID, deleted.PicID, 2
				INTO @TmpLog(HeadlineID, PicID, Type)
			FROM dbo.crmPICDefault t WITH(ROWLOCK, UPDLOCK)		
			WHERE PicID = @PicID

			DELETE t
			FROM dbo.crmPICHeadline t WITH(ROWLOCK, UPDLOCK)
			WHERE PicID = @PicID

		END TRY
		BEGIN CATCH
			SELECT @ErrCode = ERROR_NUMBER(), @ErrMsg = ERROR_MESSAGE()

			IF EXISTS(SELECT 1 FROM @TmpLog WHERE Type = 1)
			BEGIN
				INSERT INTO dbo.crmPicManagement (HeadlineID, CustID, PicID)
				SELECT HeadlineID ,CustID, PicID
				FROM @TmpLog
				WHERE Type = 1
			END

			IF EXISTS(SELECT 1 FROM @TmpLog WHERE Type = 2)
			BEGIN
				INSERT INTO dbo.crmPICDefault (HeadlineID, PicID)
				SELECT HeadlineID, PicID
				FROM @TmpLog
				WHERE Type = 2
			END

			RETURN
		END CATCH
	END 

	BEGIN TRY
		UPDATE t
		SET t.IsActive = @IsActive
		FROM dbo.crmPIC t WITH(ROWLOCK)
		WHERE t.PicID = @PicID
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = ERROR_NUMBER(), @ErrMsg = ERROR_MESSAGE()
		RETURN
	END CATCH

	/*====== Update Chat type mapping ======*/

	IF @IsActive = 0 AND @RecipientId IS NOT NULL
	BEGIN
		INSERT INTO @TmpRecipient(ConversationGroupId, RecipientId)
	    SELECT cgr.ConversationGroupId, cgr.RecipientId
	    FROM dbo.crmConversationGroupRecipient cgr WITH(ROWLOCK, UPDLOCK)	
	    WHERE cgr.RecipientId = @RecipientId
	    
	    INSERT INTO @TmpHeadline(ConversationGroupId, HeadlineId)
	    SELECT h.ConversationGroupId, h.HeadlineId
	    FROM dbo.crmConversationGroupHeadline h WITH(ROWLOCK, UPDLOCK)
	    CROSS APPLY(
	    	SELECT COUNT(*) AS NoOfRecipient
	    	FROM dbo.crmConversationGroupRecipient cgr WITH(NOLOCK)
	    	WHERE cgr.ConversationGroupId = h.ConversationGroupId
	    ) AS m
	    WHERE EXISTS(
	    		SELECT 1
	    		FROM @TmpRecipient t 
	    		WHERE t.ConversationGroupId = h.ConversationGroupId
	    	)
	    AND m.NoOfRecipient = 1
	    	    
		INSERT INTO @TmpGroupStatus (ConversationGroupId)
		SELECT cg.ConversationGroupId
		FROM dbo.crmConversationGroup cg WITH(NOLOCK)
		WHERE EXISTS(
			SELECT 1
			FROM @TmpHeadline t 
			WHERE t.ConversationGroupId = cg.ConversationGroupId
		) AND cg.IsActive = 1

	    DECLARE Cursor_TmpRecipient CURSOR FOR SELECT ConversationGroupId FROM @TmpRecipient
	    
	    OPEN Cursor_TmpRecipient;
	    
	    FETCH NEXT FROM Cursor_TmpRecipient INTO @___GroupId 
	    
	    WHILE @@FETCH_STATUS = 0
	    BEGIN
	    	
	    	SELECT @RecipientIds = NULL, @HeadlineIds = NULL, @Username = NULL, @ConversationId = NULL
	    
	    	SELECT @RecipientIds = STUFF((SELECT ',' + CONVERT(VARCHAR(20), cgr.RecipientId)
	    								  FROM dbo.crmConversationGroupRecipient cgr WITH(NOLOCK)
	    								  WHERE cgr.ConversationGroupId = @___GroupId AND cgr.RecipientId <> @RecipientId
	    								  FOR XML PATH('')),1,1,'')
			IF @RecipientIds IS NULL
			BEGIN
				SELECT @RecipientIds = '', @Username = ''

				SELECT @ConversationId = CASE WHEN g.ChatTypeId = 2 THEN '' ELSE @ConversationId END FROM dbo.crmConversationGroup g WITH(NOLOCK) WHERE g.ConversationGroupId = @___GroupId
			END

	    	IF EXISTS(SELECT 1 FROM @TmpHeadline h WHERE h.ConversationGroupId = @___GroupId)
	    	BEGIN
	    		SELECT @HeadlineIds = ''
	    	END
	    
	    	EXEC dbo.Acc_CRM_ChatBot_ChatTypeMapping_Upd
	    			@ConversationGroupId = @___GroupId
	    			,@BotId = NULL			
	    			,@ConversationGroupName	= NULL
	    			,@RecipientTypeId  = NULL 
	    			,@HeadlineIds = @HeadlineIds		
	    			,@RecipientIds	= @RecipientIds		
	    			,@ConversationId = @ConversationId
					,@Username = @Username
	    			,@LanguageId = NULL		
	    			,@Remark = NULL			
	    			,@UserId = @UserId	
	    			,@ErrCode = @ErrCode OUTPUT			
	    			,@ErrMsg = @ErrMsg OUTPUT	
	    			,@LoginIP = @LoginIP			
	    			,@IsAuto = 1
					
	    	IF @ErrCode <> 0
			BEGIN
				--Rollback data
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
					FROM dbo.crmConversationGroupHeadline cgr WITH(NOLOCK)
					WHERE cgr.ConversationGroupId = t.ConversationGroupId AND cgr.HeadlineId = t.HeadlineId
				)

				UPDATE cg
					SET cg.IsActive = 1
				FROM dbo.crmConversationGroup cg WITH(ROWLOCK)
				WHERE EXISTS(SELECT 1 FROM @TmpGroupStatus t WHERE t.ConversationGroupId = cg.ConversationGroupId)

				UPDATE t
				SET t.IsActive = @IsActive
				FROM dbo.crmPIC t WITH(ROWLOCK)
				WHERE t.PicID = @PicID

	    		RETURN
			END
				
	        IF EXISTS(SELECT 1 FROM @TmpGroupStatus t WHERE t.ConversationGroupId = @___GroupId)
			BEGIN
	    		EXEC  dbo.Acc_CRM_ChatBot_ChatTypeMappingStatus_Upd 
	    							@ConversationGroupId = @___GroupId
	    							,@IsActive = 0
	    							,@UserId = @UserId		
	    							,@ErrCode = @ErrCode OUTPUT		
	    							,@ErrMsg = @ErrMsg OUTPUT		 	
	    							,@LoginIP = @LoginIP	
	    		IF @ErrCode <> 0
				BEGIN
					--Rollback data

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
						FROM dbo.crmConversationGroupHeadline cgr WITH(NOLOCK)
						WHERE cgr.ConversationGroupId = t.ConversationGroupId AND cgr.HeadlineId = t.HeadlineId
					)

					UPDATE cg
						SET cg.IsActive = 1
					FROM dbo.crmConversationGroup cg WITH(ROWLOCK)
					WHERE EXISTS(SELECT 1 FROM @TmpGroupStatus t WHERE t.ConversationGroupId = cg.ConversationGroupId)

					UPDATE t
					SET t.IsActive = @IsActive
					FROM dbo.crmPIC t WITH(ROWLOCK)
					WHERE t.PicID = @PicID

	    			RETURN
				END
			END

	    	FETCH NEXT FROM Cursor_TmpRecipient INTO @___GroupId;

	    END
	    
	    CLOSE Cursor_TmpRecipient;
	    
	    DEALLOCATE Cursor_TmpRecipient;
	END
	

	/*====== End of Updating Chat type mapping ======*/

	-- Write Log for PIC

	SELECT @OldValues = CAST((SELECT @Old_IsActive AS '@IsActive', @OldDirectAccounts, @OldHeadlines FOR XML PATH('Acc_CRM_PICStatusUpd')) AS NVARCHAR(MAX))

	SELECT @NewValues = CAST((SELECT @IsActive AS '@IsActive' FOR XML PATH('Acc_CRM_PICStatusUpd')) AS NVARCHAR(MAX))

	EXEC dbo.WriteLog_UserLog_crmUserLog_RunSP
			@UserID = @UserID,
			@CustID = @PicID,
			@ActionID = 903,
			@IP = @LoginIP,
			@NewValues = @NewValues,
			@OldValues = @OldValues
	
END