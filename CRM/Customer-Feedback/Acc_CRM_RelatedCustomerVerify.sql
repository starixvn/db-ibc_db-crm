/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE dbo.Acc_CRM_RelatedCustomerVerify @UserName       NVARCHAR(MAX)  = '',
                                                  @UserRole       TINYINT        = 2,
                                                  @LicenseeType   INT            = 0,
                                                  @SitePermission NVARCHAR(MAX)  = NULL
AS

/*
    Created: Lukas
    Date: 20110629
    Task : verify list of related customer
    DB: DBCRM/bodb_CRM
    Original:

    Revisions:
        - 20120131@Lukas: verify guest user
        - 20120405@Elodie: return 2 CustID if username is real customer as well as guest
        - 20120409@Elodie: return username and custid = 0 if customer doesn't exist
        - 20121115@Lukas: change the query to use index on DB06
        - 20130121@Johnson: change linked server DB06 to DBACC
        - 20180305@Winnie: Support long list of "Verify related customer" RedmineID: #91469
        - 20190506@Winnie:  CN88 Permission - [RedmineID: #112637]
        - 20190701@Elodie: Offer for CN88 - [RedmineID: #112637]
        - 20190905@Winnie: CRM - Left panel did not show Super, Master, Agent  [RedmineId: #119708]
        - 20210528@Johnson: get site status for list related customers [Redmine: #154840]
        - 20231128@Ned.Le: CRM - Security improvement - Separate accessible data for Credit Sites (#197343)
        - 20240305@Ned.Le: [CRM] Create feedback and related 1 user but show 2 same user (HotFix #201863)

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

    -- #tmpUserName
    -- + Create temp table
    CREATE TABLE #tmpUserName (UserName VARCHAR(50))
    -- + Gen data to temp table
    INSERT INTO #tmpUserName (UserName)
    SELECT ltrim(rtrim(value)) UserName
    FROM STRING_SPLIT(@UserName, ',')

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
    FROM bodb_CRM.dbo.crmSetting sc WITH (NOLOCK)
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
        IsLicensee     BIT,
        IsSiteActive   BIT,
        IsAuthorized   BIT
    )
    -- + Gen data from MainDB to temp table
    INSERT INTO #tmpCustomer (
        CustID,
        UserName,
        SitePermission,
        IsLicensee,
        IsSiteActive,
        IsAuthorized
    )
    SELECT c.custid          CustID,
           c.username        UserName,
           sp.SitePermission SitePermission,
           si.IsLicensee     IsLicensee,
           si.IsActive       IsSiteActive,
           NULL              IsAuthorized
    FROM bodb02.dbo.Customer c WITH (NOLOCK)
         LEFT JOIN #tmpSite si ON CASE WHEN c.site = 'IBO' THEN 'Kzing'
                                       WHEN c.site = 'KeenOcean' THEN 'LIVV88'
                                       ELSE c.site END = si.SiteName
         LEFT JOIN #tmpSitePermission sp ON si.SiteID = sp.SiteID
    WHERE c.username IN (SELECT UserName FROM #tmpUserName)
          AND (si.SiteOffer = @UserRole OR si.SiteOffer IS NULL)
    -- + Gen data from CRM to temp table
    INSERT INTO #tmpCustomer (
        CustID,
        UserName,
        SitePermission,
        IsLicensee,
        IsSiteActive,
        IsAuthorized
    )
    SELECT c.CustID          CustID,
           c.UserName        UserName,
           sp.SitePermission SitePermission,
           si.IsLicensee     IsLicensee,
           si.IsActive       IsSiteActive,
           NULL              IsAuthorized
    FROM bodB_CRM.dbo.crmCustomer c WITH (NOLOCK)
         LEFT JOIN #tmpSite si ON c.SiteID = si.SiteID
         LEFT JOIN #tmpSitePermission sp ON si.SiteID = sp.SiteID
    WHERE c.UserName IN (SELECT UserName FROM #tmpUserName)
          AND (si.SiteOffer = @UserRole OR si.SiteOffer IS NULL)
          AND c.CustID NOT IN (SELECT CustID FROM #tmpCustomer)
          AND c.CustID < 0 --just get guest account and not get archived account
    -- + Gen data that not exist either from MainDB and CRM to temp table
    INSERT INTO #tmpCustomer (
        CustID,
        UserName,
        SitePermission,
        IsLicensee,
        IsSiteActive,
        IsAuthorized
    )
    SELECT 0            CustID,
           tmp.UserName UserName,
           NULL         SitePermission,
           NULL         IsLicensee,
           NULL         IsSiteActive,
           NULL         IsAuthorized
    FROM #tmpUserName tmp 
    WHERE tmp.UserName NOT IN (SELECT UserName FROM #tmpCustomer)
    -- + Update data for column IsAuthorized
    -- + --> IsAuthorized=1
    UPDATE c
    SET c.IsAuthorized = 1
    FROM #tmpCustomer c
         LEFT JOIN #tmpUserSitePermission usp ON c.SitePermission = usp.SitePermission
    WHERE c.CustID <> 0
          AND @LicenseeType <> -1
          AND (c.IsLicensee IS NULL
               OR c.IsLicensee = CASE WHEN @LicenseeType = 0 THEN c.IsLicensee WHEN @LicenseeType = 1 THEN 0 ELSE 1 END)
          AND ((c.SitePermission IS NULL AND ISNULL(c.IsLicensee, 1) = 1)
               OR c.SitePermission = usp.SitePermission)
    -- + --> IsAuthorized=0
    UPDATE c
    SET c.IsAuthorized = 0
    FROM #tmpCustomer c
    WHERE c.CustID <> 0
          AND c.IsAuthorized IS NULL

    -- Return data
    SELECT CustID,
           UserName val,
           IsLicensee,
           IsSiteActive,
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
GO