/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_Rpt_DailyStatisticsDetail] (
					@SiteType			BIT				= 0
				,	@FromDate			DATETIME
				,	@ToDate				DATETIME
				,	@ProductID			VARCHAR(500)
				,	@MainCategoryID		VARCHAR(500)
				,	@CommunicationID	VARCHAR(500)
				,	@PageSize			INT				= 0
				,	@PageIndex			INT				= 0
				,	@TotalRows			INT				= 0		OUTPUT
				,	@ErrorCode			INT				= 0		OUTPUT
				,	@ErrorMsg			VARCHAR(200)	= ''	OUTPUT
				)
AS
/*
	Created:	20151111@Elodie
	Task:		View daily statistics report more detail
	DB:			DBCRM/bodb_CRM
	Original:

	Revisions:	
		- 20160505@Billy:	Add Sub-Product in Detail Reports - [Redmine: #57052]
		- 20180117@Winnie:	Add Is Related Customer - [Redmine: #88774]
		- 20171225@Winnie: Change for support multiple product/categories. [RedmineID: #84714]
		- 20180814@Winnie: Enhancement made for Excel. [RedmineID: #99811]
		- 20190506@Winnie:  CN88 Permission RedmineID: #112637
		- 20190923@Winnie: CRM - Include no. of Inquiries in Feedbacks RedmineID: #120596
	Param's Explanation:		
		@SiteType: 	0: IBC
					1: Licensee
	Ex: EXEC Acc_CRM_Rpt_DailyStatisticsDetail @SiteType = 0, @FromDate = '20151001', @ToDate = '20151118', @ProductID = '8000,8001,8003,8009,8010,8013,8014', @MainCategoryID = '3000,3001,3003,3008,3009', @CommunicationID = '1000,1001,1003,1006,1007'				
*/
BEGIN
	SET NOCOUNT ON;
		
	DECLARE	@RowStart		INT
		,	@RowEnd			INT
		,	@string			VARCHAR(MAX)
		,	@splitter		CHAR(1)
		,	@xml			XML
		
	CREATE TABLE	#Product		 (ProductID			INT PRIMARY KEY)
	CREATE TABLE	#Category		 (CategoryID		INT PRIMARY KEY)
	CREATE TABLE	#Communication	 (CommunicationID	INT PRIMARY KEY)
	CREATE TABLE	#FBProduct		 (ProductID			INT ,SubProductID	INT ,FeedbackID		INT,PRIMARY KEY(FeedbackID,ProductID,SubProductID))
	CREATE TABLE	#FBCategory		 (CategoryID		INT ,SubCategoryID	INT	,FeedbackID		INT,PRIMARY KEY(FeedbackID,CategoryID,SubCategoryID))
	CREATE TABLE	#FBCommunication (CommunicationID	INT ,FeedbackID		INT,SiteName NVARCHAR(100),Description XML,PRIMARY KEY(FeedbackID,CommunicationID))
	CREATE TABLE	#FBStation		 (StationID			INT ,FeedbackID		INT,SiteName NVARCHAR(100),PRIMARY KEY(FeedbackID,StationID))
	
	SELECT	@TotalRows		= 0;	
	SELECT	@PageIndex		= @PageIndex - 1
		,	@RowStart		= @PageSize * @PageIndex + 1
		,	@RowEnd			= @RowStart + @PageSize - 1;

	SELECT	@splitter		= ','
		,	@string			= @ProductID
		,	@XML			= N'<root><r>' + REPLACE(@string, @splitter, '</r><r>') + '</r></root>';

	INSERT INTO	#Product(ProductID)
	SELECT	r.value('.','INT')
	FROM		@xml.nodes('//root/r') AS RECORDS(r)
	
	SELECT	@string			= @MainCategoryID
		,	@XML			= N'<root><r>' + REPLACE(@string, @splitter, '</r><r>') + '</r></root>';

	INSERT INTO	#Category(CategoryID)
	SELECT	r.value('.','INT')
	FROM		@xml.nodes('//root/r') AS RECORDS(r)

	SELECT	@string			= @CommunicationID
		,	@XML			= N'<root><r>' + REPLACE(@string, @splitter, '</r><r>') + '</r></root>';

	INSERT INTO	#Communication(CommunicationID)
	SELECT	r.value('.','INT')
	FROM		@xml.nodes('//root/r') AS RECORDS(r)
	
				
	INSERT INTO #FBProduct(FeedbackID,ProductID,SubProductID)
	SELECT DISTINCT fs.FeedbackID,fs.SettingID,fs.SubSettingID
	FROM crmFeedback fb WITH (NOLOCK) 
		INNER JOIN crmFeedbackSetting fs WITH(NOLOCK) 
			ON fs.FeedbackID=fb.FeedbackID	
		INNER JOIN #Product p
			ON fs.SettingID=p.ProductID		
	WHERE fb.feedbackdate BETWEEN @fromdate AND @todate				
		AND	fb.StatusID <> 11004
		AND	fb.StatusID <> 11019
				
	INSERT INTO #FBCategory(FeedbackID,CategoryID,SubCategoryID)
	SELECT fs.FeedbackID,fs.SettingID,fs.SubSettingID
	FROM crmFeedback fb WITH (NOLOCK)
		INNER JOIN crmFeedbackSetting fs WITH(NOLOCK) 
			ON fs.FeedbackID=fb.FeedbackID	
		INNER JOIN #Category p
			ON fs.SettingID=p.CategoryID 			
	WHERE fb.feedbackdate BETWEEN @fromdate AND @todate				
	AND	fb.StatusID <> 11004	
	AND	fb.StatusID <> 11019
						
	INSERT INTO #FBCommunication(FeedbackID,CommunicationID,SiteName)
	SELECT fs.FeedbackID,fs.SettingID,s.SiteName
	FROM crmFeedback fb WITH (NOLOCK) 
		INNER JOIN crmFeedbackSetting fs WITH(NOLOCK) 
			ON fs.FeedbackID=fb.FeedbackID	
		INNER JOIN #Communication c
			ON fs.SettingID=c.CommunicationID 
		LEFT JOIN	crmSite s WITH (NOLOCK)
				ON	s.SiteID = fb.SiteID 
	WHERE fb.feedbackdate BETWEEN @fromdate AND @todate				
	AND	fb.StatusID <> 11004
	AND	fb.StatusID <> 11019
	AND (	@SiteType = 0
		AND	(	s.IsLicensee = 0
			OR	ISNULL(fb.SiteID, 0) = 0
			OR	ISNULL(s.SiteID, 0) = 0
			)
		OR	(	@SiteType = 1
			AND	s.IsLicensee = 1
			)
		)
		
	INSERT INTO #FBStation(FeedbackID,StationID)
	SELECT DISTINCT fs.FeedbackID,fs.SettingID
	FROM #FBCommunication fp
		INNER JOIN crmFeedbackSetting fs WITH(NOLOCK) 
			ON fs.FeedbackID=fp.FeedbackID	
		INNER JOIN crmSetting c
			ON fs.SettingID=c.SettingID AND c.SettingName='Station'				
		
	IF(	@TotalRows=0)
	BEGIN
		SELECT @TotalRows = COUNT(1) 	
		FROM		crmFeedback fb WITH (NOLOCK)
		INNER JOIN #FBProduct p ON fb.FeedbackID=p.FeedbackID
		INNER JOIN #FBCategory ca ON fb.FeedbackID=ca.FeedbackID
		INNER JOIN #FBCommunication com ON fb.FeedbackID=com.FeedbackID
		INNER JOIN crmCustomer c WITH (NOLOCK)	ON	fb.CustID = c.CustID
		INNER JOIN #FBStation sta ON fb.FeedbackID=sta.FeedbackID
	END	
			
	IF	((@PageSize <= 0) AND (@PageIndex <= 0))
	BEGIN		
		IF(@TotalRows>1000000)
		BEGIN		
			SELECT @ErrorCode=100;
			SELECT @ErrorMsg='That''s more than a million data, So we can not export excel.Pls choice another range date.'
			RETURN
		END	
		
		UPDATE  t
			SET t.Description=fb.Description
			FROM #FBCommunication t
			INNER JOIN crmFeedback fb ON t.FeedbackID=fb.FeedbackID		
			
		SELECT	FeedbackID				=	fb.FeedbackID
			,	CustID					=	fb.CustID
			,	TitleID					=	fb.TitleID
			,	UserName				=	c.UserName
			,	FirstName				=	fb.FirstName
			,	LastName				=	fb.LastName
			,	Email					=	fb.Email
			,	Skype					=	fb.Skype
			,	MSN						=	fb.MSN
			,	Language				=	ISNULL(l.Name, 'N/A')
			,	CountryName				=	ISNULL(ct.CountryName, 'N/A')
			,	CreateDate				=	fb.CreateDate
			,	CreatorID				=	fb.CreatorID
			,	CreatorName				=	ci.UserName
			,	FeedbackDate			=	fb.FeedbackDate
			,	ResolutionDate			=	fb.ResolutionDate
			,	SolveDate				=	fb.SolveDate
			,	SiteName				=	ISNULL(com.SiteName, 'N/A')
			,	Role					=	Role.Role
			,	Response				=	ISNULL(Response.Response, 'N/A')
			,	Status					=	ISNULL(st.Name, 'N/A')			
			,	Solution				=	fb.Solution
			,	IsReviewed				=	fb.IsReviewed
			,	Review					=	fb.Review
			,	ReviewerID				=	fb.ReviewerID
			,	Subject					=	fb.Subject
			,	FaxCountryCode			=	ISNULL(fb.FaxCountryCode, '')
			,	FaxAreaCode				=	ISNULL(fb.FaxAreaCode, '')
			,	Fax						=	ISNULL(fb.Fax, '')
			,	PhoneCountryCode		=	ISNULL(fb.PhoneCountryCode, '')
			,	PhoneAreaCode			=	ISNULL(fb.PhoneAreaCode, '')
			,	Phone					=	ISNULL(fb.Phone, '')
			,	Phone2CountryCode		=	ISNULL(fb.Phone2CountryCode, '')
			,	Phone2AreaCode			=	ISNULL(fb.Phone2AreaCode, '')
			,	Phone2					=	ISNULL(fb.Phone2, '')
			,	Phone3CountryCode		=	ISNULL(fb.Phone3CountryCode, '')
			,	Phone3AreaCode			=	ISNULL(fb.Phone3AreaCode, '')
			,	Phone3					=	ISNULL(fb.Phone3, '')
			,	WhatsApp				=	ISNULL(fb.WhatsApp, '')
			,	Line					=	ISNULL(fb.Line, '')
			,	WeChat					=	ISNULL(fb.WeChat, '')
			,	Yahoo					=	ISNULL(fb.Yahoo, '')
			,	QQ						=	ISNULL(fb.QQ, '')
			,	BBM						=	ISNULL(fb.BBM, '')
			,	MobilePhoneCountryCode	=	ISNULL(fb.MobilePhoneCountryCode, '') 
			,	MobilePhoneAreaCode		=	ISNULL(fb.MobilePhoneAreaCode, '') 
			,	MobilePhone				=	ISNULL(fb.MobilePhone, '')
			,	PIC1					=	ISNULL(fb.PIC1, '')
			,	PIC2					=	ISNULL(fb.PIC2, '')
			,	PIC3					=	ISNULL(fb.PIC3, '')
			,	PIC4					=	ISNULL(fb.PIC4, '')
			,	PIC1Name				=	ISNULL(fb.PIC1Name, '')
			,	PIC2Name				=	ISNULL(fb.PIC2Name, '')
			,	PIC3Name				=	ISNULL(fb.PIC3Name, '')
			,	PIC4Name				=	ISNULL(fb.PIC4Name, '')	
			,	nr.value(N'@AutoField',N'nvarchar(max)') AS AutoField
			,	nr.value(N'@Remark',N'nvarchar(max)') AS Remark	
			,p.ProductID
			,p.SubProductID
			,ca.CategoryID
			,ca.SubCategoryID
			,com.CommunicationID
			,sta.StationID
			,ISNULL(fb.Inquiries,'-') AS NoInquiries
		FROM		crmFeedback fb WITH (NOLOCK) 
		INNER JOIN #FBProduct p ON fb.FeedbackID=p.FeedbackID
		INNER JOIN #FBCategory ca ON fb.FeedbackID=ca.FeedbackID
		INNER JOIN #FBCommunication com ON fb.FeedbackID=com.FeedbackID
		INNER JOIN crmCustomer c WITH (NOLOCK)
				ON	fb.CustID = c.CustID
		INNER JOIN #FBStation sta ON fb.FeedbackID=sta.FeedbackID
		OUTER APPLY com.Description.nodes(N'//row') AS A(nr)		
		LEFT JOIN	crmLanguage l WITH (NOLOCK)
				ON	l.LanguageID = fb.languageid
		LEFT JOIN	crmCountry ct WITH (NOLOCK)
				ON	ct.CountryID = fb.CountryID
		LEFT JOIN	bodb02.dbo.custinfo ci WITH (NOLOCK)
				ON	fb.CreatorID = ci.custID
		LEFT JOIN	crmStatus st WITH (NOLOCK)
				ON	st.StatusID = fb.StatusID	
		LEFT JOIN	(	SELECT	SettingID ResponseID, SettingValue Response
						FROM	crmSetting WITH (NOLOCK)
						WHERE	SettingName = 'Response'
					) Response
				ON	Response.ResponseID = fb.ResponseID
		LEFT JOIN	(	SELECT	SettingID RoleID, SettingValue Role
						FROM	crmSetting WITH (NOLOCK)
						WHERE	SettingName = 'Role'
					) Role
				ON	Role.RoleID = fb.RoleID
		ORDER BY	fb.feedbackdate DESC		

		RETURN;
	END;
	
	;WITH Pag AS (	
		SELECT fb.feedbackid,fb.FeedbackDate,com.sitename,p.ProductID,p.SubProductID,ca.CategoryID,ca.SubCategoryID,com.CommunicationID,sta.StationID,c.Username,RowNum=ROW_NUMBER() OVER(ORDER BY feedbackdate DESC)		
		FROM	crmFeedback fb WITH (NOLOCK)
			INNER JOIN #FBProduct p ON fb.FeedbackID=p.FeedbackID
			INNER JOIN #FBCategory ca ON fb.FeedbackID=ca.FeedbackID
			INNER JOIN #FBCommunication com ON fb.FeedbackID=com.FeedbackID
			INNER JOIN crmCustomer c WITH (NOLOCK)	ON	fb.CustID = c.CustID
			INNER JOIN #FBStation sta ON fb.FeedbackID=sta.FeedbackID
	)
	
	SELECT	FeedbackID				=	fb.FeedbackID
		,	CustID					=	fb.CustID
		,	TitleID					=	fb.TitleID
		,	UserName				=	c.UserName
		,	FirstName				=	fb.FirstName
		,	LastName				=	fb.LastName
		,	Email					=	fb.Email
		,	Skype					=	fb.Skype
		,	MSN						=	fb.MSN		
		,	Language				=	ISNULL(l.Name, 'N/A')
		,	CountryName				=	ISNULL(ct.CountryName, 'N/A')
		,	CreateDate				=	fb.CreateDate
		,	CreatorID				=	fb.CreatorID
		,	CreatorName				=	ci.UserName
		,	FeedbackDate			=	fb.FeedbackDate
		,	ResolutionDate			=	fb.ResolutionDate
		,	SolveDate				=	fb.SolveDate			
		,	SiteName				=	ISNULL(pag.SiteName, 'N/A')
		,	Role					=	Role.Role		
		,	Response				=	ISNULL(Response.Response, 'N/A')
		,	Status					=	ISNULL(st.Name, 'N/A')
		,	Description				=	CAST(fb.Description AS XML)
		,	Solution				=	fb.Solution
		,	IsReviewed				=	fb.IsReviewed
		,	Review					=	fb.Review
		,	ReviewerID				=	fb.ReviewerID
		,	Subject					=	fb.Subject
		,	FaxCountryCode			=	ISNULL(fb.FaxCountryCode, '')
		,	FaxAreaCode				=	ISNULL(fb.FaxAreaCode, '')
		,	Fax						=	ISNULL(fb.Fax, '')
		,	PhoneCountryCode		=	ISNULL(fb.PhoneCountryCode, '')
		,	PhoneAreaCode			=	ISNULL(fb.PhoneAreaCode, '')
		,	Phone					=	ISNULL(fb.Phone, '')
		,	Phone2CountryCode		=	ISNULL(fb.Phone2CountryCode, '')
		,	Phone2AreaCode			=	ISNULL(fb.Phone2AreaCode, '')
		,	Phone2					=	ISNULL(fb.Phone2, '')
		,	Phone3CountryCode		=	ISNULL(fb.Phone3CountryCode, '')
		,	Phone3AreaCode			=	ISNULL(fb.Phone3AreaCode, '')
		,	Phone3					=	ISNULL(fb.Phone3, '')
		,	WhatsApp				=	ISNULL(fb.WhatsApp, '')
		,	Line					=	ISNULL(fb.Line, '')
		,	WeChat					=	ISNULL(fb.WeChat, '')
		,	Yahoo					=	ISNULL(fb.Yahoo, '')
		,	QQ						=	ISNULL(fb.QQ, '')
		,	BBM						=	ISNULL(fb.BBM, '')
		,	MobilePhoneCountryCode	=	ISNULL(fb.MobilePhoneCountryCode, '')
		,	MobilePhoneAreaCode		=	ISNULL(fb.MobilePhoneAreaCode, '')
		,	MobilePhone				=	ISNULL(fb.MobilePhone, '')
		,	PIC1					=	ISNULL(fb.PIC1, '')
		,	PIC2					=	ISNULL(fb.PIC2, '')
		,	PIC3					=	ISNULL(fb.PIC3, '')
		,	PIC4					=	ISNULL(fb.PIC4, '')
		,	PIC1Name				=	ISNULL(fb.PIC1Name, '')
		,	PIC2Name				=	ISNULL(fb.PIC2Name, '')
		,	PIC3Name				=	ISNULL(fb.PIC3Name, '')
		,	PIC4Name				=	ISNULL(fb.PIC4Name, '')
		,   ProductID				=	pag.ProductID
		,   SubProductID			=	pag.SubProductID
		,   CategoryID				=	pag.CategoryID
		,   SubCategoryID			=	pag.SubCategoryID
		,   CommunicationID			=	pag.CommunicationID
		,   StationID			    =	pag.StationID
		,   NoInquiries             =   ISNULL(fb.Inquiries,'-')
	INTO #temp
	FROM		crmFeedback fb WITH (NOLOCK) 
	INNER JOIN	Pag
			ON	fb.FeedbackID = pag.FeedbackID
	INNER JOIN	crmCustomer c WITH (NOLOCK)
			ON	fb.CustID = c.CustID	
	LEFT JOIN	crmLanguage l WITH (NOLOCK)
			ON	l.LanguageID = fb.languageid
	LEFT JOIN	crmCountry ct WITH (NOLOCK)
			ON	ct.CountryID = fb.CountryID
	LEFT JOIN	bodb02.dbo.custinfo ci WITH (NOLOCK)
			ON	fb.CreatorID = ci.custID		
	LEFT JOIN	crmStatus st WITH (NOLOCK)
			ON	st.StatusID = fb.StatusID	
	LEFT JOIN	(	SELECT	SettingID ResponseID, SettingValue Response
					FROM	crmSetting WITH (NOLOCK)
					WHERE	SettingName = 'Response'
				) Response
			ON	Response.ResponseID = fb.ResponseID
	LEFT JOIN	(	SELECT	SettingID RoleID, SettingValue Role
					FROM	crmSetting WITH (NOLOCK)
					WHERE	SettingName = 'Role'
			) Role 
			ON	Role.RoleID = fb.RoleID	
	WHERE	pag.RowNum BETWEEN @RowStart AND @RowEnd
	
	SELECT c.FeedbackID
			,nr.value(N'@AutoField',N'nvarchar(max)') AS AutoField
			,nr.value(N'@Remark',N'nvarchar(max)') AS Remark
			,	CustID		
			,	TitleID			
			,	UserName			
			,	FirstName			
			,	LastName				
			,	Email				
			,	Skype					
			,	MSN		
			,	Language				
			,	CountryName				
			,	CreateDate				
			,	CreatorID				
			,	CreatorName				
			,	FeedbackDate			
			,	ResolutionDate			
			,	SolveDate	
			,	SiteName				
			,	Role	
			,	Response				
			,	Status			
			,	Solution				
			,	IsReviewed				
			,	Review					
			,	ReviewerID				
			,	Subject					
			,	FaxCountryCode			
			,	FaxAreaCode				
			,	Fax						
			,	PhoneCountryCode		
			,	PhoneAreaCode			
			,	Phone					
			,	Phone2CountryCode		
			,	Phone2AreaCode			
			,	Phone2					
			,	Phone3CountryCode		
			,	Phone3AreaCode			
			,	Phone3					
			,	WhatsApp				
			,	Line					
			,	WeChat					
			,	Yahoo					
			,	QQ						
			,	BBM						
			,	MobilePhoneCountryCode	
			,	MobilePhoneAreaCode		
			,	MobilePhone				
			,	PIC1					
			,	PIC2					
			,	PIC3					
			,	PIC4					
			,	PIC1Name				
			,	PIC2Name				
			,	PIC3Name				
			,	PIC4Name	
			,	ProductID
			,   SubProductID			
			,   CategoryID				
			,   SubCategoryID			
			,   CommunicationID			
			,   StationID		
			,   NoInquiries	   		
	 from #temp AS c
	 OUTER APPLY c.Description.nodes(N'//row') AS A(nr)	
END;
GO
