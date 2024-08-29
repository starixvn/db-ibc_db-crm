/*<info serverAlias="DBCRM-bodb_CRM" executers="wsv_nap" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE dbo.Acc_CRM_Rpt_FeedbackStatistics @Type           INT,
                                                   @FromDate       DATETIME,
                                                   @ToDate         DATETIME,
                                                   @FromDuration   VARCHAR(100),
                                                   @ToDuration     VARCHAR(100),
                                                   @UserRole       TINYINT       = 2,
                                                   @LicenseeType   INT           = 0,
                                                   @SitePermission NVARCHAR(MAX) = NULL
AS

/*
    Created: Lukas
    Date:    20101116
    Task:    feedback statistics report
    DB:      DBCRM.bodb_CRM

    Revisions:
        20110818@Kevin:  add new filter: Communication
        20110622@Kevin:  add new filter: Status, Response, Product, Category
        20110628@Lukas:  add filter Licensee & remove licensees from 'site' filter
        20111011@Lukas:  Add filter duration
        20120425@Sophia: remove converting @FromDate, @Todate
        20120103@Lukas:  exclude Pending feedback (statusID = 11001)
        20140523@Dom:    modify site condition
        20180420@Winnie: FB Statistics report - There is no data when filter By Site RedmineID:#94047
        20171225@Winnie: Change for support multiple product/categories. [RedmineID: #84714]
        20190506@Winnie: CN88 Permission RedmineID: #112637
        20231128@Ned.Le: CRM - Security improvement - Separate accessible data for Credit Sites (#197343)
        20240130@Ned.Le: Fix bug at dynamic query
        20240829@Ned.Le: CRM - When clicking Latest Feedback not found the feedback Due to permission limitations for account P5S (#210055)

    Param's Explanation:
        @Type = 1:  By Creator
                2:  By Country
                3:  By Role
                4:  By Site
                5:  By Status
                6:  By Customer Response
                7:  By Product
                8:  By Category
                9:  By Licensee
                10: By Communication Tool
        @UserRole = 0: Manager
                    1: CN88 staff
                    2: Company staff
        @LicenseeType = -1: None
                         0: Both
                         1: Credit
                         2: Licensee
        @SitePermission: Value depend on user's permission and maybe NULL

    Example:
        EXEC bodb_CRM.dbo.Acc_CRM_Rpt_FeedbackStatistics @Type           = 1,
                                                         @FromDate       = '2023-01-01 12:00:00',
                                                         @ToDate         = '2023-01-31 12:00:00',
                                                         @FromDuration   = '0:0:0:0',
                                                         @ToDuration     = '0:0:0:0',
                                                         @UserRole       = 2,
                                                         @LicenseeType   = 0,
                                                         @SitePermission = '789y,MBC,IBC'
*/

