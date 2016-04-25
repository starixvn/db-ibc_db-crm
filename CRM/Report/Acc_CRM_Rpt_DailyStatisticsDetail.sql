SET QUOTED_IDENTIFIER ON; 
GO
SET ANSI_NULLS ON; 
GO

ALTER PROCEDURE [dbo].[Acc_CRM_Rpt_DailyStatisticsDetail]
(
	@SiteType			BIT = 0,
	@FromDate			DATETIME,
	@ToDate				DATETIME,
	@ProductID			VARCHAR(500), 
	@MainCategoryID		VARCHAR(500), 
	@CommunicationID	VARCHAR(500),
	@PageSize			INT = 0,
	@PageIndex			INT = 0,
	@TotalRows			INT = 0 OUTPUT
)
AS
/*
	Created:	20151111@Elodie
	Task:		View daily statistics report more detail
	DB:			DBCRM/bodb_CRM
	Original:

	Revisions:
		
	Param's Explanation:		
		@SiteType: 	0: IBC
					1: Licensee

	Ex: EXEC Acc_CRM_Rpt_DailyStatisticsDetail @SiteType = 0, @FromDate = '20151001', @ToDate = '20151118', @ProductID = '8000,8001,8003,8009,8010,8013,8014', @MainCategoryID = '3000,3001,3003,3008,3009', @CommunicationID = '1000,1001,1003,1006,1007'
				
*/
BEGIN
	SET NOCOUNT ON	
	DECLARE @RowStart INT, @RowEnd INT 
	SELECT @TotalRows = 0		
	SELECT @PageIndex = @PageIndex - 1
			,@RowStart = @PageSize * @PageIndex + 1
			,@RowEnd = @RowStart + @PageSize - 1

	DECLARE @Product TABLE (ProductID INT, Product NVARCHAR(100))	
	DECLARE @MainCategory TABLE (MainCategoryID INT, MainCategory NVARCHAR(100))	
	DECLARE @Communication TABLE (CommunicationID INT, Communication NVARCHAR(100))		

	DECLARE @string VARCHAR(max), @splitter CHAR(1), @xml XML
	SELECT @splitter = ',' 
	
	SELECT @string = @ProductID
	SET @XML = N'<root><r>' + REPLACE(@string, @splitter, '</r><r>') + '</r></root>'

	INSERT INTO @Product(ProductID, Product)
	SELECT r.value('.','INT'), s.SettingValue
	FROM @xml.nodes('//root/r') AS RECORDS(r)
		INNER JOIN crmSetting s WITH(NOLOCK) ON r.value('.','INT') = s.SettingID
	WHERE SettingName = 'Product'
	
	SELECT @string = @MainCategoryID
	SET @XML = N'<root><r>' + REPLACE(@string, @splitter, '</r><r>') + '</r></root>'

	INSERT INTO @MainCategory (MainCategoryID, MainCategory)
	SELECT r.value('.','INT'), s.SettingValue
	FROM @xml.nodes('//root/r') AS RECORDS(r)
		INNER JOIN crmSetting s WITH(NOLOCK) ON r.value('.','INT') = s.SettingID
	WHERE SettingName = 'Maincategory'

	SELECT @string = @CommunicationID
	SET @XML = N'<root><r>' + REPLACE(@string, @splitter, '</r><r>') + '</r></root>'

	INSERT INTO @Communication (CommunicationID, Communication)
	SELECT r.value('.','INT'), s.SettingValue
	FROM @xml.nodes('//root/r') AS RECORDS(r)
		INNER JOIN crmSetting s WITH(NOLOCK) ON r.value('.','INT') = s.SettingID
	WHERE SettingName = 'Communication'
			
	IF ((@PageSize <= 0) AND (@PageIndex <= 0))
	BEGIN
		SELECT	fb.FeedbackID, 
				fb.CustID, 
				fb.TitleID,
				c.UserName,
				fb.FirstName, 
				fb.LastName, 
				fb.Email, 
				fb.Skype, 
				fb.MSN,
				ISNULL(P.Product,'N/A') Product, 
				ISNULL(l.Name,'N/A') Language, 
				ISNULL(ct.CountryName,'N/A') CountryName, 
				fb.CreateDate, 		
				fb.CreatorID,
				ci.UserName AS CreatorName, 
				fb.FeedbackDate, 
				fb.ResolutionDate,
				fb.SolveDate, 
				ISNULL(cto.Communication,'N/A') Communication, 
				ISNULL(Station.Name,'N/A') Station, 
				ISNULL(mc.MainCategory,'N/A') MainCategory, 		
				ISNULL(sc.Name,'N/A') SubCategory, 
				ISNULL(s.SiteName,'N/A') SiteName, 
				Role.Role, 
				ISNULL(bt.Name,'N/A') Bettype, 
				ISNULL(Response.Response,'N/A') Response, 
				ISNULL(st.Name,'N/A') Status, 		
				fb.Description, 
				fb.Solution, 
				fb.IsReviewed, 
				fb.Review, 
				fb.ReviewerID, 
				fb.Subject,
				ISNULL(fb.FaxCountryCode,'') FaxCountryCode,
				ISNULL(fb.FaxAreaCode,'') FaxAreaCode,
				ISNULL(fb.Fax,'') Fax,
				ISNULL(fb.PhoneCountryCode,'') PhoneCountryCode,
				ISNULL(fb.PhoneAreaCode,'') PhoneAreaCode,
				ISNULL(fb.Phone,'') Phone,
				ISNULL(fb.Phone2CountryCode,'') Phone2CountryCode,
				ISNULL(fb.Phone2AreaCode,'') Phone2AreaCode,
				ISNULL(fb.Phone2,'') Phone2,
				ISNULL(fb.Phone3CountryCode,'') Phone3CountryCode,
				ISNULL(fb.Phone3AreaCode,'') Phone3AreaCode,
				ISNULL(fb.Phone3,'') Phone3,
				ISNULL(fb.WhatsApp,'') WhatsApp,
				ISNULL(fb.Line,'') Line,
				ISNULL(fb.WeChat,'') WeChat,
				ISNULL(fb.Yahoo,'') Yahoo,
				ISNULL(fb.QQ,'') QQ,
				ISNULL(fb.BBM,'') BBM,
				ISNULL(fb.MobilePhoneCountryCode,'') MobilePhoneCountryCode,
				ISNULL(fb.MobilePhoneAreaCode,'') MobilePhoneAreaCode,
				ISNULL(fb.MobilePhone,'') MobilePhone,
				ISNULL(fb.PIC1,'') PIC1,
				ISNULL(fb.PIC2,'') PIC2,
				ISNULL(fb.PIC3,'') PIC3,
				ISNULL(fb.PIC4,'') PIC4,
				ISNULL(fb.PIC1Name,'') PIC1Name,
				ISNULL(fb.PIC2Name,'') PIC2Name,
				ISNULL(fb.PIC3Name,'') PIC3Name,
				ISNULL(fb.PIC4Name,'') PIC4Name
		FROM crmFeedback fb WITH(NOLOCK) 
			INNER JOIN @Product p ON fb.ProductID = p.ProductID
			INNER JOIN @MainCategory mc ON fb.MainCategoryID = mc.MainCategoryID	
			INNER JOIN @Communication cto ON fb.CommunicationID = cto.CommunicationID
			LEFT JOIN crmSite s WITH(NOLOCK) ON s.SiteID = fb.SiteID
			INNER JOIN crmCustomer c WITH(NOLOCK) ON fb.CustID = c.CustID	
			LEFT JOIN crmLanguage l WITH(NOLOCK) ON l.LanguageID = fb.languageid
			LEFT JOIN crmCountry ct WITH(NOLOCK) ON ct.CountryID = fb.CountryID
			LEFT JOIN bodb02.dbo.custinfo ci WITH(NOLOCK) ON fb.CreatorID = ci.custID
			LEFT JOIN crmStation Station ON Station.StationID = fb.StationID		
			LEFT JOIN crmBettype bt WITH(NOLOCK) ON bt.BettypeID = fb.BettypeID AND fb.ProductID = bt.ProductID
			LEFT JOIN crmStatus st WITH(NOLOCK) ON st.StatusID = fb.StatusID			
			LEFT JOIN crmSubCategory sc WITH(NOLOCK) ON sc.SubCategoryID = fb.SubCategoryID and sc.MainCategoryID = fb.MainCategoryID
			LEFT JOIN (
							SELECT SettingID ResponseID, SettingValue Response FROM crmSetting WITH(NOLOCK) WHERE SettingName = 'Response'
						) Response ON Response.ResponseID = fb.ResponseID
			LEFT JOIN (
							SELECT SettingID RoleID, SettingValue Role FROM crmSetting WITH(NOLOCK) WHERE SettingName = 'Role'
						) Role ON Role.RoleID = fb.RoleID			
		WHERE fb.feedbackdate BETWEEN @fromdate AND @todate
				AND fb.StatusID <> 11004
				AND (@SiteType = 0 AND (s.IsLicensee = 0 OR ISNULL(fb.SiteID,0) = 0) OR (@SiteType = 1 AND s.IsLicensee = 1))
		ORDER BY fb.feedbackdate DESC
		
		RETURN
	END
	
	IF @TotalRows = 0  
	BEGIN  
		SELECT @TotalRows = count(1)
		FROM crmFeedback fb WITH(NOLOCK) 
			INNER JOIN @Product p ON fb.ProductID = p.ProductID
			INNER JOIN @MainCategory mc ON fb.MainCategoryID = mc.MainCategoryID	
			INNER JOIN @Communication cto ON fb.CommunicationID = cto.CommunicationID
			LEFT JOIN crmSite s WITH(NOLOCK) ON s.SiteID = fb.SiteID
		WHERE fb.feedbackdate BETWEEN @fromdate AND @todate
				AND fb.StatusID <> 11004
				AND (@SiteType = 0 AND (s.IsLicensee = 0 OR ISNULL(fb.SiteID,0) = 0) OR (@SiteType = 1 AND s.IsLicensee = 1))
	END

	;WITH Pag AS
	(
	  SELECT ROW_NUMBER() OVER(ORDER BY feedbackdate DESC) AS RowNum, FeedbackID
	  FROM crmFeedback fb WITH(NOLOCK) 
			INNER JOIN @Product p ON fb.ProductID = p.ProductID
			INNER JOIN @MainCategory mc ON fb.MainCategoryID = mc.MainCategoryID	
			INNER JOIN @Communication cto ON fb.CommunicationID = cto.CommunicationID
			LEFT JOIN crmSite s WITH(NOLOCK) ON s.SiteID = fb.SiteID
		WHERE fb.feedbackdate BETWEEN @fromdate AND @todate
				AND fb.StatusID <> 11004
				AND (@SiteType = 0 AND (s.IsLicensee = 0 OR ISNULL(fb.SiteID,0) = 0) OR (@SiteType = 1 AND s.IsLicensee = 1))
	)
	
	SELECT	fb.FeedbackID, 
			fb.CustID, 
			fb.TitleID,
			c.UserName,
			fb.FirstName, 
			fb.LastName, 
			fb.Email, 
			fb.Skype, 
			fb.MSN,
			ISNULL(P.Product,'N/A') Product, 
			ISNULL(l.Name,'N/A') Language, 
			ISNULL(ct.CountryName,'N/A') CountryName, 
			fb.CreateDate, 		
			fb.CreatorID,
			ci.UserName AS CreatorName, 
			fb.FeedbackDate, 
			fb.ResolutionDate,
			fb.SolveDate, 
			ISNULL(cto.Communication,'N/A') Communication, 
			ISNULL(Station.Name,'N/A') Station, 
			ISNULL(mc.MainCategory,'N/A') MainCategory, 		
			ISNULL(sc.Name,'N/A') SubCategory, 
			ISNULL(s.SiteName,'N/A') SiteName, 
			Role.Role, 
			ISNULL(bt.Name,'N/A') Bettype, 
			ISNULL(Response.Response,'N/A') Response, 
			ISNULL(st.Name,'N/A') Status, 		
			fb.Description, 
			fb.Solution, 
			fb.IsReviewed, 
			fb.Review, 
			fb.ReviewerID, 
			fb.Subject,
			ISNULL(fb.FaxCountryCode,'') FaxCountryCode,
			ISNULL(fb.FaxAreaCode,'') FaxAreaCode,
			ISNULL(fb.Fax,'') Fax,
			ISNULL(fb.PhoneCountryCode,'') PhoneCountryCode,
			ISNULL(fb.PhoneAreaCode,'') PhoneAreaCode,
			ISNULL(fb.Phone,'') Phone,
			ISNULL(fb.Phone2CountryCode,'') Phone2CountryCode,
			ISNULL(fb.Phone2AreaCode,'') Phone2AreaCode,
			ISNULL(fb.Phone2,'') Phone2,
			ISNULL(fb.Phone3CountryCode,'') Phone3CountryCode,
			ISNULL(fb.Phone3AreaCode,'') Phone3AreaCode,
			ISNULL(fb.Phone3,'') Phone3,
			ISNULL(fb.WhatsApp,'') WhatsApp,
			ISNULL(fb.Line,'') Line,
			ISNULL(fb.WeChat,'') WeChat,
			ISNULL(fb.Yahoo,'') Yahoo,
			ISNULL(fb.QQ,'') QQ,
			ISNULL(fb.BBM,'') BBM,
			ISNULL(fb.MobilePhoneCountryCode,'') MobilePhoneCountryCode,
			ISNULL(fb.MobilePhoneAreaCode,'') MobilePhoneAreaCode,
			ISNULL(fb.MobilePhone,'') MobilePhone,
			ISNULL(fb.PIC1,'') PIC1,
			ISNULL(fb.PIC2,'') PIC2,
			ISNULL(fb.PIC3,'') PIC3,
			ISNULL(fb.PIC4,'') PIC4,
			ISNULL(fb.PIC1Name,'') PIC1Name,
			ISNULL(fb.PIC2Name,'') PIC2Name,
			ISNULL(fb.PIC3Name,'') PIC3Name,
			ISNULL(fb.PIC4Name,'') PIC4Name
	FROM crmFeedback fb WITH(NOLOCK) 
		INNER JOIN Pag ON fb.FeedbackID = pag.FeedbackID
		INNER JOIN @Product p ON fb.ProductID = p.ProductID
		INNER JOIN @MainCategory mc ON fb.MainCategoryID = mc.MainCategoryID	
		INNER JOIN @Communication cto ON fb.CommunicationID = cto.CommunicationID
		LEFT JOIN crmSite s WITH(NOLOCK) ON s.SiteID = fb.SiteID
		INNER JOIN crmCustomer c WITH(NOLOCK) ON fb.CustID = c.CustID	
		LEFT JOIN crmLanguage l WITH(NOLOCK) ON l.LanguageID = fb.languageid
		LEFT JOIN crmCountry ct WITH(NOLOCK) ON ct.CountryID = fb.CountryID
		LEFT JOIN bodb02.dbo.custinfo ci WITH(NOLOCK) ON fb.CreatorID = ci.custID
		LEFT JOIN crmStation Station ON Station.StationID = fb.StationID		
		LEFT JOIN crmBettype bt WITH(NOLOCK) ON bt.BettypeID = fb.BettypeID AND fb.ProductID = bt.ProductID
		LEFT JOIN crmStatus st WITH(NOLOCK) ON st.StatusID = fb.StatusID			
		LEFT JOIN crmSubCategory sc WITH(NOLOCK) ON sc.SubCategoryID = fb.SubCategoryID and sc.MainCategoryID = fb.MainCategoryID
		LEFT JOIN (
						SELECT SettingID ResponseID, SettingValue Response FROM crmSetting WITH(NOLOCK) WHERE SettingName = 'Response'
					) Response ON Response.ResponseID = fb.ResponseID
		LEFT JOIN (
						SELECT SettingID RoleID, SettingValue Role FROM crmSetting WITH(NOLOCK) WHERE SettingName = 'Role'
					) Role ON Role.RoleID = fb.RoleID			
	WHERE pag.RowNum BETWEEN @RowStart AND @RowEnd
END

GO
GRANT EXECUTE ON [dbo].[Acc_CRM_Rpt_DailyStatisticsDetail] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_Rpt_DailyStatisticsDetail] TO [vnteam]