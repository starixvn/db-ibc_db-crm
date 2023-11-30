/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE [dbo].[Acc_CRM_Rpt_FeedbackStatisticsPeriod]
(
	@FromDate		DATETIME,
	@ToDate			DATETIME,
	@MainCategoryID INT = 0,
	@SubCategoryID	INT = 0,
	@UserRole		INT = 2,
    @LicenseeType   TINYINT = 0,
    @SiteLabel      VARCHAR(MAX) = NULL
)
AS

/*
    Created: Dom
    Date: 20140408
    Task : feedback statistics report period
    DB: DBCRM.bodb_CRM
    Original:

    Revisions:
        - 20171225@Winnie: Change for support multiple product/categories. [RedmineID: #84714]
        - 20190506@Winnie:  CN88 Permission RedmineID: #112637
        - 20231128@Ned.Le: CRM - Security improvement - Separate accessible data for Credit Sites (#197343)

    Param's Explanation:
        - @LicenseeType = 0: Both
                          1: Credit
                          2: Licensee
        - @SiteLabel: Value depend on user's permission and maybe NULL
*/

BEGIN

	SET NOCOUNT ON

    -- #tmpSiteLabel
    CREATE TABLE #tmpSiteLabel (SiteLabel VARCHAR(50))

    INSERT INTO #tmpSiteLabel (SiteLabel)
    SELECT value SiteLabel
    FROM STRING_SPLIT(@SiteLabel, ',')

    -- #tmpSite
    CREATE TABLE #tmpSite (
        SiteID     INT,
        SiteName   NVARCHAR(100),
        SiteLabel  VARCHAR(50),
        IsLicensee INT
    )

    IF (@UserRole = 2)
    BEGIN
        INSERT INTO #tmpSite (
            SiteID,
            SiteName,
            SiteLabel,
            IsLicensee
        )
        SELECT s.SettingID SiteID,
               s.SettingValue SiteName,
               s.ExtraInfo SiteLabel,
               CASE WHEN sr.ParentID = 33000 THEN 1
                    WHEN sr.ParentID = 33001 THEN 0
                    ELSE -1 END IsLicensee
        FROM bodb_CRM.dbo.crmSettingRelation sr WITH (NOLOCK)
             INNER JOIN	bodb_CRM.dbo.crmSetting s WITH(NOLOCK) ON sr.SettingID = s.SettingID AND s.SettingName = 'Site'
        WHERE sr.ParentID IN (33000, 33001)
    END
    ELSE IF (@UserRole = 1)
	BEGIN
        INSERT INTO #tmpSite (
            SiteID,
            SiteName,
            SiteLabel,
            IsLicensee
        )
        SELECT s.SettingID SiteID,
               s.SettingValue SiteName,
               s.ExtraInfo SiteLabel,
               0 IsLicensee
        FROM bodb_CRM.dbo.crmSetting s WITH (NOLOCK)
		WHERE s.SettingID = 33002
    END

    CREATE CLUSTERED INDEX CIX_tmpSite ON #tmpSite(SiteID)

    -- Return data
	IF(@MainCategoryID<>0)
	BEGIN
		SELECT 		
				f.FeedbackDate,
				ISNULL(f.CountryID,0) CountryID,
				ISNULL(c.CountryName,'N/A') CountryName,
				COUNT(distinct f.FeedbackID) NoOfIssues 
		FROM crmFeedback f WITH(NOLOCK)	
		INNER JOIN dbo.f_GetFeedbackSetting(0,@MainCategoryID,@SubCategoryID,2) fs ON f.FeedbackID=fs.FeedbackID		
		LEFT JOIN crmCountry c WITH(NOLOCK) ON c.CountryID = f.CountryID
        LEFT JOIN #tmpSite s ON f.SiteID = s.SiteID
        LEFT JOIN #tmpSiteLabel sl ON s.SiteLabel = sl.SiteLabel
		WHERE f.StatusID NOT IN( 11004,11019)
		AND f.FeedbackDate BETWEEN @FromDate AND @ToDate	
		AND c.siteoffer=@UserRole
        AND (s.IsLicensee IS NULL
             OR s.IsLicensee = CASE WHEN @LicenseeType = 0 THEN s.IsLicensee WHEN @LicenseeType = 1 THEN 0 ELSE 1 END)
        AND (ISNULL(s.SiteLabel, '') = CASE WHEN @LicenseeType = 0 THEN CASE WHEN s.IsLicensee = 0 THEN sl.SiteLabel ELSE ISNULL(s.SiteLabel, '') END
                                            WHEN @LicenseeType = 1 THEN sl.SiteLabel
                                            WHEN @LicenseeType = 2 THEN ISNULL(s.SiteLabel, '') END)
		GROUP BY f.FeedbackDate,c.CountryName,f.CountryID
		ORDER BY f.FeedbackDate DESC
	END
	ELSE 
	BEGIN
		SELECT 
				f.FeedbackDate,
				ISNULL(f.CountryID,0) CountryID,
				ISNULL(c.CountryName,'N/A') CountryName,
				COUNT(distinct f.FeedbackID) NoOfIssues 
		FROM crmFeedback f WITH(NOLOCK)	
		LEFT JOIN crmCountry c WITH(NOLOCK) ON c.CountryID = f.CountryID
        LEFT JOIN #tmpSite s ON f.SiteID = s.SiteID
        LEFT JOIN #tmpSiteLabel sl ON s.SiteLabel = sl.SiteLabel
		WHERE f.StatusID NOT IN( 11004,11019)
		AND f.FeedbackDate BETWEEN @FromDate AND @ToDate	
		AND c.siteoffer=@UserRole
        AND (s.IsLicensee IS NULL
             OR s.IsLicensee = CASE WHEN @LicenseeType = 0 THEN s.IsLicensee WHEN @LicenseeType = 1 THEN 0 ELSE 1 END)
        AND (ISNULL(s.SiteLabel, '') = CASE WHEN @LicenseeType = 0 THEN CASE WHEN s.IsLicensee = 0 THEN sl.SiteLabel ELSE ISNULL(s.SiteLabel, '') END
                                            WHEN @LicenseeType = 1 THEN sl.SiteLabel
                                            WHEN @LicenseeType = 2 THEN ISNULL(s.SiteLabel, '') END)
		GROUP BY 
				 f.FeedbackDate,c.CountryName,f.CountryID
		ORDER BY f.FeedbackDate DESC
	END

    -- DROP temp tables
    DROP TABLE #tmpSiteLabel
    DROP TABLE #tmpSite

END
GO