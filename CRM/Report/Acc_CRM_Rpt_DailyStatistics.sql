/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE [dbo].[Acc_CRM_Rpt_DailyStatistics]
(
	@ProductType		BIT = 0,
	@CategoryType		BIT = 0,
	@SiteType			BIT = 0,
	@FromDate			DATETIME,
	@ToDate				DATETIME,
	@ProductID			VARCHAR(500), 
	@MainCategoryID		VARCHAR(500), 
	@CommunicationID	VARCHAR(500),
    @UserRole           TINYINT       = 2,
    @LicenseeType       INT           = 0,
    @SitePermission     NVARCHAR(MAX) = NULL
)
AS

/*
	Created:	20151111@Elodie
	Task:		Daily statistics report
	DB:			DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20171225@Winnie: Change for support multiple product/categories. [RedmineID: #84714]
		- 20190506@Winnie:  CN88 Permission RedmineID: #112637
		- 20230424@Malcolm:  Enhance Performance: #112637
        - 20230823@Ned.Le: CRM - Security improvement - Separate accessible data for Credit and Licensee Users (#192556)
        - 20231128@Ned.Le: CRM - Security improvement - Separate accessible data for Credit Sites (#197343)

	Param's Explanation:
		@ProductType:	0: Summary
						1: Detail	

		@CategoryType:	0: Main Category
						1: Sub Category	

		@SiteType: 	0: IBC
					1: Licensee

        @UserRole = 0: Manager 
                    1: CN88 staff
                    2: Company staff

        @LicenseeType = -1: None
                         0: Both
                         1: Credit
                         2: Licensee

        @SitePermission: Value depend on user's permission and maybe NULL

	Ex: EXEC Acc_CRM_Rpt_DailyStatistics @ProductType = 0, @CategoryType = 1, @SiteType = 0, @FromDate = '20151001', @ToDate = '20151118', @ProductID = '8000,8001,8003,8009,8010,8013,8014', @MainCategoryID = '3000,3001,3003,3008,3009', @CommunicationID = '1000,1001,1003,1006,1007', @LicenseeType = 0, @SitePermission = NULL
*/

