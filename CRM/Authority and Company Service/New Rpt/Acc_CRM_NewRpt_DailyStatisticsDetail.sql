/*<info serverAlias="DBCRM-bodb_CRM" executers="wsv_nap" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE dbo.Acc_CRM_NewRpt_DailyStatisticsDetail @SiteType        BIT           = 0,
                                                         @FromDate        DATETIME,
                                                         @ToDate          DATETIME,
                                                         @ProductID       VARCHAR(500),
                                                         @MainCategoryID  VARCHAR(500),
                                                         @CommunicationID VARCHAR(500),
                                                         @UserRole        TINYINT       = 2,
                                                         @LicenseeType    INT           = 0,
                                                         @SitePermission  NVARCHAR(MAX) = NULL,
                                                         @PageSize        INT           = 0,
                                                         @PageIndex       INT           = 0,
                                                         @TotalRows       INT           = 0  OUTPUT,
                                                         @ErrorCode       INT           = 0  OUTPUT,
                                                         @ErrorMsg        VARCHAR(200)  = '' OUTPUT
AS

/*
    Created:  Ned.Le
    Date:     20240220
    Task:     View daily statistics report more detail
    DB:       DBCRM.bodb_CRM
    Original: Acc_CRM_Rpt_DailyStatisticsDetail

    Revisions:
        20240220@Ned.Le: CRM - Manage Headline/PIC/Staff authority and Company services (#193385)
        20240829@Ned.Le: CRM - When clicking Latest Feedback not found the feedback Due to permission limitations for account P5S (#210055)

    Param's Explanation:        
        @SiteType = 0: IBC
                    1: Licensee

        @UserRole = 0: Manager 
                    1: CN88 staff
                    2: Company staff

        @LicenseeType = -1: None
                         0: Both
                         1: Credit
                         2: Licensee

        @SitePermission: Value depend on user's permission and maybe NULL

    Example:
        DECLARE @TotalRows_out INT
        DECLARE @ErrorCode_out INT
        DECLARE @ErrorMsg_out  VARCHAR(200)
        EXEC bodb_CRM.dbo.Acc_CRM_NewRpt_DailyStatisticsDetail @SiteType        = 0,
                                                               @FromDate        = '2024-02-21 12:00:00',
                                                               @ToDate          = '2024-02-22 11:59:59',
                                                               @ProductID       = '46006,46007,46003,46004,46005,46008,46002,46000,46001',
                                                               @MainCategoryID  = '3009,3041,3008,3022,3033,3000,3040,3015,3032,3016,3028,3027,3017,3038,3011,3031,3066,3067,3018,3035,3001,3036,3019,3014,3006,3023,3026,3057,3059,3064,3058,3056,3060,3063,3062,3061,3065,3003,3005,3030,3029,3020,3004,3025,3021,3037,3024,3002,3034,3010,3013',
                                                               @CommunicationID = '1011,1001,1012,1008,1004,1005,1000,1010,1003,1006,1007,1009,1002',
                                                               @UserRole        = 2,
                                                               @LicenseeType    = 0,
                                                               @SitePermission  = N'777,789y,IBC,MBC,TH7a5,Ultra888',
                                                               @PageSize        = 100,
                                                               @PageIndex       = 1,
                                                               @TotalRows       = @TotalRows_out OUTPUT,
                                                               @ErrorCode       = @ErrorCode_out OUTPUT,
                                                               @ErrorMsg        = @ErrorMsg_out  OUTPUT
*/

