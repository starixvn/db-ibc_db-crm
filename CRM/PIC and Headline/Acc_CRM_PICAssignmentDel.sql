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
		- 20200916@Malcolm : Update chat Type mapping [Redmine : #130544]
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
			@PicID 					INT,			
			@PicName 				NVARCHAR(200), 
			@RowTotal 				INT = 0, 
			@GroupId				INT,
			@CurrentRow 			INT = 0,		
			@NewValues 				NVARCHAR(MAX),
			@OldValues 				NVARCHAR(MAX),						
			@HeadlineIds			VARCHAR(1000),
			@RecipientIds			VARCHAR(1000)

	DECLARE @TmpLog TABLE (HeadlineID INT, CustID INT, PicID INT, Type INT)

	DECLARE @TmpGroupStatus	TABLE (ConversationGroupId INT)

	DECLARE @TmpHeadline TABLE (ConversationGroupId SMALLINT, HeadlineId INT)

	DECLARE @TmpRecipient TABLE (ConversationGroupId SMALLINT, RecipientId INT)

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

	INSERT INTO @TmpHeadline (ConversationGroupId, HeadlineId)
	SELECT DISTINCT cgh.ConversationGroupId, cgh.HeadlineId
	FROM #input i
		INNER JOIN dbo.crmRecipient r WITH(NOLOCK) ON r.SourceId = i.PicID
		INNER JOIN dbo.crmConversationGroupHeadline cgh WITH(NOLOCK) ON cgh.HeadlineId = i.HeadlineID
		INNER JOIN dbo.crmConversationGroupRecipient cgr WITH(NOLOCK) 
			ON cgr.RecipientId = r.RecipientId AND cgr.ConversationGroupId = cgh.ConversationGroupId
	WHERE r.DataSource = 'bodb_CRM.dbo.crmPIC'
	
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
	SELECT cgr.ConversationGroupId, cgr.RecipientId
	FROM dbo.crmConversationGroupRecipient cgr WITH(NOLOCK)
		INNER JOIN @TmpHeadline h ON h.ConversationGroupId = cgr.ConversationGroupId
	WHERE NOT EXISTS(
		SELECT 1
		FROM dbo.crmConversationGroupHeadline cgh WITH(NOLOCK)
			LEFT JOIN @TmpHeadline t ON t.ConversationGroupId = cgh.ConversationGroupId AND t.HeadlineId = cgh.HeadlineId
		WHERE t.HeadlineId IS NULL AND cgr.ConversationGroupId = cgh.ConversationGroupId
	)
	
	INSERT INTO @TmpGroupStatus (ConversationGroupId)
	SELECT g.ConversationGroupId
	FROM dbo.crmConversationGroup g WITH(NOLOCK)
	WHERE EXISTS (
			SELECT 1
			FROM @TmpRecipient t
			WHERE t.ConversationGroupId = g.ConversationGroupId
		)
	AND g.IsActive = 1

	DECLARE Cursor_TmpHeadline CURSOR

	FOR SELECT DISTINCT ConversationGroupId FROM @TmpHeadline

	OPEN Cursor_TmpHeadline;

	FETCH NEXT FROM Cursor_TmpHeadline INTO @GroupId

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
				,@ErrCode = @ErrCode OUTPUT			
				,@ErrMsg = @ErrMsg	OUTPUT			
				,@LoginIP = @LoginIP			
				,@IsAuto = 1
				
		IF @ErrCode <> 0
		BEGIN	
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

			RETURN
		END

		IF EXISTS(SELECT 1 FROM @TmpGroupStatus t WHERE t.ConversationGroupId = @GroupId )
		BEGIN	-- Deactive Group
			EXEC  dbo.Acc_CRM_ChatBot_ChatTypeMappingStatus_Upd 
					@ConversationGroupId = @GroupId
					,@IsActive			 = 0
					,@UserId			 = @UserId		
					,@ErrCode            = @ErrCode	OUTPUT	
					,@ErrMsg             = @ErrMsg  OUTPUT 	
					,@LoginIP            = @LoginIP	
					
			IF @ErrCode <> 0
			BEGIN
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

				RETURN
			END
		END

		FETCH NEXT FROM Cursor_TmpHeadline INTO @GroupId;
	END

	CLOSE Cursor_TmpHeadline

	DEALLOCATE Cursor_TmpHeadline

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

	/*End of Writing Logs*/
	DROP TABLE #input	

	DROP TABLE #TmpLog
END