BEGIN
	SET NOCOUNT ON	

    CREATE TABLE #tmpUserSitePermission (SitePermission NVARCHAR(100))
    CREATE TABLE #tmpSitePermission (SiteID INT, SiteName NVARCHAR(100), SitePermission NVARCHAR(100))
	CREATE TABLE #Product  (ProductID INT PRIMARY KEY, Product NVARCHAR(100))	
	CREATE TABLE #MainCategory (MainCategoryID INT PRIMARY KEY, MainCategory NVARCHAR(100))	
	CREATE TABLE #Communication  (CommunicationID INT PRIMARY KEY, Communication NVARCHAR(100))		
	CREATE TABLE #tmpFB (FeedbackID INT, SiteID INT)
	CREATE TABLE #ProductFeedback (SettingID INT, FeedbackID INT)
	CREATE TABLE #MainCategoryFeedBack (SettingID INT, SubSettingID INT,FeedbackID INT)
	CREATE TABLE #CommunicationFeedBack (SettingID INT, FeedbackID INT)

    INSERT INTO #tmpUserSitePermission (SitePermission)
    SELECT value SitePermission
    FROM STRING_SPLIT(@SitePermission, ',')

    INSERT INTO #tmpSitePermission (SiteID, SiteName, SitePermission)
    SELECT sr.SettingID    SiteID,
           si.SettingValue SiteName,
           sp.SettingValue SitePermission
    FROM bodb_CRM.dbo.crmSettingRelation sr WITH (NOLOCK)
         INNER JOIN bodb_CRM.dbo.crmSetting sp WITH (NOLOCK) ON sp.SettingName = 'SitePermission' AND sr.ParentID = sp.SettingID
         INNER JOIN bodb_CRM.dbo.crmSetting si WITH (NOLOCK) ON si.SettingName = 'Site' AND sr.SettingID = si.SettingID

	INSERT INTO #Product(ProductID, Product)
	SELECT s.SettingID, s.SettingValue
	FROM STRING_SPLIT(@ProductID, ',') f
		INNER JOIN dbo.crmSetting s WITH(NOLOCK) ON s.SettingID = f.value
	WHERE s.SettingName = 'Product'

	INSERT INTO #MainCategory (MainCategoryID, MainCategory)
	SELECT s.SettingID, s.SettingValue
	FROM STRING_SPLIT(@MainCategoryID, ',') f
		INNER JOIN dbo.crmSetting s WITH(NOLOCK) ON s.SettingID = f.value
	WHERE s.SettingName = 'Maincategory'

	INSERT INTO #Communication (CommunicationID, Communication)
	SELECT s.SettingID, s.SettingValue
	FROM STRING_SPLIT(@CommunicationID, ',') f
		INNER JOIN dbo.crmSetting s WITH(NOLOCK) ON s.SettingID = f.value
	WHERE s.SettingName = 'Communication'

	INSERT INTO #tmpFB (FeedbackID, SiteID)
	SELECT fb.FeedbackID, fb.SiteID
	FROM dbo.crmFeedback fb WITH(NOLOCK)
	WHERE fb.feedbackdate BETWEEN @fromdate AND @todate
		AND fb.StatusID NOT IN (11004, 11019)
	OPTION (RECOMPILE)

	INSERT INTO #ProductFeedback (SettingID, FeedbackID)
	SELECT fs.SettingID, fs.FeedbackID
	FROM dbo.crmFeedbackSetting fs WITH(NOLOCK)
	WHERE fs.FeedbackID IN (SELECT fb.FeedbackId FROM #TmpFB fb)
		AND fs.SettingID IN (SELECT p.ProductId FROM #Product p)

	INSERT INTO #MainCategoryFeedBack (SettingID,SubSettingID,FeedbackID)
	SELECT SettingID,SubSettingID,FeedbackID
	FROM crmFeedbackSetting (NOLOCK)
	WHERE FeedbackID IN (SELECT Feedbackid FROM #ProductFeedback)
		AND SettingID IN (SELECT MainCategoryID FROM #MainCategory)

	INSERT INTO #CommunicationFeedBack (SettingID,FeedbackID)
	SELECT SettingID,FeedbackID
	FROM crmFeedbackSetting (NOLOCK)
	WHERE FeedbackID IN (SELECT Feedbackid FROM #MainCategoryFeedBack)
		AND SettingID IN (SELECT CommunicationID FROM #Communication)

	/*Sum*/
	CREATE TABLE #tmpResultDetail (MainCategoryID INT, SubCategoryID INT, CommunicationID INT, ProductID INT, Total INT,PRIMARY KEY(MainCategoryID,SubCategoryID,CommunicationID,ProductID))
			
	INSERT INTO #tmpResultDetail (MainCategoryID, SubCategoryID, ProductID, CommunicationID, Total)
	SELECT 
		fm.SettingID AS MainCategoryID
		,CASE WHEN @CategoryType = 1 THEN sc.SubCategoryID ELSE @CategoryType END  AS SubCategoryID
		,CASE WHEN @ProductType = 1 THEN fp.SettingID ELSE @ProductType END AS ProductID
		,fc.SettingID AS CommunicationID
		,COUNT(DISTINCT fb.Feedbackid) AS Total
	FROM #tmpfb fb WITH(NOLOCK) 
		INNER JOIN #ProductFeedback fp ON fb.FeedbackID=fp.FeedbackID	
		INNER JOIN #MainCategoryFeedBack fm WITH(NOLOCK) ON fb.FeedbackID=fm.FeedbackID
		INNER JOIN #CommunicationFeedBack fc WITH(NOLOCK) ON fb.FeedbackID=fc.FeedbackID
		LEFT JOIN crmSubCategory sc ON fm.SubSettingID = sc.SubCategoryID AND fm.SettingID = sc.MainCategoryID
		LEFT JOIN crmSite s WITH(NOLOCK) ON s.SiteID = fb.SiteID
        LEFT JOIN #tmpSitePermission sp ON s.SiteID = sp.SiteID
        LEFT JOIN #tmpUserSitePermission usp ON sp.SitePermission = sp.SitePermission
	WHERE @LicenseeType <> -1
          AND
          (
              (@LicenseeType = 0 AND ((@SiteType = 0 AND (s.IsLicensee = 0
                                                          OR ISNULL(fb.SiteID,0) = 0
                                                          OR ISNULL(s.SiteID, 0) = 0))
                                      OR
                                      (@SiteType = 1 AND (s.IsLicensee = 1))))
              OR
              (@LicenseeType = 1 AND ((@SiteType = 0 AND (s.IsLicensee = 0
                                                          OR ISNULL(fb.SiteID,0) = 0
                                                          OR ISNULL(s.SiteID, 0) = 0))))
              OR
              (@LicenseeType = 2 AND ((@SiteType = 1 AND (s.IsLicensee = 1
                                                          OR ISNULL(fb.SiteID,0) = 0
                                                          OR ISNULL(s.SiteID, 0) = 0))))
          )
          AND
          (
              (sp.SitePermission IS NULL AND ISNULL(s.IsLicensee, 1) = 1)
              OR sp.SitePermission = usp.SitePermission
          )
          AND
          (
              @CategoryType = 0 OR sc.MainCategoryID IS NOT NULL
          )
	GROUP BY 
		fm.SettingID
		,CASE WHEN @CategoryType = 1 THEN sc.SubCategoryID ELSE @CategoryType END 
		,CASE WHEN @ProductType = 1 THEN fp.SettingID ELSE @ProductType END
		,fc.SettingID
	OPTION(RECOMPILE)

	;WITH CTE AS
	(
		SELECT 
			mc.MainCategoryID
			,c.CommunicationID
			,CASE WHEN @ProductType = 1 THEN p.ProductID ELSE @ProductType END AS ProductID
			,MAX(CASE WHEN @ProductType = 1 THEN Product ELSE '' END) AS Product
			,MAX(mc.MainCategory) AS MainCategory
			,CASE WHEN @CategoryType = 1 THEN sc.SubCategoryID ELSE @CategoryType END AS SubCategoryID
			,MAX(CASE WHEN @CategoryType = 1 THEN sc.Name ELSE '' END) AS SubCategory
			,MAX(Communication) AS Communication
		FROM #MainCategory mc
		LEFT JOIN crmSubCategory sc ON mc.MainCategoryID = sc.MainCategoryID
		LEFT JOIN #Product p ON 1 = 1
		CROSS JOIN #Communication c
		WHERE (@CategoryType = 0 OR sc.MainCategoryID IS NOT NULL) AND (@ProductType = 0 OR p.ProductId IS NOT NULL) 
		GROUP BY 
			mc.MainCategoryID
			,c.CommunicationID
			,CASE WHEN @CategoryType = 1 THEN sc.SubCategoryID ELSE @CategoryType END 
			,CASE WHEN @ProductType = 1 THEN p.ProductID ELSE @ProductType END
	)
	SELECT e.MainCategoryID, e.MainCategory, e.SubCategoryID, e.SubCategory, e.CommunicationID, e.Communication, e.ProductID, e.Product, ISNULL(n.Total, 0) AS Total
	FROM CTE e	
		OUTER APPLY 
		(
			SELECT tr.Total
			FROM #tmpResultDetail tr
			WHERE tr.MainCategoryID = e.MainCategoryID AND tr.SubCategoryID = e.SubCategoryID AND tr.CommunicationID = e.CommunicationID AND tr.ProductID = e.ProductID

		) AS n
   ORDER BY e.MainCategoryID, e.SubCategoryID, e.CommunicationID, e.ProductID

   DROP TABLE #tmpUserSitePermission
   DROP TABLE #tmpSitePermission
   DROP TABLE #Product 
   DROP TABLE #MainCategory
   DROP TABLE #Communication 
   DROP TABLE #tmpFB
   DROP TABLE #ProductFeedback 
   DROP TABLE #MainCategoryFeedBack 
   DROP TABLE #CommunicationFeedBack
   DROP TABLE #tmpResultDetail
END
GO
