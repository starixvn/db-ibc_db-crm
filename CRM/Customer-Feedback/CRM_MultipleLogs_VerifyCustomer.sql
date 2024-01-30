/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE dbo.CRM_MultipleLogs_VerifyCustomer @Username       NVARCHAR(MAX) = '',
                                                    @UserRole       TINYINT       = 2,
                                                    @LicenseeType   INT           = 0,
                                                    @SitePermission NVARCHAR(MAX) = NULL
AS

/*
    Created: 20200303@Tim
    Task : Support "is related customers" function in Create Multiple Logs
    DB: DBCRM/bodb_CRM
    Original:

    Revisions:
        - 20200303@Tim: Support "is related customers" function in Create Multiple Logs - RedmineId: #129144
        - 20210601@Johnson: Prevent CSD create new feedback mistakenly If the licensee is terminated [redmine:#154840]
        - 20231128@Ned.Le: CRM - Security improvement - Separate accessible data for Credit Sites (#197343)

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
         INNER JOIN bodb_CRM.dbo.crmSetting si WITH (NOLOCK) ON si.SettingName = 'Site' AND sr.SettingID = si.SettingID
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

    -- #tmpDirectCustomer
    -- + Create temp table
    CREATE TABLE #tmpDirectCustomer (CustId INT PRIMARY KEY)
    -- + Gen data of super not belong to any group headline
    INSERT INTO #tmpDirectCustomer (CustId)
    SELECT c.custid
    FROM bodb02.dbo.Customer c WITH (NOLOCK)
         INNER JOIN bodb02.dbo.CustSuper cs WITH (NOLOCK) ON c.custid = cs.custid
                                                             AND cs.IsInternal = 0
                                                             AND c.roleid = 4
    WHERE EXISTS (
            SELECT 1
            FROM #tmpUserName AS tbl
            WHERE c.username = tbl.Username
            )
        AND NOT EXISTS (
            SELECT 1
            FROM bodb02.dbo.custAccount AS ca WITH (NOLOCK)
            WHERE ca.custid = c.custid AND ca.groupId <> 0
            )
        AND NOT EXISTS (
            SELECT 1
            FROM bodb02.dbo.Acc_CustDirect AS cd WITH (NOLOCK)
            WHERE cd.custid = c.custid
        )
    -- + Gen data of direct master, agent, member
    INSERT INTO #tmpDirectCustomer (CustId)
    SELECT ci.custid
    FROM bodb02.dbo.custInfo AS ci WITH (NOLOCK)
         INNER JOIN bodb02.dbo.CustDirectAccount AS d WITH (NOLOCK) ON ci.custid = d.custid
    WHERE EXISTS (
            SELECT 1
            FROM #tmpUserName AS tbl
            WHERE ci.username = tbl.Username
            )
        AND NOT EXISTS (
            SELECT 1
            FROM #tmpDirectCustomer AS tbl WITH (NOLOCK)
            WHERE ci.custid = tbl.CustId
            )
        AND NOT EXISTS (
            SELECT 1
            FROM bodb02.dbo.custAccount AS ca WITH (NOLOCK)
            WHERE ca.custid = ci.custid AND ca.groupId <> 0
            )
        AND NOT EXISTS (
            SELECT 1
            FROM bodb02.dbo.CustMaster AS cm WITH (NOLOCK)
            WHERE ci.custid = cm.custid AND cm.IsInternal = 1
            )
        AND NOT EXISTS (
            SELECT 1
            FROM bodb02.dbo.CustAgent AS ca WITH (NOLOCK)
            WHERE (ci.custid = ca.custid OR ci.recommend = ca.custid) AND ca.IsInternal = 1
            )

    -- #tmpResult
    CREATE TABLE #tmpResult (
        HeadlineId      INT,
        Headline        VARCHAR(50),
        CustId          INT,
        Username        VARCHAR(50),
        IsHeadline      BIT,
        IsDirectAccount BIT,
        Site            NVARCHAR(100)
    )

    INSERT INTO #tmpResult (
        HeadlineId,
        Headline,
        CustId,
        Username,
        IsHeadline,
        IsDirectAccount,
        Site
    )
    SELECT gh.CustId AS HeadlineId,
           gh.username AS Headline,
           c.custid,
           c.username,
           CASE WHEN gh.custid = c.custid THEN 1 ELSE 0 END IsHeadline,
           CASE WHEN da.CustId IS NOT NULL THEN 1 ELSE 0 END IsDirectAccount,
           CASE WHEN c.site = 'IBO' THEN 'Kzing'
                     WHEN c.site = 'KeenOcean' THEN 'LIVV88'
                     ELSE c.site END Site
    FROM bodb02.dbo.custAccount AS ca WITH (NOLOCK)
         INNER JOIN bodb02.dbo.Customer AS c WITH (NOLOCK) ON c.custid = ca.custid
         OUTER APPLY (
            SELECT gh.custid, ghi.username
            FROM bodb02.dbo.custAccount AS gh WITH (NOLOCK)
                INNER JOIN bodb02.dbo.Customer AS ghi WITH (NOLOCK) ON gh.custid = ghi.custid
            WHERE ca.groupId = gh.groupId AND gh.IsGroupHeadLine = 1
        ) AS gh
        LEFT JOIN #tmpDirectCustomer AS da WITH (NOLOCK) ON c.custid = da.CustId
    WHERE ISNULL(c.[site], '') <> 'CN88'
        AND EXISTS (
            SELECT 1
            FROM #tmpUserName AS tbl
            WHERE tbl.Username = c.username
            )
    UNION
    SELECT NULL AS HeadlineId,
           NULL AS Headline,
           c.custid,
           c.username,
           0 IsHeadline,
           CASE  WHEN da.CustId IS NOT NULL THEN 1 ELSE 0 END IsDirectAccount,
           CASE WHEN c.site = 'IBO' THEN 'Kzing'
                     WHEN c.site = 'KeenOcean' THEN 'LIVV88'
                     ELSE c.site END Site
    FROM bodb02.dbo.Customer AS c WITH (NOLOCK)
        LEFT JOIN #tmpDirectCustomer AS da WITH (NOLOCK) ON c.custid = da.CustId
    WHERE ISNULL(c.[site], '') <> 'CN88'
        AND EXISTS (
            SELECT 1
            FROM #tmpUserName AS tbl
            WHERE tbl.Username = c.username
            )
        AND NOT EXISTS (
            SELECT 1
            FROM bodb02.dbo.custAccount AS ca WITH (NOLOCK)
            WHERE c.custid = ca.custid
            )

    INSERT INTO #tmpResult (CustId, Username, Site)
    SELECT c.CustId, c.Username, si.SiteName
    FROM bodb_CRM.dbo.crmCustomer AS c WITH (NOLOCK)
         LEFT JOIN #tmpSite si ON c.SiteID = si.SiteID 
    WHERE c.CustId < 0
        AND c.SiteId <> 33002
        AND EXISTS (
            SELECT 1
            FROM #tmpUserName AS tbl
            WHERE tbl.Username = c.Username
            )

    INSERT INTO #tmpResult (CustId, Username)
    SELECT 0, c.Username
    FROM #tmpUserName AS c
    WHERE NOT EXISTS (
            SELECT 1
            FROM #tmpResult AS tbl WITH (NOLOCK)
            WHERE tbl.Username = c.Username
            )
    
    IF EXISTS(SELECT 1 FROM #tmpUserName WHERE username IN ('ETUS'))
    BEGIN
        UPDATE t
        SET IsHeadline = 0
        FROM #tmpResult t
        WHERE username IN ('ETUS')
    END    
       
    IF EXISTS(SELECT 1 FROM #tmpUserName WHERE username IN ('ET789','ET889','XT'))
    BEGIN
        UPDATE t
        SET HeadlineID = custid,
            Headline = 'ETUS('+ username +')',
            IsHeadline = 1
        FROM #tmpResult     t
        WHERE username IN ('ET789','ET889','XT')
    END    

    -- Return result
    ;WITH
    CTE_Username_NotExist AS (
        SELECT NULL HeadlineId,
               NULL Headline,
               0 CustId,
               t.Username,
               NULL IsHeadline,
               NULL IsDirectAccount,
               NULL IsLicensee,
               NULL IsSiteActive,
               NULL IsAuthorized
        FROM #tmpUserName t
        WHERE t.Username NOT IN (SELECT Username FROM #tmpResult)
    ),
    CTE_Username_HavePermission AS (
        SELECT t.HeadlineId,
               t.Headline,
               t.CustId,
               t.Username,
               t.IsHeadline,
               t.IsDirectAccount,
               si.IsLicensee,
               si.IsActive IsSiteActive,
               1 IsAuthorized
        FROM #tmpResult t WITH (NOLOCK)
             LEFT JOIN #tmpSite si ON t.Site = si.SiteName
             LEFT JOIN #tmpSitePermission sp ON si.SiteID = sp.SiteID
             LEFT JOIN #tmpUserSitePermission usp ON sp.SitePermission = usp.SitePermission
        WHERE @LicenseeType <> -1
              AND (si.IsLicensee IS NULL
                   OR si.IsLicensee = CASE WHEN @LicenseeType = 0 THEN si.IsLicensee WHEN @LicenseeType = 1 THEN 0 ELSE 1 END)
              AND ((sp.SitePermission IS NULL AND ISNULL(si.IsLicensee, 1) = 1)
                   OR sp.SitePermission = usp.SitePermission)
    ),
    CTE_Username_NoPermission AS (
        SELECT t.HeadlineId,
               t.Headline,
               t.CustId,
               t.Username,
               t.IsHeadline,
               t.IsDirectAccount,
               si.IsLicensee,
               si.IsActive IsSiteActive,
               0 IsAuthorized
        FROM #tmpResult t WITH (NOLOCK)
             LEFT JOIN #tmpSite si ON t.Site = si.SiteName
        WHERE t.Username NOT IN (SELECT Username FROM CTE_Username_HavePermission)
    ),
    CTE_UnionData AS (
        SELECT HeadlineId, Headline, CustId, Username, IsHeadline, IsDirectAccount, IsLicensee, IsSiteActive, IsAuthorized FROM CTE_Username_NotExist
        UNION ALL
        SELECT HeadlineId, Headline, CustId, Username, IsHeadline, IsDirectAccount, IsLicensee, IsSiteActive, IsAuthorized FROM CTE_Username_HavePermission
        UNION ALL
        SELECT HeadlineId, Headline, CustId, Username, IsHeadline, IsDirectAccount, IsLicensee, IsSiteActive, IsAuthorized FROM CTE_Username_NoPermission
    )
    SELECT HeadlineId, Headline, CustId, Username, IsHeadline, IsDirectAccount, IsLicensee, IsSiteActive, IsAuthorized
    FROM CTE_UnionData
    ORDER BY Username

    -- Drop temp table
    DROP TABLE #tmpUserName
    DROP TABLE #tmpUserSitePermission
    DROP TABLE #tmpSite
    DROP TABLE #tmpSitePermission
    DROP TABLE #tmpDirectCustomer
    DROP TABLE #tmpResult
END
GO