BEGIN

    SET NOCOUNT ON


    ------------------
    -- Prepare data --

    ---------------------
    -- Data of Permission 

    -- #tmpUserSitePermission
    CREATE TABLE #tmpUserSitePermission (SitePermission  NVARCHAR(100))
    INSERT INTO  #tmpUserSitePermission (SitePermission)
    SELECT value SitePermission
    FROM STRING_SPLIT(@SitePermission, ',')

    -- #tmpSitePermission
    CREATE TABLE #tmpSitePermission (SiteID INT, SiteName NVARCHAR(100), SitePermission NVARCHAR(100))
    INSERT INTO  #tmpSitePermission (SiteID, SiteName, SitePermission)
    SELECT sr.SettingID    SiteID,
           si.SettingValue SiteName,
           sp.SettingValue SitePermission
    FROM bodb_CRM.dbo.crmSettingRelation sr WITH (NOLOCK)
         INNER JOIN bodb_CRM.dbo.crmSetting sp WITH (NOLOCK) ON sp.SettingName = 'SitePermission' AND sr.ParentID = sp.SettingID
         INNER JOIN bodb_CRM.dbo.crmSetting si WITH (NOLOCK) ON si.SettingName = 'Site' AND sr.SettingID = si.SettingID

    ------------------------
    -- Data of XML parameter

    -- Declare variables
    DECLARE @string   VARCHAR(MAX)
    DECLARE @splitter CHAR(1)
    DECLARE @xml      XML
    
    -- ProductID
    SELECT @string   = @ProductID
    SELECT @splitter = ','
    SELECT @XML      = N'<root><r>' + REPLACE(@string, @splitter, '</r><r>') + '</r></root>'

    CREATE TABLE #tmpXMLProductID (ProductID INT PRIMARY KEY)
    INSERT INTO  #tmpXMLProductID (ProductID)
    SELECT r.value('.','INT')
    FROM @xml.nodes('//root/r') AS RECORDS(r)

    -- MainCategoryID
    SELECT @string   = @MainCategoryID
    SELECT @splitter = ','
    SELECT @XML      = N'<root><r>' + REPLACE(@string, @splitter, '</r><r>') + '</r></root>'

    CREATE TABLE #tmpXMLMainCategoryID (CategoryID INT PRIMARY KEY)
    INSERT INTO  #tmpXMLMainCategoryID (CategoryID)
    SELECT r.value('.','INT')
    FROM @xml.nodes('//root/r') AS RECORDS(r)

    -- CommunicationID
    SELECT @string   = @CommunicationID
    SELECT @splitter = ','
    SELECT @XML      = N'<root><r>' + REPLACE(@string, @splitter, '</r><r>') + '</r></root>'

    CREATE TABLE #tmpXMLCommunicationID (CommunicationID INT PRIMARY KEY)
    INSERT INTO  #tmpXMLCommunicationID (CommunicationID)
    SELECT r.value('.','INT')
    FROM @xml.nodes('//root/r') AS RECORDS(r)

    --------------------------
    -- Data of Feedback Filter 

    -- #tmpFBProduct
    CREATE TABLE #tmpFBProduct (
        FeedbackID   INT,
        ProductID    INT,
        SubProductID INT,
        PRIMARY KEY (FeedbackID, ProductID, SubProductID)
    )

    INSERT INTO #tmpFBProduct (
        FeedbackID,
        ProductID,
        SubProductID
    )
    SELECT DISTINCT
           fbs.FeedbackID   FeedbackID,
           fbs.SettingID    ProductID,
           fbs.SubSettingID SubProductID
    FROM bodb_CRM.dbo.crmFeedback fb WITH (NOLOCK) 
         INNER JOIN bodb_CRM.dbo.crmFeedbackSetting fbs WITH (NOLOCK) ON fb.FeedbackID = fbs.FeedbackID
         INNER JOIN #tmpXMLProductID p ON fbs.SettingID = p.ProductID
    WHERE fb.FeedbackDate BETWEEN @fromdate AND @todate
          AND fb.StatusID NOT IN (11004, 11019)
    OPTION (RECOMPILE)

    -- #tmpFBCategory
    CREATE TABLE #tmpFBCategory (
        FeedbackID    INT,
        CategoryID    INT,
        SubCategoryID INT,
        PRIMARY KEY (FeedbackID, CategoryID, SubCategoryID)
    )

    INSERT INTO #tmpFBCategory (
        FeedbackID,
        CategoryID,
        SubCategoryID
    )
    SELECT DISTINCT
           fbs.FeedbackID   FeedbackID,
           fbs.SettingID    CategoryID,
           fbs.SubSettingID SubCategoryID
    FROM bodb_CRM.dbo.crmFeedback fb WITH (NOLOCK)
         INNER JOIN bodb_CRM.dbo.crmFeedbackSetting fbs WITH (NOLOCK) ON fb.FeedbackID = fbs.FeedbackID
         INNER JOIN #tmpXMLMainCategoryID c ON fbs.SettingID = c.CategoryID
    WHERE fb.FeedbackDate BETWEEN @fromdate AND @todate
          AND fb.StatusID NOT IN (11004, 11019)
    OPTION (RECOMPILE)

    -- #tmpFBCommunication
    CREATE TABLE #tmpFBCommunication (
        FeedbackID      INT,
        CommunicationID INT
        PRIMARY KEY (FeedbackID, CommunicationID)
    )

    INSERT INTO #tmpFBCommunication (
        FeedbackID,
        CommunicationID
    )
    SELECT DISTINCT
           fbs.FeedbackID FeedbackID,
           fbs.SettingID  CommunicationID
    FROM bodb_CRM.dbo.crmFeedback fb WITH (NOLOCK)
         INNER JOIN bodb_CRM.dbo.crmFeedbackSetting fbs WITH (NOLOCK) ON fb.FeedbackID = fbs.FeedbackID
         INNER JOIN #tmpXMLCommunicationID c ON fbs.SettingID = c.CommunicationID
    WHERE fb.FeedbackDate BETWEEN @fromdate AND @todate
          AND fb.StatusID NOT IN (11004, 11019)

    -- #tmpFBStation
    CREATE TABLE #tmpFBStation (
        FeedbackID INT,
        StationID  INT,
        PRIMARY KEY (FeedbackID, StationID)
    )

    INSERT INTO #tmpFBStation (
        FeedbackID,
        StationID
    )
    SELECT DISTINCT
           fbc.FeedbackID FeedbackID,
           fbs.SettingID  StationID
    FROM #tmpFBCommunication fbc
         INNER JOIN bodb_CRM.dbo.crmFeedbackSetting fbs WITH (NOLOCK) ON fbc.FeedbackID = fbs.FeedbackID
         INNER JOIN bodb_CRM.dbo.crmSetting s ON fbs.SettingID = s.SettingID AND s.SettingName = 'Station'
    OPTION (RECOMPILE)


    ------------------
    -- Process data --

    -- Set data for variables
    DECLARE @RowStart INT,
            @RowEnd   INT

    SELECT @PageIndex = @PageIndex - 1,
           @RowStart  = @PageSize * @PageIndex + 1,
           @RowEnd    = @RowStart + @PageSize - 1

    -- Get base data
    CREATE TABLE #tmpFeedback (
        FeedbackID      INT,
        SiteName        NVARCHAR(100),
        Description     XML,
        ProductID       INT,
        SubProductID    INT,
        CategoryID      INT,
        SubCategoryID   INT,
        CommunicationID INT,
        StationID       INT,
        RowNum          INT
    )

    INSERT INTO #tmpFeedback (
        FeedbackID,
        SiteName,
        Description,
        ProductID,
        SubProductID,
        CategoryID,
        SubCategoryID,
        CommunicationID,
        StationID,
        RowNum
    )
    SELECT fb.FeedbackID,
           s.SiteName,
           fb.Description,
           p.ProductID,
           p.SubProductID,
           ca.CategoryID,
           ca.SubCategoryID,
           com.CommunicationID,
           sta.StationID,
           ROW_NUMBER() OVER(ORDER BY feedbackdate DESC) RowNum
    FROM bodb_CRM.dbo.crmFeedback fb WITH (NOLOCK)
         INNER JOIN #tmpFBProduct p ON fb.FeedbackID = p.FeedbackID
         INNER JOIN #tmpFBCategory ca ON fb.FeedbackID = ca.FeedbackID
         INNER JOIN #tmpFBCommunication com ON fb.FeedbackID = com.FeedbackID
         INNER JOIN #tmpFBStation sta ON fb.FeedbackID = sta.FeedbackID
         INNER JOIN bodb_CRM.dbo.crmCustomer c WITH (NOLOCK) ON fb.CustID = c.CustID
         LEFT JOIN bodb_CRM.dbo.crmSite s WITH (NOLOCK) ON fb.SiteID = s.SiteID
         LEFT JOIN #tmpSitePermission sp ON s.SiteID = sp.SiteID
         LEFT JOIN #tmpUserSitePermission usp ON sp.SitePermission = usp.SitePermission
    WHERE fb.FeedbackDate BETWEEN @fromdate AND @todate
          AND fb.StatusID NOT IN (11004, 11019)
          AND @LicenseeType <> -1
          AND (
                  (@LicenseeType = 0 AND ((@SiteType = 0 AND (s.IsLicensee = 0
                                                              OR ISNULL(fb.SiteID,0) = 0
                                                              OR ISNULL(s.SiteID, 0) = 0))
                                          OR
                                          (@SiteType = 1 AND (s.IsLicensee = 1))))
                  OR
                  (@LicenseeType = 1 AND ((@SiteType = 0 AND (s.IsLicensee = 0
                                                              OR ISNULL(fb.SiteID,0) = 0
                                                              OR ISNULL(s.SiteID, 0) = 0))))
                  OR
                  (@LicenseeType = 2 AND ((@SiteType = 1 AND (s.IsLicensee = 1
                                                              OR ISNULL(fb.SiteID,0) = 0
                                                              OR ISNULL(s.SiteID, 0) = 0))))
              )
          AND (
                  (sp.SitePermission IS NULL AND ISNULL(s.IsLicensee, 1) = 1)
                  OR sp.SitePermission = usp.SitePermission
              )
    OPTION (RECOMPILE)

    CREATE CLUSTERED INDEX CIX_FeedbackID ON #tmpFeedback(FeedbackID)

    -- Check total row
    SELECT @TotalRows = COUNT(1) FROM #tmpFeedback

    IF ((@PageSize <= 0) AND (@PageIndex <= 0) AND (@TotalRows > 1000000))
    BEGIN        
        SELECT @ErrorCode = 100
        SELECT @ErrorMsg  = 'That''s more than a million data, So we can not export excel.Pls choice another range date.'
        RETURN
    END

    -- Filter data according to page size
    IF ((@RowStart > 0) AND (@RowEnd > 0))
    BEGIN
        DELETE fb FROM #tmpFeedback fb WHERE RowNum < @RowStart
        DELETE fb FROM #tmpFeedback fb WHERE RowNum > @RowEnd
    END


    -----------------
    -- Return data --

    -- Parameter help to determine old and new feedback
    DECLARE @FeebackID_SeparateNewOld INT
    SELECT  @FeebackID_SeparateNewOld = CAST(Value AS INT)
    FROM bodb_CRM.dbo.SystemSetting WITH (NOLOCK)
    WHERE ServiceName = 'Internal Setting'
          AND SettingName = 'FeebackID_SeparateNewOld'

    -- Main data
    SELECT --Base information
           fb.FeedbackID                                                         FeedbackID,
           fb.CustID                                                             CustID,
           fb.TitleID                                                            TitleID,
           c.UserName                                                            UserName,
           fb.FirstName                                                          FirstName,
           fb.LastName                                                           LastName,
           ISNULL(l.Name, 'N/A')                                                 Language,
           ISNULL(ct.CountryName, 'N/A')                                         CountryName,
           fb.CreateDate                                                         CreateDate,
           fb.CreatorID                                                          CreatorID,
           ci.UserName                                                           CreatorName,
           fb.FeedbackDate                                                       FeedbackDate,
           fb.ResolutionDate                                                     ResolutionDate,
           fb.SolveDate                                                          SolveDate,
           ISNULL(base.SiteName, 'N/A')                                          SiteName,
           Role.Role                                                             Role,
           ISNULL(Response.Response, 'N/A')                                      Response,
           ISNULL(st.Name, 'N/A')                                                Status, 
           fb.Solution                                                           Solution,
           fb.IsReviewed                                                         IsReviewed,
           fb.Review                                                             Review,
           fb.ReviewerID                                                         ReviewerID,
           fb.Subject                                                            Subject,
           nr.value(N'@AutoField',N'nvarchar(max)')                              AutoField,
           nr.value(N'@Remark',N'nvarchar(max)')                                 Remark,
           base.ProductID                                                        ProductID,
           base.SubProductID                                                     SubProductID,
           base.CategoryID                                                       CategoryID,
           base.SubCategoryID                                                    SubCategoryID,
           base.CommunicationID                                                  CommunicationID,
           base.StationID                                                        StationID,
           ISNULL(fb.Inquiries,0)                                                NoInquiries,
           --Old communication information
           ISNULL(fb.Email, '')                                                  Email,
           ISNULL(fb.Skype, '')                                                  Skype,
           ISNULL(fb.MSN, '')                                                    MSN,
           ISNULL(fb.FaxCountryCode, '')                                         FaxCountryCode,
           ISNULL(fb.FaxAreaCode, '')                                            FaxAreaCode,
           ISNULL(fb.Fax, '')                                                    Fax,
           ISNULL(fb.PhoneCountryCode, '')                                       PhoneCountryCode,
           ISNULL(fb.PhoneAreaCode, '')                                          PhoneAreaCode,
           ISNULL(fb.Phone, '')                                                  Phone,
           ISNULL(fb.Phone2CountryCode, '')                                      Phone2CountryCode,
           ISNULL(fb.Phone2AreaCode, '')                                         Phone2AreaCode,
           ISNULL(fb.Phone2, '')                                                 Phone2,
           ISNULL(fb.Phone3CountryCode, '')                                      Phone3CountryCode,
           ISNULL(fb.Phone3AreaCode, '')                                         Phone3AreaCode,
           ISNULL(fb.Phone3, '')                                                 Phone3,
           ISNULL(fb.WhatsApp, '')                                               WhatsApp,
           ISNULL(fb.Line, '')                                                   Line,
           ISNULL(fb.WeChat, '')                                                 WeChat,
           ISNULL(fb.Yahoo, '')                                                  Yahoo,
           ISNULL(fb.QQ, '')                                                     QQ,
           ISNULL(fb.BBM, '')                                                    BBM,
           ISNULL(fb.MobilePhoneCountryCode, '')                                 MobilePhoneCountryCode,
           ISNULL(fb.MobilePhoneAreaCode, '')                                    MobilePhoneAreaCode,
           ISNULL(fb.MobilePhone, '')                                            MobilePhone,
           ISNULL(fb.PIC1, '')                                                   PIC1,
           ISNULL(fb.PIC2, '')                                                   PIC2,
           ISNULL(fb.PIC3, '')                                                   PIC3,
           ISNULL(fb.PIC4, '')                                                   PIC4,
           ISNULL(fb.PIC1Name, '')                                               PIC1Name,
           ISNULL(fb.PIC2Name, '')                                               PIC2Name,
           ISNULL(fb.PIC3Name, '')                                               PIC3Name,
           ISNULL(fb.PIC4Name, '')                                               PIC4Name,
           --Separate Old New
           CASE WHEN fb.FeedbackID > @FeebackID_SeparateNewOld THEN 1 ELSE 0 END isNewFeedback
    FROM #tmpFeedback base
         INNER JOIN bodb_CRM.dbo.crmFeedback fb WITH (NOLOCK) ON base.FeedbackID = fb.FeedbackID
         INNER JOIN bodb_CRM.dbo.crmCustomer c WITH (NOLOCK) ON fb.CustID = c.CustID
         LEFT JOIN bodb_CRM.dbo.crmLanguage l WITH (NOLOCK) ON l.LanguageID = fb.languageid
         LEFT JOIN bodb_CRM.dbo.crmCountry ct WITH (NOLOCK) ON ct.CountryID = fb.CountryID
         LEFT JOIN bodb02.dbo.custinfo ci WITH (NOLOCK) ON fb.CreatorID = ci.custID
         LEFT JOIN bodb_CRM.dbo.crmStatus st WITH (NOLOCK) ON st.StatusID = fb.StatusID    
         LEFT JOIN (SELECT SettingID ResponseID, SettingValue Response
                    FROM bodb_CRM.dbo.crmSetting WITH (NOLOCK)
                    WHERE SettingName = 'Response') Response ON Response.ResponseID = fb.ResponseID
         LEFT JOIN (SELECT SettingID RoleID, SettingValue Role
                    FROM bodb_CRM.dbo.crmSetting WITH (NOLOCK)
                    WHERE SettingName = 'Role') Role ON Role.RoleID = fb.RoleID
         OUTER APPLY base.Description.nodes(N'//row') AS A(nr)
    ORDER BY base.RowNum

    -- NewCommunicationTool data
    ;WITH CTE_Data AS (
        SELECT ft.FeedbackID,
               ft.CustID,
               ft.isHeadline,
               ft.PicInfo,
               ft.CommunicationID,
               sc.SettingValue CommunicationName,
               ft.CommunicationValue,
               LEFT(ft.PicInfo, CASE WHEN (CHARINDEX('(', ft.PicInfo) - 2) < 0 THEN 0 ELSE (CHARINDEX('(', ft.PicInfo) - 2) END) PicName,
               REPLACE(RIGHT(ft.PicInfo, LEN(ft.PicInfo) - CHARINDEX('(', ft.PicInfo)), ')', '') PicRoleName
        FROM bodb_CRM.dbo.crmFeedbackNewCommunicationTool ft WITH (NOLOCK)
             LEFT JOIN bodb_CRM.dbo.crmSetting sc WITH (NOLOCK) ON sc.SettingName = 'PICCommunicationTool' AND ft.CommunicationID = sc.SettingID
        WHERE EXISTS (SELECT TOP 1 1
                      FROM #tmpFeedback b
                      WHERE b.FeedbackID = ft.FeedbackID)
    )
    SELECT FeedbackID,
           CustID,
           isHeadline,
           PicInfo,
           CommunicationID,
           CommunicationName,
           CommunicationValue
    FROM CTE_Data
    ORDER BY FeedbackID,
             CASE WHEN PicRoleName = 'Boss' THEN 1 ELSE 2 END,
             CASE WHEN PicRoleName = 'Boss' THEN PicName END,
             PicRoleName,
             PicName,
             CommunicationName


    ---------------
    -- Drop data --

    DROP TABLE #tmpXMLProductID
    DROP TABLE #tmpXMLMainCategoryID
    DROP TABLE #tmpXMLCommunicationID

    DROP TABLE #tmpUserSitePermission
    DROP TABLE #tmpSitePermission

    DROP TABLE #tmpFBProduct
    DROP TABLE #tmpFBCategory
    DROP TABLE #tmpFBCommunication
    DROP TABLE #tmpFBStation

    DROP TABLE #tmpFeedback

END
GO