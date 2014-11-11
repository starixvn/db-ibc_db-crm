ALTER PROCEDURE [dbo].[Acc_CRM_Rpt_CasinoStatisticsDetail]
(
	@fromdate	DATETIME,
	@todate		DATETIME
)
AS
/*
	Created: 20110830@Lukas	
	Task :  related casino feedback detail report
	DB: DB052.bodb_CRM
	Original:

	Revisions:
		- 20120420@Sophia: Add ProductID = 8014 for Live Casino 
		- 20120425@Sophia: remove converting @FromDate, @Todate
		- 20120710@Sophia: Add ProductID = 8013 for Mini Game
		- 20120730@Sophia: Add ProductID = 8017 for Poker
		- 20130805@Kathy:  Add ProductID = 8005 for Bingo
	Param's Explanation:
		@Type:	- 1	Daily
				- 2	Weekly					
*/
BEGIN
	SET NOCOUNT ON	

	
	SELECT	FeedbackID, 
			fb.CustID, 
			fb.TitleID, 
			--c.UserName, 
			fb.FirstName, 
			fb.LastName, 
			fb.Phone, 					
			fb.MobilePhone, 
			fb.Fax, 
			fb.Email, 
			fb.Skype, 
			fb.MSN, 
			fb.LanguageID, 
			fb.CountryID, 
			fb.CreateDate, 					
			fb.CreatorID, 
			--ci.UserName as CreatorName, 
			fb.FeedbackDate, 
			fb.ResolutionDate,
			fb.SolveDate, 
			fb.CommunicationID, 
			fb.StationID, 
			fb.MainCategoryID,					
			fb.SubCategoryID, 
			fb.SiteID, 
			fb.RoleID, 
			fb.ProductID, 
			fb.BetTypeID, 
			fb.ResponseID, 
			fb.StatusID, 					
			fb.Description, 
			fb.Solution, 
			fb.IsReviewed, 
			fb.Review, 
			fb.ReviewerID, 
			fb.Subject
	INTO #Data
	FROM crmFeedback fb WITH(NOLOCK)
		--INNER JOIN crmCustomer c WITH(NOLOCK) ON fb.CustID = c.CustID		
		--LEFT JOIN bodb02.dbo.custinfo ci WITH(NOLOCK) ON fb.CreatorID = ci.custID
	WHERE ProductID IN (8003,8005,8008,8011,8013,8014,8017) 
			AND fb.feedbackdate BETWEEN @fromdate AND @todate
			AND fb.StatusID <> 11004	
	ORDER BY fb.feedbackdate DESC

	SELECT FeedbackID, 
			d.CustID, 
			Title.Title, 
			c.UserName, 
			d.FirstName, 
			d.LastName, 
			d.Phone, 					
			d.MobilePhone, 
			d.Fax, 
			d.Email, 
			d.Skype, 
			d.MSN, 
			ISNULL(Product.Product,'N/A') Product, 
			ISNULL(lang.Name,'N/A') Language, 
			ISNULL(country.CountryName,'N/A') CountryName, 
			d.CreateDate, 					
			ci.UserName as CreatorName, 
			d.FeedbackDate, 
			d.ResolutionDate,
			d.SolveDate, 
			ISNULL(cto.Name,'N/A') Communication, 
			ISNULL(Station.Station,'N/A') Station, 
			ISNULL(mc.Name,'N/A') MainCategory, 		
			ISNULL(sc.Name,'N/A') SubCategory, 
			ISNULL(s.SiteName,'N/A') SiteName, 
			Role.Role, 
			ISNULL(bt.Name,'N/A') Bettype, 
			ISNULL(Response.Response,'N/A') Response, 
			ISNULL(st.Name,'N/A') Status, 							
			d.Description, 
			d.Solution, 
			d.IsReviewed, 
			d.Review, 
			d.ReviewerID, 
			d.Subject
	FROM #Data d
	INNER JOIN crmCustomer c WITH(NOLOCK) ON d.CustID = c.CustID
	LEFT JOIN bodb02.dbo.custinfo ci WITH(NOLOCK) ON d.CreatorID = ci.custID
	LEFT JOIN (
		SELECT SettingID ProductID, SettingValue Product FROM crmSetting WITH(NOLOCK) WHERE SettingName = 'Product'
	) Product ON Product.ProductID = d.ProductID
	LEFT JOIN crmBettype bt WITH(NOLOCK) ON bt.BettypeID = d.BettypeID AND d.ProductID = bt.ProductID
	LEFT JOIN (
		SELECT SettingValue Title, SettingID TitleID FROM crmSetting WITH(NOLOCK) WHERE SettingName = 'Title'
	) Title ON Title.TitleID = d.TitleID
	LEFT JOIN crmLanguage lang WITH(NOLOCK) ON lang.LanguageID = d.LanguageID
	LEFT JOIN crmCountry country WITH(NOLOCK) ON country.CountryID = d.CountryID
	LEFT JOIN crmCommunicationTool cto WITH(NOLOCK) ON cto.CommunicationID = d.CommunicationID
	LEFT JOIN (
		SELECT SettingID StationID, SettingValue Station FROM crmSetting WITH(NOLOCK) WHERE SettingName = 'Station'
	) Station ON Station.StationID = d.StationID
	LEFT JOIN crmMainCategory mc WITH(NOLOCK) ON mc.MainCategoryID = d.MainCategoryID
	LEFT JOIN crmSubCategory sc WITH(NOLOCK) ON sc.SubCategoryID = d.SubCategoryID and sc.MainCategoryID = d.MainCategoryID
	LEFT JOIN crmSite s WITH(NOLOCK) ON s.SiteID = d.SiteID
	LEFT JOIN (
		SELECT SettingID RoleID, SettingValue Role FROM crmSetting WITH(NOLOCK) WHERE SettingName = 'Role'
	) Role ON Role.RoleID = d.RoleID
	LEFT JOIN (
		SELECT SettingID ResponseID, SettingValue Response FROM crmSetting WITH(NOLOCK) WHERE SettingName = 'Response'
	) Response ON Response.ResponseID = d.ResponseID
	LEFT JOIN crmStatus st WITH(NOLOCK) ON st.StatusID = d.StatusID

END



GO
GRANT EXECUTE ON [dbo].[Acc_CRM_Rpt_CasinoStatisticsDetail] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_Rpt_CasinoStatisticsDetail] TO [vnteam]

