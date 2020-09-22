/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_PICAssignment]
	@HeadlineID		INT,
	@PicID			VARCHAR(200),
	@DirectAccount	VARCHAR(1000),
	@IsKeepAssign   BIT = 1,
	@UserID			INT,
	@LoginIP        VARCHAR(20) ='',
	@ErrCode        INT = 0 OUTPUT,
	@ErrMsg         NVARCHAR(MAX) = '' OUTPUT
	
AS
/*
Created: 20200506@Malcolm
Task :  CRM - Staff/Boss Management of headline
DB: DBCRM/bodb_CRM
Original:

	Revisions:
		- 20200506@Malcolm: CRM - Staff/Boss Management of headline [Redmine: #108739]
		- 20200723@Malcolm : change logs [RedmineId : #137144]
	Param's Explanation:
	
		
*/
BEGIN
	SET NOCOUNT ON
	
	CREATE TABLE #DirectAccountTmp (CustID INT, Username VARCHAR(30))

	CREATE TABLE #TmpLog
	(
		HeadlineID  INT,
		PicName		NVARCHAR(200), 
		PicID		INT, 
		RoleID      INT,
		RoleName    NVARCHAR(100),
		CustID		INT,
		Type		INT
	)

	DECLARE @TmpLog TABLE (HeadlineID INT, CustID INT, PicID INT, Type INT)

	DECLARE @TmpGroup	TABLE (ConversationGroupId INT, HeadlineId INT)

	DECLARE @TmpHeadline TABLE (ConversationGroupId SMALLINT, HeadlineId INT)

	DECLARE @TmpRecipient TABLE (ConversationGroupId SMALLINT, RecipientId INT)

	DECLARE @TmpHeadlineLog TABLE (ConversationGroupId SMALLINT, HeadlineId INT)

	DECLARE @Tmp_Cust TABLE (CustID INT)

	DECLARE @Xml					XML, 
			@CustId					INT = 0, 
			@BotXML					XML,	
			@GroupID				INT = 0,
			@RowTotal				INT = 0, 
			@_CustID				INT,
			@NewValues				NVARCHAR(MAX), 
			@OldValues 				NVARCHAR(MAX),
			@CurrentRow				INT = 1, 
			@LanguageXML			XML,
			@HeadlineXML			XML, 
			@RecipientXML			XML,
			@HeadlineName			VARCHAR(30) = '',		
			@NumberOfRecipient		INT,
			@NumberOfHeadline		INT
		
	DECLARE @DirectAccounts TABLE (username VARCHAR(50))
	INSERT INTO @DirectAccounts (username)
	SELECT val FROM dbo.f_split(@DirectAccount, ',')

	INSERT INTO #DirectAccountTmp
	(
		CustID,
		Username
	)
	SELECT Custid, Username
	FROM bodb02.dbo.Customer c WITH(NOLOCK)
	WHERE EXISTS (SELECT 1 FROM @DirectAccounts d WHERE c.username = d.username)

	SELECT @HeadlineID = ISNULL(@HeadlineID,0)

	SELECT @GroupID = GroupID FROM bodb02.dbo.CustGroupHeadline WITH(NOLOCK) WHERE custid = @HeadlineID	

	SELECT @GroupID = ISNULL(@GroupID,0)

	IF EXISTS(SELECT 1 FROM bodb02.dbo.custAccount ca WITH(NOLOCK)
			  WHERE ca.custid IN (SELECT custid from #DirectAccountTmp)
				 AND ca.groupID <> @GroupID) OR (@HeadlineID  <> 0 AND @GroupID = 0)
	BEGIN
		SELECT @ErrCode = 100, @ErrMsg = 'There are some updates on PIC assignment. Please submit again to get the lastest updates!'
		RETURN
	END
	
	SET @IsKeepAssign = ISNULL(@IsKeepAssign,0)

	IF @IsKeepAssign = 0 
	BEGIN
	    BEGIN TRY
			DELETE m
			OUTPUT deleted.PicID, deleted.CustID, deleted.HeadlineID, 1
				INTO #TmpLog (PicID, CustID, HeadlineID, Type)
			FROM dbo.crmPicManagement m WITH(ROWLOCK, UPDLOCK)
				INNER JOIN #DirectAccountTmp t ON m.CustID = t.CustID

			DELETE h
			OUTPUT deleted.HeadlineID, deleted.PicID, 2
				INTO #TmpLog (HeadlineID, PicID, Type)
			FROM dbo.crmPICHeadline h WITH(ROWLOCK, UPDLOCK)
				INNER JOIN #TmpLog t ON h.HeadlineID = t.HeadlineID AND t.PicID = h.PicID
			WHERE NOT EXISTS(SELECT 1 
							 FROM dbo.crmPicManagement m WITH(NOLOCK)
							 WHERE m.HeadlineID = h.HeadlineID AND m.PicID = h.PicID)

		END TRY
		BEGIN CATCH
			SELECT @ErrCode = @@ERROR, @ErrMsg = ERROR_MESSAGE()

			IF EXISTS(SELECT 1 FROM #TmpLog WHERE Type = 1)
			BEGIN
				INSERT INTO dbo.crmPicManagement(CustID, PicID, HeadlineID)
				SELECT CustID, PicID, @HeadlineID
				FROM #TmpLog
				WHERE Type = 1
			END

			RETURN
		END CATCH
				
	END

	--DELETE #TmpLog WHERE Type = 2

	INSERT INTO #TmpLog
	(
			PicName,
			PicID,
			RoleID,
			CustID,
			Type
	)		
	SELECT  l.PicName,
			l.PicID, 
			l.RoleID,
			t.CustID,
			4
	FROM #DirectAccountTmp t
	   CROSS APPLY(
		SELECT Val AS PicID , r.Username AS PicName, r.Role AS RoleID
		FROM bodb02.dbo.strSplit(@PicID,',') AS s
			INNER JOIN dbo.crmPIC r WITH(NOLOCK) ON s.val = r.PicID
	)l

	BEGIN TRY
		INSERT INTO dbo.crmPicManagement
		(		
				PicID,
				CustID,
				HeadlineID
		)	
		OUTPUT inserted.PicID, inserted.CustID, inserted.HeadlineID, 5
			INTO #TmpLog (PicID, CustID, HeadlineID, Type)
		SELECT	PicID,
				CustID,
				@HeadlineID
		FROM #TmpLog l
		WHERE (@IsKeepAssign = 0 
			OR NOT EXISTS(SELECT 1 
			FROM dbo.crmPicManagement WITH(NOLOCK) 
			WHERE PicID = l.PicID AND CustID = l.CustID)) AND l.Type = 4

		INSERT INTO dbo.crmPICHeadline
		(
			HeadlineID,
			PicID
		)
		SELECT DISTINCT @HeadlineID,l.PicID
		FROM #TmpLog l
		WHERE NOT EXISTS(
			SELECT 1 
			FROM dbo.crmPICHeadline h WITH(NOLOCK) 
			WHERE h.HeadlineID = @HeadlineID AND h.PicID = l.PicID
		) AND @HeadlineID <> 0 AND l.Type = 4
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR, @ErrMsg = ERROR_MESSAGE()

		IF EXISTS(SELECT 1 FROM #TmpLog WHERE Type = 1)
			BEGIN
				INSERT INTO dbo.crmPicManagement(CustID, PicID, HeadlineID)
				SELECT CustID, PicID, @HeadlineID
				FROM #TmpLog
				WHERE Type = 1
			END

		IF EXISTS(SELECT 1 FROM #TmpLog WHERE Type = 2)
		BEGIN
			INSERT INTO dbo.crmPICHeadline(HeadlineID, PicID)
			SELECT HeadlineID, PicID
			FROM #TmpLog 
			WHERE Type = 2
		END

		IF EXISTS(SELECT 1 FROM #TmpLog WHERE Type = 5)
		BEGIN
			DELETE m 
			FROM dbo.crmPicManagement m WITH(ROWLOCK, UPDLOCK)
			WHERE EXISTS(SELECT 1 
						 FROM #TmpLog t WHERE Type = 5
						 AND m.CustID = t.CustID 
						 AND m.PicID = t.PicID)
		END

		RETURN
	END CATCH 
	/*===================Update for Chat Type Mapping========================*/

	IF @IsKeepAssign = 0
	BEGIN
		INSERT INTO @TmpGroup (ConversationGroupId, HeadlineId)
		SELECT cgh.ConversationGroupId, cgh.HeadlineId
		FROM dbo.crmConversationGroupHeadline cgh WITH(NOLOCK)
		WHERE cgh.HeadlineId IN (SELECT i.HeadlineId FROM #TmpLog i WHERE i.Type = 1 )

		DELETE t
		FROM @TmpGroup t
		WHERE NOT EXISTS(
				SELECT 1
				FROM dbo.crmConversationGroupRecipient cgr WITH(NOLOCK)	
					INNER JOIN dbo.crmRecipient r WITH(NOLOCK) ON r.RecipientId = cgr.RecipientId
					INNER JOIN #TmpLog i ON i.PicID = r.SourceId
				WHERE r.DataSource = 'bodb_CRM.dbo.crmPIC'	AND i.HeadlineID = t.HeadlineId 
					AND cgr.ConversationGroupId = t.ConversationGroupId
					AND i.Type = 1
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
	END
	/*===================End of Updating for Chat Type Mapping===============*/
	/*===================Write Log====================*/
	DELETE #TmpLog WHERE Type NOT IN (1, 5)

	UPDATE t
	SET t.RoleName	= s.SettingValue,
		t.PicName	= p.Username,
		t.RoleID	= s.SettingID
	FROM #TmpLog t 
		INNER JOIN dbo.crmPIC p WITH(NOLOCK) ON  p.PicID = t.PicID
		INNER JOIN dbo.crmSetting s WITH(NOLOCK) ON p.Role = s.SettingID		

	IF @IsKeepAssign = 0
	BEGIN
	    
		INSERT INTO @Tmp_Cust
		(
			CustID
		)
		SELECT DISTINCT CustID
		FROM #TmpLog
		WHERE Type = 1

		DECLARE cursor_custid CURSOR FOR SELECT CustID FROM @Tmp_Cust 
		OPEN cursor_custid 
		FETCH NEXT FROM cursor_custid INTO @_CustID

		WHILE @@FETCH_STATUS = 0
		BEGIN			
			SELECT @NewValues  = CAST((SELECT PicID			AS '@PicID',
										      PicName		AS '@PicName',
										      RoleID        AS '@RoleID',
										      RoleName      AS '@RoleName'								 
									   FROM #TmpLog
								       WHERE CustID = @_CustID AND Type = 1
								       FOR XML PATH('PIC'), ROOT('Acc_CRM_PICAssignment')) AS NVARCHAR(MAX))

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
	END 

	DELETE @Tmp_Cust

	DELETE #TmpLog WHERE Type <> 5

	INSERT INTO @Tmp_Cust
	(
		CustID
	)
	SELECT DISTINCT CustID
	FROM #TmpLog
	WHERE Type = 5

	
	DECLARE cursor_custid_ CURSOR FOR SELECT CustID FROM @Tmp_Cust 
	OPEN cursor_custid_ 
	FETCH NEXT FROM cursor_custid_ INTO @_CustID

	WHILE @@FETCH_STATUS = 0
	BEGIN
		SELECT @NewValues = CAST((SELECT PicID			AS '@PicID',
										 PicName	    AS '@PicName',
									     RoleID         AS '@RoleID',
										 RoleName       AS '@RoleName'
							      FROM #TmpLog
							      WHERE CustID = @_CustID
							      FOR XML PATH('PIC'),ROOT('Acc_CRM_PICAssignment')) AS NVARCHAR(MAX))

		EXEC dbo.WriteLog_UserLog_crmUserLog_RunSP
				@UserID = @UserID,
				@CustId = @_CustId,
				@ActionID = 905,
				@IP = @LoginIP,
				@NewValues = @NewValues  

		FETCH NEXT FROM cursor_custid_ INTO @_CustID
	END
	CLOSE cursor_custid_
	DEALLOCATE cursor_custid_

	-- Write Logs for Chat Type Mapping

	IF @IsKeepAssign = 0
	BEGIN
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
	END
	
	/*End of Writing logs*/
	    
	DROP TABLE #DirectAccountTmp
	DROP TABLE #TmpLog
END