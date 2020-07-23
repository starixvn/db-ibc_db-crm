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
		- 20200723@Malcolm : change log [RedmineId : #137144]
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

	DECLARE @iDOC INT, @NewValues XML,@PicID INT,@PicName NVARCHAR(200), @RowTotal INT = 0, @CurrentRow INT = 0

	DECLARE @TmpLog TABLE (CustID INT, PicID INT, Type INT)

    CREATE TABLE #TmpLog
	(
		ID		INT IDENTITY(1,1) PRIMARY KEY,
		CustID	INT
	)

	CREATE TABLE #input 
	(
		HeadlineID		INT,
		HeadlineName	VARCHAR(30),
		CustID			INT,
		UserName        VARCHAR(30),
		PICName			NVARCHAR(200),
		PicID			INT
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
	
	UPDATE t
		SET t.PICName = p.Username,
			t.HeadlineName = h.username,
			t.UserName = m.username
	FROM #input t 
		INNER JOIN dbo.crmPIC p WITH(NOLOCK) ON t.PicID = p.PicID
		LEFT JOIN bodb02.dbo.Customer h WITH(NOLOCK) ON h.custid = t.HeadlineID
		INNER JOIN bodb02.dbo.Customer m WITH(NOLOCK) ON m.custid = t.CustID
	
	BEGIN TRY
		DELETE t
		OUTPUT deleted.CustID, deleted.PicID, 1
			INTO @TmpLog (CustID, PicID, Type)
		FROM dbo.crmPicManagement t WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #input i ON t.CustID = i.CustID AND t.PicID = i.PicID
	
		DELETE t
		OUTPUT deleted.HeadlineID, deleted.PicID, 2
			INTO @TmpLog(CustID, PicID, Type)
		FROM dbo.crmPICHeadline t WITH(ROWLOCK, UPDLOCK)
			INNER JOIN bodb02.dbo.CustGroupHeadline h WITH(NOLOCK) ON t.HeadlineID = h.CustID
			INNER JOIN #input i ON t.HeadlineID = i.HeadlineID AND t.PicID = i.PicID	
		WHERE NOT EXISTS(
			SELECT 1
			FROM bodb02.dbo.custAccount c WITH(NOLOCK)
				INNER JOIN dbo.crmPicManagement p WITH(NOLOCK) ON p.CustID = c.custid
			WHERE c.groupID = h.GroupID AND p.PicID = i.PicID
		)
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR, @ErrMsg = ERROR_MESSAGE()

		IF EXISTS(SELECT 1 FROM @TmpLog WHERE Type = 2)
		BEGIN
			INSERT INTO dbo.crmPICHeadline (HeadlineID, PicID)
			SELECT CustID, PicID
			FROM @TmpLog 
			WHERE Type = 2
		END

		IF EXISTS(SELECT 1 FROM @TmpLog WHERE Type = 1)
		BEGIN
			INSERT INTO dbo.crmPicManagement (CustID, PicID)
			SELECT CustID, PicID
			FROM @TmpLog
			WHERE Type = 1
		END

		RETURN
	END CATCH
	
	
	INSERT INTO #TmpLog
	(
		CustID
	)
	SELECT DISTINCT CustID
	FROM #input

	DECLARE @_CustID INT

	DECLARE cursor_custid CURSOR FOR SELECT CustID FROM #TmpLog
	OPEN cursor_custid
	FETCH NEXT FROM cursor_custid INTO @_CustID 

	WHILE @@FETCH_STATUS = 0
	BEGIN	
	
			SELECT @NewValues =	(SELECT PicID			AS 'PicID',
										PicName			AS 'PicName'
								 FROM #input
								 WHERE CustID = @_CustID
								 FOR XML PATH('PIC'),ROOT('Acc_CRM_PICAssignmentDel'))

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
		
	DROP TABLE #input	

	DROP TABLE #TmpLog
END