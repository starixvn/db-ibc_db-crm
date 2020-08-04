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

	DECLARE @Tmp_Cust TABLE (CustID INT)

	DECLARE @HeadlineName VARCHAR(30) = '', @GroupID INT = 0,@NewValues NVARCHAR(MAX), 
			@RowTotal INT = 0, @CurrentRow INT = 1, @CustId INT = 0, @Xml XML, @_CustID INT

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
	    
	DROP TABLE #DirectAccountTmp
	DROP TABLE #TmpLog
END