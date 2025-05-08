/*<info serverAlias="DBCRM-bodb_CRM" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
USE bodb_CRM
GO

CREATE PROCEDURE [dbo].[Acc_CRM_SitePermissionSel] (
	@UserRole		TINYINT			= 2,
	@LicenseeType	INT				= 0,
	@SitePermission	NVARCHAR(MAX)	= NULL
)
AS
/*
	Created: 20250416@Virgil
	Task: CRM - Manage SMA Feedback in effective way [Redmine #196012]
	DB: DBBOT-bodb_Chatbot
	Note: Separate the permission control part into a SP

	Revisions:
		20250416@Virgil: Initial SP [Redmine #196012]

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
	SET NOCOUNT ON;

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
			CASE 
				WHEN sr.ParentID = 33000 THEN 1
				WHEN sr.ParentID = 33001 THEN 0
				ELSE -1 
			END AS IsLicensee,
			si.IsActive IsActive,
			si.ExtraInfo SiteLabel,
			sc.SiteOffer SiteOffer
    FROM dbo.crmSettingRelation sr WITH (NOLOCK)
		INNER JOIN dbo.crmSetting sc WITH (NOLOCK) 
			ON sc.SettingName	= 'SiteCategory' 
			AND sr.ParentID		= sc.SettingID
		INNER JOIN dbo.crmSetting si WITH (NOLOCK) 
			ON si.SettingName	= 'Site' 
			AND sr.SettingID	= si.SettingID
    WHERE sr.ParentID IN (33000, 33001)
    UNION ALL
    SELECT sc.SettingID SiteID,
           sc.SettingValue SiteName,
           0 IsLicensee,
           sc.IsActive IsActive,
           NULL SiteLabel,
           sc.SiteOffer SiteOffer
    FROM dbo.crmSetting sc WITH (NOLOCK)
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
    FROM dbo.crmSettingRelation sr WITH (NOLOCK)
         INNER JOIN dbo.crmSetting sp WITH (NOLOCK) ON sp.SettingName = 'SitePermission' AND sr.ParentID = sp.SettingID
         INNER JOIN dbo.crmSetting si WITH (NOLOCK) ON si.SettingName = 'Site' AND sr.SettingID = si.SettingID

    CREATE CLUSTERED INDEX CIX_tmpSitePermission ON #tmpSitePermission(SiteID)

	SELECT si.SiteID,
			si.SiteName, 
			si.IsLicensee, 
			si.IsActive, 
			si.SiteLabel, 
			si.SiteOffer
	FROM #tmpSite si
		LEFT JOIN #tmpSitePermission sp ON si.SiteID = sp.SiteID
		LEFT JOIN #tmpUserSitePermission usp ON sp.SitePermission = usp.SitePermission
	WHERE @LicenseeType <> -1
		AND
		(
			(sp.SitePermission IS NULL AND ISNULL(si.IsLicensee, 1) = 1 AND @SitePermission IS NULL)
			OR sp.SitePermission = usp.SitePermission
		)



	DROP TABLE #tmpUserSitePermission
    DROP TABLE #tmpSite
    DROP TABLE #tmpSitePermission

END