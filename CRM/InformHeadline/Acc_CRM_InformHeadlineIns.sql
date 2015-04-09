ALTER PROCEDURE [dbo].[Acc_CRM_InformHeadlineIns]
	@Title			NVARCHAR(2000),
	@Currency		VARCHAR(1000) = '',
	@Level			VARCHAR(10) = '',
	@Site			VARCHAR(4000) = '',
	@TypeAccount	TINYINT,
	@UserID			INT,
	@IP				VARCHAR(40),
	@ErrCode		INT = 0 OUTPUT,
	@ErrMsg			NVARCHAR(200) = '' OUTPUT
AS	
/*
	Created: Elodie
	Date: 2015-04-03
	Task: Insert inform title and headline
	DB: DBCRM/bodb_CRM
		
	Revisions:

	Parameter's Explanation:				
		- @TypeAccount =1: Headline
						2: Direct account
						3: Both
	Example: EXEC Acc_CRM_InformHeadlineIns @Title = 'aa', @Currency = '20,10,2', @Level = '3,4', @Site = 'BEST-ODDS,722222,222223', @TypeAccount = 3, @UserID = 8, @IP = '10.19.1.15'
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
	DECLARE @Filter VARCHAR(4000), @TitleID INT

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

	--DECLARE @HeadlineData TABLE(HeadlineID INT, GroupID INT, InformHeadlineStatusID INT, Remark NVARCHAR(4000), Extension INT, ProductStatus INT)
	--INSERT INTO @HeadlineData
	--SELECT	xmlData.Col.value('@HeadlineID','INT') HeadlineID,
	--		xmlData.Col.value('@GroupID','INT') GroupID,
	--		xmlData.Col.value('@StatusID','INT') InformHeadlineStatusID,
	--		dbo.[f_EncodeXMLValue](xmlData.Col.value('@Remark','NVARCHAR(4000)')) Remark,
	--		ISNULL(xmlData.Col.value('@Extension','INT'),0) Extension,
	--		ISNULL(xmlData.Col.value('@ProductStatus','INT'),0) ProductStatus
	--FROM @Content.nodes('//content/headline') xmlData(Col)

	SELECT @Filter = '<Filters Site = ''' + @Site + ''' Position  = ''' + @Level + ''' Currency  = ''' + @Currency + ''' DirrectAccount  = ''' + CONVERT(VARCHAR(1),@TypeAccount) + '''></Filters>'

	INSERT INTO crmInformTitle (Title, CreatedDate, Creator, StatusID, Filter) VALUES (@Title, GETDATE(), @UserID, 11009, @Filter)
      
	SELECT @TitleID = @@identity

	--INSERT INTO [dbo].[crmInformHeadline] (HeadlineID, TitleID, InformHeadlineStatusID, GroupID, UpdatedTime, Remark, Handler, Extension, ProductStatus, IsInform)
	--SELECT hl.HeadlineID, @TitleID, hl.InformHeadlineStatusID, hl.GroupID, GETDATE(), hl.Remark, @UserID, hl.Extension, hl.ProductStatus, 1
	--FROM @HeadlineData hl

	--IF @@ERROR <> 0
	--BEGIN
	--	DELETE crmInformTitle WHERE TitleID = @TitleID
	--	SELECT @ErrCode = 102
	--	SELECT @ErrMsg = 'Create new case unsuccessfuly.'
	--	RETURN
	--END

	INSERT INTO [dbo].[crmInformHeadline] (HeadlineID, TitleID, InformHeadlineStatusID, GroupID, UpdatedTime, Remark, Handler, Extension, ProductStatus, IsInform)
	SELECT hl.CustID, @TitleID, 45006, hl.GroupID, NULL, '', NULL, NULL, NULL, 1
	FROM #DirectAcc hl --WHERE hl.CustID NOT IN (SELECT HeadlineID FROM @HeadlineData)	

	IF @@ERROR <> 0
	BEGIN
		DELETE crmInformTitle WHERE TitleID = @TitleID
		SELECT @ErrCode = 102
		SELECT @ErrMsg = 'Create new case unsuccessfuly.'
		RETURN
	END

	-- write log
	DECLARE @LogElement XML
	SELECT @LogElement = 				
					'<Acc_CRM_InformHeadlineIns>'	+ --SP Name
						'<Title>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Title),'')	+ '</Title>' +
						'<Currency>'				+ @Currency										+ '</Currency>' +
						'<Level>'					+ @Level										+ '</Level>' +
						'<Site>'					+ @Site											+ '</Site>' +
						'<TypeAccount>'				+ CONVERT(VARCHAR(1), @TypeAccount)				+ '</TypeAccount>' +
					'</Acc_CRM_InformHeadlineIns>'
	
	DECLARE @CustID INT
	DECLARE CustID_cursor CURSOR FOR
	SELECT CustID FROM #DirectAcc

	OPEN CustID_cursor
	FETCH NEXT FROM CustID_cursor INTO @CustID
	WHILE @@FETCH_STATUS = 0
	BEGIN
		EXEC [dbo].[WriteLog_UserLog_crmLogInformHeadline]
			@CustID = @CustID, 
			@TitleID = @TitleID,
			@UserID = @UserID,  
			@ActionID = 700, 
			@IP = @IP, 					
			@NewValues = @LogElement
		FETCH NEXT FROM CustID_cursor INTO @CustID
	END
	CLOSE CustID_cursor
	DEALLOCATE CustID_cursor	
END

GO 
GRANT EXECUTE ON [dbo].[Acc_CRM_InformHeadlineIns] TO [bodbAdminNet]
GO 
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_InformHeadlineIns] TO [vnteam]