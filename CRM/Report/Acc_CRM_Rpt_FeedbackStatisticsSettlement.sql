/*<info serverAlias="DBCRM-bodb_CRM" executers="wsv_nap" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE dbo.Acc_CRM_Rpt_FeedbackStatisticsSettlement @Year           INT,
                                                             @TimeSpan       INT,
                                                             @UserRole       TINYINT       = 2,
                                                             @LicenseeType   INT           = 0,
                                                             @SitePermission NVARCHAR(MAX) = NULL
AS

/*
    Created: Dom
    Date: 20140408
    Task : feedback statistics settlement report
    DB: DBCRM.bodb_CRM

    Revisions:
        - 20171225@Winnie: Change for support multiple product/categories. [RedmineID: #84714]
        - 20190506@Winnie:  CN88 Permission RedmineID: #112637
        - 20231128@Ned.Le: CRM - Security improvement - Separate accessible data for Credit Sites (#197343)
        - 20240829@Ned.Le: CRM - When clicking Latest Feedback not found the feedback Due to permission limitations for account P5S (#210055)
    
    Param's Explanation:
        - @UserRole = 0: Manager 
                      1: CN88 staff
                      2: Company staff
        - @LicenseeType = -1: None
                           0: Both
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
         INNER JOIN    bodb_CRM.dbo.crmSetting si WITH (NOLOCK) ON si.SettingName = 'Site' AND sr.SettingID = si.SettingID
    WHERE sr.ParentID IN (33000, 33001)
    UNION ALL
    SELECT sc.SettingID SiteID,
           sc.SettingValue SiteName,
           0 IsLicensee,
           sc.IsActive IsActive,
           NULL SiteLabel,
           sc.SiteOffer SiteOffer
    FROM bodb_CRM.dbo.crmSetting sc WITH (NOLOCK)
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

    -- Get data to return
    DECLARE @FromDate DATETIME = DATEADD(HOUR, @TimeSpan, CONVERT( DATETIME, CAST (@Year AS VARCHAR(10)) + '01' + '01', 102))
    DECLARE @ToDate   DATETIME = DATEADD(YEAR, 1, @FromDate)

    SELECT MONTH( DATEADD(hour,-@TimeSpan,f.FeedbackDate)) [Month],
           f.CountryID,
           c.CountryName,
           COUNT(f.FeedbackID) NoOfIssues
    FROM bodb_CRM.dbo.crmFeedback f WITH (NOLOCK)
         INNER JOIN bodb_CRM.dbo.crmFeedbackSetting fs WITH(NOLOCK) ON f.FeedbackID = fs.FeedbackID    
         LEFT JOIN bodb_CRM.dbo.crmCountry c WITH(NOLOCK) ON c.CountryID = f.CountryID
         LEFT JOIN #tmpSite si ON f.SiteID = si.SiteID
         LEFT JOIN #tmpSitePermission sp ON si.SiteID = sp.SiteID
         LEFT JOIN #tmpUserSitePermission usp ON sp.SitePermission = usp.SitePermission
    WHERE f.StatusID NOT IN(11004, 11019)
          AND fs.SettingID = 3025
          AND f.FeedbackDate >= @FromDate AND f.FeedbackDate < @ToDate
          AND (si.SiteOffer = @UserRole OR si.SiteOffer IS NULL)
          AND @LicenseeType <> -1
          AND (si.IsLicensee IS NULL
               OR si.IsLicensee = CASE WHEN @LicenseeType = 0 THEN si.IsLicensee WHEN @LicenseeType = 1 THEN 0 ELSE 1 END)
          AND ((sp.SitePermission IS NULL AND ISNULL(si.IsLicensee, 1) = 1)
               OR sp.SitePermission = usp.SitePermission)
    GROUP BY MONTH( DATEADD(hour,-@TimeSpan,f.FeedbackDate)),
             f.CountryID,
             c.CountryName

    -- DROP temp tables
    DROP TABLE #tmpUserSitePermission
    DROP TABLE #tmpSite
    DROP TABLE #tmpSitePermission

END
GO