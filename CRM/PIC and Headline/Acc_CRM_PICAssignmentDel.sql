/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_PICAssignmentDel]
	@RemovedPICs	NVARCHAR(MAX),
	@InActivatedPIC BIT = 0,
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

	DECLARE @iDOC INT, @NewValues XML,@PicID INT,@PicName NVARCHAR(200), @RowTotal INT = 0, @CurrentRow INT = 0, @CustId INT = 0,
			@ActionID INT = 0

	CREATE TABLE #input 
	(
		ID              INT IDENTITY(1,1) PRIMARY KEY,
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
	
	SELECT @InActivatedPIC = ISNULL(@InActivatedPIC,0)

	IF @InActivatedPIC = 1
	BEGIN
	    SELECT @PicID = PicID FROM #input WHERE CustID = 0 AND HeadlineID = 0

		SELECT @PicName = Username FROM  dbo.crmPIC WITH(NOLOCK) WHERE PicID = @PicID

		INSERT INTO #input
		(
			HeadlineID,
			CustID,
			PicID
		)
		SELECT	h.CustID,
				m.CustID,
				@PicID
		FROM dbo.crmPicManagement m WITH(NOLOCK)
			LEFT JOIN bodb02.dbo.custAccount a WITH(NOLOCK) ON m.CustID = a.custid
			LEFT JOIN bodb02.dbo.CustGroupHeadline h WITH(NOLOCK) ON h.GroupID = a.groupID AND h.GroupID <> 0
		WHERE m.PicID = @PicID
		
		DELETE #input
		WHERE CustID = 0

		DELETE t
		FROM dbo.crmPicManagement t
		WHERE t.PicID = @PicID

		DELETE t
		FROM dbo.crmPICHeadline t
		WHERE PicID = @PicID

	END

	UPDATE t
		SET t.PICName = p.Username,
			t.HeadlineName = h.username,
			t.UserName = m.username
	FROM #input t 
		INNER JOIN dbo.crmPIC p WITH(NOLOCK) ON t.PicID = p.PicID
		LEFT JOIN bodb02.dbo.Customer h WITH(NOLOCK) ON h.custid = t.HeadlineID
		INNER JOIN bodb02.dbo.Customer m WITH(NOLOCK) ON m.custid = t.CustID

	IF @InActivatedPIC = 0
	BEGIN
		DELETE t
		FROM dbo.crmPicManagement t
			INNER JOIN #input i ON t.CustID = i.CustID AND t.PicID = i.PicID

		DELETE t
		FROM dbo.crmPICHeadline t
			INNER JOIN bodb02.dbo.CustGroupHeadline h WITH(NOLOCK) ON t.HeadlineID = h.CustID
			INNER JOIN #input i ON t.HeadlineID = i.HeadlineID AND t.PicID = i.PicID	
		WHERE NOT EXISTS(
			SELECT 1
			FROM bodb02.dbo.custAccount c WITH(NOLOCK)
				INNER JOIN dbo.crmPicManagement p WITH(NOLOCK) ON p.CustID = c.custid
			WHERE c.groupID = h.GroupID AND p.PicID = i.PicID
		)
	END	
	SELECT @RowTotal = COUNT(*) FROM #input

	SELECT @CurrentRow = 1

	IF @InActivatedPIC = 0
		SET @ActionID = 904
	ELSE
		SET @ActionID = 907
	 

	--WHILE @RowTotal >= @CurrentRow
	--BEGIN
		

	--	IF @InActivatedPIC = 0
	--	BEGIN
	--		SELECT @CustId = CustId FROM #input WHERE ID = @CurrentRow

	--		SELECT @NewValues =	(SELECT PicID			AS 'PicID',
	--									PicName			AS 'PicName'
	--							 FROM #input
	--							 WHERE ID = @CurrentRow
	--							 FOR XML PATH('Acc_CRM_PICAssignmentDel'))
	--	END
	--	ELSE 
	--	BEGIN
	--		SELECT @CustId = PicID FROM #input WHERE ID = @CurrentRow

	--		SELECT @NewValues =	(SELECT CustID			AS 'CustID',
	--									UserName		AS 'UserName'
	--							 FROM #input
	--							 WHERE ID = @CurrentRow
	--							 FOR XML PATH('Acc_CRM_PICAssignmentDel'))
	--	END

	--	EXEC dbo.WriteLog_UserLog_crmUserLog_RunSP
	--		@UserID = @UserID,
	--		@CustId = @CustId,
	--		@ActionID = @ActionID,
	--		@IP = @LoginIP,
	--		@NewValues = @NewValues

	--	SELECT @CurrentRow = @CurrentRow + 1
	--END
	
	
	DROP TABLE #input	
END