BEGIN

    SET NOCOUNT ON


    ---------------------
    -- Deal with duration

    DECLARE @tmp TABLE (ID INT IDENTITY PRIMARY KEY, val INT)
    INSERT INTO @tmp(val) SELECT CONVERT(INT, val) FROM dbo.f_split(@FromDuration,':')
    INSERT INTO @tmp(val) SELECT CONVERT(INT, val) FROM dbo.f_split(@ToDuration,':')

    DECLARE @fDuration INT,
            @tDuration INT
    SELECT @fDuration = SUM(CASE WHEN ID = 1 THEN val*24*60*60 
                                 WHEN ID = 2 THEN val*60*60 
                                 WHEN ID = 3 THEN val*60 
                                 WHEN ID = 4 THEN val
                                 ELSE 0 END),
           @tDuration = SUM(CASE WHEN ID = 5 THEN val*24*60*60 
                                 WHEN ID = 6 THEN val*60*60 
                                 WHEN ID = 7 THEN val*60 
                                 WHEN ID = 8 THEN val
                                 ELSE 0 END)
    FROM @tmp

    IF (@fDuration = 0 AND @tDuration = 0)
    BEGIN
        SET @tDuration = 2100000000
    END


    -----------------------
    -- Deal with permission

    -- #tmpUserSitePermission
    CREATE TABLE #tmpUserSitePermission (SitePermission NVARCHAR(100))
    INSERT INTO  #tmpUserSitePermission (SitePermission)
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


    ---------------
    -- Process data

    -- Create temp table
    CREATE TABLE #tmpFeedbackData (
        FeedbackID     INT,
        MainCategoryID INT,
        MainCategory   NVARCHAR(1000),
        SubCategoryID  INT,
        SubCategory    NVARCHAR(1000),
        ShowColumnID   INT,
        ShowColumnName NVARCHAR(1000)
    )

    -- @Type=1 - By Creator
    IF (@Type = 1 AND @UserRole = 2)
    BEGIN
        INSERT INTO #tmpFeedbackData (
            FeedbackID,
            MainCategoryID,
            MainCategory,
            SubCategoryID,
            SubCategory,
            ShowColumnID,
            ShowColumnName
        )
        SELECT DISTINCT fb.FeedbackID   FeedbackID, 
                        fs.SettingID    MainCategoryID,
                        m.SettingValue  MainCategory, 
                        fs.SubSettingID SubCategoryID,
                        s.SettingValue  SubCategory,
                        c.custid        ShowColumnID,
                        c.username      ShowColumnName
        FROM bodb_CRM.dbo.crmFeedback fb WITH (NOLOCK) 
             INNER JOIN bodb_CRM.dbo.crmFeedbackSetting fs WITH (NOLOCK) ON fb.FeedbackID = fs.FeedbackID    
             INNER JOIN bodb_CRM.dbo.crmSetting m WITH (NOLOCK) ON fs.SettingID = m.SettingID AND m.SettingName = 'MainCategory' AND m.siteOffer = 2
             INNER JOIN bodb_CRM.dbo.crmSetting s WITH (NOLOCK) ON fs.SubSettingID = s.SettingID AND s.SettingName = 'SubCategory' AND s.siteOffer = 2
             LEFT JOIN bodb02.dbo.customer c WITH (NOLOCK) ON fb.CreatorID = c.CustID
             LEFT JOIN #tmpSite si ON fb.SiteID = si.SiteID
             LEFT JOIN #tmpSitePermission sp ON si.SiteID = sp.SiteID
             LEFT JOIN #tmpUserSitePermission usp ON sp.SitePermission = usp.SitePermission
        WHERE fb.FeedbackDate BETWEEN @FromDate AND @ToDate
              AND fb.StatusID NOT IN (11001, 11004, 11019, 11016)
              AND DATEDIFF(s,FeedbackDate, ResolutionDate) >= @fDuration
              AND DATEDIFF(s,FeedbackDate, ResolutionDate) <= @tDuration
              AND (si.SiteOffer = @UserRole OR si.SiteOffer IS NULL)
              AND @LicenseeType <> -1
              AND (si.IsLicensee IS NULL
                   OR si.IsLicensee = CASE WHEN @LicenseeType = 0 THEN si.IsLicensee WHEN @LicenseeType = 1 THEN 0 ELSE 1 END)
              AND ((sp.SitePermission IS NULL AND ISNULL(si.IsLicensee, 1) = 1)
                   OR sp.SitePermission = usp.SitePermission)
    END

    -- @Type=2 - By Country
    IF (@Type = 2 AND @UserRole = 2)
    BEGIN
        INSERT INTO #tmpFeedbackData (
            FeedbackID,
            MainCategoryID,
            MainCategory,
            SubCategoryID,
            SubCategory,
            ShowColumnID,
            ShowColumnName
        )
        SELECT DISTINCT fb.FeedbackID                 FeedbackID, 
                        fs.SettingID                  MainCategoryID,
                        m.SettingValue                MainCategory, 
                        fs.SubSettingID               SubCategoryID,
                        s.SettingValue                SubCategory,
                        ISNULL(ct.CountryID, 0)       ShowColumnID,
                        ISNULL(ct.CountryName, 'N/A') ShowColumnName
        FROM bodb_CRM.dbo.crmFeedback fb WITH (NOLOCK) 
             INNER JOIN bodb_CRM.dbo.crmFeedbackSetting fs WITH (NOLOCK) ON fb.FeedbackID = fs.FeedbackID    
             INNER JOIN bodb_CRM.dbo.crmSetting m WITH (NOLOCK) ON fs.SettingID = m.SettingID AND m.SettingName = 'MainCategory' AND m.siteOffer = 2
             INNER JOIN bodb_CRM.dbo.crmSetting s WITH (NOLOCK) ON fs.SubSettingID = s.SettingID AND s.SettingName = 'SubCategory' AND s.siteOffer = 2
             LEFT JOIN bodb_CRM.dbo.crmCountry ct WITH(NOLOCK) ON fb.CountryId = ct.CountryID
             LEFT JOIN #tmpSite si ON fb.SiteID = si.SiteID
             LEFT JOIN #tmpSitePermission sp ON si.SiteID = sp.SiteID
             LEFT JOIN #tmpUserSitePermission usp ON sp.SitePermission = usp.SitePermission
        WHERE fb.FeedbackDate BETWEEN @FromDate AND @ToDate
              AND fb.StatusID NOT IN (11001, 11004, 11019, 11016)
              AND DATEDIFF(s,FeedbackDate, ResolutionDate) >= @fDuration
              AND DATEDIFF(s,FeedbackDate, ResolutionDate) <= @tDuration
              AND (si.SiteOffer = @UserRole OR si.SiteOffer IS NULL)
              AND @LicenseeType <> -1
              AND (si.IsLicensee IS NULL
                   OR si.IsLicensee = CASE WHEN @LicenseeType = 0 THEN si.IsLicensee WHEN @LicenseeType = 1 THEN 0 ELSE 1 END)
              AND ((sp.SitePermission IS NULL AND ISNULL(si.IsLicensee, 1) = 1)
                   OR sp.SitePermission = usp.SitePermission)
    END

    -- @Type=3 - By Role
    IF (@Type = 3 AND @UserRole = 2)
    BEGIN
        INSERT INTO #tmpFeedbackData (
            FeedbackID,
            MainCategoryID,
            MainCategory,
            SubCategoryID,
            SubCategory,
            ShowColumnID,
            ShowColumnName
        )
        SELECT DISTINCT fb.FeedbackID   FeedbackID, 
                        fs.SettingID    MainCategoryID,
                        m.SettingValue  MainCategory, 
                        fs.SubSettingID SubCategoryID,
                        s.SettingValue  SubCategory,
                        r.SettingID     ShowColumnID,
                        r.SettingValue  ShowColumnName
        FROM bodb_CRM.dbo.crmFeedback fb WITH (NOLOCK) 
             INNER JOIN bodb_CRM.dbo.crmFeedbackSetting fs WITH (NOLOCK) ON fb.FeedbackID = fs.FeedbackID    
             INNER JOIN bodb_CRM.dbo.crmSetting m WITH (NOLOCK) ON fs.SettingID = m.SettingID AND m.SettingName = 'MainCategory' AND m.siteOffer = 2
             INNER JOIN bodb_CRM.dbo.crmSetting s WITH (NOLOCK) ON fs.SubSettingID = s.SettingID AND s.SettingName = 'SubCategory' AND s.siteOffer = 2
             LEFT JOIN bodb_CRM.dbo.crmSetting r WITH (NOLOCK) ON fb.RoleID = r.SettingID
             LEFT JOIN #tmpSite si ON fb.SiteID = si.SiteID
             LEFT JOIN #tmpSitePermission sp ON si.SiteID = sp.SiteID
             LEFT JOIN #tmpUserSitePermission usp ON sp.SitePermission = usp.SitePermission
        WHERE fb.FeedbackDate BETWEEN @FromDate AND @ToDate
              AND fb.StatusID NOT IN (11001, 11004, 11019, 11016)
              AND DATEDIFF(s,FeedbackDate, ResolutionDate) >= @fDuration
              AND DATEDIFF(s,FeedbackDate, ResolutionDate) <= @tDuration
              AND (si.SiteOffer = @UserRole OR si.SiteOffer IS NULL)
              AND @LicenseeType <> -1
              AND (si.IsLicensee IS NULL
                   OR si.IsLicensee = CASE WHEN @LicenseeType = 0 THEN si.IsLicensee WHEN @LicenseeType = 1 THEN 0 ELSE 1 END)
              AND ((sp.SitePermission IS NULL AND ISNULL(si.IsLicensee, 1) = 1)
                   OR sp.SitePermission = usp.SitePermission)
    END

    -- @Type=4 - By Site
    IF (@Type = 4 AND @UserRole = 2)
    BEGIN
        INSERT INTO #tmpFeedbackData (
            FeedbackID,
            MainCategoryID,
            MainCategory,
            SubCategoryID,
            SubCategory,
            ShowColumnID,
            ShowColumnName
        )
        SELECT DISTINCT fb.FeedbackID                FeedbackID, 
                        fs.SettingID                 MainCategoryID,
                        m.SettingValue               MainCategory, 
                        fs.SubSettingID              SubCategoryID,
                        s.SettingValue               SubCategory,
                        ISNULL(site.SiteID, 0)       ShowColumnID,
                        ISNULL(site.SiteName, 'N/A') ShowColumnName
        FROM bodb_CRM.dbo.crmFeedback fb WITH (NOLOCK) 
             INNER JOIN bodb_CRM.dbo.crmFeedbackSetting fs WITH (NOLOCK) ON fb.FeedbackID = fs.FeedbackID    
             INNER JOIN bodb_CRM.dbo.crmSetting m WITH (NOLOCK) ON fs.SettingID = m.SettingID AND m.SettingName = 'MainCategory' AND m.siteOffer = 2
             INNER JOIN bodb_CRM.dbo.crmSetting s WITH (NOLOCK) ON fs.SubSettingID = s.SettingID AND s.SettingName = 'SubCategory' AND s.siteOffer = 2
             LEFT JOIN bodb_CRM.dbo.crmSite site WITH (NOLOCK) ON fb.SiteID = site.SiteID
             LEFT JOIN #tmpSite si ON fb.SiteID = si.SiteID
             LEFT JOIN #tmpSitePermission sp ON si.SiteID = sp.SiteID
             LEFT JOIN #tmpUserSitePermission usp ON sp.SitePermission = usp.SitePermission
        WHERE fb.FeedbackDate BETWEEN @FromDate AND @ToDate
              AND fb.StatusID NOT IN (11001, 11004, 11019, 11016)
              AND DATEDIFF(s,FeedbackDate, ResolutionDate) >= @fDuration
              AND DATEDIFF(s,FeedbackDate, ResolutionDate) <= @tDuration
              AND (si.SiteOffer = @UserRole OR si.SiteOffer IS NULL)
              AND @LicenseeType <> -1
              AND (si.IsLicensee IS NULL
                   OR si.IsLicensee = CASE WHEN @LicenseeType = 0 THEN si.IsLicensee WHEN @LicenseeType = 1 THEN 0 ELSE 1 END)
              AND ((sp.SitePermission IS NULL AND ISNULL(si.IsLicensee, 1) = 1)
                   OR sp.SitePermission = usp.SitePermission)
    END

    -- @Type=5 - By Status
    IF (@Type = 5 AND @UserRole = 2)
    BEGIN
        INSERT INTO #tmpFeedbackData (
            FeedbackID,
            MainCategoryID,
            MainCategory,
            SubCategoryID,
            SubCategory,
            ShowColumnID,
            ShowColumnName
        )
        SELECT DISTINCT fb.FeedbackID   FeedbackID, 
                        fs.SettingID    MainCategoryID,
                        m.SettingValue  MainCategory, 
                        fs.SubSettingID SubCategoryID,
                        s.SettingValue  SubCategory,
                        st.SettingID    ShowColumnID,
                        st.SettingValue ShowColumnName
        FROM bodb_CRM.dbo.crmFeedback fb WITH (NOLOCK) 
             INNER JOIN bodb_CRM.dbo.crmFeedbackSetting fs WITH (NOLOCK) ON fb.FeedbackID = fs.FeedbackID    
             INNER JOIN bodb_CRM.dbo.crmSetting m WITH (NOLOCK) ON fs.SettingID = m.SettingID AND m.SettingName = 'MainCategory' AND m.siteOffer = 2
             INNER JOIN bodb_CRM.dbo.crmSetting s WITH (NOLOCK) ON fs.SubSettingID = s.SettingID AND s.SettingName = 'SubCategory' AND s.siteOffer = 2
             LEFT JOIN bodb_CRM.dbo.crmSetting st WITH(NOLOCK) ON fb.StatusID = st.SettingID
             LEFT JOIN #tmpSite si ON fb.SiteID = si.SiteID
             LEFT JOIN #tmpSitePermission sp ON si.SiteID = sp.SiteID
             LEFT JOIN #tmpUserSitePermission usp ON sp.SitePermission = usp.SitePermission
        WHERE fb.FeedbackDate BETWEEN @FromDate AND @ToDate
              AND fb.StatusID NOT IN (11001, 11004, 11019, 11016)
              AND DATEDIFF(s,FeedbackDate, ResolutionDate) >= @fDuration
              AND DATEDIFF(s,FeedbackDate, ResolutionDate) <= @tDuration
              AND (si.SiteOffer = @UserRole OR si.SiteOffer IS NULL)
              AND @LicenseeType <> -1
              AND (si.IsLicensee IS NULL
                   OR si.IsLicensee = CASE WHEN @LicenseeType = 0 THEN si.IsLicensee WHEN @LicenseeType = 1 THEN 0 ELSE 1 END)
              AND ((sp.SitePermission IS NULL AND ISNULL(si.IsLicensee, 1) = 1)
                   OR sp.SitePermission = usp.SitePermission)
    END

    -- @Type=6 - By Customer Response
    IF (@Type = 6 AND @UserRole = 2)
    BEGIN
        INSERT INTO #tmpFeedbackData (
            FeedbackID,
            MainCategoryID,
            MainCategory,
            SubCategoryID,
            SubCategory,
            ShowColumnID,
            ShowColumnName
        )
        SELECT DISTINCT fb.FeedbackID   FeedbackID, 
                        fs.SettingID    MainCategoryID,
                        m.SettingValue  MainCategory, 
                        fs.SubSettingID SubCategoryID,
                        s.SettingValue  SubCategory,
                        st.SettingID    ShowColumnID,
                        st.SettingValue ShowColumnName
        FROM bodb_CRM.dbo.crmFeedback fb WITH (NOLOCK) 
             INNER JOIN bodb_CRM.dbo.crmFeedbackSetting fs WITH (NOLOCK) ON fb.FeedbackID = fs.FeedbackID    
             INNER JOIN bodb_CRM.dbo.crmSetting m WITH (NOLOCK) ON fs.SettingID = m.SettingID AND m.SettingName = 'MainCategory' AND m.siteOffer = 2
             INNER JOIN bodb_CRM.dbo.crmSetting s WITH (NOLOCK) ON fs.SubSettingID = s.SettingID AND s.SettingName = 'SubCategory' AND s.siteOffer = 2
             LEFT JOIN bodb_CRM.dbo.crmSetting st WITH(NOLOCK) ON fb.ResponseID = st.SettingID
             LEFT JOIN #tmpSite si ON fb.SiteID = si.SiteID
             LEFT JOIN #tmpSitePermission sp ON si.SiteID = sp.SiteID
             LEFT JOIN #tmpUserSitePermission usp ON sp.SitePermission = usp.SitePermission
        WHERE fb.FeedbackDate BETWEEN @FromDate AND @ToDate
              AND fb.StatusID NOT IN (11001, 11004, 11019, 11016)
              AND DATEDIFF(s,FeedbackDate, ResolutionDate) >= @fDuration
              AND DATEDIFF(s,FeedbackDate, ResolutionDate) <= @tDuration
              AND (si.SiteOffer = @UserRole OR si.SiteOffer IS NULL)
              AND @LicenseeType <> -1
              AND (si.IsLicensee IS NULL
                   OR si.IsLicensee = CASE WHEN @LicenseeType = 0 THEN si.IsLicensee WHEN @LicenseeType = 1 THEN 0 ELSE 1 END)
              AND ((sp.SitePermission IS NULL AND ISNULL(si.IsLicensee, 1) = 1)
                   OR sp.SitePermission = usp.SitePermission)
    END

    -- @Type=7 - By Product
    IF (@Type = 7 AND @UserRole = 2)
    BEGIN
        INSERT INTO #tmpFeedbackData (
            FeedbackID,
            MainCategoryID,
            MainCategory,
            SubCategoryID,
            SubCategory,
            ShowColumnID,
            ShowColumnName
        )
        SELECT DISTINCT fb.FeedbackID                 FeedbackID, 
                        fs.SettingID                  MainCategoryID,
                        m.SettingValue                MainCategory, 
                        fs.SubSettingID               SubCategoryID,
                        s.SettingValue                SubCategory,
                        ISNULL(p.SettingID, 0)        ShowColumnID,
                        ISNULL(p.SettingValue, 'N/A') ShowColumnName
        FROM bodb_CRM.dbo.crmFeedback fb WITH (NOLOCK) 
             INNER JOIN bodb_CRM.dbo.crmFeedbackSetting fs WITH (NOLOCK) ON fb.FeedbackID = fs.FeedbackID    
             INNER JOIN bodb_CRM.dbo.crmSetting m WITH (NOLOCK) ON fs.SettingID = m.SettingID AND m.SettingName = 'MainCategory' AND m.siteOffer = 2
             INNER JOIN bodb_CRM.dbo.crmSetting s WITH (NOLOCK) ON fs.SubSettingID = s.SettingID AND s.SettingName = 'SubCategory' AND s.siteOffer = 2
             INNER JOIN bodb_CRM.dbo.crmFeedbackSetting st WITH (NOLOCK) ON fs.FeedbackID = st.FeedbackID
             INNER JOIN bodb_CRM.dbo.crmSetting p WITH(NOLOCK) ON st.SettingID = p.SettingID AND p.SettingName='Product'
             LEFT JOIN #tmpSite si ON fb.SiteID = si.SiteID
             LEFT JOIN #tmpSitePermission sp ON si.SiteID = sp.SiteID
             LEFT JOIN #tmpUserSitePermission usp ON sp.SitePermission = usp.SitePermission
        WHERE fb.FeedbackDate BETWEEN @FromDate AND @ToDate
              AND fb.StatusID NOT IN (11001, 11004, 11019, 11016)
              AND DATEDIFF(s,FeedbackDate, ResolutionDate) >= @fDuration
              AND DATEDIFF(s,FeedbackDate, ResolutionDate) <= @tDuration
              AND (si.SiteOffer = @UserRole OR si.SiteOffer IS NULL)
              AND @LicenseeType <> -1
              AND (si.IsLicensee IS NULL
                   OR si.IsLicensee = CASE WHEN @LicenseeType = 0 THEN si.IsLicensee WHEN @LicenseeType = 1 THEN 0 ELSE 1 END)
              AND ((sp.SitePermission IS NULL AND ISNULL(si.IsLicensee, 1) = 1)
                   OR sp.SitePermission = usp.SitePermission)
    END

    -- @Type=8 - By Category
    IF (@Type = 8 AND @UserRole = 2)
    BEGIN
        INSERT INTO #tmpFeedbackData (
            FeedbackID,
            MainCategoryID,
            MainCategory,
            SubCategoryID,
            SubCategory,
            ShowColumnID,
            ShowColumnName
        )
        SELECT DISTINCT fb.FeedbackID   FeedbackID, 
                        fs.SettingID    MainCategoryID,
                        m.SettingValue  MainCategory, 
                        fs.SubSettingID SubCategoryID,
                        s.SettingValue  SubCategory,
                        m.SettingID     ShowColumnID,
                        m.SettingValue  ShowColumnName
        FROM bodb_CRM.dbo.crmFeedback fb WITH (NOLOCK) 
             INNER JOIN bodb_CRM.dbo.crmFeedbackSetting fs WITH (NOLOCK) ON fb.FeedbackID = fs.FeedbackID    
             INNER JOIN bodb_CRM.dbo.crmSetting m WITH (NOLOCK) ON fs.SettingID = m.SettingID AND m.SettingName = 'MainCategory' AND m.siteOffer = 2
             INNER JOIN bodb_CRM.dbo.crmSetting s WITH (NOLOCK) ON fs.SubSettingID = s.SettingID AND s.SettingName = 'SubCategory' AND s.siteOffer = 2
             LEFT JOIN #tmpSite si ON fb.SiteID = si.SiteID
             LEFT JOIN #tmpSitePermission sp ON si.SiteID = sp.SiteID
             LEFT JOIN #tmpUserSitePermission usp ON sp.SitePermission = usp.SitePermission
        WHERE fb.FeedbackDate BETWEEN @FromDate AND @ToDate
              AND fb.StatusID NOT IN (11001, 11004, 11019, 11016)
              AND DATEDIFF(s,FeedbackDate, ResolutionDate) >= @fDuration
              AND DATEDIFF(s,FeedbackDate, ResolutionDate) <= @tDuration
              AND (si.SiteOffer = @UserRole OR si.SiteOffer IS NULL)
              AND @LicenseeType <> -1
              AND (si.IsLicensee IS NULL
                   OR si.IsLicensee = CASE WHEN @LicenseeType = 0 THEN si.IsLicensee WHEN @LicenseeType = 1 THEN 0 ELSE 1 END)
              AND ((sp.SitePermission IS NULL AND ISNULL(si.IsLicensee, 1) = 1)
                   OR sp.SitePermission = usp.SitePermission)
    END

    -- @Type=9 - By Licensee
    IF (@Type = 9 AND @UserRole = 2)
    BEGIN
        INSERT INTO #tmpFeedbackData (
            FeedbackID,
            MainCategoryID,
            MainCategory,
            SubCategoryID,
            SubCategory,
            ShowColumnID,
            ShowColumnName
        )
        SELECT DISTINCT fb.FeedbackID              FeedbackID, 
                        fs.SettingID               MainCategoryID,
                        m.SettingValue             MainCategory, 
                        fs.SubSettingID            SubCategoryID,
                        s.SettingValue             SubCategory,
                        ISNULL(st.SiteID, 0)       ShowColumnID,
                        ISNULL(st.SiteName, 'N/A') ShowColumnName
        FROM bodb_CRM.dbo.crmFeedback fb WITH (NOLOCK) 
             INNER JOIN bodb_CRM.dbo.crmFeedbackSetting fs WITH (NOLOCK) ON fb.FeedbackID = fs.FeedbackID    
             INNER JOIN bodb_CRM.dbo.crmSetting m WITH (NOLOCK) ON fs.SettingID = m.SettingID AND m.SettingName = 'MainCategory' AND m.siteOffer = 2
             INNER JOIN bodb_CRM.dbo.crmSetting s WITH (NOLOCK) ON fs.SubSettingID = s.SettingID AND s.SettingName = 'SubCategory' AND s.siteOffer = 2
             LEFT JOIN bodb_CRM.dbo.crmSite st WITH(NOLOCK) ON fb.SiteID = st.SiteID
             LEFT JOIN #tmpSite si ON fb.SiteID = si.SiteID
             LEFT JOIN #tmpSitePermission sp ON si.SiteID = sp.SiteID
             LEFT JOIN #tmpUserSitePermission usp ON sp.SitePermission = usp.SitePermission
        WHERE fb.FeedbackDate BETWEEN @FromDate AND @ToDate
              AND fb.StatusID NOT IN (11001, 11004, 11019, 11016)
              AND DATEDIFF(s,FeedbackDate, ResolutionDate) >= @fDuration
              AND DATEDIFF(s,FeedbackDate, ResolutionDate) <= @tDuration
              AND (st.IsLicensee = 1 OR ISNULL(fb.SiteID, 0) = 0)
              AND (si.SiteOffer = @UserRole OR si.SiteOffer IS NULL)
              AND @LicenseeType <> -1
              AND (si.IsLicensee IS NULL
                   OR si.IsLicensee = CASE WHEN @LicenseeType = 0 THEN si.IsLicensee WHEN @LicenseeType = 1 THEN 0 ELSE 1 END)
              AND ((sp.SitePermission IS NULL AND ISNULL(si.IsLicensee, 1) = 1)
                   OR sp.SitePermission = usp.SitePermission)
    END

    -- @Type=10 - By Communication Tool
    IF (@Type = 10 AND @UserRole = 2)
    BEGIN
        INSERT INTO #tmpFeedbackData (
            FeedbackID,
            MainCategoryID,
            MainCategory,
            SubCategoryID,
            SubCategory,
            ShowColumnID,
            ShowColumnName
        )
        SELECT DISTINCT fb.FeedbackID                 FeedbackID, 
                        fs.SettingID                  MainCategoryID,
                        m.SettingValue                MainCategory, 
                        fs.SubSettingID               SubCategoryID,
                        s.SettingValue                SubCategory,
                        ISNULL(p.SettingID, 0)        ShowColumnID,
                        ISNULL(p.SettingValue, 'N/A') ShowColumnName
        FROM bodb_CRM.dbo.crmFeedback fb WITH (NOLOCK) 
             INNER JOIN bodb_CRM.dbo.crmFeedbackSetting fs WITH (NOLOCK) ON fb.FeedbackID = fs.FeedbackID    
             INNER JOIN bodb_CRM.dbo.crmSetting m WITH (NOLOCK) ON fs.SettingID = m.SettingID AND m.SettingName = 'MainCategory' AND m.siteOffer = 2
             INNER JOIN bodb_CRM.dbo.crmSetting s WITH (NOLOCK) ON fs.SubSettingID = s.SettingID AND s.SettingName = 'SubCategory' AND s.siteOffer = 2
             INNER JOIN bodb_CRM.dbo.crmFeedbackSetting st WITH (NOLOCK) ON fs.FeedbackID = st.FeedbackID
             INNER JOIN bodb_CRM.dbo.crmSetting p WITH (NOLOCK) ON st.SettingID = p.SettingID AND p.SettingName = 'communication'
             LEFT JOIN #tmpSite si ON fb.SiteID = si.SiteID
             LEFT JOIN #tmpSitePermission sp ON si.SiteID = sp.SiteID
             LEFT JOIN #tmpUserSitePermission usp ON sp.SitePermission = usp.SitePermission
        WHERE fb.FeedbackDate BETWEEN @FromDate AND @ToDate
              AND fb.StatusID NOT IN (11001, 11004, 11019, 11016)
              AND DATEDIFF(s,FeedbackDate, ResolutionDate) >= @fDuration
              AND DATEDIFF(s,FeedbackDate, ResolutionDate) <= @tDuration
              AND (si.SiteOffer = @UserRole OR si.SiteOffer IS NULL)
              AND @LicenseeType <> -1
              AND (si.IsLicensee IS NULL
                   OR si.IsLicensee = CASE WHEN @LicenseeType = 0 THEN si.IsLicensee WHEN @LicenseeType = 1 THEN 0 ELSE 1 END)
              AND ((sp.SitePermission IS NULL AND ISNULL(si.IsLicensee, 1) = 1)
                   OR sp.SitePermission = usp.SitePermission)
    END


    --------------
    -- Return data

    CREATE TABLE #tmpShowColumnName (
        ID             INT IDENTITY PRIMARY KEY,
        ShowColumnID   INT,
        ShowColumnName NVARCHAR(1000)
    )

    IF (@type IN (3, 10))
    BEGIN
        INSERT INTO #tmpShowColumnName (
            ShowColumnID,
            ShowColumnName
        )
        SELECT ShowColumnID,
               ShowColumnName
        FROM #tmpFeedbackData
        GROUP BY ShowColumnID, ShowColumnName
        ORDER BY ShowColumnID
    END
    ELSE
    BEGIN
        INSERT INTO #tmpShowColumnName (
            ShowColumnID,
            ShowColumnName
        )
        SELECT ShowColumnID,
               ShowColumnName
        FROM #tmpFeedbackData
        GROUP BY ShowColumnID, ShowColumnName
        ORDER BY CASE WHEN ShowColumnName IN ('N/A', 'N/A.') THEN 'ZZZ' ELSE ShowColumnName END
    END           

    DECLARE @cols NVARCHAR(MAX)
    SELECT  @cols = COALESCE(@cols + ',[' + ShowColumnName + ']','[' + ShowColumnName + ']')
    FROM #tmpShowColumnName

    DECLARE @sql  NVARCHAR(MAX)
    SELECT  @sql =
    '
    SELECT MainCategoryID, SubCategoryID, MainCategory, SubCategory, ' + @cols + '
    FROM (
            SELECT FeedbackID,
                   MainCategoryID,
                   MainCategory,
                   SubCategoryID,
                   SubCategory,
                   ShowColumnName
            FROM #tmpFeedbackData
         ) p
        PIVOT
        (
            COUNT(FeedbackID)
            FOR ShowColumnName IN (' + @cols + ')
        ) AS pvt
        ORDER BY MainCategory, SubCategory
    '
    EXECUTE (@sql)
    SELECT ShowColumnID Item FROM #tmpShowColumnName WHERE ShowColumnID IS NOT NULL

    -------------------
    -- Drop temp tables

    DROP TABLE #tmpUserSitePermission
    DROP TABLE #tmpSite
    DROP TABLE #tmpSitePermission

    DROP TABLE #tmpFeedbackData
    DROP TABLE #tmpShowColumnName

END
GO