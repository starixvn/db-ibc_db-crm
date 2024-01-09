/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE dbo.Acc_CRM_CustomerRemarkNewCheck @Username       NVARCHAR(50)  = NULL,
                                                   @IsGuest        BIT           = 0,
                                                   @UserRole       TINYINT       = 2,
                                                   @LicenseeType   TINYINT       = 0,
                                                   @SitePermission NVARCHAR(MAX) = NULL
AS

/*
    Created: 20220325@Winfred
    Task : CRM - insert special remarks renovation into CRM
    DB: DBCRM/bodb_CRM
    Original:

    Revisions:
        - 20220325@Winfred: CRM - insert special remarks renovation [RedmineId : #167941]
    
    Parameter's Explanation:
        @username: the search term.
        @IsGuest: search by real customer or guest
        @UserRole = 0 : Manager 
                    1 : CN88 staff
                    2 : Company staff
        @LicenseeType = 0: Both
                        1: Credit
                        2: Licensee
        @SitePermission: Value depend on user's permission and maybe NULL
*/

BEGIN

    SET NOCOUNT ON

    -- #tmpUserName
    -- + Create temp table
    CREATE TABLE #tmpUserName (UserName VARCHAR(50))
    -- + Gen data to temp table
    INSERT INTO #tmpUserName (UserName)
    SELECT value UserName
    FROM STRING_SPLIT(@Username,',')
    WHERE value <> ''

    -- #tmpUserSitePermission
    -- + Create temp table
    CREATE TABLE #tmpUserSitePermission (SitePermission NVARCHAR(100))
    -- + Gen data to temp table
    INSERT INTO #tmpUserSitePermission (SitePermission)
    SELECT value SitePermission
    FROM STRING_SPLIT(@SitePermission, ',')

    -- #tmpSite
    -- + Create temp table
    CREATE TABLE #tmpSite (
        SiteID     INT,
        SiteName   NVARCHAR(100),
        IsLicensee INT,
        IsActive   BIT,
        SiteLabel  VARCHAR(50),
        SiteOffer  INT
    )
    -- + Gen data to temp table
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
    -- + Create index for temp table
    CREATE CLUSTERED INDEX CIX_tmpSite ON #tmpSite(SiteID)

    -- #tmpSitePermission
    -- + Create temp table
    CREATE TABLE #tmpSitePermission (
        SiteID         INT,
        SiteName       NVARCHAR(100),
        SitePermission NVARCHAR(100)
    )
    -- + Gen data to temp table
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
    -- + Create index for temp table
    CREATE CLUSTERED INDEX CIX_tmpSitePermission ON #tmpSitePermission(SiteID)

    -- #tmpCustomer
    -- + Create temp table
    CREATE TABLE #tmpCustomer (
        CustID         INT,
        UserName       VARCHAR(50),
        SitePermission NVARCHAR(100),
        IsCredit       BIT,
        IsAuthorized   BIT
    )    
    -- + Gen data from MainDB to temp table
    INSERT INTO #tmpCustomer (
        CustID,
        UserName,
        SitePermission,
        IsCredit,
        IsAuthorized
    )
    SELECT c.custid CustID,
           c.username UserName,
           sp.SitePermission,
           CASE WHEN si.IsLicensee = 1 THEN 0 ELSE 1 END IsCredit,
           NULL IsAuthorized
    FROM bodb02.dbo.Customer c WITH (NOLOCK)
         LEFT JOIN #tmpSite si ON c.site = si.SiteName
         LEFT JOIN #tmpSitePermission sp ON si.SiteID = sp.SiteID
    WHERE c.username IN (SELECT UserName FROM #tmpUserName)
          AND @IsGuest = 0
          AND (si.SiteOffer = @UserRole OR si.SiteOffer IS NULL)
    -- + Gen data that not be guest customer from CRM to temp table
    INSERT INTO #tmpCustomer (
        CustID,
        UserName,
        SitePermission,
        IsCredit,
        IsAuthorized
    )
    SELECT c.CustID,
           c.UserName,
           sp.SitePermission,
           CASE WHEN si.IsLicensee = 1 THEN 0 ELSE 1 END IsCredit,
           NULL IsAuthorized
    FROM bodb_CRM.dbo.crmCustomer c WITH (NOLOCK)      
         LEFT JOIN #tmpSite si ON c.SiteID = si.SiteID
         LEFT JOIN #tmpSitePermission sp ON si.SiteID = sp.SiteID
    WHERE c.UserName IN (SELECT UserName FROM #tmpUserName)
          AND @IsGuest = 0
          AND (si.SiteOffer = @UserRole OR si.SiteOffer IS NULL)
          AND c.CustID > 0
          AND c.CustID NOT IN (SELECT CustID FROM #tmpCustomer)
    -- + Gen data that be guest customer from CRM to temp table
    INSERT INTO #tmpCustomer (
        CustID,
        UserName,
        SitePermission,
        IsCredit,
        IsAuthorized
    )
    SELECT c.CustID,
           c.UserName,
           sp.SitePermission,
           CASE WHEN si.IsLicensee = 1 THEN 0 ELSE 1 END IsCredit,
           NULL IsAuthorized
    FROM bodb_CRM.dbo.crmCustomer c WITH (NOLOCK) 
         LEFT JOIN #tmpSite si ON c.SiteID = si.SiteID
         LEFT JOIN #tmpSitePermission sp ON si.SiteID = sp.SiteID
    WHERE c.UserName IN (SELECT UserName FROM #tmpUserName)
          AND @IsGuest = 1
          AND (si.SiteOffer = @UserRole OR si.SiteOffer IS NULL)
          AND c.CustID < 0
          AND c.CustID NOT IN (SELECT CustID FROM #tmpCustomer)
    -- + Gen data that not exist both from MainDB and CRM to temp table
    INSERT INTO #tmpCustomer (
        CustID,
        UserName,
        SitePermission,
        IsCredit,
        IsAuthorized
    )
    SELECT 0 CustID,
           tmp.UserName,
           NULL SitePermission,
           NULL IsCredit,
           NULL IsAuthorized
    FROM #tmpUserName tmp 
    WHERE tmp.UserName NOT IN (SELECT UserName FROM #tmpCustomer)
    -- + Update data for column IsAuthorized
    -- + --> IsAuthorized=1
    UPDATE c
    SET c.IsAuthorized = 1
    FROM #tmpCustomer c
         LEFT JOIN #tmpUserSitePermission usp ON c.SitePermission = usp.SitePermission
    WHERE c.CustID <> 0
          AND
          (
              c.IsCredit IS NULL
              OR c.IsCredit = CASE WHEN @LicenseeType = 0 THEN c.IsCredit WHEN @LicenseeType = 1 THEN 1 ELSE 0 END
          )
          AND
          (
              c.SitePermission IS NULL
              OR c.SitePermission = usp.SitePermission
          )
    -- + --> IsAuthorized=0
    UPDATE c
    SET c.IsAuthorized = 0
    FROM #tmpCustomer c
    WHERE c.CustID <> 0
          AND c.IsAuthorized IS NULL

    -- Return data
    SELECT CustID,
           UserName val,
           IsCredit,
           IsAuthorized
    FROM #tmpCustomer
    ORDER BY UserName

    -- DROP temp tables
    DROP TABLE #tmpUserName
    DROP TABLE #tmpUserSitePermission
    DROP TABLE #tmpSite
    DROP TABLE #tmpSitePermission
    DROP TABLE #tmpCustomer
END    