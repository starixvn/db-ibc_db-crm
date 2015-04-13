ALTER PROCEDURE [dbo].[Acc_CRM_InformHeadlineSearchUpd]
	@TitleID		INT,
	@Title			NVARCHAR(2000),
	@Currency		VARCHAR(1000) = '',
	@Level			VARCHAR(10) = '',
	@Site			VARCHAR(4000) = '',
	@TypeAccount	TINYINT,
	@ChangeFilter	BIT, 	
	@Content		XML,
	@UserID			INT,
	@IP				VARCHAR(40),
	@ErrCode		INT	= 0 OUTPUT,
	@ErrMsg			NVARCHAR(4000) = '' OUTPUT	
AS	
/*
	Created: Elodie
	Date: 2015-04-03
	Task: Update inform headline
	DB: DBCRM/bodb_CRM
		
	Revisions:

	Parameter's Explanation:				
		- @TypeAccount =1: Headline
						2: Direct account
						3: Both
		- @ChangeFilter =0: Not change
						=1: Change filter
	Example: EXEC Acc_CRM_InformHeadlineSearchUpd @TitleID = 1, @Currency = '20,10,2', @Level = '3,4', @Site = 'BEST-ODDS,722222,222223', @TypeAccount = 3, @ChangeFilter = 0
*/
BEGIN
	SET NOCOUNT ON
	IF @Currency = '' OR @Level = '' OR @Site = ''
	BEGIN
		SELECT @ErrCode = 101, @ErrMsg = 'At least 1 option is selected.'
		RETURN
	END	

	DECLARE @tmpCurrency TABLE (currency INT)	
	DECLARE @tmpLevel TABLE (id INT IDENTITY(1,1), roleID INT)	
	DECLARE @tmpSite TABLE (Site VARCHAR(50))	
	CREATE TABLE #DirectAcc (CustID INT PRIMARY KEY, GroupID INT)	

	INSERT INTO @tmpCurrency
	SELECT val
	FROM f_split (@Currency,',')

	INSERT INTO @tmpLevel
	SELECT val
	FROM f_split (@Level,',')

	INSERT INTO @tmpSite
	SELECT val
	FROM f_split (@Site,',')

	IF @TypeAccount = 1 OR @TypeAccount = 3
	BEGIN
	INSERT INTO #DirectAcc (CustID, GroupID)
	SELECT DISTINCT hl.custid, hl.groupID
	FROM bodb02.dbo.custAccount hl WITH (NOLOCK)  
		INNER JOIN bodb02.dbo.Customer ch WITH (NOLOCK) ON hl.custid = ch.custid
		INNER JOIN bodb02.dbo.CustInfo cih WITH (NOLOCK) ON ch.custid = cih.custid
		INNER JOIN bodb02.dbo.custAccount m WITH (NOLOCK) ON hl.groupID = m.groupID
		INNER JOIN bodb02.dbo.Customer cm WITH (NOLOCK) ON m.custid = cm.custid
		INNER JOIN bodb02.dbo.CustInfo cim WITH (NOLOCK) ON cm.custid = cim.custid
	WHERE hl.IsGroupHeadLine = 1 
		AND m.IsGroupHeadLine = 0 
		AND ch.roleid IN (SELECT roleID FROM @tmpLevel)
		AND (ch.currency IN (SELECT currency FROM @tmpCurrency) OR cm.currency IN (SELECT currency FROM @tmpCurrency)) 
		AND (ch.site IN (SELECT Site FROM @tmpSite) OR cm.site IN (SELECT Site FROM @tmpSite))
		AND ((cih.closed=0 AND ISNULL(cih.reject,0) = 0 AND cih.Enabled = 1) OR (cim.closed=0 AND ISNULL(cim.reject,0) = 0) AND cim.Enabled = 1)
		AND hl.groupID > 0
	END

	IF @TypeAccount = 2 OR @TypeAccount = 3
	BEGIN
		INSERT INTO #DirectAcc (CustID, GroupID)
		SELECT c.CustID, 0
		FROM bodb02.dbo.Customer c WITH (NOLOCK) 
			INNER JOIN bodb02.dbo.CustInfo ci WITH (NOLOCK) ON c.custid = ci.custid
		WHERE c.roleid IN (SELECT roleID FROM @tmpLevel)
			AND NOT EXISTS (SELECT 1 FROM bodb02.dbo.Acc_CustDirect WITH (NOLOCK) WHERE custid = c.custid AND roleid IN (SELECT roleID FROM @tmpLevel))
			AND NOT EXISTS (SELECT 1 FROM bodb02.dbo.custAccount WITH (NOLOCK) WHERE custid = c.custid AND groupid > 0)
			AND c.currency IN (SELECT currency FROM @tmpCurrency) 
			AND c.site IN (SELECT Site FROM @tmpSite)
			AND ci.closed=0 AND ISNULL(ci.reject,0) = 0	AND ci.Enabled = 1
	END		

	DECLARE @HeadlineData TABLE(HeadlineID INT, GroupID INT, InformHeadlineStatusID INT, Remark NVARCHAR(4000), Extension INT, ProductStatus INT, IsKeep BIT)
	DECLARE @HeadlineDataOld TABLE(HeadlineID INT, GroupID INT, InformHeadlineStatusID INT, Remark NVARCHAR(4000), Extension INT, ProductStatus INT)

	INSERT INTO @HeadlineData
	SELECT	xmlData.Col.value('@HeadlineID','INT') HeadlineID,
			xmlData.Col.value('@GroupID','INT') GroupID,
			xmlData.Col.value('@StatusID','INT') InformHeadlineStatusID,
			dbo.[f_EncodeXMLValue](xmlData.Col.value('@Remark','NVARCHAR(4000)')) Remark,
			ISNULL(xmlData.Col.value('@Extension','INT'),0) Extension,
			ISNULL(xmlData.Col.value('@ProductStatus','INT'),0) ProductStatus,
			xmlData.Col.value('@IsKeep','BIT') IsKeep
	FROM @Content.nodes('//Content/Headline') xmlData(Col)

	INSERT INTO @HeadlineDataOld
	SELECT ih.HeadlineID, ih.GroupID, ih.InformHeadlineStatusID, ih.Remark, ih.Extension, ih.ProductStatus
	FROM @HeadlineData hl
		INNER JOIN crmInformHeadline ih WITH (NOLOCK) ON hl.HeadlineID = ih.HeadlineID
	
	CREATE TABLE #NewDirectAcc (CustID_New INT, GroupID_New INT, CustID_Old INT, GroupID_Old INT, Cases TINYINT)
	IF @ChangeFilter = 1
	BEGIN		
		INSERT INTO #NewDirectAcc (CustID_New, GroupID_New, CustID_Old, GroupID_Old, Cases)
		SELECT	ac.CustID, ac.GroupID, ih.HeadlineID, ih.GroupID,
				CASE WHEN ih.GroupID IS NULL THEN 2 WHEN ac.GroupID IS NULL AND ih.InformHeadlineStatusID <> 45007 THEN 1 ELSE 0 END AS Cases
		FROM crmInformHeadline ih WITH (NOLOCK)
			FULL OUTER JOIN #DirectAcc ac ON ih.GroupID = ac.GroupID AND ih.HeadlineID = ac.CustID
		WHERE (ih.TitleID = @TitleID OR ih.TitleID IS NULL) AND (ih.IsInform = 1 OR ih.IsInform IS NULL)		
	END
	ELSE
	BEGIN
		INSERT INTO #NewDirectAcc (CustID_New, GroupID_New, CustID_Old, GroupID_Old, Cases)
		SELECT	ac.CustID, ac.GroupID, ih.HeadlineID, ih.GroupID,
				CASE WHEN ih.HeadlineID IS NULL THEN 2 ELSE CASE WHEN ci.closed=0 AND ISNULL(ci.reject,0)=0 AND ci.Enabled=1 THEN 5 ELSE 1 END END
		FROM crmInformHeadline ih WITH (NOLOCK)
			FULL OUTER JOIN #DirectAcc ac ON ih.HeadlineID = ac.CustID
			LEFT JOIN bodb02.dbo.CustInfo ci WITH (NOLOCK) ON ih.HeadlineID = ci.custid
		WHERE ih.HeadlineID IS NULL OR ac.CustID IS NULL AND (ih.TitleID = @TitleID OR ih.TitleID IS NULL)
			AND (ih.IsInform = 1 OR ih.IsInform IS NULL) AND ih.InformHeadlineStatusID <> 45007

		INSERT INTO #NewDirectAcc (CustID_New, GroupID_New, CustID_Old, GroupID_Old, Cases)
		SELECT	ac.CustID, ac.GroupID, ih.HeadlineID, ih.GroupID,
				CASE WHEN ih.GroupID = 0 THEN 4 ELSE 2 END
		FROM crmInformHeadline ih WITH (NOLOCK)
			INNER JOIN #DirectAcc ac ON ih.HeadlineID = ac.CustID
		WHERE (ih.GroupID = 0 OR ac.GroupID = 0) AND ac.GroupID <> ih.GroupID AND ih.TitleID = @TitleID AND ih.IsInform = 1 AND ih.InformHeadlineStatusID <> 45007

		INSERT INTO #NewDirectAcc (CustID_New, GroupID_New, CustID_Old, GroupID_Old, Cases)
		SELECT	ac.CustID, ac.GroupID, ih.HeadlineID, ih.GroupID,
				3
		FROM crmInformHeadline ih WITH (NOLOCK)
			INNER JOIN #DirectAcc ac ON ih.GroupID = ac.GroupID
		WHERE ih.GroupID <> 0 AND ih.HeadlineID <> ac.CustID AND ih.TitleID = @TitleID AND ih.IsInform = 1 AND ih.InformHeadlineStatusID <> 45007

		INSERT INTO #NewDirectAcc (CustID_New, GroupID_New, CustID_Old, GroupID_Old, Cases)
		SELECT	ac.CustID, ac.GroupID, ih.HeadlineID, ih.GroupID,
				0
		FROM crmInformHeadline ih WITH (NOLOCK)
			INNER JOIN #DirectAcc ac ON ih.GroupID = ac.GroupID AND ih.HeadlineID = ac.CustID
		WHERE ih.TitleID = @TitleID AND ih.IsInform = 1 AND ih.InformHeadlineStatusID <> 45007

		INSERT INTO #NewDirectAcc (CustID_New, GroupID_New, CustID_Old, GroupID_Old, Cases)
		SELECT	ih.HeadlineID, ih.GroupID, ih.HeadlineID, ih.GroupID,
				0
		FROM crmInformHeadline ih WITH (NOLOCK)
		WHERE ih.TitleID = @TitleID AND ih.InformHeadlineStatusID = 45007		
	END	
	--MERGE crmInformHeadline ih
	--USING (SELECT HeadlineID, GroupID, InformHeadlineStatusID, Remark, Extension, ProductStatus FROM @HeadlineData) AS h (HeadlineID, GroupID, InformHeadlineStatusID, Remark, Extension, ProductStatus) 
	--ON (ih.HeadlineID = h.HeadlineID AND ih.TitleID = @TitleID)
	--WHEN MATCHED THEN 
	--	UPDATE SET	ih.GroupID = h.GroupID,
	--				ih.InformHeadlineStatusID = h.InformHeadlineStatusID
	--WHEN NOT MATCHED THEN
	--	INSERT (HeadlineID, TitleID, InformHeadlineStatusID, GroupID, UpdatedTime, Remark, Handler, Extension, ProductStatus, IsInform)
	--	VALUES (h.HeadlineID, @TitleID, h.InformHeadlineStatusID, h.GroupID, GETDATE(), h.Remark, @UserID, h.Extension, h.ProductStatus, 1);
	DECLARE @Filter VARCHAR(4000)
	SELECT @Filter = '<Filters Site = ''' + @Site + ''' Position  = ''' + @Level + ''' Currency  = ''' + @Currency + ''' DirrectAccount  = ''' + CONVERT(VARCHAR(1),@TypeAccount) + '''></Filters>'

	UPDATE crmInformTitle WITH (ROWLOCK, UPDLOCK)
	SET Title = @Title, 
		CreatedDate = GETDATE(),
		Creator = @UserID,
		Filter = @Filter
	WHERE TitleID = @TitleID

	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrCode = 102
		SELECT @ErrMsg = 'Update case unsuccessfuly.'
		RETURN
	END	

	UPDATE ih
	SET HeadlineID = CASE WHEN ac.Cases = 3 THEN ac.CustID_New ELSE ih.HeadlineID END,
		GroupID = CASE WHEN ac.Cases = 4 THEN ac.GroupID_New ELSE ih.GroupID END,
		InformHeadlineStatusID = CASE WHEN hl.IsKeep = 1 THEN 45007 ELSE hl.InformHeadlineStatusID END,
		Remark = hl.Remark,
		Extension = hl.Extension,
		ProductStatus = hl.ProductStatus,
		IsInform = CASE WHEN (ac.Cases = 1  OR ac.Cases = 5) AND (hl.IsKeep = 0 OR hl.IsKeep = NULL) THEN 0 ELSE IsInform END,
		UpdatedTime = GETDATE(),
		Handler = @UserID
	FROM crmInformHeadline ih WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #NewDirectAcc ac ON ih.HeadlineID = ac.CustID_Old
		LEFT JOIN @HeadlineData hl ON ih.HeadlineID = hl.HeadlineID			
	WHERE ih.TitleID = @TitleID		

	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrCode = 103
		SELECT @ErrMsg = 'Update case unsuccessfuly.'
		RETURN
	END

	UPDATE ih
	SET HeadlineID = ac.CustID_New,
		GroupID = ac.GroupID_New,
		InformHeadlineStatusID = 45006,
		Remark = hl.Remark,
		Extension = hl.Extension,
		ProductStatus = hl.ProductStatus,
		IsInform = 1,
		UpdatedTime = GETDATE(),
		Handler = @UserID
	FROM crmInformHeadline ih WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #NewDirectAcc ac ON ih.HeadlineID = ac.CustID_Old
		LEFT JOIN @HeadlineData hl ON ih.HeadlineID = hl.HeadlineID			
	WHERE ih.TitleID = @TitleID	AND ac.Cases = 2

	INSERT INTO crmInformHeadline (HeadlineID, TitleID, InformHeadlineStatusID, GroupID, UpdatedTime, Remark, Handler, Extension, ProductStatus, IsInform)
	SELECT ac.CustID_New, @TitleID, ISNULL(hl.InformHeadlineStatusID, 45006), ac.GroupID_New, GETDATE(), ISNULL(hl.Remark, ''), @UserID, hl.Extension, hl.ProductStatus, 1
	FROM #NewDirectAcc ac
		LEFT JOIN @HeadlineData hl ON ac.CustID_New = hl.HeadlineID
	WHERE ac.Cases = 2 AND ac.CustID_New NOT IN (SELECT HeadlineID FROM crmInformHeadline WITH (NOLOCK) WHERE TitleID = @TitleID)

	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrCode = 104
		SELECT @ErrMsg = 'Update case unsuccessfuly.'
		RETURN
	END

	-- write log
	DECLARE @OldValues XML, @NewValues XML

	DECLARE @HeadlineID INT
	DECLARE HeadlineID_cursor CURSOR FOR
	SELECT CustID_New FROM #NewDirectAcc

	OPEN HeadlineID_cursor
	FETCH NEXT FROM HeadlineID_cursor INTO @HeadlineID
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SELECT @OldValues = 				
					'<Acc_CRM_InformHeadlineSearchUpd>'			+ --SP Name
						'<Title>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Title),'')											+ '</Title>' +
						'<Currency>'					+ @Currency																				+ '</Currency>' +
						'<Level>'						+ @Level																				+ '</Level>' +
						'<Site>'						+ @Site																					+ '</Site>' +
						'<TypeAccount>'					+ CONVERT(VARCHAR(1), @TypeAccount)														+ '</TypeAccount>' +
						'<GroupID>'						+ CAST(ISNULL(hl.GroupID, -1) AS VARCHAR(30))											+ '</GroupID>' +
						'<StatusID>'					+ CAST(ISNULL(hl.InformHeadlineStatusID, -1) AS VARCHAR(30))							+ '</StatusID>' +
						'<Remark>'						+ ISNULL([dbo].[f_EncodeXMLValue](Remark),'')											+ '</Remark>' +
						'<Extension>'					+ ISNULL(CAST(Extension AS VARCHAR(30)),'')												+ '</Extension>'+													
						'<ProductStatus>'				+ ISNULL(CAST(ProductStatus AS VARCHAR(30)),'')											+'</ProductStatus>'	+
						'<IsKeep>'						+ CAST(CASE WHEN hl.InformHeadlineStatusID = 45007 THEN 1 ELSE 0 END AS VARCHAR(1))		+ '</IsKeep>' +
						'<Case>'						+ '0'																					+ '</Case>' +
					'</Acc_CRM_InformHeadlineSearchUpd>' 
		FROM #NewDirectAcc ac
			LEFT JOIN @HeadlineDataOld hl ON ac.CustID_New = hl.HeadlineID
		WHERE CustID_New = @HeadlineID

		SELECT @NewValues = 				
					'<Acc_CRM_InformHeadlineSearchUpd>'			+ --SP Name
						'<Title>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Title),'')											+ '</Title>' +
						'<Currency>'					+ @Currency																				+ '</Currency>' +
						'<Level>'						+ @Level																				+ '</Level>' +
						'<Site>'						+ @Site																					+ '</Site>' +
						'<TypeAccount>'					+ CONVERT(VARCHAR(1), @TypeAccount)														+ '</TypeAccount>' +
						'<GroupID>'						+ CAST(ISNULL(hl.GroupID, -1) AS VARCHAR(30))											+ '</GroupID>' +
						'<StatusID>'					+ CAST(ISNULL(hl.InformHeadlineStatusID, -1) AS VARCHAR(30))							+ '</StatusID>' +
						'<Remark>'						+ ISNULL([dbo].[f_EncodeXMLValue](Remark),'')											+ '</Remark>' +
						'<Extension>'					+ ISNULL(CAST(Extension AS VARCHAR(30)),'')												+ '</Extension>'+													
						'<ProductStatus>'				+ ISNULL(CAST(ProductStatus AS VARCHAR(30)),'')											+'</ProductStatus>'	+
						'<IsKeep>'						+ CAST(ISNULL(hl.IsKeep, 0) AS VARCHAR(1))												+ '</IsKeep>' +
						'<Case>'						+ CAST(ISNULL(ac.Cases, 0) AS VARCHAR(30))												+ '</Case>' +
					'</Acc_CRM_InformHeadlineSearchUpd>' 
		FROM #NewDirectAcc ac
			LEFT JOIN @HeadlineData hl ON ac.CustID_New = hl.HeadlineID
		WHERE CustID_New = @HeadlineID

		EXEC [dbo].[WriteLog_UserLog_crmLogInformHeadline]
			@CustID = @HeadlineID, 
			@TitleID = @TitleID,
			@UserID = @UserID,  
			@ActionID = 703, 
			@IP = @IP, 				
			@NewValues = @NewValues,	
			@OldValues = @OldValues
		FETCH NEXT FROM HeadlineID_cursor INTO @HeadlineID
	END
	CLOSE HeadlineID_cursor
	DEALLOCATE HeadlineID_cursor
END

GO 
GRANT EXECUTE ON [dbo].[Acc_CRM_InformHeadlineSearchUpd] TO [bodbAdminNet]
GO 
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_InformHeadlineSearchUpd] TO [vnteam]