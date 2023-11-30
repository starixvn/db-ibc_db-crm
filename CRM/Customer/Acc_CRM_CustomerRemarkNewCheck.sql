/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE dbo.Acc_CRM_CustomerRemarkNewCheck @Username     NVARCHAR(50) = NULL,
                                                   @IsGuest      BIT          = 0,
                                                   @UserRole     TINYINT      = 2,
                                                   @LicenseeType TINYINT      = 0,
                                                   @SiteLabel    VARCHAR(MAX) = NULL
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
        @SiteLabel: Value depend on user's permission and maybe NULL
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

    -- #tmpSiteLabel
    -- + Create temp table
    CREATE TABLE #tmpSiteLabel (SiteLabel VARCHAR(50))
    -- + Gen data to temp table
    INSERT INTO #tmpSiteLabel (SiteLabel)
    SELECT value SiteLabel
    FROM STRING_SPLIT(@SiteLabel, ',')
    WHERE value <> ''

    -- #tmpSite
    -- + Create temp table
    CREATE TABLE #tmpSite (
        SiteID     INT,
        SiteName   NVARCHAR(100),
        SiteLabel  VARCHAR(50),
        IsLicensee INT
    )
    -- + Gen data that not be CN88 to temp table
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
            IsLicensee
        )
        SELECT s.SettingID SiteID,
               s.SettingValue SiteName,
               s.ExtraInfo SiteLabel,
               0 IsLicensee
        FROM bodb_CRM.dbo.crmSetting s WITH (NOLOCK)
        WHERE s.SettingID = 33002
    END
    -- + Create index for temp table
    CREATE CLUSTERED INDEX CIX_tmpSite ON #tmpSite(SiteID)

    -- #tmpCustomer
    -- + Create temp table
    CREATE TABLE #tmpCustomer (
        CustID   INT,
        UserName VARCHAR(50),
        IsCredit BIT
    )    
    -- + Gen data from MainDB to temp table
    INSERT INTO #tmpCustomer (
        CustID,
        UserName,
        IsCredit
    )
    SELECT c.custid CustID,
           c.username UserName,
           CASE WHEN s.IsLicensee = 1 THEN 0 ELSE 1 END IsCredit
    FROM bodb02.dbo.Customer c WITH (NOLOCK)
         LEFT JOIN #tmpSite s ON c.site = s.SiteName
         LEFT JOIN #tmpSiteLabel sl ON s.SiteLabel = sl.SiteLabel
    WHERE c.username IN (SELECT UserName FROM #tmpUserName)
          AND @IsGuest = 0
          AND ((@UserRole = 1 AND c.site = 'CN88') OR (@UserRole = 2 AND ISNULL(c.site,'') <> 'CN88'))
          AND (s.IsLicensee IS NULL
               OR s.IsLicensee = CASE WHEN @LicenseeType = 0 THEN s.IsLicensee WHEN @LicenseeType = 1 THEN 0 ELSE 1 END)
          AND (ISNULL(s.SiteLabel, '') = CASE WHEN @LicenseeType = 0 THEN CASE WHEN s.IsLicensee = 0 THEN sl.SiteLabel ELSE ISNULL(s.SiteLabel, '') END
                                              WHEN @LicenseeType = 1 THEN sl.SiteLabel
                                              WHEN @LicenseeType = 2 THEN ISNULL(s.SiteLabel, '') END)
    -- + Gen data that not be guest customer from CRM to temp table
    INSERT INTO #tmpCustomer (
        CustID,
        UserName,
        IsCredit
    )
    SELECT c.CustID,
           c.UserName,
           CASE WHEN s.IsLicensee = 1 THEN 0 ELSE 1 END IsCredit
    FROM bodb_CRM.dbo.crmCustomer c WITH (NOLOCK)      
         LEFT JOIN #tmpSite s ON c.SiteID = s.SiteID
         LEFT JOIN #tmpSiteLabel sl ON s.SiteLabel = sl.SiteLabel
    WHERE c.UserName IN (SELECT UserName FROM #tmpUserName)
          AND @IsGuest = 0
          AND ((@UserRole=1 AND c.SiteID = 33002) OR (@UserRole=2 AND c.SiteID <> 33002))
          AND c.CustID > 0
          AND c.CustID NOT IN (SELECT CustID FROM #tmpCustomer)
          AND (s.IsLicensee IS NULL
               OR s.IsLicensee = CASE WHEN @LicenseeType = 0 THEN s.IsLicensee WHEN @LicenseeType = 1 THEN 0 ELSE 1 END)
          AND (ISNULL(s.SiteLabel, '') = CASE WHEN @LicenseeType = 0 THEN CASE WHEN s.IsLicensee = 0 THEN sl.SiteLabel ELSE ISNULL(s.SiteLabel, '') END
                                              WHEN @LicenseeType = 1 THEN sl.SiteLabel
                                              WHEN @LicenseeType = 2 THEN ISNULL(s.SiteLabel, '') END)
    -- + Gen data that be guest customer from CRM to temp table
    INSERT INTO #tmpCustomer (
        CustID,
        UserName,
        IsCredit
    )
    SELECT c.CustID,
           c.UserName,
           CASE WHEN s.IsLicensee = 1 THEN 0 ELSE 1 END IsCredit
    FROM bodb_CRM.dbo.crmCustomer c WITH (NOLOCK) 
         LEFT JOIN #tmpSite s ON c.SiteID = s.SiteID
         LEFT JOIN #tmpSiteLabel sl ON s.SiteLabel = sl.SiteLabel
    WHERE c.UserName IN (SELECT UserName FROM #tmpUserName)
          AND @IsGuest = 1
          AND ((@UserRole = 1 AND c.SiteID = 33002) OR (@UserRole = 2 AND c.SiteID <> 33002))
          AND c.CustID < 0
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
           ISNULL(IsCredit,0) IsCredit
    FROM #tmpCustomer
    ORDER BY UserName 

    -- DROP temp tables
    DROP TABLE #tmpUserName
    DROP TABLE #tmpSiteLabel
    DROP TABLE #tmpSite
    DROP TABLE #tmpCustomer
END    