/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet,vnteam" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_Rpt_DailyStatistics]
(
	@ProductType		BIT = 0,
	@CategoryType		BIT = 0,
	@SiteType			BIT = 0,
	@FromDate			DATETIME,
	@ToDate				DATETIME,
	@ProductID			VARCHAR(500), 
	@MainCategoryID		VARCHAR(500), 
	@CommunicationID	VARCHAR(500)
)
AS
/*
	Created:	20151111@Elodie
	Task:		Daily statistics report
	DB:			DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20171225@Winnie: Change for support multiple product/categories. [RedmineID: #84714]
	Param's Explanation:
		@ProductType:	0: Summary
						1: Detail	

		@CategoryType:	0: Main Category
						1: Sub Category	

		@SiteType: 	0: IBC
					1: Licensee

	Ex: EXEC Acc_CRM_Rpt_DailyStatistics @ProductType = 0, @CategoryType = 1, @SiteType = 0, @FromDate = '20151001', @ToDate = '20151118', @ProductID = '8000,8001,8003,8009,8010,8013,8014', @MainCategoryID = '3000,3001,3003,3008,3009', @CommunicationID = '1000,1001,1003,1006,1007'
				
*/
BEGIN
	SET NOCOUNT ON	
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

	IF @ProductType = 0
	BEGIN	
		IF @CategoryType = 0
		BEGIN
			CREATE TABLE #tmpResultAll (MainCategoryID INT, CommunicationID INT, Total INT)

			INSERT INTO #tmpResultAll (MainCategoryID, CommunicationID, Total)
			SELECT mc.MainCategoryID, c.CommunicationID, count(1) AS Total
			FROM crmFeedback fb WITH(NOLOCK) 
				INNER JOIN crmFeedbackSetting fp WITH(NOLOCK) ON fb.FeedbackID=fp.FeedbackID	
				INNER JOIN crmFeedbackSetting fm WITH(NOLOCK) ON fb.FeedbackID=fm.FeedbackID
				INNER JOIN crmFeedbackSetting fc WITH(NOLOCK) ON fb.FeedbackID=fc.FeedbackID			
				INNER JOIN @Product p ON fp.SettingID = p.ProductID
				INNER JOIN @MainCategory mc ON fm.SettingID = mc.MainCategoryID
				INNER JOIN @Communication c ON fc.SettingID = c.CommunicationID
				LEFT JOIN crmSite s WITH(NOLOCK) ON s.SiteID = fb.SiteID
			WHERE fb.feedbackdate BETWEEN @fromdate AND @todate
					AND fb.StatusID NOT IN (11004, 11001)
					AND (@SiteType = 0 AND (s.IsLicensee = 0 OR ISNULL(fb.SiteID,0) = 0) OR (@SiteType = 1 AND s.IsLicensee = 1))
			GROUP BY mc.MainCategoryID, c.CommunicationID
			ORDER BY mc.MainCategoryID, c.CommunicationID

			SELECT f.MainCategoryID, f.MainCategory, f.CommunicationID, f.Communication, ISNULL(r.Total, 0) AS Total
			FROM #tmpResultAll r
				RIGHT JOIN (SELECT MainCategoryID, MainCategory, CommunicationID, Communication
							FROM @MainCategory
								CROSS JOIN @Communication) AS f ON r.MainCategoryID = f.MainCategoryID AND r.CommunicationID = f.CommunicationID
			ORDER BY f.MainCategoryID, f.CommunicationID

			DROP TABLE #tmpResultAll
		END
		ELSE
		BEGIN			
			CREATE TABLE #tmpResultAllDetail (MainCategoryID INT, SubCategoryID INT, CommunicationID INT, Total INT)

			INSERT INTO #tmpResultAllDetail (MainCategoryID, SubCategoryID, CommunicationID, Total)
			SELECT mc.MainCategoryID, sc.SubCategoryID, c.CommunicationID, count(1) AS Total
			FROM crmFeedback fb WITH(NOLOCK)				
				INNER JOIN crmFeedbackSetting fp WITH(NOLOCK) ON fb.FeedbackID=fp.FeedbackID	
				INNER JOIN crmFeedbackSetting fm WITH(NOLOCK) ON fb.FeedbackID=fm.FeedbackID
				INNER JOIN crmFeedbackSetting fc WITH(NOLOCK) ON fb.FeedbackID=fc.FeedbackID	
				INNER JOIN @Product p ON fp.SettingID = p.ProductID
				INNER JOIN @MainCategory mc ON fm.SettingID = mc.MainCategoryID
				INNER JOIN crmSubCategory sc ON fm.SubSettingID = sc.SubCategoryID AND fm.SettingID = sc.MainCategoryID
				INNER JOIN @Communication c ON fc.SettingID = c.CommunicationID
				LEFT JOIN crmSite s WITH(NOLOCK) ON s.SiteID = fb.SiteID
			WHERE fb.feedbackdate BETWEEN @fromdate AND @todate
					AND fb.StatusID NOT IN (11004, 11001)
					AND (@SiteType = 0 AND (s.IsLicensee = 0 OR ISNULL(fb.SiteID,0) = 0) OR (@SiteType = 1 AND s.IsLicensee = 1))
			GROUP BY mc.MainCategoryID, sc.SubCategoryID, c.CommunicationID
			ORDER BY mc.MainCategoryID, sc.SubCategoryID, c.CommunicationID

			SELECT f.MainCategoryID, f.MainCategory, f.SubCategoryID, f.SubCategory, f.CommunicationID, f.Communication, ISNULL(r.Total, 0) AS Total
			FROM #tmpResultAllDetail r
				RIGHT JOIN (SELECT mc.MainCategoryID, MainCategory, sc.SubCategoryID, sc.Name AS SubCategory, CommunicationID, Communication
							FROM @MainCategory mc
								INNER JOIN crmSubCategory sc ON mc.MainCategoryID = sc.MainCategoryID
								CROSS JOIN @Communication) AS f ON r.MainCategoryID = f.MainCategoryID AND r.CommunicationID = f.CommunicationID AND r.SubCategoryID = f.SubCategoryID
			ORDER BY f.MainCategoryID, f.SubCategoryID, f.CommunicationID

			DROP TABLE #tmpResultAllDetail
		END
	END
	ELSE 
	BEGIN
		IF @CategoryType = 0
		BEGIN
			CREATE TABLE #tmpResult (MainCategoryID INT, CommunicationID INT, ProductID INT, Total INT)

			INSERT INTO #tmpResult (MainCategoryID, CommunicationID, ProductID, Total)
			SELECT mc.MainCategoryID, c.CommunicationID, p.ProductID, count(1) AS Total
			FROM crmFeedback fb WITH(NOLOCK) 
				INNER JOIN crmFeedbackSetting fp WITH(NOLOCK) ON fb.FeedbackID=fp.FeedbackID	
				INNER JOIN crmFeedbackSetting fm WITH(NOLOCK) ON fb.FeedbackID=fm.FeedbackID
				INNER JOIN crmFeedbackSetting fc WITH(NOLOCK) ON fb.FeedbackID=fc.FeedbackID	
				INNER JOIN @Product p ON fp.SettingID = p.ProductID
				INNER JOIN @MainCategory mc ON fm.SettingID = mc.MainCategoryID				
				INNER JOIN @Communication c ON fc.SettingID = c.CommunicationID
				LEFT JOIN crmSite s WITH(NOLOCK) ON s.SiteID = fb.SiteID
			WHERE fb.feedbackdate BETWEEN @fromdate AND @todate
					AND fb.StatusID NOT IN (11004, 11001)
					AND (@SiteType = 0 AND (s.IsLicensee = 0 OR ISNULL(fb.SiteID,0) = 0) OR (@SiteType = 1 AND s.IsLicensee = 1))
			GROUP BY mc.MainCategoryID, c.CommunicationID, p.ProductID
			ORDER BY mc.MainCategoryID, c.CommunicationID, p.ProductID

			SELECT f.MainCategoryID, f.MainCategory, f.CommunicationID, f.Communication, f.ProductID, f.Product, ISNULL(r.Total, 0) AS Total
			FROM #tmpResult r
				RIGHT JOIN (SELECT ProductID, Product, MainCategoryID, MainCategory, CommunicationID, Communication
							FROM @Product
								CROSS JOIN @MainCategory
								CROSS JOIN @Communication) AS f ON r.MainCategoryID = f.MainCategoryID AND r.CommunicationID = f.CommunicationID AND r.ProductID = f.ProductID
			ORDER BY f.MainCategoryID, f.CommunicationID, f.ProductID

			DROP TABLE #tmpResult
		END
		ELSE
		BEGIN			
			CREATE TABLE #tmpResultDetail (MainCategoryID INT, SubCategoryID INT, CommunicationID INT, ProductID INT, Total INT)
			
			INSERT INTO #tmpResultDetail (MainCategoryID, SubCategoryID, CommunicationID, ProductID, Total)
			SELECT mc.MainCategoryID, sc.SubCategoryID, c.CommunicationID, p.ProductID, count(1) AS Total
			FROM crmFeedback fb WITH(NOLOCK) 
				INNER JOIN crmFeedbackSetting fp WITH(NOLOCK) ON fb.FeedbackID=fp.FeedbackID	
				INNER JOIN crmFeedbackSetting fm WITH(NOLOCK) ON fb.FeedbackID=fm.FeedbackID
				INNER JOIN crmFeedbackSetting fc WITH(NOLOCK) ON fb.FeedbackID=fc.FeedbackID
				INNER JOIN @Product p ON fp.SettingID = p.ProductID
				INNER JOIN @MainCategory mc ON fm.SettingID = mc.MainCategoryID
				INNER JOIN crmSubCategory sc ON fm.SubSettingID = sc.SubCategoryID AND fm.SettingID = sc.MainCategoryID
				INNER JOIN @Communication c ON fc.SettingID = c.CommunicationID
				LEFT JOIN crmSite s WITH(NOLOCK) ON s.SiteID = fb.SiteID
			WHERE fb.feedbackdate BETWEEN @fromdate AND @todate
					AND fb.StatusID NOT IN (11004, 11001)
					AND (@SiteType = 0 AND (s.IsLicensee = 0 OR ISNULL(fb.SiteID,0) = 0) OR (@SiteType = 1 AND s.IsLicensee = 1))
			GROUP BY mc.MainCategoryID, sc.SubCategoryID, c.CommunicationID, p.ProductID
			ORDER BY mc.MainCategoryID, sc.SubCategoryID, c.CommunicationID, p.ProductID
			
			SELECT f.MainCategoryID, f.MainCategory, f.SubCategoryID, f.SubCategory, f.CommunicationID, f.Communication, f.ProductID, f.Product, ISNULL(r.Total, 0) AS Total
			FROM #tmpResultDetail r
				RIGHT JOIN (SELECT ProductID, Product, mc.MainCategoryID, MainCategory, sc.SubCategoryID, sc.Name AS SubCategory, CommunicationID, Communication
							FROM @Product
								CROSS JOIN @MainCategory mc
								INNER JOIN crmSubCategory sc ON mc.MainCategoryID = sc.MainCategoryID
								CROSS JOIN @Communication) AS f ON r.MainCategoryID = f.MainCategoryID AND r.SubCategoryID = f.SubCategoryID AND r.CommunicationID = f.CommunicationID AND r.ProductID = f.ProductID				
			ORDER BY f.MainCategoryID, f.SubCategoryID, f.CommunicationID, f.ProductID

			DROP TABLE #tmpResultDetail
		END
	END	
END

GO
