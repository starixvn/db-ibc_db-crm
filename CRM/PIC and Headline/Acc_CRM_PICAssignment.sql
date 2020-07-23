/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_PICAssignment]
	@HeadlineID		INT,
	@PicID			VARCHAR(200),
	@DirectAccount	VARCHAR(1000),
	@IsKeepAssign   BIT = 1,
	@UserID			INT,
	@LoginIP        VARCHAR(20) ='',
	@ErrorCode      INT = 0 OUTPUT,
	@ErrorMsg       NVARCHAR(MAX) = '' OUTPUT
	
AS
/*
Created: 20200506@Malcolm
Task :  CRM - Staff/Boss Management of headline
DB: DBCRM/bodb_CRM
Original:

	Revisions:
		- 20200506@Malcolm: CRM - Staff/Boss Management of headline [Redmine: #108739]
		- 20200723@Malcolm : change log [RedmineId : #137144]
	Param's Explanation:
	
		
*/
BEGIN
	SET NOCOUNT ON
	
	CREATE TABLE #DirectAccountTmp (CustID INT, Username VARCHAR(30))

	CREATE TABLE #TmpLog
	(
		HeadlineName VARCHAR(30), 
		PicName NVARCHAR(200), 
		PicID INT, 
		Username VARCHAR(30), 
		CustID INT,
		Type INT
	)

	DECLARE @Tmp_Cust TABLE (CustID INT)

	DECLARE @HeadlineName VARCHAR(30) = '', @GroupID INT = 0,@NewValues XML, @OldValues XML, 
			@RowTotal INT = 0, @CurrentRow INT = 1, @CustId INT = 0, @Xml XML, @_CustID INT
	
	SELECT @HeadlineID = ISNULL(@HeadlineID,0)

	SELECT @HeadlineName = Username FROM bodb02.dbo.Customer WITH(NOLOCK) WHERE custid = @HeadlineID

	SELECT @GroupID = GroupID FROM bodb02.dbo.CustGroupHeadline WITH(NOLOCK) WHERE custid = @HeadlineID

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

	SET @IsKeepAssign = ISNULL(@IsKeepAssign,0)

	IF @IsKeepAssign = 0 
	BEGIN
	    BEGIN TRY
			DELETE m
			OUTPUT @HeadlineName, p.Username, p.PicID,t.Username, t.CustID, 1
				INTO #TmpLog (HeadlineName, PicName, PicID, Username, CustID, Type)
			FROM dbo.crmPicManagement m WITH(ROWLOCK, UPDLOCK)
				INNER JOIN #DirectAccountTmp t ON m.CustID = t.CustID
				LEFT JOIN  dbo.crmPIC p WITH(NOLOCK) ON p.PicID = m.PicID

			DELETE h
			OUTPUT deleted.HeadlineID, deleted.PicID, 2
				INTO #TmpLog (CustID, PicID, Type)
			FROM dbo.crmPICHeadline h WITH(ROWLOCK, UPDLOCK)
			WHERE h.HeadlineID = @HeadlineID  
				AND h.PicID IN (SELECT PicID FROM #TmpLog WHERE type = 1)

			INSERT INTO dbo.crmPICHeadline
			(
				HeadlineID,
				PicID
			)
			SELECT DISTINCT @HeadlineID, m.PicID
			FROM dbo.crmPicManagement m WITH(NOLOCK)
				INNER JOIN bodb02.dbo.CustAccount c WITH(NOLOCK) ON m.CustID = c.custid
			WHERE  c.groupID = @GroupID  AND @GroupID <> 0
				AND m.PicID IN (SELECT PicID FROM #TmpLog WHERE Type = 1)	
		END TRY
		BEGIN CATCH
			SELECT @ErrorCode = @@ERROR, @ErrorMsg = ERROR_MESSAGE()

			IF EXISTS(SELECT 1 FROM #TmpLog WHERE Type = 1)
			BEGIN
				INSERT INTO dbo.crmPicManagement(CustID, PicID)
				SELECT CustID, PicID
				FROM #TmpLog
				WHERE Type = 1
			END

			IF EXISTS(SELECT 1 FROM #TmpLog WHERE Type = 2)
			BEGIN
				INSERT INTO dbo.crmPICHeadline(HeadlineID, PicID)
				SELECT CustID, PicID
				FROM #TmpLog 
				WHERE Type = 2
			END

			RETURN
		END CATCH
				
	END

	DELETE #TmpLog WHERE Type = 2

	INSERT INTO #TmpLog
	(
			HeadlineName,
			PicName,
			PicID,
			Username,
			CustID,
			Type
	)		
	SELECT	@HeadlineName,
			l.PicName,
			l.PicID, 
			t.Username,		
			t.CustID,
			3
	FROM #DirectAccountTmp t
	   CROSS APPLY(
		SELECT Val AS PicID , r.Username AS PicName
		FROM bodb02.dbo.strSplit(@PicID,',') AS s
			INNER JOIN dbo.crmPIC r WITH(NOLOCK) ON s.val = r.PicID
	)l

	BEGIN TRY
		INSERT INTO dbo.crmPicManagement
		(
				PicID,
				CustID
		)	
		OUTPUT inserted.PicID, inserted.CustID, 4
			INTO #TmpLog (PicID, CustID, Type)
		SELECT	PicID,
				CustID
		FROM #TmpLog l
		WHERE (@IsKeepAssign = 0 
			OR NOT EXISTS(SELECT 1 
			FROM dbo.crmPicManagement WITH(NOLOCK) 
			WHERE PicID = l.PicID AND CustID = l.CustID)) AND l.Type = 3

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
		) AND @HeadlineID <> 0 AND l.Type = 3
	END TRY
	BEGIN CATCH
		SELECT @ErrorCode = @@ERROR, @ErrorMsg = ERROR_MESSAGE()

		IF EXISTS(SELECT 1 FROM #TmpLog WHERE Type = 4)
		BEGIN
			DELETE m 
			FROM dbo.crmPicManagement m WITH(ROWLOCK, UPDLOCK)
			WHERE EXISTS(SELECT 1 
						 FROM #TmpLog t WHERE Type = 4 
						 AND m.CustID = t.CustID 
						 AND m.PicID = t.PicID)
		END

		RETURN
	END CATCH 
	
	DELETE #TmpLog WHERE Type = 4

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
			SELECT @NewValues  = (SELECT PicID			AS '@PicID',
										 PicName		AS '@PicName'
								  FROM #TmpLog
								  WHERE CustID = @_CustID AND Type = 1
								  FOR XML PATH('PIC'), ROOT('Acc_CRM_PICAssignment'))	

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

	DELETE #TmpLog WHERE Type <> 3

	INSERT INTO @Tmp_Cust
	(
		CustID
	)
	SELECT DISTINCT CustID
	FROM #TmpLog
	WHERE Type = 3

	DECLARE cursor_custid_ CURSOR FOR SELECT CustID FROM @Tmp_Cust 
	OPEN cursor_custid_ 
	FETCH NEXT FROM cursor_custid_ INTO @_CustID

	WHILE @@FETCH_STATUS = 0
	BEGIN
		SELECT @NewValues =	(SELECT PicID			AS 'PicID',
								    PicName			AS 'PicName'
							FROM #TmpLog
							WHERE CustID = @_CustID
							FOR XML PATH('PIC'),ROOT('Acc_CRM_PICAssignment'))
	
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