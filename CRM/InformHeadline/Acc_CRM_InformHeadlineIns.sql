ALTER PROCEDURE [dbo].[Acc_CRM_InformHeadlineIns]
	@Title			NVARCHAR(2000),
	@Currency		VARCHAR(1000) = '',
	@Level			VARCHAR(10) = '',
	@Site			VARCHAR(4000) = '',
	@TypeAccount	TINYINT,
	@UserID			INT,
	@IP				VARCHAR(40),
	@TitleID		INT OUTPUT, 
	@ExcludeIgnored	BIT=0,
	@ErrCode		INT = 0 OUTPUT,
	@ErrMsg			NVARCHAR(200) = '' OUTPUT
AS	
/*
	Created: Elodie
	Date: 2015-04-03
	Task: Insert inform title and headline
	DB: DBCRM/bodb_CRM		
	Revisions:
	- 20161005@Winnie: Include 'Checker' and 'Ignored Accounts' RedmineID: #64067
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
	
	CREATE TABLE #DirectAcc (CustID INT PRIMARY KEY, GroupID INT)	
	DECLARE @Filter VARCHAR(4000)

	INSERT INTO #DirectAcc (CustID, GroupID)
	SELECT CustID, GroupID FROM bodb02.dbo.f_InformHeadlineList (@Currency, @Level, @Site, @TypeAccount) 

	--DECLARE @HeadlineData TABLE(HeadlineID INT, GroupID INT, InformHeadlineStatusID INT, Remark NVARCHAR(4000), Extension INT, ProductStatus INT)
	--INSERT INTO @HeadlineData
	--SELECT	xmlData.Col.value('@HeadlineID','INT') HeadlineID,
	--		xmlData.Col.value('@GroupID','INT') GroupID,
	--		xmlData.Col.value('@StatusID','INT') InformHeadlineStatusID,
	--		dbo.[f_EncodeXMLValue](xmlData.Col.value('@Remark','NVARCHAR(4000)')) Remark,
	--		ISNULL(xmlData.Col.value('@Extension','INT'),0) Extension,
	--		ISNULL(xmlData.Col.value('@ProductStatus','INT'),0) ProductStatus
	--FROM @Content.nodes('//content/headline') xmlData(Col)

	SELECT @Filter = '<Filters Site = ''' + @Site + ''' Position  = ''' + @Level + ''' Currency  = ''' + @Currency + ''' DirectAccount  = ''' + CONVERT(VARCHAR(1),@TypeAccount) + ''' ExcludeIgnored  = ''' + CONVERT(VARCHAR(1),@ExcludeIgnored)+ '''></Filters>'

	INSERT INTO crmInformTitle_New (Title, CreatedDate, Creator, StatusID, Filter) VALUES (@Title, GETDATE(), @UserID, 11009, @Filter)
      
	SELECT @TitleID = @@identity

	--INSERT INTO [dbo].[crmInformHeadline_New] (HeadlineID, TitleID, InformHeadlineStatusID, GroupID, UpdatedTime, Remark, Handler, Extension, ProductStatus, IsInform)
	--SELECT hl.HeadlineID, @TitleID, hl.InformHeadlineStatusID, hl.GroupID, GETDATE(), hl.Remark, @UserID, hl.Extension, hl.ProductStatus, 1
	--FROM @HeadlineData hl

	--IF @@ERROR <> 0
	--BEGIN
	--	DELETE crmInformTitle_New WHERE TitleID = @TitleID
	--	SELECT @ErrCode = 102
	--	SELECT @ErrMsg = 'Create new case unsuccessfuly.'
	--	RETURN
	--END

	INSERT INTO [dbo].[crmInformHeadline_New] (HeadlineID, TitleID, InformHeadlineStatusID, GroupID, UpdatedTime, Remark, Handler, Extension, ProductStatus, IsInform)
	SELECT hl.CustID, @TitleID, 45006, hl.GroupID, NULL, '', 0, 0, 0, 1
	FROM #DirectAcc hl --WHERE hl.CustID NOT IN (SELECT HeadlineID FROM @HeadlineData)	

	IF @@ERROR <> 0
	BEGIN
		DELETE crmInformTitle_New WHERE TitleID = @TitleID
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
						'<ExcludeIgnored>'			+ CONVERT(VARCHAR(1), @ExcludeIgnored)			+ '</ExcludeIgnored>' +
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
	
	DROP TABLE #DirectAcc 	
END

GO 
GRANT EXECUTE ON [dbo].[Acc_CRM_InformHeadlineIns] TO [bodbAdminNet]
GO 
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_InformHeadlineIns] TO [vnteam]