/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet,vnteam" viewers="vnteam" isFunction="0"></info>*/
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
		- 20180117@Winnie:	Add Is Related Customer - [Redmine: #88774]
		- 20171225@Winnie: Change for support multiple product/categories. [RedmineID: #84714]	
	Param's Explanation:
		@SiteType: 	0: All
					1: IBC
					2: Licensee				
*/
BEGIN
	SET NOCOUNT ON	 
	CREATE TABLE #temp (FeedbackID INT PRIMARY KEY)
	INSERT INTO #temp(FeedbackID)
	SELECT	DISTINCT fb.FeedbackID
	FROM crmFeedback fb WITH(NOLOCK)
		INNER JOIN crmFeedbackSetting fp WITH(NOLOCK) ON fb.FeedbackID=fp.FeedbackID
		INNER JOIN crmSetting p WITH(NOLOCK) ON fp.SettingID=p.SettingID AND p.SettingName='Product'
		LEFT JOIN crmSite st WITH(NOLOCK) ON fb.SiteID = st.SiteID
	WHERE fb.feedbackdate BETWEEN @fromdate AND @todate		
		AND fp.SubSettingID NOT IN (8003, 8005, 8008, 8011, 8013, 8014, 8017)
		AND fb.StatusID <> 11004
		AND ( (@SiteType=0) OR (@SiteType=1 AND (st.IsLicensee=0 OR ISNULL(fb.SiteID,0)=0)) OR (@SiteType=2 AND st.IsLicensee=1))
	
	SELECT d.FeedbackID, 
			d.CustID, 
			d.TitleID,
			c.UserName,
			d.FirstName, 
			d.LastName, 
			d.Email, 
			d.Skype, 
			d.MSN,			
			ISNULL(l.Name,'N/A') Language, 
			ISNULL(ct.CountryName,'N/A') CountryName, 
			d.CreateDate, 		
			d.CreatorID,
			ci.UserName as CreatorName, 
			d.FeedbackDate, 
			d.ResolutionDate,
			d.SolveDate, 				 
			ISNULL(s.SiteName,'N/A') SiteName, 
			Role.Role, 
			ISNULL(Response.Response,'N/A') Response, 
			ISNULL(st.Name,'N/A') Status, 	
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
			ISNULL(d.PIC4Name,'') PIC4Name,
			CAST(d.Description AS XML) AS Description			
	INTO #Data
	FROM #temp t
	INNER JOIN crmFeedback d WITH(NOLOCK) ON t.Feedbackid=d.Feedbackid	
	INNER JOIN crmCustomer c WITH(NOLOCK) ON d.CustID = c.CustID		
	LEFT JOIN bodb02.dbo.custinfo ci WITH(NOLOCK) ON d.CreatorID = ci.custID		
	LEFT JOIN crmLanguage l WITH(NOLOCK) ON l.LanguageID = d.languageid
	LEFT JOIN crmCountry ct WITH(NOLOCK) ON ct.CountryID = d.CountryID
	LEFT JOIN crmSite s WITH(NOLOCK) ON s.SiteID = d.SiteID
	LEFT JOIN (
		SELECT SettingID RoleID, SettingValue Role FROM crmSetting WITH(NOLOCK) WHERE SettingName = 'Role'
	) Role ON Role.RoleID = d.RoleID
	LEFT JOIN (
		SELECT SettingID ResponseID, SettingValue Response FROM crmSetting WITH(NOLOCK) WHERE SettingName = 'Response'
	) Response ON Response.ResponseID = d.ResponseID
	LEFT JOIN crmStatus st WITH(NOLOCK) ON st.StatusID = d.StatusID
	ORDER BY d.FeedbackDate DESC
	
	 
		SELECT d.FeedbackID, 
			d.CustID, 
			d.TitleID,
			d.UserName,
			d.FirstName, 
			d.LastName, 
			d.Email, 
			d.Skype, 
			d.MSN,			
			d.Language, 
			d.CountryName, 
			d.CreateDate, 		
			d.CreatorID,
			d.CreatorName, 
			d.FeedbackDate, 
			d.ResolutionDate,
			d.SolveDate, 				 
			d.SiteName, 
			d.Role, 
			d.Response, 
			d.Status, 	
			d.Solution, 
			d.IsReviewed, 
			d.Review, 
			d.ReviewerID, 
			d.Subject,
			d.FaxCountryCode,
			d.FaxAreaCode,
			d.Fax,
			d.PhoneCountryCode,
			d.PhoneAreaCode,
			d.Phone,
			d.Phone2CountryCode,
			d.Phone2AreaCode,
			d.Phone2,
			d.Phone3CountryCode,
			d.Phone3AreaCode,
			d.Phone3,
			d.WhatsApp,
			d.Line,
			d.WeChat,
			d.Yahoo,
			d.QQ,
			d.BBM,
			d.MobilePhoneCountryCode,
			d.MobilePhoneAreaCode,
			d.MobilePhone,
			d.PIC1,
			d.PIC2,
			d.PIC3,
			d.PIC4,
			d.PIC1Name,
			d.PIC2Name,
			d.PIC3Name,
			d.PIC4Name,			
			nr.value(N'@Remark',N'nvarchar(max)') AS Description
	FROM #Data d
		OUTER APPLY d.Description.nodes(N'//row') AS A(nr)
		
	SELECT fs.FeedbackID,fs.SettingID,fs.SubSettingID,fs.SubSettingIDLevel3,
		CASE	WHEN m.MainCategoryID	IS NOT NULL THEN 'Category' 
				WHEN s.StationID		IS NOT NULL THEN 'Station' 
				WHEN p.SettingID		IS NOT NULL THEN 'Product' 
				WHEN c.SettingID		IS NOT NULL THEN 'Communication' 
				END AS SettingType
		FROM #Data fp
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
	DROP TABLE #DATA	
END
GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_Rpt_CustomerStatisticsDetail] TO [bodbAdminNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_Rpt_CustomerStatisticsDetail] TO [vnteam]
GO 

