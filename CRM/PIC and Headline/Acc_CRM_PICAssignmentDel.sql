/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_PICAssignmentDel]
	@RemovedPICs	NVARCHAR(MAX),
	@ErrCode		INT = 0 OUTPUT,
	@ErrMsg			NVARCHAR(4000) = '' OUTPUT,
	@LoginIP		VARCHAR(20),
	@UserID			INT
AS
/*
Created: 20200513@Malcolm
Task :  CRM - Staff/Boss Management of headline
DB: DBCRM/bodb_CRM
Original:

	Revisions:
		- 20200513@Malcolm: CRM - Staff/Boss Management of headline [Redmine: #108739]
		- 20200723@Malcolm : change logs [RedmineId : #137144]
	Param's Explanation:
	- @RemovedPICs:		
		<ROOT>
				<RemovedPIC HeadlineID = "123" CustID = "456"  PicID = ""/>
				<RemovedPIC HeadlineID = "123" CustID = "456"  PicID = ""/>
		</ROOT>	
		
*/
BEGIN 
	SET NOCOUNT ON

	IF @RemovedPICs  = ''
		RETURN

	DECLARE @Id						INT,
			@iDOC 					INT, 
			@IsErr 					BIT = 0, 
			@MaxId					INT,
			@PicID 					INT,
			@BotXML					XML,		
			@PicName 				NVARCHAR(200), 
			@RowTotal 				INT = 0, 
			@GroupId				INT,
			@CurrentRow 			INT = 0,		
			@NewValues 				NVARCHAR(MAX),
			@OldValues 				NVARCHAR(MAX),		
			@HeadlineId				INT,		
			@HeadlineXML			XML, 
			@RecipientXML			XML,
			@LanguageXML			XML,			
			@LetstalkID				VARCHAR(200),
			@NumberOfRecipient		INT,
			@NumberOfHeadline		INT

	DECLARE @TmpLog TABLE (HeadlineID INT, CustID INT, PicID INT, Type INT)

	DECLARE @TmpGroup	TABLE (ConversationGroupId INT, HeadlineId INT)

	DECLARE @TmpHeadline TABLE (ConversationGroupId SMALLINT, HeadlineId INT)

	DECLARE @TmpRecipient TABLE (ConversationGroupId SMALLINT, RecipientId INT)

	DECLARE @TmpHeadlineLog TABLE (ConversationGroupId SMALLINT, HeadlineId INT)

    CREATE TABLE #TmpLog(CustID	INT)

	CREATE TABLE #input 
	(
		HeadlineID      INT,
		CustID			INT,
		PICName			NVARCHAR(200),
		PicID			INT,
		RoleName        NVARCHAR(100),
		RoleID          INT
	)

	BEGIN TRY
			EXEC sp_xml_preparedocument @iDoc OUTPUT, @RemovedPICs	

			INSERT INTO #input
			(
				HeadlineID,
				CustID,
				PicID
			)
			SELECT HeadlineID,
				   CustID,
				   PicID				   
			FROM OPENXML(@iDOC, '/ROOT/RemovedPIC',1) WITH (HeadlineID	INT,
															CustID      INT,
															PicID       INT)
			EXEC sp_xml_removedocument @iDOC
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = ERROR_NUMBER(), @ErrMsg = ERROR_MESSAGE()
		RETURN
	END CATCH	

	SELECT @IsErr = 1
	FROM #input i 
	WHERE NOT EXISTS(SELECT 1 FROM dbo.crmPicManagement m WITH(NOLOCK)
					 WHERE m.HeadlineID = i.HeadlineID AND m.CustID = i.CustID AND m.PicID = i.PicID)
	IF @IsErr = 1
	BEGIN
		SELECT @ErrCode = 100, @ErrMsg = 'There are some updates on PIC assignment. Please submit again to get the lastest updates!'
	END
	
	UPDATE t
		SET t.PICName = p.Username,
			t.RoleID = p.Role
	FROM #input t 
		INNER JOIN dbo.crmPIC p WITH(NOLOCK) ON t.PicID = p.PicID
	
	BEGIN TRY
		DELETE t
		OUTPUT deleted.HeadlineID, deleted.CustID, deleted.PicID, 1
			INTO @TmpLog (HeadlineID, CustID, PicID, Type)
		FROM dbo.crmPicManagement t WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #input i ON t.CustID = i.CustID AND t.PicID = i.PicID
	
		DELETE h
		OUTPUT deleted.HeadlineID, deleted.PicID, 2
			INTO @TmpLog(HeadlineID, PicID, Type)
		FROM dbo.crmPICHeadline h WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @TmpLog t ON h.HeadlineID = t.HeadlineID AND h.PicID = t.PicID	
		WHERE NOT EXISTS(
			SELECT 1
			FROM dbo.crmPicManagement p WITH(NOLOCK) 
			WHERE P.HeadlineID = t.HeadlineID 
				AND p.PicID = t.PicID
		)AND t.Type = 1

	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR, @ErrMsg = ERROR_MESSAGE()

		IF EXISTS(SELECT 1 FROM @TmpLog WHERE Type = 2)
		BEGIN
			INSERT INTO dbo.crmPICHeadline (HeadlineID, PicID)
			SELECT HeadlineID, PicID
			FROM @TmpLog 
			WHERE Type = 2
		END

		IF EXISTS(SELECT 1 FROM @TmpLog WHERE Type = 1)
		BEGIN
			INSERT INTO dbo.crmPicManagement (HeadlineID, CustID, PicID)
			SELECT HeadlineID, CustID, PicID
			FROM @TmpLog
			WHERE Type = 1
		END

		RETURN
	END CATCH
	/*========Update Chat Type Mapping ==========*/

	INSERT INTO @TmpGroup (ConversationGroupId, HeadlineId)
	SELECT cgh.ConversationGroupId, cgh.HeadlineId
	FROM dbo.crmConversationGroupHeadline cgh WITH(NOLOCK)
	WHERE cgh.HeadlineId IN (SELECT i.HeadlineId FROM #input i)

	DELETE t
	FROM @TmpGroup t
	WHERE NOT EXISTS(
			SELECT 1
			FROM dbo.crmConversationGroupRecipient cgr WITH(NOLOCK)	
				INNER JOIN dbo.crmRecipient r WITH(NOLOCK) ON r.RecipientId = cgr.RecipientId
				INNER JOIN #input i ON i.PicID = r.SourceId
			WHERE r.DataSource = 'bodb_CRM.dbo.crmPIC'	AND i.HeadlineID = t.HeadlineId 
				AND cgr.ConversationGroupId = t.ConversationGroupId
		)

	INSERT INTO @TmpHeadlineLog (ConversationGroupId, HeadlineId)
	SELECT cgh.ConversationGroupId, cgh.HeadlineId
	FROM dbo.crmConversationGroupHeadline cgh WITH(NOLOCK)
	WHERE EXISTS(SELECT 1 FROM @TmpGroup g WHERE g.ConversationGroupId = cgh.ConversationGroupId)

	DECLARE Cursor_TmpGroup CURSOR

	FOR SELECT ConversationGroupId, HeadlineId FROM @TmpGroup

	OPEN Cursor_TmpGroup;

	FETCH NEXT FROM Cursor_TmpGroup INTO @GroupId, @HeadlineID

	WHILE @@FETCH_STATUS = 0
		BEGIN
			SELECT @NumberOfHeadline = 0, @NumberOfRecipient = 0
			
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
						AND m.HeadlineID = @HeadlineId
					GROUP BY m.CustID
					HAVING COUNT(PicId) = @NumberOfRecipient)
			BEGIN
				IF @NumberOfHeadline = 1
				BEGIN
					DELETE cgr
					OUTPUT deleted.ConversationGroupId, deleted.RecipientId
						INTO @TmpRecipient(ConversationGroupId, RecipientId)
					FROM dbo.crmConversationGroupRecipient cgr WITH(ROWLOCK, UPDLOCK)
					WHERE cgr.ConversationGroupId = @GroupId

					-- Deactive Group
					EXEC  dbo.Acc_CRM_ChatBot_ChatTypeMappingStatus_Upd 
							@ConversationGroupId = @GroupId
							,@IsActive			 = 0
							,@UserId			 = @UserId		
							,@ErrCode            = @ErrCode		
							,@ErrMsg             = @ErrMsg		 	
							,@LoginIP            = @LoginIP	
				END

				DELETE dbo.crmConversationGroupHeadline WITH(ROWLOCK, UPDLOCK)
				OUTPUT deleted.ConversationGroupId, deleted.HeadlineId
					INTO @TmpHeadline (ConversationGroupId, HeadlineId)
				WHERE ConversationGroupId = @GroupId AND HeadlineId = @HeadlineId

			END

			FETCH NEXT FROM Cursor_TmpGroup INTO @GroupId;
		END

		CLOSE Cursor_TmpGroup

		DEALLOCATE Cursor_TmpGroup

	/*========End of Updating Chat Type Mapping ==========*/

	/*========Write Log========*/

	-- Write Log for PIC
	INSERT INTO #TmpLog
	(
		CustID
	)
	SELECT DISTINCT CustID
	FROM #input

	UPDATE i
	SET i.RoleName = s.SettingValue
	FROM #input i
		INNER JOIN dbo.crmSetting s WITH(NOLOCK) ON i.RoleID = s.SettingID

	DECLARE @_CustID INT

	DECLARE cursor_custid CURSOR FOR SELECT CustID FROM #TmpLog
	OPEN cursor_custid
	FETCH NEXT FROM cursor_custid INTO @_CustID 

	WHILE @@FETCH_STATUS = 0
	BEGIN	
	
			SELECT @NewValues =	CAST((SELECT PicID			AS '@PicID',
											 PicName		AS '@PicName',
											 RoleID         AS '@RoleID',
											 RoleName       AS '@RoleName'
									 FROM #input i																	
									 WHERE CustID = @_CustID
									 FOR XML PATH('PIC'),ROOT('Acc_CRM_PICAssignmentDel')) AS NVARCHAR(MAX))

			EXEC dbo.WriteLog_UserLog_crmUserLog_RunSP
				@UserID = @UserID,
				@CustId = @_CustID,
				@ActionID = 904,
				@IP = @LoginIP,
				@NewValues = @NewValues
		   
		    FETCH NEXT FROM cursor_custid INTO @_CustID 

	END
	CLOSE cursor_custid
	DEALLOCATE cursor_custid

	--Write Log for Updating Chat Type Mapping

	
	DECLARE Cursor_Chat CURSOR FOR  SELECT DISTINCT ConversationGroupId FROM @TmpHeadline

	OPEN Cursor_Chat;

	FETCH NEXT FROM Cursor_Chat INTO @GroupId

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
						FROM @TmpHeadlineLog t
								LEFT JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON c.custid = t.HeadlineId
						WHERE t.ConversationGroupId = @GroupId
						FOR XML PATH('Headline'))

		IF EXISTS(SELECT 1 FROM @TmpRecipient tgr WHERE tgr.ConversationGroupId = @GroupId)
		BEGIN
			SELECT @RecipientXML = (
						SELECT t.RecipientId AS '@Id', 
								 p.Username AS '@Name', 
								 r.RecipientTypeId AS '@RecipientTypeId', 
								 rt.RecipientTypeName AS '@RecipientTypeName'
						FROM @TmpRecipient t
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

		FETCH NEXT FROM Cursor_Chat INTO @GroupId
	END
	
	CLOSE Cursor_Chat;
	
	DEALLOCATE Cursor_Chat;
	/*End of Writing Logs*/
	DROP TABLE #input	

	DROP TABLE #TmpLog
END