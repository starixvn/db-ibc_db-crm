/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet,vnteam" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE	dbo.Acc_CRM_Rpt_DailyStatisticsDetail (
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
		(	MainCategoryID    , MainCategory  )
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
		WITH temp AS
		(
		SELECT	FeedbackID				=	fb.FeedbackID
			,	CustID					=	fb.CustID
			,	TitleID					=	fb.TitleID
			,	UserName				=	c.UserName
			,	FirstName				=	fb.FirstName
			,	LastName				=	fb.LastName
			,	Email					=	fb.Email
			,	Skype					=	fb.Skype
			,	MSN						=	fb.MSN
			,	Product					=	ISNULL(P.Product, 'N/A')
			,	SubProduct				=	ISNULL(SP.SubProduct, 'N/A')
			,	Language				=	ISNULL(l.Name, 'N/A')
			,	CountryName				=	ISNULL(ct.CountryName, 'N/A')
			,	CreateDate				=	fb.CreateDate
			,	CreatorID				=	fb.CreatorID
			,	CreatorName				=	ci.UserName
			,	FeedbackDate			=	fb.FeedbackDate
			,	ResolutionDate			=	fb.ResolutionDate
			,	SolveDate				=	fb.SolveDate
			,	Communication			=	ISNULL(cto.Communication, 'N/A')
			,	Station					=	ISNULL(Station.Name, 'N/A')
			,	MainCategory			=	ISNULL(mc.MainCategory, 'N/A')
			,	SubCategory				=	ISNULL(sc.Name, 'N/A')
			,	SiteName				=	ISNULL(s.SiteName, 'N/A')
			,	Role					=	Role.Role
			,	Bettype					=	ISNULL(bt.Name, 'N/A')
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
		FROM		crmFeedback fb WITH (NOLOCK) 
		INNER JOIN	@Product p
				ON	fb.ProductID = p.ProductID
		INNER JOIN	@MainCategory mc
				ON	fb.MainCategoryID = mc.MainCategoryID	
		INNER JOIN	@Communication cto
				ON	fb.CommunicationID = cto.CommunicationID
		LEFT JOIN	crmSite s WITH (NOLOCK)
				ON	s.SiteID = fb.SiteID
		INNER JOIN	crmCustomer c WITH (NOLOCK)
				ON	fb.CustID = c.CustID	
		LEFT JOIN	crmLanguage l WITH (NOLOCK)
				ON	l.LanguageID = fb.languageid
		LEFT JOIN	crmCountry ct WITH (NOLOCK)
				ON	ct.CountryID = fb.CountryID
		LEFT JOIN	bodb02.dbo.custinfo ci WITH (NOLOCK)
				ON	fb.CreatorID = ci.custID
		LEFT JOIN	crmStation Station
				ON	Station.StationID = fb.StationID		
		LEFT JOIN	crmBettype bt WITH (NOLOCK)
				ON	bt.BettypeID = fb.BettypeID
				AND	fb.ProductID = bt.ProductID
		LEFT JOIN	crmStatus st WITH (NOLOCK)
				ON	st.StatusID = fb.StatusID			
		LEFT JOIN	crmSubCategory sc WITH (NOLOCK)
				ON	sc.SubCategoryID = fb.SubCategoryID
				AND	sc.MainCategoryID = fb.MainCategoryID
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
		LEFT JOIN	(	SELECT	SettingID SubProductID, SettingValue SubProduct
						FROM	dbo.crmSetting WITH (NOLOCK)
						WHERE	SettingName = 'SubProduct'
					) SP
				ON	SP.SubProductID = fb.SubProductID	
		WHERE	fb.feedbackdate BETWEEN @fromdate AND @todate
			AND	fb.StatusID <> 11004
			AND	(	@SiteType = 0
				AND	(	s.IsLicensee = 0
					OR	ISNULL(fb.SiteID, 0) = 0
					)
				OR	(	@SiteType = 1
					AND	s.IsLicensee = 1
					)
				)
		
		)
		
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
				,	Product				
				,	SubProduct				
				,	Language				
				,	CountryName				
				,	CreateDate				
				,	CreatorID				
				,	CreatorName				
				,	FeedbackDate			
				,	ResolutionDate			
				,	SolveDate				
				,	Communication			
				,	Station					
				,	MainCategory			
				,	SubCategory				
				,	SiteName				
				,	Role					
				,	Bettype					
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
		 from temp AS c
		 OUTER APPLY c.Description.nodes(N'//row') AS A(nr)
		 ORDER BY	c.feedbackdate DESC
		RETURN;
	END;
	
	IF	@TotalRows = 0  
	BEGIN  
		SELECT	@TotalRows = COUNT(1)
		FROM		crmFeedback fb WITH (NOLOCK) 
		INNER JOIN	@Product p
				ON	fb.ProductID = p.ProductID
		INNER JOIN	@MainCategory mc
				ON	fb.MainCategoryID = mc.MainCategoryID	
		INNER JOIN	@Communication cto
				ON	fb.CommunicationID = cto.CommunicationID
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
	END;
	
	WITH Pag AS (
		SELECT	RowNum		=	ROW_NUMBER() OVER(ORDER BY feedbackdate DESC)
			,	FeedbackID	=	fb.FeedbackID
		FROM	crmFeedback fb WITH (NOLOCK)
		INNER JOIN	@Product p
				ON	fb.ProductID = p.ProductID
		INNER JOIN	@MainCategory mc
				ON	fb.MainCategoryID = mc.MainCategoryID	
		INNER JOIN	@Communication cto
				ON	fb.CommunicationID = cto.CommunicationID
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
				)
			),
	temp AS
	(
		SELECT	FeedbackID				=	fb.FeedbackID
			,	CustID					=	fb.CustID
			,	TitleID					=	fb.TitleID
			,	UserName				=	c.UserName
			,	FirstName				=	fb.FirstName
			,	LastName				=	fb.LastName
			,	Email					=	fb.Email
			,	Skype					=	fb.Skype
			,	MSN						=	fb.MSN
			,	Product					=	ISNULL(P.Product, 'N/A')
			,	SubProduct				=	ISNULL(SP.SubProduct, 'N/A')
			,	Language				=	ISNULL(l.Name, 'N/A')
			,	CountryName				=	ISNULL(ct.CountryName, 'N/A')
			,	CreateDate				=	fb.CreateDate
			,	CreatorID				=	fb.CreatorID
			,	CreatorName				=	ci.UserName
			,	FeedbackDate			=	fb.FeedbackDate
			,	ResolutionDate			=	fb.ResolutionDate
			,	SolveDate				=	fb.SolveDate
			,	Communication			=	ISNULL(cto.Communication, 'N/A')
			,	Station					=	ISNULL(Station.Name, 'N/A')
			,	MainCategory			=	ISNULL(mc.MainCategory, 'N/A')
			,	SubCategory				=	ISNULL(sc.Name, 'N/A')
			,	SiteName				=	ISNULL(s.SiteName, 'N/A')
			,	Role					=	Role.Role
			,	Bettype					=	ISNULL(bt.Name, 'N/A')
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
		FROM		crmFeedback fb WITH (NOLOCK) 
		INNER JOIN	Pag
				ON	fb.FeedbackID = pag.FeedbackID
		INNER JOIN	@Product p
				ON	fb.ProductID = p.ProductID
		INNER JOIN	@MainCategory mc
				ON	fb.MainCategoryID = mc.MainCategoryID	
		INNER JOIN	@Communication cto
				ON	fb.CommunicationID = cto.CommunicationID
		LEFT JOIN	crmSite s WITH (NOLOCK)
				ON	s.SiteID = fb.SiteID
		INNER JOIN	crmCustomer c WITH (NOLOCK)
				ON	fb.CustID = c.CustID	
		LEFT JOIN	crmLanguage l WITH (NOLOCK)
				ON	l.LanguageID = fb.languageid
		LEFT JOIN	crmCountry ct WITH (NOLOCK)
				ON	ct.CountryID = fb.CountryID
		LEFT JOIN	bodb02.dbo.custinfo ci WITH (NOLOCK)
				ON	fb.CreatorID = ci.custID
		LEFT JOIN	crmStation Station
				ON	Station.StationID = fb.StationID		
		LEFT JOIN	crmBettype bt WITH (NOLOCK)
				ON	bt.BettypeID = fb.BettypeID
				AND	fb.ProductID = bt.ProductID
		LEFT JOIN	crmStatus st WITH (NOLOCK)
				ON	st.StatusID = fb.StatusID			
		LEFT JOIN	crmSubCategory sc WITH (NOLOCK)
				ON	sc.SubCategoryID = fb.SubCategoryID
				AND	sc.MainCategoryID = fb.MainCategoryID
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
		LEFT JOIN	(	SELECT	SettingID SubProductID, SettingValue SubProduct
							FROM	dbo.crmSetting WITH (NOLOCK)
							WHERE	SettingName = 'SubProduct'
						) SP
				ON	SP.SubProductID = fb.SubProductID
		WHERE	pag.RowNum BETWEEN @RowStart AND @RowEnd
	)
			
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
				,	Product				
				,	SubProduct				
				,	Language				
				,	CountryName				
				,	CreateDate				
				,	CreatorID				
				,	CreatorName				
				,	FeedbackDate			
				,	ResolutionDate			
				,	SolveDate				
				,	Communication			
				,	Station					
				,	MainCategory			
				,	SubCategory				
				,	SiteName				
				,	Role					
				,	Bettype					
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
		 from temp AS c
		 OUTER APPLY c.Description.nodes(N'//row') AS A(nr)
END;
GO

GRANT EXECUTE ON dbo.Acc_CRM_Rpt_DailyStatisticsDetail TO bodbAdminNet;
GO
GRANT VIEW DEFINITION ON dbo.Acc_CRM_Rpt_DailyStatisticsDetail TO vnteam;
GO