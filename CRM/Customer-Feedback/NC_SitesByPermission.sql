/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE dbo.NC_SitesByPermission @UserRole       TINYINT       = 2,
                                         @LicenseeType   INT           = 0,
                                         @SitePermission NVARCHAR(MAX) = NULL
AS

/*
    Created: 20231128@Ned.Le
    Task:    Get list of sites by permission for NC system
    DB:      DBCRM/bodb_CRM

    Revisions:
        20231128@Ned.Le: CRM - Security improvement - Separate accessible data for Credit Sites (#197343)

    Param's Explanation:
        @UserRole = 1: CN88
                    2: The rest
        @LicenseeType = -1: None
                         0: Both
                         1: Credit
                         2: Licensee
        @SitePermission: Value depend on user's permission and maybe NULL

    Example:
        EXEC bodb_CRM.dbo.NC_SitesByPermission @UserRole       = 2,
                                               @LicenseeType   = 1,
                                               @SitePermission = '789y,MBC'
*/

BEGIN

    SET NOCOUNT ON


    ------------------
    -- Prepare data --

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


    -----------------
    -- Return data --

    -- Create temp table
    CREATE TABLE #tmpListSiteName (SiteName NVARCHAR(100))

    -- Gen data to temp table
    INSERT INTO #tmpListSiteName (SiteName)
    SELECT si.SiteName
    FROM #tmpSite si
         LEFT JOIN #tmpSitePermission sp ON si.SiteID = sp.SiteID
         LEFT JOIN #tmpUserSitePermission usp ON sp.SitePermission = sp.SitePermission
    WHERE si.SiteOffer = @UserRole
          AND @LicenseeType <> -1
          AND si.IsLicensee = CASE WHEN 1 = 0 THEN si.IsLicensee WHEN 1 = 1 THEN 0 ELSE 1 END
          AND (ISNULL(sp.SitePermission, '') = CASE WHEN 2 = 1 THEN ISNULL(sp.SitePermission, '')
                                                    WHEN 1 = 0 THEN CASE WHEN si.IsLicensee = 0 THEN usp.SitePermission ELSE ISNULL(sp.SitePermission, '') END
                                                    WHEN 1 = 1 THEN usp.SitePermission
                                                    WHEN 1 = 2 THEN ISNULL(sp.SitePermission, '') END)

    -- Return data
    IF EXISTS (SELECT 1 FROM #tmpListSiteName)
    BEGIN
        SELECT STRING_AGG(CAST(SiteName AS NVARCHAR(MAX)), ',') ListSiteName FROM #tmpListSiteName
    END
    ELSE
    BEGIN
        SELECT SiteName FROM #tmpListSiteName
    END


    ---------------
    -- Drop data --

    DROP TABLE #tmpUserSitePermission
    DROP TABLE #tmpSite
    DROP TABLE #tmpSitePermission

END
GO