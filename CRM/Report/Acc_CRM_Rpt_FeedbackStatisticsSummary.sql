 /*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

 USE bodb_CRM
 GO

ALTER PROCEDURE dbo.Acc_CRM_Rpt_FeedbackStatisticsSummary @Year         INT,
                                                          @SiteType     TINYINT = 0,
                                                          @TimeSpan     INT,
                                                          @UserRole     TINYINT = 2,
                                                          @LicenseeType TINYINT = 0,
                                                          @SiteLabel    VARCHAR(MAX) = NULL
AS

/*
Created: Dom
Date: 20140408
Task : feedback statistics Summary report
DB: DBCRM.bodb_CRM
Original:

Revisions:
		- 2014-08-12@Dom: Feature [#18860] Change requests on 10 Jul 2014
		- 20180420@Winnie: Missing some data on Categories Summary Report RedmineID:#94053
		- 20171225@Winnie: Change for support multiple product/categories. [RedmineID: #84714]	
		- 20190506@Winnie:  CN88 Permission RedmineID: #112637
        - 20231128@Ned.Le: CRM - Security improvement - Separate accessible data for Credit Sites (#197343)

Param's Explanation:
	@SiteType:	0-All,
				1-IBC,
				2-Licensee
    @LicenseeType = 0: Both
                    1: Credit
                    2: Licensee
    @SiteLabel: Value depend on user's permission and maybe NULL
*/

BEGIN
	SET NOCOUNT ON

    CREATE TABLE #tmpSiteLabel (SiteLabel VARCHAR(50))
    INSERT INTO  #tmpSiteLabel (SiteLabel) SELECT value SiteLabel FROM STRING_SPLIT(@SiteLabel, ',')

	DECLARE @FromDate datetime
		, @ToDate datetime
	SELECT @FromDate = DATEADD(hour,@TimeSpan,CONVERT( DATETIME, CAST (@Year AS VARCHAR(10))+'01'+'01',102 ));
	SELECT @ToDate = DATEADD(year,1,@FromDate);

	SELECT 
			MONTH( DATEADD(hour,-@TimeSpan,f.FeedbackDate) ) m,
			LEFT( DATENAME(mm,DATEADD(hour,-@TimeSpan,f.FeedbackDate)),3 ) [Month],
			m.MainCategoryID,
			m.Name MainCategory,
			s.SubCategoryID,
			s.Name SubCategory,
			COUNT(f.FeedbackID) NoOfIssues 
	FROM crmFeedback f WITH(NOLOCK) 
		INNER JOIN crmFeedbackSetting fs WITH(NOLOCK) ON f.FeedbackID=fs.FeedbackID
		INNER JOIN crmMainCategory m WITH(NOLOCK)  ON m.MainCategoryID = fs.SettingID
		INNER JOIN crmSubCategory s WITH(NOLOCK)  ON s.MainCategoryID = m.MainCategoryID and fs.SubSettingID = s.SubCategoryID
		LEFT JOIN crmSite [site] WITH (NOLOCK) ON [site].SiteID = f.SiteID
        LEFT JOIN #tmpSiteLabel sl ON [site].SiteLabel = sl.SiteLabel
	WHERE f.StatusID NOT IN( 11004,11019)
		AND f.FeedbackDate >= @FromDate AND f.FeedbackDate < @ToDate
		AND (@SiteType=0 OR (@SiteType=1 and IsLicensee=0)  OR (@SiteType=2 and IsLicensee=1)   OR (@SiteType=3 and IsLicensee IS NULL))
        AND ([site].IsLicensee IS NULL
             OR [site].IsLicensee = CASE WHEN @LicenseeType = 0 THEN [site].IsLicensee WHEN @LicenseeType = 1 THEN 0 ELSE 1 END)
        AND (ISNULL([site].SiteLabel, '') = CASE WHEN @LicenseeType = 0 THEN CASE WHEN [site].IsLicensee = 0 THEN sl.SiteLabel ELSE ISNULL([site].SiteLabel, '') END
                                                 WHEN @LicenseeType = 1 THEN sl.SiteLabel
                                                 WHEN @LicenseeType = 2 THEN ISNULL([site].SiteLabel, '') END)
	GROUP BY MONTH( DATEADD(hour,-@TimeSpan,f.FeedbackDate) ),
			LEFT( DATENAME(mm,DATEADD(hour,-@TimeSpan,f.FeedbackDate)),3 ),
			m.MainCategoryID,
			m.Name,
			s.SubCategoryID,
			s.Name
	ORDER BY	m.Name,
				s.SubCategoryID,
				Month(DATEADD(hour,-@TimeSpan,f.FeedbackDate))

    DROP TABLE #tmpSiteLabel
END

GO
GRANT EXECUTE ON [dbo].[Acc_CRM_Rpt_FeedbackStatisticsSummary] TO [bodbAdminNet]
GO
