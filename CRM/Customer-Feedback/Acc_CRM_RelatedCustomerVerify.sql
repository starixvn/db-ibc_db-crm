/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE dbo.Acc_CRM_RelatedCustomerVerify @UserName     NVARCHAR(MAX) = '',
                                                  @UserRole     TINYINT       = 2,
                                                  @LicenseeType TINYINT       = 0,
                                                  @SiteLabel    VARCHAR(MAX)  = NULL
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

    Param's Explanation:
        - @LicenseeType = 0: Both
                          1: Credit
                          2: Licensee
        - @SiteLabel: Value depend on user's permission and maybe NULL

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

    -- #tmpSiteLabel
    -- + Create temp table
    CREATE TABLE #tmpSiteLabel (SiteLabel VARCHAR(50))
    -- + Gen data to temp table
    INSERT INTO #tmpSiteLabel (SiteLabel)
    SELECT value SiteLabel
    FROM STRING_SPLIT(@SiteLabel, ',')

    -- #tmpSite
    -- + Create temp table
    CREATE TABLE #tmpSite (
        SiteID     INT,
        SiteName   NVARCHAR(100),
        SiteLabel  VARCHAR(50),
        IsLicensee INT,
        IsActive   BIT
    )
    -- + Gen data that not be CN88 to temp table
    IF (@UserRole = 2)
    BEGIN
        INSERT INTO #tmpSite (
            SiteID,
            SiteName,
            SiteLabel,
            IsLicensee,
            IsActive
        )
        SELECT s.SettingID SiteID,
               s.SettingValue SiteName,
               s.ExtraInfo SiteLabel,
               CASE WHEN sr.ParentID = 33000 THEN 1
                    WHEN sr.ParentID = 33001 THEN 0
                    ELSE -1 END IsLicensee,
               s.IsActive
        FROM bodb_CRM.dbo.crmSettingRelation sr WITH (NOLOCK)
             INNER JOIN bodb_CRM.dbo.crmSetting s WITH(NOLOCK) ON sr.SettingID = s.SettingID AND s.SettingName = 'Site'
        WHERE sr.ParentID IN (33000, 33001)
    END
    -- + Gen data that be CN88 to temp table
    ELSE IF (@UserRole = 1)
    BEGIN
        INSERT INTO #tmpSite (
            SiteID,
            SiteName,
            SiteLabel,
            IsLicensee,
            IsActive
        )
        SELECT s.SettingID SiteID,
               s.SettingValue SiteName,
               s.ExtraInfo SiteLabel,
               0 IsLicensee,
               s.IsActive
        FROM bodb_CRM.dbo.crmSetting s WITH (NOLOCK)
        WHERE s.SettingID = 33002
    END
    -- + Create index for temp table
    CREATE CLUSTERED INDEX CIX_tmpSite ON #tmpSite(SiteID)

    -- #tmpCustomer
    -- + Create temp table
    CREATE TABLE #tmpCustomer (
        CustID       INT,
        UserName     VARCHAR(50),
        IsLicensee   BIT,
        IsSiteActive BIT
    )
    -- + Gen data from MainDB to temp table
    INSERT INTO #tmpCustomer (
        CustID,
        UserName,
        IsLicensee,
        isSiteActive
    )
    SELECT c.custid     CustID,
           c.username   UserName, 
           s.IsLicensee IsLicensee,
           s.isActive   isSiteActive
    FROM bodb02.dbo.Customer c WITH (NOLOCK)        
         LEFT JOIN #tmpSite s ON c.site = s.SiteName
         LEFT JOIN #tmpSiteLabel sl ON s.SiteLabel = sl.SiteLabel
    WHERE c.username IN (SELECT UserName FROM #tmpUserName)
          AND ((@UserRole = 1 AND c.site = 'CN88') OR (@UserRole = 2 AND ISNULL(c.site,'') <> 'CN88'))
          AND (s.IsLicensee IS NULL
               OR s.IsLicensee = CASE WHEN @LicenseeType = 0 THEN s.IsLicensee WHEN @LicenseeType = 1 THEN 0 ELSE 1 END)
          AND (ISNULL(s.SiteLabel, '') = CASE WHEN @LicenseeType = 0 THEN CASE WHEN s.IsLicensee = 0 THEN sl.SiteLabel ELSE ISNULL(s.SiteLabel, '') END
                                              WHEN @LicenseeType = 1 THEN sl.SiteLabel
                                              WHEN @LicenseeType = 2 THEN ISNULL(s.SiteLabel, '') END)
    -- + Gen data that be guest customer to temp table
    INSERT INTO #tmpCustomer (
        CustID,
        UserName,
        IsLicensee,
        isSiteActive
    )
    SELECT c.CustID,
           c.UserName, 
           s.IsLicensee,
           s.IsActive
    FROM bodB_CRM.dbo.crmCustomer c WITH (NOLOCK)
         LEFT JOIN #tmpSite s ON c.SiteID = s.SiteID
         LEFT JOIN #tmpSiteLabel sl ON s.SiteLabel = sl.SiteLabel
    WHERE c.CustID < 0
          AND c.UserName IN (SELECT UserName FROM #tmpUserName)
          AND ((@UserRole = 1 AND c.SiteID = 33002) OR (@UserRole = 2 AND c.SiteID <> 33002))
          AND (s.IsLicensee IS NULL
               OR s.IsLicensee = CASE WHEN @LicenseeType = 0 THEN s.IsLicensee WHEN @LicenseeType = 1 THEN 0 ELSE 1 END)
          AND (ISNULL(s.SiteLabel, '') = CASE WHEN @LicenseeType = 0 THEN CASE WHEN s.IsLicensee = 0 THEN sl.SiteLabel ELSE ISNULL(s.SiteLabel, '') END
                                              WHEN @LicenseeType = 1 THEN sl.SiteLabel
                                              WHEN @LicenseeType = 2 THEN ISNULL(s.SiteLabel, '') END)
    -- + Gen data that not exist both from MainDB and CRM to temp table
    INSERT INTO #tmpCustomer (
        CustID,
        UserName
    )
    SELECT 0 CustID,
           tmp.UserName 
    FROM #tmpUserName tmp 
    WHERE tmp.UserName NOT IN (SELECT UserName FROM #tmpCustomer)

    -- Return data
    SELECT CustID,
           UserName val,
           ISNULL(IsLicensee, 0) IsLicensee,
           ISNULL(IsSiteActive, 0) IsSiteActive
    FROM #tmpCustomer
    ORDER BY UserName

    -- DROP temp tables
    DROP TABLE #tmpUserName
    DROP TABLE #tmpSiteLabel
    DROP TABLE #tmpSite
    DROP TABLE #tmpCustomer

END
GO