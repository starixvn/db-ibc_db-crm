ALTER PROCEDURE [dbo].[Acc_CRM_InformHeadlineSearchUpd]
	@TitleID		INT,
	@Title			NVARCHAR(2000) = '',
	@Currency		VARCHAR(1000) = '',
	@Level			VARCHAR(10) = '',
	@Site			VARCHAR(4000) = '',
	@TypeAccount	TINYINT,
	@ChangeFilter	BIT, 	
	@Content		XML = '',
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
	Example:  EXEC Acc_CRM_InformHeadlineSearchUpd @TitleID = 1, @Currency = '20,10,2', @Level = '3,4', @Site = 'BEST-ODDS,722222,222223', @TypeAccount = 3, @ChangeFilter = 0
*/
BEGIN
	SET NOCOUNT ON
	IF @Currency = '' OR @Level = '' OR @Site = ''
	BEGIN
		SELECT @ErrCode = 101, @ErrMsg = 'At least 1 option is selected.'
		RETURN
	END	
	
	CREATE TABLE #DirectAcc (CustID INT PRIMARY KEY, GroupID INT)	
	INSERT INTO #DirectAcc (CustID, GroupID)
	SELECT CustID, GroupID FROM bodb02.dbo.f_InformHeadlineList (@Currency, @Level, @Site, @TypeAccount) 		

	DECLARE @HeadlineData TABLE(HeadlineID INT, GroupID INT, InformHeadlineStatusID INT, Remark NVARCHAR(4000), Extension INT, ProductStatus INT, IsKeep BIT)
	DECLARE @HeadlineDataOld TABLE(HeadlineID INT, GroupID INT, InformHeadlineStatusID INT, Remark NVARCHAR(4000), Extension INT, ProductStatus INT, Handler INT, UpdatedTime DATETIME, IsInform BIT)

	--Infomation which user input 
	INSERT INTO @HeadlineData
	SELECT	xmlData.Col.value('@HeadlineID','INT') HeadlineID,
			xmlData.Col.value('@GroupID','INT') GroupID,
			xmlData.Col.value('@StatusID','INT') InformHeadlineStatusID,
			dbo.[f_EncodeXMLValue](xmlData.Col.value('@Remark','NVARCHAR(4000)')) Remark,
			ISNULL(xmlData.Col.value('@Extension','INT'),0) Extension,
			ISNULL(xmlData.Col.value('@ProductStatus','INT'),0) ProductStatus,
			xmlData.Col.value('@IsKeep','BIT') IsKeep
	FROM @Content.nodes('//Content/Headline') xmlData(Col)		
	
	CREATE TABLE #NewDirectAcc (CustID_New INT, GroupID_New INT, CustID_Old INT, GroupID_Old INT, Cases TINYINT)
	IF @ChangeFilter = 1 --if filter is changed
	BEGIN		
		INSERT INTO #NewDirectAcc (CustID_New, GroupID_New, CustID_Old, GroupID_Old, Cases)
		SELECT	ac.CustID, ac.GroupID, ih.HeadlineID, ih.GroupID,							
				CASE WHEN ih.GroupID IS NULL THEN 2 WHEN ac.GroupID IS NULL THEN 1 WHEN ih.GroupID = 0 AND ac.GroupID <> 0 THEN 4 WHEN ih.GroupID <> 0 AND ac.GroupID = 0 THEN 2 ELSE 0 END AS Cases
		FROM #DirectAcc ac
			FULL OUTER JOIN (SELECT * FROM crmInformHeadline_New WITH (NOLOCK) WHERE TitleID = @TitleID AND IsInform = 1 AND InformHeadlineStatusID <> 45007) ih ON ih.HeadlineID = ac.CustID		

		INSERT INTO #NewDirectAcc (CustID_New, GroupID_New, CustID_Old, GroupID_Old, Cases)
		SELECT	ih.HeadlineID, ih.GroupID, ih.HeadlineID, ih.GroupID,							
				0 AS Cases
		FROM crmInformHeadline_New ih WITH (NOLOCK) 
		WHERE TitleID = @TitleID AND IsInform = 1 AND InformHeadlineStatusID = 45007
			AND ih.HeadlineID NOT IN (SELECT CustID_New FROM #NewDirectAcc WHERE CustID_New IS NOT NULL)
	END
	ELSE --if filter is not changed
	BEGIN				
		--Get headline list who is changed headlineID
		INSERT INTO #NewDirectAcc (CustID_New, GroupID_New, CustID_Old, GroupID_Old, Cases)
		SELECT	ac.CustID, ac.GroupID, ih.HeadlineID, ih.GroupID,
				3
		FROM crmInformHeadline_New ih WITH (NOLOCK)
			INNER JOIN #DirectAcc ac ON ih.GroupID = ac.GroupID
		WHERE ih.GroupID <> 0 AND ih.HeadlineID <> ac.CustID AND ih.TitleID = @TitleID AND ih.IsInform = 1  AND ih.InformHeadlineStatusID <> 45007

		--Get headline list who is changed group headline
		INSERT INTO #NewDirectAcc (CustID_New, GroupID_New, CustID_Old, GroupID_Old, Cases)
		SELECT	ac.CustID, ac.GroupID, ih.HeadlineID, ih.GroupID,
				CASE WHEN ih.GroupID = 0 THEN 4 ELSE 2 END
		FROM crmInformHeadline_New ih WITH (NOLOCK)
			INNER JOIN #DirectAcc ac ON ih.HeadlineID = ac.CustID
		WHERE (ih.GroupID = 0 OR ac.GroupID = 0) AND ac.GroupID <> ih.GroupID AND ih.TitleID = @TitleID AND ih.IsInform = 1 AND ih.InformHeadlineStatusID <> 45007		
			AND ac.CustID NOT IN (SELECT CustID_New FROM #NewDirectAcc)

		--Get headline list who is not changed
		INSERT INTO #NewDirectAcc (CustID_New, GroupID_New, CustID_Old, GroupID_Old, Cases)
		SELECT	ac.CustID, ac.GroupID, ih.HeadlineID, ih.GroupID,
				0
		FROM crmInformHeadline_New ih WITH (NOLOCK)
			INNER JOIN #DirectAcc ac ON ih.GroupID = ac.GroupID AND ih.HeadlineID = ac.CustID
		WHERE ih.TitleID = @TitleID AND ih.IsInform = 1 AND ih.InformHeadlineStatusID <> 45007

		--Get headline list who is found or removed now
		INSERT INTO #NewDirectAcc (CustID_New, GroupID_New, CustID_Old, GroupID_Old, Cases)
		SELECT	ac.CustID, ac.GroupID, ih.HeadlineID, ih.GroupID,
				CASE WHEN ih.HeadlineID IS NULL THEN 2 
				ELSE 
				CASE WHEN ci.closed=0 AND ISNULL(ci.reject,0)=0 AND ci.Enabled=1  THEN CASE WHEN ih.GroupID = 0 THEN 5 ELSE 1 END 
				ELSE 1 END END
		FROM #DirectAcc ac
			FULL OUTER JOIN (SELECT * FROM crmInformHeadline_New WITH (NOLOCK) WHERE TitleID = @TitleID AND IsInform = 1 AND InformHeadlineStatusID <> 45007) ih ON ih.HeadlineID = ac.CustID		
			LEFT JOIN bodb02.dbo.CustInfo ci WITH (NOLOCK) ON ih.HeadlineID = ci.custid
		WHERE (ih.HeadlineID IS NULL AND ac.CustID NOT IN (SELECT CustID_New FROM #NewDirectAcc)) OR (ac.CustID IS NULL AND ih.HeadlineID NOT IN (SELECT CustID_Old FROM #NewDirectAcc))	

		--Get headline list who is keep for reference
		INSERT INTO #NewDirectAcc (CustID_New, GroupID_New, CustID_Old, GroupID_Old, Cases)
		SELECT	ih.HeadlineID, ih.GroupID, ih.HeadlineID, ih.GroupID,
				0
		FROM crmInformHeadline_New ih WITH (NOLOCK)
		WHERE ih.TitleID = @TitleID AND ih.InformHeadlineStatusID = 45007
			AND ih.HeadlineID NOT IN (SELECT CustID_New FROM #NewDirectAcc)
	END	
	
	--MERGE crmInformHeadline_New ih
	--USING (SELECT HeadlineID, GroupID, InformHeadlineStatusID, Remark, Extension, ProductStatus FROM @HeadlineData) AS h (HeadlineID, GroupID, InformHeadlineStatusID, Remark, Extension, ProductStatus) 
	--ON (ih.HeadlineID = h.HeadlineID AND ih.TitleID = @TitleID)
	--WHEN MATCHED THEN 
	--	UPDATE SET	ih.GroupID = h.GroupID,
	--				ih.InformHeadlineStatusID = h.InformHeadlineStatusID
	--WHEN NOT MATCHED THEN
	--	INSERT (HeadlineID, TitleID, InformHeadlineStatusID, GroupID, UpdatedTime, Remark, Handler, Extension, ProductStatus, IsInform)
	--	VALUES (h.HeadlineID, @TitleID, h.InformHeadlineStatusID, h.GroupID, GETDATE(), h.Remark, @UserID, h.Extension, h.ProductStatus, 1);
	DECLARE @Filter VARCHAR(4000), @Old_Filter XML, @Old_Title NVARCHAR(2000), @Old_Site VARCHAR(4000), @Old_Currency VARCHAR(1000), @Old_Level VARCHAR(10), @Old_TypeAccount TINYINT
	
	SELECT @Filter = '<Filters Site = ''' + @Site + ''' Position  = ''' + @Level + ''' Currency  = ''' + @Currency + ''' DirectAccount  = ''' + CONVERT(VARCHAR(1),@TypeAccount) + '''></Filters>'
	SELECT @Old_Title = Title, @Old_Filter = Filter FROM crmInformTitle_New WITH (NOLOCK) WHERE TitleID = @TitleID

	SELECT	@Old_Site = xmlData.Col.value('@Site','VARCHAR(4000)'),
			@Old_Level = xmlData.Col.value('@Position','VARCHAR(10)'),
			@Old_Currency = xmlData.Col.value('@Currency','VARCHAR(1000)'),			
			@Old_TypeAccount = xmlData.Col.value('@DirectAccount','TINYINT')
	FROM @Old_Filter.nodes('//Filters') xmlData(Col)	
	
	IF @ChangeFilter = 1 OR @Old_Title <> @Title
	BEGIN
		UPDATE crmInformTitle_New WITH (ROWLOCK, UPDLOCK)
		SET Title = @Title, 
			Creator = @UserID,
			Filter = @Filter
		WHERE TitleID = @TitleID

		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrCode = 102
			SELECT @ErrMsg = 'Update case unsuccessfuly.'
			RETURN
		END			
	END	

	IF @ChangeFilter = 0 
		AND  @Old_Title = @Title
		AND NOT EXISTS (SELECT 1 FROM @HeadlineData) 
		AND NOT EXISTS (SELECT 1 FROM #NewDirectAcc WHERE Cases <> 0)
	BEGIN
		RETURN		
	END	
	
	-- Get old values
	INSERT INTO @HeadlineDataOld
	SELECT ih.HeadlineID, ih.GroupID, ih.InformHeadlineStatusID, ih.Remark, ih.Extension, ih.ProductStatus, ih.Handler, ih.UpdatedTime, ih.IsInform
	FROM crmInformHeadline_New ih WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #NewDirectAcc ac ON ISNULL(ac.CustID_Old, ac.CustID_New) = ih.HeadlineID
	WHERE ih.TitleID = @TitleID AND ac.Cases <> 0

	INSERT INTO @HeadlineDataOld
	SELECT ih.HeadlineID, ih.GroupID, ih.InformHeadlineStatusID, ih.Remark, ih.Extension, ih.ProductStatus, ih.Handler, ih.UpdatedTime, ih.IsInform
	FROM crmInformHeadline_New ih WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #NewDirectAcc ac ON ih.HeadlineID = ac.CustID_Old
	WHERE ih.TitleID = @TitleID AND ac.Cases = 0 AND ih.HeadlineID IN (SELECT HeadlineID FROM @HeadlineData)	

	DELETE ih WITH (UPDLOCK,ROWLOCK)	
	FROM crmInformHeadline_New ih
		LEFT JOIN #NewDirectAcc ac ON ih.HeadlineID = ac.CustID_Old AND ih.GroupID = ac.GroupID_Old
	WHERE ac.CustID_Old  IS NULL AND ih.TitleID = @TitleID AND ih.IsInform = 1	
	
	UPDATE ih
	SET InformHeadlineStatusID = CASE WHEN hl.IsKeep = 1 THEN 45007 WHEN hl.IsKeep = 0  THEN hl.InformHeadlineStatusID ELSE ih.InformHeadlineStatusID END,
		Remark = ISNULL(hl.Remark, ih.Remark),
		Extension = ISNULL(hl.Extension, ih.Extension),
		ProductStatus = ISNULL(hl.ProductStatus, ih.ProductStatus),
		IsInform = CASE WHEN hl.IsKeep = 0 OR hl.IsKeep IS NULL THEN 0 ELSE IsInform END,
		UpdatedTime = GETDATE(),
		Handler = @UserID
	FROM crmInformHeadline_New ih WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #NewDirectAcc ac ON ih.HeadlineID = ac.CustID_Old
		LEFT JOIN @HeadlineData hl ON ac.CustID_Old = hl.HeadlineID			
	WHERE ih.TitleID = @TitleID AND ac.Cases IN (1,5) AND ih.IsInform = 1

	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrCode = 103
		SELECT @ErrMsg = 'Update case unsuccessfuly.'
		RETURN
	END

	UPDATE ih
	SET HeadlineID = CASE WHEN ac.Cases = 3 THEN ac.CustID_New ELSE ih.HeadlineID END,
		GroupID = CASE WHEN ac.Cases = 4 THEN ac.GroupID_New ELSE ih.GroupID END,
		InformHeadlineStatusID = ISNULL(hl.InformHeadlineStatusID, ih.InformHeadlineStatusID),
		Remark = ISNULL(hl.Remark, ih.Remark),
		Extension = ISNULL(hl.Extension, ih.Extension),
		ProductStatus = ISNULL(hl.ProductStatus, ih.ProductStatus),
		UpdatedTime = GETDATE(),
		Handler = @UserID
	FROM crmInformHeadline_New ih WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #NewDirectAcc ac ON ih.HeadlineID = ac.CustID_Old
		LEFT JOIN @HeadlineData hl ON ac.CustID_New = hl.HeadlineID			
	WHERE ih.TitleID = @TitleID AND ac.Cases IN (3,4) AND ih.IsInform = 1

	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrCode = 103
		SELECT @ErrMsg = 'Update case unsuccessfuly.'
		RETURN
	END
		
	UPDATE ih
	SET Remark = hl.Remark,
		InformHeadlineStatusID = hl.InformHeadlineStatusID,
		Extension = ISNULL(hl.Extension,0),
		ProductStatus = ISNULL(hl.ProductStatus,0),
		UpdatedTime = GETDATE(),
		Handler = @UserID
	FROM crmInformHeadline_New ih WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #NewDirectAcc ac ON ih.HeadlineID = ac.CustID_Old
		INNER JOIN @HeadlineData hl ON ih.HeadlineID = hl.HeadlineID			
	WHERE ih.TitleID = @TitleID AND ac.Cases = 0 AND ih.IsInform = 1
	
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
		Remark = ISNULL(hl.Remark,ih.Remark),
		Extension = ISNULL(hl.Extension,0),
		ProductStatus = ISNULL(hl.ProductStatus,0),
		IsInform = 1,
		UpdatedTime = GETDATE(),
		Handler = @UserID
	FROM crmInformHeadline_New ih WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #NewDirectAcc ac ON ih.HeadlineID = ac.CustID_New
		LEFT JOIN @HeadlineData hl ON ac.CustID_New = hl.HeadlineID			
	WHERE ih.TitleID = @TitleID	AND ac.Cases = 2
	
	--Insert headline list who is found now
	INSERT INTO crmInformHeadline_New (HeadlineID, TitleID, InformHeadlineStatusID, GroupID, UpdatedTime, Remark, Handler, Extension, ProductStatus, IsInform)
	SELECT ac.CustID_New, @TitleID, ISNULL(hl.InformHeadlineStatusID, 45006), ac.GroupID_New, GETDATE(), ISNULL(hl.Remark, ''), @UserID, ISNULL(hl.Extension,0), ISNULL(hl.ProductStatus,0), 1
	FROM #NewDirectAcc ac
		LEFT JOIN @HeadlineData hl ON ac.CustID_New = hl.HeadlineID
	WHERE ac.Cases = 2 AND ac.CustID_New NOT IN (SELECT HeadlineID FROM crmInformHeadline_New WITH (NOLOCK) WHERE TitleID = @TitleID)

	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrCode = 104
		SELECT @ErrMsg = 'Update case unsuccessfuly.'
		RETURN
	END
	
	--SELECT DISTINCT a.HeadlineID
	--FROM
	--	(SELECT ISNULL(CustID_New, CustID_Old) AS HeadlineID FROM #NewDirectAcc WHERE Cases <> 0
	--	UNION ALL
	--	SELECT HeadlineID FROM @HeadlineData) a	

	-- write log
	DECLARE @OldValues XML = '', @NewValues XML = ''

	DECLARE @HeadlineID INT
	DECLARE HeadlineID_cursor CURSOR FOR
	SELECT DISTINCT a.HeadlineID
	FROM
		(SELECT ISNULL(CustID_New, CustID_Old) AS HeadlineID FROM #NewDirectAcc WHERE Cases <> 0
		UNION ALL
		SELECT HeadlineID FROM @HeadlineData) a	
	
	OPEN HeadlineID_cursor
	FETCH NEXT FROM HeadlineID_cursor INTO @HeadlineID
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SELECT @OldValues = 				
					'<Acc_CRM_InformHeadlineSearchUpd>'			+ --SP Name
						'<Title>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Old_Title),'')										+ '</Title>' +
						'<Currency>'					+ @Old_Currency																			+ '</Currency>' +
						'<Level>'						+ @Old_Level																			+ '</Level>' +
						'<Site>'						+ @Old_Site																				+ '</Site>' +
						'<TypeAccount>'					+ CONVERT(VARCHAR(1), @Old_TypeAccount)													+ '</TypeAccount>' +
						'<HeadlineID>'					+ CAST(ISNULL(hl.HeadlineID, ac.CustID_Old) AS VARCHAR(30))								+ '</HeadlineID>' +
						'<GroupID>'						+ CAST(ISNULL(hl.GroupID, ac.GroupID_Old) AS VARCHAR(30))								+ '</GroupID>' +
						'<StatusID>'					+ CAST(ISNULL(hl.InformHeadlineStatusID, -1) AS VARCHAR(30))							+ '</StatusID>' +
						'<Remark>'						+ ISNULL([dbo].[f_EncodeXMLValue](Remark),'')											+ '</Remark>' +
						'<Extension>'					+ ISNULL(CAST(hl.Extension AS VARCHAR(30)),0)											+ '</Extension>'+													
						'<ProductStatus>'				+ ISNULL(CAST(hl.ProductStatus AS VARCHAR(30)),0)										+ '</ProductStatus>'+
						'<Handler>'						+ ISNULL(CAST(hl.Handler AS VARCHAR(30)),'')											+ '</Handler>'+	
						'<IsKeep>'						+ CAST(CASE WHEN hl.InformHeadlineStatusID = 45007 THEN 1 ELSE 0 END AS VARCHAR(1))		+ '</IsKeep>' +
						'<UpdateTime>'					+ ISNULL(CAST(hl.UpdatedTime AS VARCHAR(30)),'')										+ '</UpdateTime>'+													
						'<IsInform>'					+ ISNULL(CAST(hl.IsInform AS VARCHAR(30)),'')											+ '</IsInform>'+		
						'<Case>'						+ '0'																					+ '</Case>' +
					'</Acc_CRM_InformHeadlineSearchUpd>' 
		FROM #NewDirectAcc ac
			LEFT JOIN @HeadlineDataOld hl ON ISNULL(ac.CustID_Old,ac.CustID_New) = hl.HeadlineID
		WHERE ISNULL(ac.CustID_New,ac.CustID_Old) = @HeadlineID

		SELECT @NewValues = 				
					'<Acc_CRM_InformHeadlineSearchUpd>'			+ --SP Name
						'<Title>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Title),'')											+ '</Title>' +
						'<Currency>'					+ @Currency																				+ '</Currency>' +
						'<Level>'						+ @Level																				+ '</Level>' +
						'<Site>'						+ @Site																					+ '</Site>' +
						'<TypeAccount>'					+ CONVERT(VARCHAR(1), @TypeAccount)														+ '</TypeAccount>' +
						'<HeadlineID>'					+ CAST(ISNULL(ac.CustID_New, ac.CustID_Old) AS VARCHAR(30))								+ '</HeadlineID>' +
						'<GroupID>'						+ CAST(ISNULL(ac.GroupID_New, ac.GroupID_Old) AS VARCHAR(30))							+ '</GroupID>' +
						'<StatusID>'					+ CAST(ISNULL(hl.InformHeadlineStatusID, ih.InformHeadlineStatusID) AS VARCHAR(30))		+ '</StatusID>' +
						'<Remark>'						+ ISNULL([dbo].[f_EncodeXMLValue](hl.Remark),[dbo].[f_EncodeXMLValue](ih.Remark))		+ '</Remark>' +
						'<Extension>'					+ ISNULL(CAST(hl.Extension AS VARCHAR(30)),CAST(ih.Extension AS VARCHAR(30)))			+ '</Extension>'+													
						'<ProductStatus>'				+ ISNULL(CAST(hl.ProductStatus AS VARCHAR(30)),CAST(ih.ProductStatus AS VARCHAR(30)))	+ '</ProductStatus>' +
						'<Handler>'						+ ISNULL(CAST(@UserID AS VARCHAR(30)),'')												+ '</Handler>'+	
						'<IsKeep>'						+ CAST(ISNULL(hl.IsKeep, 0) AS VARCHAR(1))												+ '</IsKeep>' +
						'<UpdateTime>'					+ ISNULL(CAST(ih.UpdatedTime AS VARCHAR(30)),'')										+ '</UpdateTime>'+													
						'<IsInform>'					+ ISNULL(CAST(ih.IsInform AS VARCHAR(30)),'')											+ '</IsInform>'+		
						'<Case>'						+ CAST(ac.Cases AS VARCHAR(30))															+ '</Case>' +
					'</Acc_CRM_InformHeadlineSearchUpd>' 
		FROM #NewDirectAcc ac
			INNER JOIN crmInformHeadline_New ih WITH (NOLOCK) ON ISNULL(ac.CustID_New,ac.CustID_Old) = ih.HeadlineID
			LEFT JOIN @HeadlineData hl ON ISNULL(ac.CustID_New,ac.CustID_Old) = hl.HeadlineID
		WHERE ISNULL(ac.CustID_New,ac.CustID_Old) = @HeadlineID AND ih.TitleID = @TitleID

		--SELECT * FROM #NewDirectAcc WHERE cases <> 0
		--SELECT * FROM @HeadlineDataOld

		--SELECT ISNULL([dbo].[f_EncodeXMLValue](@Old_Title),'')									
		--	   ,@Old_Currency																		
		--	   ,@Old_Level																		
		--	   ,@Old_Site																			
		--	   ,CONVERT(VARCHAR(1), @Old_TypeAccount)	
		--	   ,CAST(ISNULL(ac.CustID_New, ac.CustID_Old) AS VARCHAR(30))												
		--	   ,CAST(ISNULL(hl.GroupID, ac.GroupID_Old) AS VARCHAR(30))							
		--	   ,CAST(ISNULL(hl.InformHeadlineStatusID, -1) AS VARCHAR(30))						
		--	   ,ISNULL([dbo].[f_EncodeXMLValue](Remark),'')										
		--	   ,ISNULL(CAST(hl.Extension AS VARCHAR(30)),'')										
		--	   ,ISNULL(CAST(hl.ProductStatus AS VARCHAR(30)),'')									
		--	   ,ISNULL(CAST(hl.Handler AS VARCHAR(30)),'')										
		--	   ,CAST(CASE WHEN hl.InformHeadlineStatusID = 45007 THEN 1 ELSE 0 END AS VARCHAR(1))		
		--	   ,ISNULL(CAST(hl.UpdatedTime AS VARCHAR(30)),'')									
		--FROM #NewDirectAcc ac
		--	LEFT JOIN @HeadlineDataOld hl ON ISNULL(ac.CustID_Old,ac.CustID_New) = hl.HeadlineID
		--WHERE ISNULL(ac.CustID_New,ac.CustID_Old) = @HeadlineID

		--SELECT ISNULL([dbo].[f_EncodeXMLValue](@Title),'')											
		--	   ,@Currency																				
		--	   ,@Level																				
		--	   ,@Site																					
		--	   ,CONVERT(VARCHAR(1), @TypeAccount)														
		--	   ,CAST(ISNULL(ac.GroupID_New, ac.GroupID_Old) AS VARCHAR(30))		
		--	   ,ac.CustID_New,ac.CustID_Old
		--	   ,ih.InformHeadlineStatusID					
		--	   ,hl.InformHeadlineStatusID
		--	   ,ih.Remark
		--	   ,hl.Remark
		--	   ,CAST(ISNULL(hl.InformHeadlineStatusID, ih.InformHeadlineStatusID) AS VARCHAR(30))		
		--	   ,ISNULL([dbo].[f_EncodeXMLValue](hl.Remark),[dbo].[f_EncodeXMLValue](ih.Remark))		
		--	   ,ISNULL(CAST(hl.Extension AS VARCHAR(30)),CAST(ih.Extension AS VARCHAR(30)))			
		--	   ,ISNULL(CAST(hl.ProductStatus AS VARCHAR(30)),CAST(ih.ProductStatus AS VARCHAR(30)))	
		--	   ,ISNULL(CAST(@UserID AS VARCHAR(30)),'')												
		--	   ,CAST(ISNULL(hl.IsKeep, 0) AS VARCHAR(1))												
		--	   ,ISNULL(CAST(ih.UpdatedTime AS VARCHAR(30)),'')										
		--	   ,CAST(ac.Cases AS VARCHAR(30))															
		--FROM #NewDirectAcc ac
		--	INNER JOIN crmInformHeadline_New ih WITH (NOLOCK) ON ISNULL(ac.CustID_New,ac.CustID_Old) = ih.HeadlineID
		--	LEFT JOIN @HeadlineData hl ON ISNULL(ac.CustID_New,ac.CustID_Old) = hl.HeadlineID
		--WHERE ISNULL(ac.CustID_New,ac.CustID_Old) = @HeadlineID AND ih.TitleID = @TitleID

		--SELECT @OldValues, @NewValues

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
	
	DROP TABLE #DirectAcc 	
	DROP TABLE #NewDirectAcc
END

GO 
GRANT EXECUTE ON [dbo].[Acc_CRM_InformHeadlineSearchUpd] TO [bodbAdminNet]
GO 
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_InformHeadlineSearchUpd] TO [vnteam]