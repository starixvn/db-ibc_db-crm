/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet,vnteam" viewers="vnteam" isFunction="0"></info>*/
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
	Param's Explanation:		
		@SiteType: 	0: IBC
					1: Licensee
	Ex: EXEC Acc_CRM_Rpt_DailyStatisticsDetail @SiteType = 0, @FromDate = '20151001', @ToDate = '20151118', @ProductID = '8000,8001,8003,8009,8010,8013,8014', @MainCategoryID = '3000,3001,3003,3008,3009', @CommunicationID = '1000,1001,1003,1006,1007'				
*/
BEGIN
	SET NOCOUNT ON;
		
	DECLARE	@RowStart		INT
		,	@RowEnd			INT;

	SELECT	@TotalRows		= 0;	
	CREATE TABLE #tempFB(FeedbackID INT PRIMARY KEY,Description XML,Username NVARCHAR(50),SiteName NVARCHAR(100))	
	CREATE TABLE #tempFB2(FeedbackID INT PRIMARY KEY,FeedbackDate DATETIME,SiteName NVARCHAR(100))	
	
	SELECT	@PageIndex		= @PageIndex - 1
		,	@RowStart		= @PageSize * @PageIndex + 1
		,	@RowEnd			= @RowStart + @PageSize - 1;

	DECLARE	@Product		TABLE (
								ProductID		INT
							,	Product			NVARCHAR(100)
							);	
	DECLARE	@MainCategory	TABLE (
								MainCategoryID	INT
							,	MainCategory	NVARCHAR(100)
							);	
	DECLARE	@Communication	TABLE (
								CommunicationID	INT
							,	Communication	NVARCHAR(100)
							);		

	DECLARE	@string			VARCHAR(MAX)
		,	@splitter		CHAR(1)
		,	@xml			XML;

	SELECT	@splitter		= ','
		,	@string			= @ProductID
		,	@XML			= N'<root><r>' + REPLACE(@string, @splitter, '</r><r>') + '</r></root>';

	INSERT INTO	@Product
		(	ProductID         , Product       )
	SELECT	r.value('.','INT'), s.SettingValue
	FROM		@xml.nodes('//root/r') AS RECORDS(r)
	INNER JOIN	crmSetting s WITH (NOLOCK)
			ON	r.value('.', 'INT') = s.SettingID
	WHERE	SettingName = 'Product';
	
	SELECT	@string			= @MainCategoryID
		,	@XML			= N'<root><r>' + REPLACE(@string, @splitter, '</r><r>') + '</r></root>';

	INSERT INTO	@MainCategory
		(MainCategoryID,MainCategory)
	SELECT	r.value('.','INT'), s.SettingValue
	FROM		@xml.nodes('//root/r') AS RECORDS(r)
	INNER JOIN	crmSetting s WITH (NOLOCK)
			ON	r.value('.', 'INT') = s.SettingID
	WHERE	SettingName = 'Maincategory';

	SELECT	@string			= @CommunicationID
		,	@XML			= N'<root><r>' + REPLACE(@string, @splitter, '</r><r>') + '</r></root>';

	INSERT INTO	@Communication
		(	CommunicationID   , Communication )
	SELECT	r.value('.','INT'), s.SettingValue
	FROM		@xml.nodes('//root/r') AS RECORDS(r)
	INNER JOIN	crmSetting s WITH (NOLOCK)
			ON	r.value('.', 'INT') = s.SettingID
	WHERE	SettingName = 'Communication';
			
	IF	((@PageSize <= 0) AND (@PageIndex <= 0))
	BEGIN		
		INSERT INTO #tempFB(FeedbackID,Username,SiteName)
		SELECT fb.FeedbackID,c.UserName,s.SiteName
		FROM crmFeedback fb WITH (NOLOCK) 
		INNER JOIN crmFeedbackSetting fp WITH(NOLOCK) 
				ON fb.FeedbackID=fp.FeedbackID	
		INNER JOIN crmFeedbackSetting fm WITH(NOLOCK) 
				ON fb.FeedbackID=fm.FeedbackID
		INNER JOIN crmFeedbackSetting fc WITH(NOLOCK) 
				ON fb.FeedbackID=fc.FeedbackID			
		INNER JOIN	@Product p
				ON	fp.SettingID = p.ProductID
		INNER JOIN	@MainCategory mc
				ON	fm.SettingID = mc.MainCategoryID	
		INNER JOIN	@Communication cto
				ON	fc.SettingID = cto.CommunicationID
		LEFT JOIN	crmSite s WITH (NOLOCK)
				ON	s.SiteID = fb.SiteID
		INNER JOIN	crmCustomer c WITH (NOLOCK)
			ON	fb.CustID = c.CustID
		WHERE fb.feedbackdate BETWEEN @fromdate AND @todate				
		AND	fb.StatusID <> 11004
		AND	(	@SiteType = 0
			AND	(	s.IsLicensee = 0
				OR	ISNULL(fb.SiteID, 0) = 0
				)
			OR	(	@SiteType = 1
				AND	s.IsLicensee = 1
				)
			)			
		UPDATE  t
			SET t.Description=fb.Description
			FROM #tempFB t
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
			,	SiteName				=	ISNULL(t.SiteName, 'N/A')
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
			,	nr.value(N'@AutoField',N'nvarchar(max)') AS AutoField
			,	nr.value(N'@Remark',N'nvarchar(max)') AS Remark	
		FROM		crmFeedback fb WITH (NOLOCK) 
		INNER JOIN #tempFB t ON fb.FeedbackID=t.FeedbackID
		OUTER APPLY t.Description.nodes(N'//row') AS A(nr)
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
		ORDER BY	fb.feedbackdate DESC

		SELECT fs.FeedbackID,fs.SettingID,fs.SubSettingID,fs.SubSettingIDLevel3,
		CASE	WHEN m.MainCategoryID	IS NOT NULL THEN 'Category' 
				WHEN s.StationID		IS NOT NULL THEN 'Station' 
				WHEN p.SettingID		IS NOT NULL THEN 'Product' 
				WHEN c.SettingID		IS NOT NULL THEN 'Communication' 
				END AS SettingType
		FROM #tempFB fp
			INNER JOIN crmFeedbackSetting fs WITH(NOLOCK) 
				ON fs.FeedbackID=fp.FeedbackID	
			LEFT JOIN crmMainCategory m 
				ON fs.SettingID=m.MainCategoryID
			LEFT JOIN crmStation s 
				ON fs.SettingID=s.StationID
			LEFT JOIN crmSetting p
				ON fs.SettingID=p.SettingID AND p.SettingName='Product'
			LEFT JOIN crmSetting c
				ON fs.SettingID=c.SettingID AND c.SettingName='Communication'
		RETURN;
	END;
	INSERT INTO #tempFB2(FeedbackID ,FeedbackDate,SiteName)	
	SELECT DISTINCT fb.FeedbackID,fb.FeedbackDate,s.SiteName
	FROM		crmFeedback fb WITH (NOLOCK) 
		INNER JOIN crmFeedbackSetting fp WITH(NOLOCK) 
				ON fb.FeedbackID=fp.FeedbackID	
		INNER JOIN crmFeedbackSetting fm WITH(NOLOCK) 
				ON fb.FeedbackID=fm.FeedbackID
		INNER JOIN crmFeedbackSetting fc WITH(NOLOCK) 
				ON fb.FeedbackID=fc.FeedbackID			
		INNER JOIN	@Product p
				ON	fp.SettingID = p.ProductID
		INNER JOIN	@MainCategory mc
				ON	fm.SettingID = mc.MainCategoryID	
		INNER JOIN	@Communication cto
				ON	fc.SettingID = cto.CommunicationID
		LEFT JOIN	crmSite s WITH (NOLOCK)
				ON	s.SiteID = fb.SiteID
		WHERE	fb.feedbackdate BETWEEN @fromdate AND @todate
			AND	fb.StatusID <> 11004
			AND	(	@SiteType = 0
				AND	(	s.IsLicensee = 0
					OR	ISNULL(fb.SiteID, 0) = 0
					)
				OR	(	@SiteType = 1
					AND	s.IsLicensee = 1
					)
				);
	IF	@TotalRows = 0  
	BEGIN  
		SELECT	@TotalRows = COUNT(1)
		FROM #tempFB2	
	END;
	
	WITH Pag AS (
		SELECT	RowNum		=	ROW_NUMBER() OVER(ORDER BY feedbackdate DESC)
			,	FeedbackID	=	fb.FeedbackID
			,	SiteName
		FROM #tempFB2 fb
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
		 from #temp AS c
		 OUTER APPLY c.Description.nodes(N'//row') AS A(nr)
		 
		SELECT fs.FeedbackID,fs.SettingID,fs.SubSettingID,fs.SubSettingIDLevel3,
		CASE	WHEN m.MainCategoryID	IS NOT NULL THEN 'Category' 
				WHEN s.StationID		IS NOT NULL THEN 'Station' 
				WHEN p.SettingID		IS NOT NULL THEN 'Product' 
				WHEN c.SettingID		IS NOT NULL THEN 'Communication' 
				END AS SettingType
		FROM #temp fp
			INNER JOIN crmFeedbackSetting fs WITH(NOLOCK) 
				ON fs.FeedbackID=fp.FeedbackID	
			LEFT JOIN crmMainCategory m 
				ON fs.SettingID=m.MainCategoryID
			LEFT JOIN crmStation s 
				ON fs.SettingID=s.StationID
			LEFT JOIN crmSetting p
				ON fs.SettingID=p.SettingID AND p.SettingName='Product'
			LEFT JOIN crmSetting c
				ON fs.SettingID=c.SettingID AND c.SettingName='Communication'
END;

GO
