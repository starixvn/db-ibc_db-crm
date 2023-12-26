/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE [dbo].[Acc_CRM_Rpt_FeedbackStatisticsPeriod]
(
	@FromDate		DATETIME      = NULL,
	@ToDate			DATETIME      = NULL,
	@MainCategoryID INT           = 0,
	@SubCategoryID	INT           = 0,
	@UserRole		INT           = 2,
    @LicenseeType   TINYINT       = 0,
    @SitePermission NVARCHAR(MAX) = NULL
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
        - @SitePermission: Value depend on user's permission and maybe NULL
*/

BEGIN

	SET NOCOUNT ON

    -- #tmpUserSitePermission
    CREATE TABLE #tmpUserSitePermission (SitePermission NVARCHAR(100))

    INSERT INTO #tmpUserSitePermission (SitePermission)
    SELECT value SitePermission
    FROM STRING_SPLIT(@SitePermission, ',')

    -- #tmpSite
    CREATE TABLE #tmpSite (
        SiteID     INT,
        SiteName   NVARCHAR(100),
        IsLicensee INT,
        IsActive   BIT,
        SiteLabel  VARCHAR(50),
        SiteOffer  INT
    )

    INSERT INTO #tmpSite (
        SiteID,
        SiteName,
        IsLicensee,
        IsActive,
        SiteLabel,
        SiteOffer
    )
    SELECT si.SettingID SiteID,
           si.SettingValue SiteName,
           CASE WHEN sr.ParentID = 33000 THEN 1
                WHEN sr.ParentID = 33001 THEN 0
                ELSE -1 END IsLicensee,
           si.IsActive IsActive,
           si.ExtraInfo SiteLabel,
           sc.SiteOffer SiteOffer
    FROM bodb_CRM.dbo.crmSettingRelation sr WITH (NOLOCK)
         INNER JOIN bodb_CRM.dbo.crmSetting sc WITH (NOLOCK) ON sc.SettingName = 'SiteCategory' AND sr.ParentID = sc.SettingID
         INNER JOIN	bodb_CRM.dbo.crmSetting si WITH (NOLOCK) ON si.SettingName = 'Site' AND sr.SettingID = si.SettingID
    WHERE sr.ParentID IN (33000, 33001)
    UNION ALL
    SELECT sc.SettingID SiteID,
           sc.SettingValue SiteName,
           0 IsLicensee,
           sc.IsActive IsActive,
           NULL SiteLabel,
           sc.SiteOffer SiteOffer
    FROM bodb_CRM.dbo.crmSetting sc
    WHERE sc.SettingName = 'SiteCategory' AND sc.SettingID = 33002

    CREATE CLUSTERED INDEX CIX_tmpSite ON #tmpSite(SiteID)

    -- #tmpSitePermission
    CREATE TABLE #tmpSitePermission (
        SiteID         INT,
        SiteName       NVARCHAR(100),
        SitePermission NVARCHAR(100)
    )

    INSERT INTO #tmpSitePermission (
        SiteID,
        SiteName,
        SitePermission
    )
    SELECT sr.SettingID    SiteID,
           si.SettingValue SiteName,
           sp.SettingValue SitePermission
    FROM bodb_CRM.dbo.crmSettingRelation sr WITH (NOLOCK)
         INNER JOIN bodb_CRM.dbo.crmSetting sp WITH (NOLOCK) ON sp.SettingName = 'SitePermission' AND sr.ParentID = sp.SettingID
         INNER JOIN bodb_CRM.dbo.crmSetting si WITH (NOLOCK) ON si.SettingName = 'Site' AND sr.SettingID = si.SettingID

    CREATE CLUSTERED INDEX CIX_tmpSitePermission ON #tmpSitePermission(SiteID)

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
        LEFT JOIN #tmpSite si ON f.SiteID = si.SiteID
        LEFT JOIN #tmpSitePermission sp ON si.SiteID = sp.SiteID
        LEFT JOIN #tmpUserSitePermission usp ON sp.SitePermission = sp.SitePermission
		WHERE f.StatusID NOT IN( 11004,11019)
		AND f.FeedbackDate BETWEEN @FromDate AND @ToDate	
		AND c.siteoffer=@UserRole
        AND si.SiteOffer = @UserRole
        AND (si.IsLicensee IS NULL
             OR si.IsLicensee = CASE WHEN @LicenseeType = 0 THEN si.IsLicensee WHEN @LicenseeType = 1 THEN 0 ELSE 1 END)
        AND (ISNULL(sp.SitePermission, '') = CASE WHEN @LicenseeType = 0 THEN CASE WHEN si.IsLicensee = 0 THEN usp.SitePermission ELSE ISNULL(sp.SitePermission, '') END
                                                  WHEN @LicenseeType = 1 THEN usp.SitePermission
                                                  WHEN @LicenseeType = 2 THEN ISNULL(sp.SitePermission, '') END)
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
        LEFT JOIN #tmpSite si ON f.SiteID = si.SiteID
        LEFT JOIN #tmpSitePermission sp ON si.SiteID = sp.SiteID
        LEFT JOIN #tmpUserSitePermission usp ON sp.SitePermission = sp.SitePermission
		WHERE f.StatusID NOT IN( 11004,11019)
		AND f.FeedbackDate BETWEEN @FromDate AND @ToDate	
		AND c.siteoffer=@UserRole
        AND si.SiteOffer = @UserRole
        AND (si.IsLicensee IS NULL
             OR si.IsLicensee = CASE WHEN @LicenseeType = 0 THEN si.IsLicensee WHEN @LicenseeType = 1 THEN 0 ELSE 1 END)
        AND (ISNULL(sp.SitePermission, '') = CASE WHEN @LicenseeType = 0 THEN CASE WHEN si.IsLicensee = 0 THEN usp.SitePermission ELSE ISNULL(sp.SitePermission, '') END
                                                  WHEN @LicenseeType = 1 THEN usp.SitePermission
                                                  WHEN @LicenseeType = 2 THEN ISNULL(sp.SitePermission, '') END)
		GROUP BY 
				 f.FeedbackDate,c.CountryName,f.CountryID
		ORDER BY f.FeedbackDate DESC
	END

    -- DROP temp tables
    DROP TABLE #tmpUserSitePermission
    DROP TABLE #tmpSite
    DROP TABLE #tmpSitePermission

END
GO