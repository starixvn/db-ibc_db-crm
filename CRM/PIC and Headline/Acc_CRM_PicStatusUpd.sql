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
	Param's Explanation:
	
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @OldValues NVARCHAR(MAX) = '', @NewValues NVARCHAR(MAX) = '', @Old_IsActive BIT = 0, @PicName NVARCHAR(200) = '',
			@RemovedPICs NVARCHAR(MAX), @OldDirectAccounts XML, @OldHeadlines XML , @___GroupId INT
			
	DECLARE @___HeadlineXML			XML, 
			@___RecipientXML		XML,
			@___LanguageXML			XML,
			@___BotXML				XML,
			@___Count				INT,
			@___Id					INT

	DECLARE @TmpHeadline TABLE (ConversationGroupId INT, HeadlineId INT)

	DECLARE @TmpRecipient TABLE (ConversationGroupId INT, RecipientId INT)

	DECLARE @TmpGroup TABLE (ConversationGroupId INT, Id INT IDENTITY(1,1))

	SELECT @Old_IsActive = IsActive, @PicName =Username FROM dbo.crmPIC WITH(NOLOCK) WHERE PicID = @PicID

	DECLARE @TmpLog TABLE (HeadlineID INT, CustID INT, PicID INT, Type INT)

	SELECT @IsActive = ISNULL(@IsActive,0)

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

	DELETE dbo.crmConversationGroupRecipient WITH(ROWLOCK, UPDLOCK)
	OUTPUT deleted.ConversationGroupId, deleted.RecipientId
		INTO @TmpRecipient (ConversationGroupId, RecipientId)
	WHERE RecipientId = @PicID

	DELETE h
	OUTPUT deleted.ConversationGroupId, deleted.HeadlineId
		INTO @TmpHeadline (ConversationGroupId, HeadlineId)
	FROM dbo.crmConversationGroupHeadline h WITH(ROWLOCK, UPDLOCK)
	WHERE NOT EXISTS(
			SELECT 1
			FROM @TmpRecipient t 
				INNER JOIN dbo.crmConversationGroupRecipient cgr WITH(NOLOCK) ON cgr.ConversationGroupId = t.ConversationGroupId
			WHERE t.ConversationGroupId = h.ConversationGroupId
		)

	DECLARE Cursor_TmpHeadline CURSOR FOR SELECT ConversationGroupId FROM @TmpHeadline

	OPEN Cursor_TmpHeadline;

	FETCH NEXT FROM Cursor_TmpHeadline INTO @___GroupId 

	WHILE @@FETCH_STATUS = 0
	BEGIN
		EXEC  dbo.Acc_CRM_ChatBot_ChatTypeMappingStatus_Upd 
							@ConversationGroupId = @___GroupId
							,@IsActive = 0
							,@UserId = @UserId		
							,@ErrCode = @ErrCode		
							,@ErrMsg = @ErrMsg		 	
							,@LoginIP = @LoginIP	
		FETCH NEXT FROM Cursor_TmpGroup INTO @___GroupId;
	END

	CLOSE Cursor_TmpHeadline;

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

	-- Write Log when updating Chat type Mapping

	INSERT INTO @TmpGroup (ConversationGroupId)
	SELECT DISTINCT ConversationGroupId
	FROM @TmpRecipient 
	
	SELECT @___Count = COUNT(*) FROM @TmpGroup

	SET @___Id = 1

	WHILE @___Id <= @___Count
	BEGIN
		SELECT @NewValues		= NULL,
			   @OldValues		= NULL,
			   @___BotXML		= NULL,
			   @___LanguageXML	= NULL, 			  
			   @___HeadlineXML	= NULL, 
			   @___RecipientXML = NULL

		SELECT @___GroupId = ConversationGroupId FROM @TmpGroup WHERE Id = @___Id

		SELECT @___LanguageXML = 
		(
			SELECT t.LanguageId AS '@Id', s.SettingValue AS '@Name'
			FROM dbo.crmConversationGroup t WITH(NOLOCK)
				INNER JOIN dbo.crmSetting s WITH(NOLOCK) ON s.SettingID = t.LanguageId
			WHERE t.ConversationGroupId = @___GroupId
			FOR XML PATH('Language')
		)

		SELECT @___BotXML = 
		(
			SELECT t.BotId AS '@Id', cb.BotName AS '@Name'
			FROM dbo.crmConversationGroupBot t WITH(NOLOCK)
				INNER JOIN dbo.crmConversationBot cb WITH(NOLOCK) ON cb.BotId = t.BotId
			WHERE t.ConversationGroupId = @___GroupId
			FOR XML PATH('Bot')
		)

		-- Old Values
		SELECT @___HeadlineXML =	
		(
			SELECT  t.HeadlineId AS '@Id', 
					CASE WHEN  t.HeadlineId = 0 THEN 'Not Assigned Group' 
					ELSE c.username END AS '@Name'
			FROM @TmpHeadline t
					LEFT JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON c.custid = t.HeadlineId
			WHERE t.ConversationGroupId = @___GroupId
			FOR XML PATH('Headline')
		)

		IF EXISTS(SELECT 1 FROM @TmpRecipient tgr WHERE tgr.ConversationGroupId = @___GroupId)
		BEGIN
			SELECT @___RecipientXML = 
			(
				SELECT t.RecipientId AS '@Id', 
						 p.Username AS '@Name', 
						 r.RecipientTypeId AS '@RecipientTypeId', 
						 rt.RecipientTypeName AS '@RecipientTypeName'
				FROM @TmpRecipient t
					INNER JOIN dbo.crmRecipient r WITH(NOLOCK) ON r.RecipientId = t.RecipientId
					INNER JOIN dbo.crmRecipientType rt WITH(NOLOCK) ON r.RecipientTypeId = rt.RecipientTypeId
 					INNER JOIN dbo.crmPIC p WITH(NOLOCK) ON p.PicID = r.SourceId
				WHERE t.ConversationGroupId = @___GroupId AND r.DataSource = 'bodb_CRM.dbo.crmPIC'
				FOR XML PATH('Recipient')
			)
		END
		ELSE 
		BEGIN
			SELECT @___RecipientXML = 
			(
				SELECT t.RecipientId AS '@Id', 
						 p.Username AS '@Name', 
						 r.RecipientTypeId AS '@RecipientTypeId', 
						 rt.RecipientTypeName AS '@RecipientTypeName'
				FROM dbo.crmConversationGroupRecipient t
					INNER JOIN dbo.crmRecipient r WITH(NOLOCK) ON r.RecipientId = t.RecipientId
					INNER JOIN dbo.crmRecipientType rt WITH(NOLOCK) ON r.RecipientTypeId = rt.RecipientTypeId
 					INNER JOIN dbo.crmPIC p WITH(NOLOCK) ON p.PicID = r.SourceId
				WHERE t.ConversationGroupId = @___GroupId AND r.DataSource = 'bodb_CRM.dbo.crmPIC'
				FOR XML PATH('Recipient')
			)
		END

		SELECT @OldValues =	CAST((SELECT t.ConversationGroupId AS '@Id',
								 t.ConversationGroupName AS '@Name',
								 t.ConversationId AS '@LetstalkID',
								 t.Remark AS '@Remark',
								 @___BotXML,
								 @___HeadlineXML,
								 @___RecipientXML,
								 @___LanguageXML
						FROM dbo.crmConversationGroup t
						WHERE t.ConversationGroupId = @___GroupId
						FOR XML PATH('ConversationGroup'), ROOT('Acc_CRM_HeadlineUpd'))
					AS NVARCHAR(MAX))
		-- New Values

		SELECT @___HeadlineXML= NULL, @___RecipientXML = NULL

		SELECT @___HeadlineXML =	
		(
			SELECT  t.HeadlineId AS '@Id', 
					CASE WHEN  t.HeadlineId = 0 THEN 'Not Assigned Group' 
					ELSE c.username END AS '@Name'
			FROM dbo.crmConversationGroupHeadline t
					LEFT JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON c.custid = t.HeadlineId
			WHERE t.ConversationGroupId = @___GroupId
			FOR XML PATH('Headline')
		)

		SELECT @___RecipientXML = 
		(
			SELECT t.RecipientId AS '@Id', 
					 p.Username AS '@Name', 
					 r.RecipientTypeId AS '@RecipientTypeId', 
					 rt.RecipientTypeName AS '@RecipientTypeName'
			FROM dbo.crmConversationGroupRecipient t
				INNER JOIN dbo.crmRecipient r WITH(NOLOCK) ON r.RecipientId = t.RecipientId
				INNER JOIN dbo.crmRecipientType rt WITH(NOLOCK) ON r.RecipientTypeId = rt.RecipientTypeId
 				INNER JOIN dbo.crmPIC p WITH(NOLOCK) ON p.PicID = r.SourceId
			WHERE t.ConversationGroupId = @___GroupId AND r.DataSource = 'bodb_CRM.dbo.crmPIC'
			FOR XML PATH('Recipient')
		)

		SELECT @NewValues =	CAST((SELECT t.ConversationGroupId AS '@Id',
								 t.ConversationGroupName AS '@Name',
								 t.ConversationId AS '@LetstalkID',
								 t.Remark AS '@Remark',
								 @___BotXML,
								 @___HeadlineXML,
								 @___RecipientXML,
								 @___LanguageXML
						FROM dbo.crmConversationGroup t WITH(NOLOCK)
						WHERE t.ConversationGroupId = @___GroupId
						FOR XML PATH('ConversationGroup'), ROOT('Acc_CRM_HeadlineUpd'))
					AS NVARCHAR(MAX))

		EXEC dbo.WriteLog_UserLog_crmUserLog_RunSP
			@UserID = @UserID,
			@CustID = @___GroupId,
			@ActionID = 1008,
			@IP = @LoginIP,
			@NewValues = @NewValues,
			@OldValues = @OldValues
		
		SET @___Id = @___Id + 1
	END
	
END