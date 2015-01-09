ALTER PROCEDURE [dbo].[Acc_CRM_Rpt_CustomerStatisticsDetail]
(
	@fromdate	DATETIME,
	@todate		DATETIME,
	@SiteType   SMALLINT = 0
)
AS
/*
	Created: 20110830@Lukas	
	Task :  customer feedback detail report
	DB: DB052.bodb_CRM
	Original:

	Revisions:
		- 20110307@Sophia:	Add parametter @SiteType
							Add column ProductID
	    - 20110312@Sophia: . Show Number Game (ProductID = 8008) for Licensee only
						   . Add condition if SiteID = 0 then list this feedback into IBC group	
						   . Change server name to DB052 instead of DB06
		- 20120420@Sophia: Exclude ProductID = 8014 for Live Casino 	
		- 20120425@Sophia: remove converting @FromDate, @Todate
		- 20120710@Sophia: Exclude ProductID = 8013 for Mini Game 
		- 20120730@Sophia: Exclude ProductID = 8017 for Poker
		- 20130805@Kathy:  Exclude ProductID = 8005 for Bingo
		- 20140303@Dom: Modify for new structure
		- 20140523@Dom: modify site condition
		- 20141121@Dom: Add More Communication Tools
	Param's Explanation:
		@SiteType: 	0: All
					1: IBC
					2: Licensee				
*/
BEGIN
	SET NOCOUNT ON	

 	
	SELECT	FeedbackID, 
			fb.CustID, 
			fb.TitleID, 
			--c.UserName, 
			fb.FirstName, 
			fb.LastName, 
			fb.Email, 
			fb.Skype, 
			fb.MSN,
			fb.ProductID, 
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
			fb.BetTypeID, 
			fb.ResponseID, 
			fb.StatusID, 		
			fb.Description, 
			fb.Solution, 
			fb.IsReviewed, 
			fb.Review, 
			fb.ReviewerID, 
			fb.Subject,
			fb.FaxCountryCode,
			fb.FaxAreaCode,
			fb.Fax,
			fb.PhoneCountryCode,
			fb.PhoneAreaCode,
			fb.Phone,
			fb.Phone2CountryCode,
			fb.Phone2AreaCode,
			fb.Phone2,
			fb.Phone3CountryCode,
			fb.Phone3AreaCode,
			fb.Phone3,
			fb.MobilePhoneCountryCode,
			fb.MobilePhoneAreaCode,
			fb.MobilePhone,
			fb.WhatsApp,
			fb.Line,
			fb.WeChat,
			fb.Yahoo,
			fb.QQ,
			fb.BBM,
			fb.PIC1,
			fb.PIC2,
			fb.PIC3,
			fb.PIC4,
			fb.PIC1Name,
			fb.PIC2Name,
			fb.PIC3Name,
			fb.PIC4Name
	INTO #DATA
	FROM crmFeedback fb WITH(NOLOCK)
		--INNER JOIN crmCustomer c WITH(NOLOCK) ON fb.CustID = c.CustID		
		--LEFT JOIN bodb02.dbo.custinfo ci WITH(NOLOCK) ON fb.CreatorID = ci.custID
		LEFT JOIN crmSite st WITH(NOLOCK) ON fb.SiteID = st.SiteID
	WHERE fb.feedbackdate BETWEEN @fromdate AND @todate		
		AND fb.ProductID NOT IN (8003, 8005, 8008, 8011, 8013, 8014, 8017)
		AND fb.StatusID <> 11004
		AND ( (@SiteType=0) OR (@SiteType=1 AND (st.IsLicensee=0 OR ISNULL(fb.SiteID,0)=0)) OR (@SiteType=2 AND st.IsLicensee=1))

	ORDER BY fb.feedbackdate DESC


	SELECT FeedbackID, 
			d.CustID, 
			d.TitleID,
			c.UserName,
			d.FirstName, 
			d.LastName, 
			d.Email, 
			d.Skype, 
			d.MSN,
			ISNULL(Product.Product,'N/A') Product, 
			ISNULL(l.Name,'N/A') Language, 
			ISNULL(ct.CountryName,'N/A') CountryName, 
			d.CreateDate, 		
			d.CreatorID,
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
			d.Subject,
			ISNULL(d.FaxCountryCode,'') FaxCountryCode,
			ISNULL(d.FaxAreaCode,'') FaxAreaCode,
			ISNULL(d.Fax,'') Fax,
			ISNULL(d.PhoneCountryCode,'') PhoneCountryCode,
			ISNULL(d.PhoneAreaCode,'') PhoneAreaCode,
			ISNULL(d.Phone,'') Phone,
			ISNULL(d.Phone2CountryCode,'') Phone2CountryCode,
			ISNULL(d.Phone2AreaCode,'') Phone2AreaCode,
			ISNULL(d.Phone2,'') Phone2,
			ISNULL(d.Phone3CountryCode,'') Phone3CountryCode,
			ISNULL(d.Phone3AreaCode,'') Phone3AreaCode,
			ISNULL(d.Phone3,'') Phone3,
			ISNULL(d.WhatsApp,'') WhatsApp,
			ISNULL(d.Line,'') Line,
			ISNULL(d.WeChat,'') WeChat,
			ISNULL(d.Yahoo,'') Yahoo,
			ISNULL(d.QQ,'') QQ,
			ISNULL(d.BBM,'') BBM,
			ISNULL(d.MobilePhoneCountryCode,'') MobilePhoneCountryCode,
			ISNULL(d.MobilePhoneAreaCode,'') MobilePhoneAreaCode,
			ISNULL(d.MobilePhone,'') MobilePhone,
			ISNULL(d.PIC1,'') PIC1,
			ISNULL(d.PIC2,'') PIC2,
			ISNULL(d.PIC3,'') PIC3,
			ISNULL(d.PIC4,'') PIC4,
			ISNULL(d.PIC1Name,'') PIC1Name,
			ISNULL(d.PIC2Name,'') PIC2Name,
			ISNULL(d.PIC3Name,'') PIC3Name,
			ISNULL(d.PIC4Name,'') PIC4Name
	FROM #DATA d
	INNER JOIN crmCustomer c WITH(NOLOCK) ON d.CustID = c.CustID		
	LEFT JOIN bodb02.dbo.custinfo ci WITH(NOLOCK) ON d.CreatorID = ci.custID
	LEFT JOIN (
		SELECT SettingID ProductID, SettingValue Product FROM crmSetting WITH(NOLOCK) WHERE SettingName = 'Product'
	) Product ON Product.ProductID = d.ProductID
	LEFT JOIN crmBettype bt WITH(NOLOCK) ON bt.BettypeID = d.BettypeID AND d.ProductID = bt.ProductID
	LEFT JOIN crmLanguage l WITH(NOLOCK) ON l.LanguageID = d.languageid
	LEFT JOIN crmCountry ct WITH(NOLOCK) ON ct.CountryID = d.CountryID
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
	

	DROP TABLE #DATA
END


GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_Rpt_CustomerStatisticsDetail] TO [bodbAdminNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_Rpt_CustomerStatisticsDetail] TO [vnteam]
GO 

