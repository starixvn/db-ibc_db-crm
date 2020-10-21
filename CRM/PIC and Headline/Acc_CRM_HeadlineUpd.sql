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
Created: 20200717@Malcolm
Task : 
DB: DBCRM/bodb_CRM
Original:

	Revisions:
		- 20200717@Malcolm:  Integrate Credit Term & Staff/Boss Management  [Redmine: #137144]
		- 20200916@Malcolm : Update Chat Type Mapping [Redmine : #130544]
		- 20200916@Malcolm : Update chat Type mapping property[Redmine : #130544]

	Param's Explanation:
		@Case = 0 : No change
		      = 1 : IsGroupHeadline 0-> 0, the user change group
			  = 2 : IsGroupHeadline 1-> 0
			  = 3 : IsGroupHeadline 0-> 1, the user don't change group
			  = 4 : IsGroupHeadline 0-> 1, the user change group
				
*/
BEGIN 
	SET NOCOUNT ON


	DECLARE @TmpLog TABLE (Type INT, PicID INT, CustID INT, HeadlineID INT)

	DECLARE @XML XML = NULL, @NewValues	NVARCHAR(MAX) = '', @OldValues	NVARCHAR(MAX) = '', @New_HeadlineName VARCHAR(30), @HeadineID INT,
			@ActionID INT = 906
			
	SELECT @CustID = ISNULL(@CustID,0), @Username = ISNULL(@Username,''), @Case = ISNULL(@Case,0),
		   @Old_Headline = ISNULL(@Old_Headline,0), @New_Headline = ISNULL(@New_Headline,0)

	IF @Case = 0
		RETURN

	IF @CustID = 0
		SELECT @CustID = CustId FROM bodb02.dbo.Customer WITH(NOLOCK) WHERE username = @Username
	ELSE 
		SELECT @Username = UserName FROM bodb02.dbo.Customer WITH(NOLOCK) WHERE custid = @CustID

	SELECT @XML	=  (SELECT p.PicID AS '@PicID', P.Username AS '@PicName', s.SettingValue AS '@RoleName'
					FROM dbo.crmPICHeadline h WITH(NOLOCK) 
						INNER JOIN dbo.crmPIC p WITH(NOLOCK) ON h.PicID = p.PicID
						INNER JOIN dbo.crmSetting s WITH(NOLOCK) ON s.SettingID = p.Role
					WHERE h.HeadlineID = @CustID AND @Case = 2
						OR h.HeadlineID = @New_Headline AND @Case IN (3,4)
					FOR XML PATH('PIC'))	

	IF @Case IN (3,4)
	BEGIN
	    BEGIN TRY
			UPDATE dbo.crmPICHeadline WITH(ROWLOCK)
			SET HeadlineID = @CustID
			OUTPUT deleted.HeadlineID, deleted.PicID, 3
				INTO @TmpLog(HeadlineID, PicID, Type)
			WHERE HeadlineID = @New_Headline

			UPDATE dbo.crmPICDefault WITH(ROWLOCK)
			SET HeadlineID = @CustID
			OUTPUT deleted.HeadlineID, deleted.PicID, 4
				INTO @TmpLog(HeadlineID, PicID, Type)
			WHERE HeadlineID = @New_Headline

			UPDATE dbo.crmPicManagement WITH(ROWLOCK)
			SET HeadlineID = @CustID
			OUTPUT deleted.HeadlineID, deleted.CustID, deleted.PicID, 5
				INTO @TmpLog(HeadlineID, CustID, PicID, Type)
			WHERE HeadlineID = @New_Headline

		END TRY
		BEGIN CATCH
		    SELECT @ErrCode = 101, @ErrMsg = 'Internal errors! Please try again or contact the administrator!'		
			IF EXISTS(SELECT 1 FROM @TmpLog WHERE Type = 3)
			BEGIN
				UPDATE dbo.crmPICHeadline WITH(ROWLOCK)
				SET HeadlineID = @New_Headline
				WHERE HeadlineID = @CustID
			END

			IF EXISTS(SELECT 1 FROM @TmpLog WHERE Type = 4)
			BEGIN
				UPDATE dbo.crmPICDefault WITH(ROWLOCK)
				SET HeadlineID = @New_Headline
				WHERE HeadlineID = @CustID
			END

			RETURN
		END CATCH		
	END

	IF @Case IN (1,4)
	BEGIN	
	    BEGIN TRY
			IF @Case = 1 
				SET @HeadineID = @New_Headline
			ELSE
				SET @HeadineID = @CustID

			DELETE dbo.crmPicManagement WITH(ROWLOCK, UPDLOCK)
			OUTPUT deleted.HeadlineID, deleted.PicID, deleted.CustID, 1
				INTO @TmpLog (HeadlineID, PicID, CustID, Type)
			WHERE CustID = @CustID

			INSERT INTO dbo.crmPicManagement
			(
				HeadlineID,
				CustID,
				PicID
			)
			OUTPUT inserted.HeadlineID ,inserted.CustID, inserted.PicID, 2
				INTO @TmpLog (HeadlineID, CustID, PicID, Type)
			SELECT @HeadineID ,@CustID, PicID
			FROM dbo.crmPICDefault WITH(NOLOCK)
			WHERE HeadlineID = @HeadineID 

			INSERT INTO dbo.crmPICHeadline
			(
				HeadlineID,
				PicID
			)
			OUTPUT inserted.HeadlineID, inserted.PicID, 6
				INTO @TmpLog(HeadlineID,PicID, Type)
			SELECT DISTINCT @HeadineID, t.PicID
			FROM @TmpLog t
			WHERE NOT EXISTS(SELECT 1 FROM dbo.crmPICHeadline h WITH(NOLOCK) 
					         WHERE h.HeadlineID = @HeadineID AND h.PicID = t.PicID)
				  AND Type = 2
		
			DELETE h
			OUTPUT deleted.HeadlineID, deleted.PicID, 8
				INTO @TmpLog(HeadlineID, PicID, Type)
			FROM dbo.crmPICHeadline h WITH(ROWLOCK, UPDLOCK)
				INNER JOIN @TmpLog t ON t.PicID = h.PicID 
			WHERE h.HeadlineID = @Old_Headline AND t.type = 1
			AND NOT EXISTS(SELECT 1 FROM dbo.crmPicManagement m WITH(NOLOCK) 
						   WHERE m.HeadlineID = @Old_Headline AND m.PicID = t.PicID)
			AND @Old_Headline <> 0			
		END TRY
		BEGIN CATCH
			SELECT @ErrCode = 102, @ErrMsg = 'Internal errors! Please try again or contact the administrator!'

			IF EXISTS(SELECT 1 FROM @TmpLog WHERE Type = 1)
			BEGIN
				INSERT INTO dbo.crmPicManagement(HeadlineID, CustID, PicID)
				SELECT HeadlineID, CustID, PicID
				FROM @TmpLog
				WHERE Type = 1
			END

			IF EXISTS(SELECT 1 FROM @TmpLog WHERE Type = 2)
			BEGIN
				DELETE  dbo.crmPicManagement  WITH(ROWLOCK, UPDLOCK)
				WHERE EXISTS (SELECT 1 FROM @TmpLog t 
							  WHERE PicID = t.PicID AND CustID = t.CustID AND Type = 2)			 
			END			

			IF EXISTS(SELECT 1 FROM @TmpLog WHERE Type = 3)
			BEGIN
				UPDATE dbo.crmPICHeadline WITH(ROWLOCK)
				SET HeadlineID = @New_Headline
				WHERE HeadlineID = @CustID
			END

			IF EXISTS(SELECT 1 FROM @TmpLog WHERE Type = 4)
			BEGIN
				UPDATE dbo.crmPICDefault WITH(ROWLOCK)
				SET HeadlineID = @New_Headline
				WHERE HeadlineID = @CustID
			END

			IF EXISTS(SELECT 1 FROM @TmpLog WHERE Type = 5)
			BEGIN
				UPDATE dbo.crmPicManagement WITH(ROWLOCK)
				SET HeadlineID = @New_Headline
				WHERE HeadlineID = @CustID
			END

			IF EXISTS(SELECT 1 FROM @TmpLog WHERE Type = 6)
			BEGIN
				DELETE h
				FROM dbo.crmPICHeadline h WITH(ROWLOCK, UPDLOCK)
				WHERE EXISTS(SELECT 1 FROM @TmpLog t 
						     WHERE t.Type = 6 AND t.HeadlineID = h.HeadlineID AND t.PicID = h.PicID)
			END
			RETURN
		END CATCH	
	END

	IF @Case = 2
	BEGIN	
	    BEGIN TRY
			DELETE dbo.crmPicManagement WITH(ROWLOCK, UPDLOCK)
			OUTPUT deleted.HeadlineID, deleted.CustID, deleted.PicID, 11
				INTO @TmpLog (HeadlineID, CustID, PicID, Type)
			WHERE CustID = @CustID

			DELETE dbo.crmPICHeadline WITH(ROWLOCK, UPDLOCK)
			OUTPUT deleted.HeadlineID, deleted.PicID, 12
				INTO @TmpLog (HeadlineID, PicID, Type)
			WHERE HeadlineID = @CustID
		
			DELETE dbo.crmPICDefault WITH(ROWLOCK, UPDLOCK)
			OUTPUT deleted.HeadlineID, deleted.PicID, 7
				INTO @TmpLog(HeadlineID, PicID, Type)
			WHERE HeadlineID = @CustID	
		END TRY
		BEGIN CATCH
			SELECT @ErrCode = 103, @ErrMsg = 'Internal errors! Please try again or contact the administrator!'
			IF EXISTS(SELECT 1 FROM @TmpLog WHERE Type = 12)
			BEGIN
				INSERT INTO dbo.crmPICHeadline(HeadlineID, PicID)
				SELECT HeadlineID, PicID
				FROM @TmpLog 
				WHERE Type = 12
			END

			IF EXISTS(SELECT 1 FROM @TmpLog WHERE Type = 11)
			BEGIN
				INSERT INTO dbo.crmPicManagement(HeadlineID, CustID, PicID)
				SELECT HeadlineID, CustID, PicID
				FROM @TmpLog
				WHERE Type = 11
			END
			RETURN
		END CATCH			
	END
	/*==========Update Chat Type Mapping=========*/
		
	EXEC dbo.Acc_CRM_ChatBot_ChatTypeMappingProperty_Upd 
		@CustID			= @CustID
		,@Old_Headline	= @Old_Headline
		,@New_Headline	= @New_Headline
		,@Username		= @Username	
		,@Case			= @Case		
		,@LoginIP		= @LoginIP
		,@ErrCode		= @ErrCode OUTPUT	
		,@ErrMsg		= @ErrMsg OUTPUT		
		,@UserID		= @UserID		
	
	IF @ErrCode <> 0
	BEGIN
		SELECT @ErrCode = 103, @ErrMsg = 'Internal errors! Please try again or contact the administrator!'
		
		IF EXISTS(SELECT 1 FROM @TmpLog WHERE Type = 1)
		BEGIN
			INSERT INTO dbo.crmPicManagement(HeadlineID, CustID, PicID)
			SELECT HeadlineID, CustID, PicID
			FROM @TmpLog
			WHERE Type = 1
		END

		IF EXISTS(SELECT 1 FROM @TmpLog WHERE Type = 2)
		BEGIN
			DELETE  dbo.crmPicManagement  WITH(ROWLOCK, UPDLOCK)
			WHERE EXISTS (SELECT 1 FROM @TmpLog t 
						  WHERE PicID = t.PicID AND CustID = t.CustID AND Type = 2)			 
		END			

		IF EXISTS(SELECT 1 FROM @TmpLog WHERE Type = 3)
		BEGIN
			UPDATE dbo.crmPICHeadline WITH(ROWLOCK)
			SET HeadlineID = @New_Headline
			WHERE HeadlineID = @CustID
		END

		IF EXISTS(SELECT 1 FROM @TmpLog WHERE Type = 4)
		BEGIN
			UPDATE dbo.crmPICDefault WITH(ROWLOCK)
			SET HeadlineID = @New_Headline
			WHERE HeadlineID = @CustID
		END

		IF EXISTS(SELECT 1 FROM @TmpLog WHERE Type = 5)
		BEGIN
			UPDATE dbo.crmPicManagement WITH(ROWLOCK)
			SET HeadlineID = @New_Headline
			WHERE HeadlineID = @CustID
		END

		IF EXISTS(SELECT 1 FROM @TmpLog WHERE Type = 6)
		BEGIN
			DELETE h
			FROM dbo.crmPICHeadline h WITH(ROWLOCK, UPDLOCK)
			WHERE EXISTS(SELECT 1 FROM @TmpLog t 
					     WHERE t.Type = 6 AND t.HeadlineID = h.HeadlineID AND t.PicID = h.PicID)
		END

		IF EXISTS(SELECT 1 FROM @TmpLog WHERE Type = 7)
		BEGIN
			INSERT INTO dbo.crmPICDefault (HeadlineID, PicID)
			SELECT t.HeadlineID, t.PicID
			FROM @TmpLog t
			WHERE t.Type = 7
		END

		IF EXISTS(SELECT 1 FROM @TmpLog WHERE Type = 8)
		BEGIN
			INSERT INTO dbo.crmPICHeadline (HeadlineID, PicID)
			SELECT t.HeadlineID, t.PicID
			FROM @TmpLog t
			WHERE t.Type = 8
		END

		IF EXISTS(SELECT 1 FROM @TmpLog WHERE Type = 12)
		BEGIN
			INSERT INTO dbo.crmPICHeadline(HeadlineID, PicID)
			SELECT HeadlineID, PicID
			FROM @TmpLog 
			WHERE Type = 12
		END

		IF EXISTS(SELECT 1 FROM @TmpLog WHERE Type = 11)
		BEGIN
			INSERT INTO dbo.crmPicManagement(HeadlineID, CustID, PicID)
			SELECT HeadlineID, CustID, PicID
			FROM @TmpLog
			WHERE Type = 11
		END		

		RETURN
	END
	/*==========End of Updating Chat Type Mapping=========*/


	-- Write log

	IF @Case IN (1, 4)
	BEGIN
		--Remove direct account from PIC	
		SELECT @NewValues = NULL

		SELECT @NewValues = CAST((SELECT t.PicID			AS '@PicID',
										 p.Username			AS '@PicName',
									     p.Role				AS '@RoleID',
										 s.SettingValue     AS '@RoleName'
							      FROM @TmpLog t
									INNER JOIN dbo.crmPIC p WITH(NOLOCK) ON t.PicID = P.PicID
									INNER JOIN dbo.crmSetting s WITH(NOLOCK) ON p.Role = s.SettingID
							      WHERE Type = 1
						      FOR XML PATH('PIC'),ROOT('Acc_CRM_HeadlineUpd')) AS NVARCHAR(MAX))
		IF ISNULL(@NewValues,'') <> ''
		BEGIN
			BEGIN TRY
				EXEC dbo.WriteLog_UserLog_crmUserLog_RunSP
					@UserID = @UserID,
					@CustId = @CustId,
					@ActionID = 904,
					@IP = @LoginIP,
					@NewValues = @NewValues
			END TRY
			BEGIN CATCH
				SELECT @ErrCode = 104, @ErrMsg = 'Internal errors! Please try again or contact the administrator!'
				RETURN
			END CATCH
		END
		

		--Assign direct account to PIC		
		SET @NewValues = NULL

		SELECT @NewValues = CAST((SELECT t.PicID			AS '@PicID',
										 p.Username			AS '@PicName',
									     p.Role				AS '@RoleID',
										 s.SettingValue     AS '@RoleName'
							      FROM @TmpLog t
									INNER JOIN dbo.crmPIC p WITH(NOLOCK) ON t.PicID = P.PicID
									INNER JOIN dbo.crmSetting s WITH(NOLOCK) ON p.Role = s.SettingID
							      WHERE Type = 2
							      FOR XML PATH('PIC'),ROOT('Acc_CRM_HeadlineUpd')) AS NVARCHAR(MAX))
	    IF ISNULL(@NewValues,'') <> ''
		BEGIN
			BEGIN TRY
			EXEC dbo.WriteLog_UserLog_crmUserLog_RunSP
				@UserID = @UserID,
				@CustId = @CustId,
				@ActionID = 905,
				@IP = @LoginIP,
				@NewValues = @NewValues
			END TRY
			BEGIN CATCH
				SELECT @ErrCode = 104, @ErrMsg = 'Internal errors! Please try again or contact the administrator!'
				RETURN
			END CATCH	
		END
	END
	
	IF @Case = 2
	BEGIN
		--Write log Remove Default PIC for a group headline (908)
		SELECT @NewValues = NULL, @OldValues = NULL

		SELECT @NewValues = CAST((SELECT 
								p.PicID			AS '@PicID'
								,p.Username		AS '@PicName'
								,p.Role			AS '@RoleId'
								,s.SettingValue AS '@RoleName'		
							FROM @TmpLog t
								INNER JOIN dbo.crmPIC p WITH(NOLOCK) ON p.PicID = t.PicID
								INNER JOIN dbo.crmSetting s WITH(NOLOCK) ON p.Role = s.SettingID
							WHERE Type = 7 
							FOR XML PATH('PIC'),ROOT('Acc_CRM_HeadlineUpd')) AS NVARCHAR(MAX))
		BEGIN TRY
			IF ISNULL(@NewValues,'') <> ''
			BEGIN
				EXEC dbo.WriteLog_UserLog_crmUserLog_RunSP
					@UserID = @UserID,
					@CustId = @CustId,
					@ActionID = 908,
					@IP = @LoginIP,
					@NewValues = @NewValues,
					@OldValues = @OldValues
			END
		END TRY
		BEGIN CATCH
			SELECT @ErrCode = 104, @ErrMsg = 'Internal errors! Please try again or contact the administrator!'
			RETURN
		END CATCH
		--Remove direct account from PIC	
		SET @NewValues = NULL

		SELECT @NewValues = CAST((SELECT 
								p.PicID			AS '@PicID'
								,p.Username		AS '@PicName'
								,p.Role			AS '@RoleId'
								,s.SettingValue AS '@RoleName'		
							FROM @TmpLog t
								INNER JOIN dbo.crmPIC p WITH(NOLOCK) ON p.PicID = t.PicID
								INNER JOIN dbo.crmSetting s WITH(NOLOCK) ON p.Role = s.SettingID
							WHERE Type = 11
							FOR XML PATH('PIC'),ROOT('Acc_CRM_HeadlineUpd')) AS NVARCHAR(MAX))
		BEGIN TRY
			IF ISNULL(@NewValues,'') <> ''
			BEGIN
				EXEC dbo.WriteLog_UserLog_crmUserLog_RunSP
					@UserID = @UserID,
					@CustId = @CustId,
					@ActionID = 904,
					@IP = @LoginIP,
					@NewValues = @NewValues,
					@OldValues = @OldValues
			END
		END TRY
		BEGIN CATCH
			SELECT @ErrCode = 104, @ErrMsg = 'Internal errors! Please try again or contact the administrator!'
			RETURN
		END CATCH
	END

    IF @Case IN (3, 4, 2)
	BEGIN	
		SELECT @OldValues = NULL, @NewValues = NULL

		SELECT @OldValues  = CAST((SELECT @CustID   AS '@HeadlineID',
								      @Username AS '@HeadlineName',
									  @XML
							   FOR XML PATH('Acc_CRM_HeadlineUpd')) AS NVARCHAR(MAX)) --906
		IF @Case IN (3, 4)
		BEGIN
		    SELECT @New_HeadlineName = UserName 
			FROM bodb02.dbo.Customer WITH(NOLOCK) 
			WHERE custid = @New_Headline

		    SELECT @NewValues = @OldValues 

			SELECT @OldValues  = CAST((SELECT @New_Headline   AS '@HeadlineId',
											  @New_HeadlineName AS '@HeadlineName',
										      @XML
								       FOR XML PATH('Acc_CRM_HeadlineUpd')) AS NVARCHAR(MAX)) -- 906
			IF @Case = 4
			BEGIN
				SELECT @XML	=  (SELECT p.PicID AS '@PicID', P.Username AS '@PicName', s.SettingValue AS '@RoleName'
								FROM dbo.crmPICHeadline h WITH(NOLOCK) 
									INNER JOIN dbo.crmPIC p WITH(NOLOCK) ON h.PicID = p.PicID
									INNER JOIN dbo.crmSetting s WITH(NOLOCK) ON s.SettingID = p.Role
								WHERE h.HeadlineID = @CustID 
								FOR XML PATH('PIC'))

				SELECT @NewValues  = CAST((SELECT @CustID   AS '@HeadlineID',
												  @Username AS '@HeadlineName',
												  @XML
										   FOR XML PATH('Acc_CRM_HeadlineUpd')) AS NVARCHAR(MAX)) --906
			END
		END

		IF ISNULL(@NewValues,'') <> '' OR ISNULL(@OldValues,'') <> ''
		BEGIN TRY
			EXEC dbo.WriteLog_UserLog_crmUserLog_RunSP
				@UserID = @UserID,
				@CustId = @CustId,
				@ActionID = 906,
				@IP = @LoginIP,
				@NewValues = @NewValues,
				@OldValues = @OldValues
		END TRY
		BEGIN CATCH
			SELECT @ErrCode = 104, @ErrMsg = 'Internal errors! Please try again or contact the administrator!'
			RETURN
		END CATCH							
	END		
END