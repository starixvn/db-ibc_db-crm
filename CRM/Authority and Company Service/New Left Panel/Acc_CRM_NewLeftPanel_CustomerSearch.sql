/*<info serverAlias="DBCRM-bodb_CRM" executers="wsv_nap" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE dbo.Acc_CRM_NewLeftPanel_CustomerSearch @SearchInfo        NVARCHAR(200) = '',
                                                        @IsGuest           BIT           = 0,
                                                        @UserRole          TINYINT       = 2,
                                                        @LicenseeType      TINYINT       = 0,
                                                        @SitePermission    NVARCHAR(MAX) = NULL,
                                                        @IsCheckPermission BIT           = 0,
                                                        @ErrCode           INT           = 0  OUTPUT,
                                                        @ErrMsg            NVARCHAR(MAX) = '' OUTPUT
AS

/*
    Created: 20231212@Ned.Le
    Task: Search for customer
    DB: DBCRM/bodb_CRM
    Original: Acc_CRM_CustomerSearch

    Revisions:    
        20231212@Ned.Le: CRM - Manage Headline/PIC/Staff authority and Company services (#193385)
        20240509@Ned.Le: CRM - Can NOT searching for guest account with username is Thai language on Leftpanel and show related customer of an archive account is NOT being resused is Unauthorized Access on Feedback (HotFix #210353)
        20240926@Ned.Le: CRM - Search Left Panel - System is displaying role as Guest if searching an archive account (#211269)
		20241225@Tacy: CRM - Offer Direct Member for Super and Master [Redmine: #215809]

    Param's Explanation:
        @UserRole = 0: Manager 
                    1: CN88 staff
                    2: Company staff
        @LicenseeType = -1: None
                         0: Both
                         1: Credit
                         2: Licensee
        @SitePermission: Value depend on user's permission and maybe NULL
        @IsCheckPermission = 1: Check permission
                             0: No check permission

    Example:
        DECLARE @ErrCode_out INT
        DECLARE @ErrMsg_out  NVARCHAR(MAX)
        EXEC bodb_CRM.dbo.Acc_CRM_NewLeftPanel_CustomerSearch @SearchInfo        = '0919862710',
                                                              @IsGuest           = 0,
                                                              @UserRole          = 2,
                                                              @LicenseeType      = 0,
                                                              @SitePermission    = '789y,MBC',
                                                              @IsCheckPermission = 1,
                                                              @ErrCode           = @ErrCode_out OUTPUT,
                                                              @ErrMsg            = @ErrMsg_out  OUTPUT
        SELECT @ErrCode_out, @ErrMsg_out
*/

BEGIN

    SET NOCOUNT ON


    ---------------
    -- Prepare data

    -- Declare variables    
    DECLARE @CustID          INT,
            @SiteID          INT,
            @RoleID          TINYINT,
            @CountryName     VARCHAR(100),
            @CountryID       INT,
            @IsGroupHeadLine BIT,
            @StatusCN88      VARCHAR(10)

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


    ----------------------------------------------------
    -- Process data and return full customer information

    -- For normal customer
    IF (@IsGuest = 0)
    BEGIN

        -- + Search by username in Customer
        IF (@CustID IS NULL)
        BEGIN
            SELECT @CustID = custid,
                   @RoleID = roleid
            FROM bodb02.dbo.Customer WITH (NOLOCK)
            WHERE username = CAST(@SearchInfo AS VARCHAR(200))
                  AND ((@UserRole=1 AND site = 'CN88') OR (@UserRole=2 AND (site <> 'CN88' OR Site IS NULL)))
        END

        -- + Search by nickname in Customer
        IF (@CustID IS NULL)
        BEGIN
            SELECT @CustID = custid,
                   @RoleID = roleid
            FROM bodb02.dbo.customer WITH (NOLOCK)
            WHERE username2 = CAST(@SearchInfo AS VARCHAR(200))
                  AND ((@UserRole=1 AND site = 'CN88') OR (@UserRole=2 AND (site <> 'CN88' OR Site IS NULL)))
        END

        -- + Search by phone in Customer
        IF (@custID IS NULL)
        BEGIN
            SELECT @CustID = c.custID,
                   @RoleID = c.roleid
            FROM bodb02.dbo.Customer c WITH (NOLOCK)
            WHERE (c.phone = @SearchInfo OR c.mobilephone = @SearchInfo)
                  AND ((@UserRole=1 AND c.site = 'CN88') OR (@UserRole=2 AND ISNULL(c.site,'') <> 'CN88'))
        END                    

        -- + Search by username|phone in crmCustomer
        IF (@CustID IS NULL)
        BEGIN
            SELECT @CustID = CustID 
            FROM bodb_CRM.dbo.crmCustomer WITH (NOLOCK)
            WHERE CustID > 0
                  AND ((@UserRole = 2 AND SiteID <> 33002) OR (@UserRole = 1 AND SiteID = 33002))
                  AND (UserName = @SearchInfo
                       OR PhoneCountryCode+PhoneAreaCode+Phone = @SearchInfo
                       OR Phone2CountryCode+Phone2AreaCode+Phone2 = @SearchInfo
                       OR Phone3CountryCode+Phone3AreaCode+Phone3 = @SearchInfo
                       OR MobilePhoneCountryCode+MobilePhoneAreaCode+MobilePhone = @SearchInfo)
        END

        -- + Search by phone in crmPicManagement|crmCustomer|crmPIC|crmPICCommunication
        IF (@CustID IS NULL)
        BEGIN
            SELECT @CustID = c.CustID
            FROM bodb_CRM.dbo.crmPicManagement pm WITH (NOLOCK)
                 INNER JOIN bodb_CRM.dbo.crmCustomer c WITH (NOLOCK) ON pm.HeadlineID = c.CustID
                 INNER JOIN bodb_CRM.dbo.crmPIC p WITH (NOLOCK) ON pm.PicID = p.PicID
                 INNER JOIN bodb_CRM.dbo.crmPICCommunication pc WITH (NOLOCK) ON p.PicID = pc.PicID
            WHERE c.CustID > 0
                  AND ((@UserRole = 2 AND c.SiteID <> 33002) OR (@UserRole = 1 AND c.SiteID = 33002))
                  AND pc.CommunicationID = 49001
                  AND pc.CommunicationValue LIKE '%' + @SearchInfo + '%'
        END

        -- + Search by phone in crmCustomerNewCommunicationTool
        IF (@CustID IS NULL)
        BEGIN
            SELECT @CustID = c.CustID
            FROM bodb_CRM.dbo.crmCustomerNewCommunicationTool cc WITH (NOLOCK)
                 INNER JOIN bodb_CRM.dbo.crmCustomer c WITH (NOLOCK) ON cc.CustID = c.CustID
            WHERE c.CustID > 0
                  AND ((@UserRole = 2 AND c.SiteID <> 33002) OR (@UserRole = 1 AND c.SiteID = 33002))
                  AND cc.CommunicationID = 49001
                  AND cc.CommunicationValue LIKE '%' + @SearchInfo + '%'
        END

        -- + RETURN when search all system but cannot find customer
        IF (@custID IS NULL)
        BEGIN
            PRINT 'No Customer'
            RETURN
        END

        -- + Check permisstion
        IF (@IsCheckPermission = 1)
        BEGIN
            CREATE TABLE #tmpCust_01 (
                CustID         INT,
                SiteOffer      INT,
                IsLicensee     INT,
                SitePermission NVARCHAR(100)
            )

            IF NOT EXISTS (SELECT TOP 1 1 FROM #tmpCust_01)
            BEGIN
                INSERT INTO #tmpCust_01 (
                    CustID,
                    SiteOffer,
                    IsLicensee,
                    SitePermission
                )
                SELECT custid,
                       s.SiteOffer,
                       s.IsLicensee,
                       sp.SitePermission
                FROM bodb02.dbo.Customer c WITH (NOLOCK)
                     LEFT JOIN #tmpSite s ON CASE WHEN c.site = 'IBO' THEN 'Kzing'
                                                  WHEN c.site = 'KeenOcean' THEN 'LIVV88'
                                                  ELSE c.site END = s.SiteName
                     LEFT JOIN #tmpSitePermission sp ON s.SiteID = sp.SiteID
                WHERE c.custid = @custID
            END
            
            IF NOT EXISTS (SELECT TOP 1 1 FROM #tmpCust_01)
            BEGIN
               INSERT INTO #tmpCust_01 (
                    CustID,
                    SiteOffer,
                    IsLicensee,
                    SitePermission
                )
                SELECT custid,
                       s.SiteOffer,
                       s.IsLicensee,
                       sp.SitePermission
                FROM bodb_CRM.dbo.crmCustomer c WITH (NOLOCK)
                     LEFT JOIN #tmpSite s ON c.SiteID = s.SiteID
                     LEFT JOIN #tmpSitePermission sp ON s.SiteID = sp.SiteID
                WHERE c.custid = @custID
            END

            IF NOT EXISTS (
                              SELECT TOP 1 1
                              FROM #tmpCust_01 c
                                   LEFT JOIN #tmpUserSitePermission usp ON c.SitePermission = usp.SitePermission
                              WHERE (c.SiteOffer = 2 OR c.SiteOffer IS NULL)
                                    AND @LicenseeType <> -1
                                    AND (c.IsLicensee IS NULL
                                         OR c.IsLicensee = CASE WHEN @LicenseeType = 0 THEN c.IsLicensee WHEN @LicenseeType = 1 THEN 0 ELSE 1 END)
                                    AND ((c.SitePermission IS NULL AND ISNULL(c.IsLicensee, 1) = 1)
                                         OR c.SitePermission = usp.SitePermission)
                          )
            BEGIN
                SET @ErrCode = 101
                SET @ErrMsg = 'You are not authorized to search this account'
                RETURN
            END

            DROP TABLE #tmpCust_01
        END

        -- + @StatusCN88
        IF (@UserRole = 1)
        BEGIN
            SELECT @StatusCN88 = CASE WHEN CustStatus = 1 THEN 'Inactive' 
                                      WHEN CustStatus = 2 THEN 'Suspended' 
                                      WHEN CustStatus = 3 THEN 'View Only' 
                                      WHEN CustStatus = 4 THEN 'Active' END
            FROM bodb02.dbo.f_CS_GetCustomerStatus(@custID)
        END

        -- + @IsGroupHeadLine
        SELECT @IsGroupHeadLine = ISNULL(IsGroupHeadLine, 0)
        FROM bodb02.dbo.custAccount WITH (NOLOCK)
        WHERE custid = @CustID
              AND IsGroupHeadLine = 1

        -- + Get data from MainDB to return
        IF NOT EXISTS (SELECT 1 FROM bodb_CRM.dbo.crmCustomer WITH (NOLOCK) WHERE CustID = @CustID)
        BEGIN
            -- + --> @SiteID
            SELECT @SiteID = SettingID 
            FROM bodb_CRM.dbo.crmSetting WITH (NOLOCK) 
            WHERE SettingValue = (SELECT CASE WHEN c.site = 'IBO' THEN 'Kzing'
												WHEN c.site = 'KeenOcean' THEN 'LIVV88'
                                                ELSE c.site END site
                                    FROM bodb02.dbo.customer c WITH (NOLOCK)
                                    WHERE c.custid = @CustID)
                    AND SettingName IN ('Site', 'SiteCategory')

            -- + --> @CountryName|@CountryID
            SELECT @CountryName = cm.country,
                   @CountryID   = c.CountryID
            FROM bodb02.dbo.Customer cm WITH (NOLOCK)
                 INNER JOIN bodb_CRM.dbo.crmCountry c WITH (NOLOCK) ON cm.country = c.CountryName
            WHERE cm.custid = @custID

            -- + --> Return full customer information
            SELECT c.CustID,
                   c.UserName,
                   cm.UserName2,
                   crm.TitleID,
                   cm.FirstName FirstName,
                   cm.LastName LastName,
                   cm.phone Phone,
                   crm.PhoneCountryCode,
                   crm.PhoneAreaCode,
                   crm.Phone2,
                   crm.Phone2CountryCode,
                   crm.Phone2AreaCode,
                   crm.Phone3,
                   crm.Phone3CountryCode,
                   crm.Phone3AreaCode,
                   cm.MobilePhone MobilePhone,
                   crm.MobilePhoneCountryCode,
                   crm.MobilePhoneAreaCode,
                   cm.Fax Fax,
                   crm.FaxCountryCode,
                   crm.FaxAreaCode,
                   cm.Email Email,
                   crm.Skype,
                   crm.msn,
                   cm.Birthday Birthday,
                   crm.RefCode1,
                   crm.RefCode2,
                   crm.Pic1,
                   crm.Pic2,
                   crm.Pic3,
                   crm.Pic4,
                   crm.Pic1Name,
                   crm.Pic2Name,
                   crm.Pic3Name,
                   crm.Pic4Name,
                   crm.Question,
                   crm.Answer,
                   ISNULL(crm.CountryID,@CountryID) CountryID,
                   ct.CountryName,
                   crm.IsVIP,
                   ISNULL(crm.SiteID,@SiteID) as SiteID,
                   crm.Wire_BankName,
                   crm.Wire_BankAddress,
                   crm.Wire_SwiftCode,
                   crm.Wire_AccountName,
                   crm.Wire_AccountNo,
                   crm.Remark,
                   crm.CreateDate,
                   ci.Username as CreatorName,
                   CASE WHEN c.roleid=1 AND @UserRole=2 THEN 7000
                        WHEN c.roleid=2 AND @UserRole=2 THEN 7001
                        WHEN c.roleid=3 AND @UserRole=2 THEN 7002
                        WHEN c.roleid=4 AND @UserRole=2 THEN 7003
                        WHEN (c.roleid NOT IN(1,2,3,4) OR c.roleid IS NULL) AND @UserRole=2  THEN -1
                        WHEN c.roleid=1 AND @UserRole=1 THEN 7011
                        WHEN c.roleid=2 AND @UserRole=1 THEN 7007
                        WHEN c.roleid=3 AND @UserRole=1 THEN 7008
                        WHEN c.roleid=4 AND @UserRole=1 THEN 7009
                        WHEN c.roleid=0 AND @UserRole=1 THEN 7006
                        WHEN (c.roleid NOT IN(1,2,3,4,0) OR c.roleid IS NULL) AND @UserRole=1 THEN -1
                   END AS RoleID,
                   c.danger,
                   c.danger2,
                   c.danger3,
                   CASE WHEN @UserRole = 2 THEN CASE WHEN ((s.custid IS NOT NULL AND c.Closed = 1) OR (s.custid IS NULL AND ISNULL(CloseInfo,0) > 0)) THEN 'Closed'
                                                     WHEN ((s.custid IS NOT NULL AND c.Closed = 0 AND ISNULL(c.reject,0) = 1 ) OR (s.custid IS NULL AND ISNULL(ps.CloseInfo,0) = 0 AND ISNULL(ps.SuspendInfo,0) > 0)) THEN 'Suspended'
                                                     WHEN c.custid IS NULL THEN 'Archived'
                                                     WHEN s.custid IS NULL AND ps.Locked > 0 THEN 'Locked'
                                                     WHEN ((s.custid IS NOT NULL AND c.Closed = 0 AND ISNULL(c.reject,0) = 0) OR (s.custid IS NULL AND ISNULL(ps.SuspendInfo,0) = 0 AND ISNULL(ps.CloseInfo,0) = 0))THEN 'Active' END
                        WHEN @UserRole = 1 THEN @StatusCN88 END AS CustStatus,
                   CASE WHEN @UserRole = 1 THEN CASE WHEN c.Closed = 1 THEN 1 ELSE 0 END ELSE NULL END Locked,
                   @IsGroupHeadLine IsGroupHeadLine,
                   ISNULL(crm.LicenseeType,0) LicenseeType,
                   '' WhatsApp,
                   '' Line,
                   '' WeChat,
                   '' Yahoo,
                   '' QQ,
                   '' BBM,
                   ISNULL(crm.Ignored,0) AS Ignored,
                   crm.Checker,
                   CASE WHEN @UserRole=1 AND crm.ProvinceID IS NULL THEN 1 ELSE crm.ProvinceID END AS ProvinceID
            FROM bodb02.dbo.custinfo c WITH (NOLOCK)
                 LEFT JOIN bodb_CRM.dbo.crmCustomer crm WITH (NOLOCK) ON c.custID = crm.custID
                 LEFT JOIN bodb02.dbo.custinfo ci WITH (NOLOCK) ON crm.CreatorID = ci.custID
                 LEFT JOIN bodb_CRM.dbo.crmCountry ct WITH (NOLOCK) ON ct.CountryID = crm.CountryID
                 LEFT JOIN bodb02.dbo.Customer cm WITH (NOLOCK) on c.custID = cm.CustID
                 LEFT JOIN bodb02.dbo.Dep_CustSuper s WITH (NOLOCK) ON c.srecommend = s.custid
                 LEFT JOIN bodb02.dbo.CustProductStatus ps WITH (NOLOCK) on c.custid = ps.custid
            WHERE c.custID = @custID
        END

        -- + Get data from CRM to return
        ELSE
        BEGIN
            SELECT crm.CustID,
                   crm.UserName,
                   cm.username2,
                   crm.TitleID,
                   crm.FirstName,
                   crm.LastName,
                   crm.Phone,
                   crm.PhoneCountryCode,
                   crm.PhoneAreaCode,
                   crm.Phone2,
                   crm.Phone2CountryCode,
                   crm.Phone2AreaCode,
                   crm.Phone3,
                   crm.Phone3CountryCode,
                   crm.Phone3AreaCode,
                   crm.MobilePhone,
                   crm.MobilePhoneCountryCode,
                   crm.MobilePhoneAreaCode,
                   crm.Fax,
                   crm.FaxCountryCode,
                   crm.FaxAreaCode,
                   crm.Email,
                   crm.Skype,
                   crm.msn,
                   crm.Birthday,
                   crm.RefCode1,
                   crm.RefCode2,
                   crm.Pic1,
                   crm.Pic2,
                   crm.Pic3,
                   crm.Pic4,
                   crm.Pic1Name,
                   crm.Pic2Name,
                   crm.Pic3Name,
                   crm.Pic4Name,
                   crm.Question,
                   crm.Answer,
                   crm.CountryID,
                   ct.CountryName,
                   crm.IsVIP,
                   crm.SiteID,
                   crm.Wire_BankName,
                   crm.Wire_BankAddress,
                   crm.Wire_SwiftCode,
                   crm.Wire_AccountName,
                   crm.Wire_AccountNo,
                   crm.Remark,
                   crm.CreateDate,
                   ci.Username as CreatorName,
                   CASE WHEN c.roleid=1 AND @UserRole=2 THEN 7000
                        WHEN c.roleid=2 AND @UserRole=2 THEN 7001
                        WHEN c.roleid=3 AND @UserRole=2 THEN 7002
                        WHEN c.roleid=4 AND @UserRole=2 THEN 7003
                        WHEN (c.roleid NOT IN(1,2,3,4) OR c.roleid IS NULL) AND @UserRole=2  THEN -1
                        WHEN c.roleid=1 AND @UserRole=1 THEN 7011
                        WHEN c.roleid=2 AND @UserRole=1 THEN 7007
                        WHEN c.roleid=3 AND @UserRole=1 THEN 7008
                        WHEN c.roleid=4 AND @UserRole=1 THEN 7009
                        WHEN c.roleid=0 AND @UserRole=1 THEN 7006
                        WHEN (c.roleid NOT IN(1,2,3,4,0) OR c.roleid IS NULL) AND @UserRole=1 THEN -1
                   END AS RoleID,
                   c.danger,
                   c.danger2,
                   c.danger3,
                   CASE WHEN @UserRole = 2 THEN CASE WHEN ((s.custid IS NOT NULL AND c.Closed = 1) OR (s.custid IS NULL AND ISNULL(CloseInfo,0) > 0)) THEN 'Closed'
                                                     WHEN ((s.custid IS NOT NULL AND c.Closed = 0 AND ISNULL(c.reject,0) = 1 ) OR (s.custid IS NULL AND ISNULL(ps.CloseInfo,0) = 0 AND ISNULL(ps.SuspendInfo,0) > 0)) THEN 'Suspended'
                                                     WHEN c.custid IS NULL THEN 'Archived'
                                                     WHEN s.custid IS NULL AND ps.Locked > 0 THEN 'Locked'
                                                     WHEN ((s.custid IS NOT NULL AND c.Closed = 0 AND ISNULL(c.reject,0) = 0) OR (s.custid IS NULL AND ISNULL(ps.SuspendInfo,0) = 0 AND ISNULL(ps.CloseInfo,0) = 0))THEN 'Active' END
                        WHEN @UserRole = 1 THEN @StatusCN88 END AS CustStatus,
                   CASE WHEN @UserRole = 1 THEN CASE WHEN c.Closed = 1 THEN 1 ELSE 0 END ELSE NULL END Locked,
                   @IsGroupHeadLine IsGroupHeadLine,
                   ISNULL(crm.LicenseeType,0) LicenseeType,
                   ISNULL(crm.WhatsApp,'') WhatsApp,
                   ISNULL(crm.Line,'') Line,
                   ISNULL(crm.WeChat,'') WeChat,
                   ISNULL(crm.Yahoo,'') Yahoo,
                   ISNULL(crm.QQ,'') QQ,
                   ISNULL(crm.BBM,'') BBM,
                   ISNULL(crm.Ignored,0) AS Ignored ,
                   crm.Checker,
                   CASE WHEN @UserRole=1 AND crm.ProvinceID IS NULL THEN 1 ELSE crm.ProvinceID END AS ProvinceID
            FROM bodb_CRM.dbo.crmCustomer crm WITH (NOLOCK)
                 LEFT JOIN bodb02.dbo.custinfo ci WITH (NOLOCK) ON crm.CreatorID = ci.custID
                 LEFT JOIN bodb_CRM.dbo.crmCountry ct WITH (NOLOCK) ON ct.CountryID = crm.CountryID
                 LEFT JOIN bodb02.dbo.customer cm WITH (NOLOCK) ON cm.custid = crm.custID
                 LEFT JOIN bodb02.dbo.custinfo c WITH (NOLOCK) ON c.custid = crm.CustID
                 LEFT JOIN bodb02.dbo.Dep_CustSuper s WITH (NOLOCK) ON c.srecommend = s.custid
                 LEFT JOIN bodb02.dbo.CustProductStatus ps WITH (NOLOCK) on crm.custid = ps.custid
            WHERE crm.custID = @custID            
        END
    END

    -- For guest customer
    IF (@IsGuest = 1)
    BEGIN        

        -- + Search by username|phone in crmCustomer
        IF (@CustID IS NULL)
        BEGIN
            SELECT @CustID = CustID 
            FROM bodb_CRM.dbo.crmCustomer WITH (NOLOCK)
            WHERE CustID < 0
                  AND ((@UserRole = 2 AND SiteID <> 33002) OR (@UserRole = 1 AND SiteID = 33002))
                  AND (UserName = @SearchInfo
                       OR PhoneCountryCode+PhoneAreaCode+Phone = @SearchInfo
                       OR Phone2CountryCode+Phone2AreaCode+Phone2 = @SearchInfo
                       OR Phone3CountryCode+Phone3AreaCode+Phone3 = @SearchInfo
                       OR MobilePhoneCountryCode+MobilePhoneAreaCode+MobilePhone = @SearchInfo)
        END

        -- + Search by phone in crmPicManagement|crmCustomer|crmPIC|crmPICCommunication
        IF (@CustID IS NULL)
        BEGIN
            SELECT @CustID = c.CustID
            FROM bodb_CRM.dbo.crmPicManagement pm WITH (NOLOCK)
                 INNER JOIN bodb_CRM.dbo.crmCustomer c WITH (NOLOCK) ON pm.HeadlineID = c.CustID
                 INNER JOIN bodb_CRM.dbo.crmPIC p WITH (NOLOCK) ON pm.PicID = p.PicID
                 INNER JOIN bodb_CRM.dbo.crmPICCommunication pc WITH (NOLOCK) ON p.PicID = pc.PicID
            WHERE c.CustID < 0
                  AND ((@UserRole = 2 AND c.SiteID <> 33002) OR (@UserRole = 1 AND c.SiteID = 33002))
                  AND pc.CommunicationID = 49001
                  AND pc.CommunicationValue LIKE '%' + @SearchInfo + '%'
        END

        -- + Search by phone in crmCustomerNewCommunicationTool
        IF (@CustID IS NULL)
        BEGIN
            SELECT @CustID = c.CustID
            FROM bodb_CRM.dbo.crmCustomerNewCommunicationTool cc WITH (NOLOCK)
                 INNER JOIN bodb_CRM.dbo.crmCustomer c WITH (NOLOCK) ON cc.CustID = c.CustID
            WHERE c.CustID < 0
                  AND ((@UserRole = 2 AND c.SiteID <> 33002) OR (@UserRole = 1 AND c.SiteID = 33002))
                  AND cc.CommunicationID = 49001
                  AND cc.CommunicationValue LIKE '%' + @SearchInfo + '%'
        END

        -- + RETURN when search all system but cannot find customer
        IF (@custID IS NULL)
        BEGIN
            PRINT 'No Customer'
            RETURN
        END

        -- + Check permisstion
        IF (@IsCheckPermission = 1)
        BEGIN
            CREATE TABLE #tmpCust_02 (
                CustID         INT,
                SiteOffer      INT,
                IsLicensee     INT,
                SitePermission NVARCHAR(100)
            )

            INSERT INTO #tmpCust_02 (
                CustID,
                SiteOffer,
                IsLicensee,
                SitePermission
            )
            SELECT custid,
                   s.SiteOffer,
                   s.IsLicensee,
                   sp.SitePermission
            FROM bodb_CRM.dbo.crmCustomer c WITH (NOLOCK)
                 LEFT JOIN #tmpSite s ON c.SiteID = s.SiteID
                 LEFT JOIN #tmpSitePermission sp ON s.SiteID = sp.SiteID
            WHERE c.custid = @custID

            IF NOT EXISTS (
                              SELECT TOP 1 1
                              FROM #tmpCust_02 c
                                   LEFT JOIN #tmpUserSitePermission usp ON c.SitePermission = usp.SitePermission
                              WHERE (c.SiteOffer = 2 OR c.SiteOffer IS NULL)
                                    AND @LicenseeType <> -1
                                    AND (c.IsLicensee IS NULL
                                         OR c.IsLicensee = CASE WHEN @LicenseeType = 0 THEN c.IsLicensee WHEN @LicenseeType = 1 THEN 0 ELSE 1 END)
                                    AND ((c.SitePermission IS NULL AND ISNULL(c.IsLicensee, 1) = 1)
                                         OR c.SitePermission = usp.SitePermission)
                          )
            BEGIN
                SET @ErrCode = 101
                SET @ErrMsg = 'You are not authorized to search this account'
                RETURN
            END

            DROP TABLE #tmpCust_02
        END

        -- + Return full customer information
        SELECT crm.CustID, 
               crm.UserName, 
               crm.TitleID, 
               crm.FirstName, 
               crm.LastName, 
               crm.Phone, 
               crm.PhoneCountryCode,
               crm.PhoneAreaCode,
               crm.Phone2,
               crm.Phone2CountryCode,
               crm.Phone2AreaCode,
               crm.Phone3,
               crm.Phone3CountryCode,
               crm.Phone3AreaCode,
               crm.MobilePhone,
               crm.MobilePhoneCountryCode,
               crm.MobilePhoneAreaCode,
               crm.Fax, 
               crm.FaxCountryCode, 
               crm.FaxAreaCode, 
               crm.Email, 
               crm.Skype,
               crm.msn,
               crm.Birthday, 
               crm.RefCode1, 
               crm.RefCode2, 
               crm.Pic1, 
               crm.Pic2, 
               crm.Pic3,
               crm.Pic4,
               crm.Pic1Name, 
               crm.Pic2Name, 
               crm.Pic3Name,
               crm.Pic4Name,
               crm.Question, 
               crm.Answer, 
               crm.CountryID,
               ct.CountryName, 
               crm.IsVIP,
               crm.SiteID,
               crm.Wire_BankName, 
               crm.Wire_BankAddress, 
               crm.Wire_SwiftCode, 
               crm.Wire_AccountName, 
               crm.Wire_AccountNo,
               crm.Remark, 
               crm.CreateDate, 
               ci.Username as CreatorName,
               CASE WHEN @UserRole=2 THEN 7004
                    WHEN @UserRole=1 THEN 7010 END AS roleID,
               danger = NULL,
               danger2 = NULL,
               danger3 = NULL,
               CustStatus = NULL,
               Locked = NULL,
               CAST(0 as BIT) IsGroupHeadLine,
               ISNULL(crm.LicenseeType,0) LicenseeType,
               ISNULL(crm.WhatsApp,'') WhatsApp,
               ISNULL(crm.Line,'') Line,
               ISNULL(crm.WeChat,'') WeChat,
               ISNULL(crm.Yahoo,'') Yahoo,
               ISNULL(crm.QQ,'') QQ,
               ISNULL(crm.BBM,'') BBM,
               ISNULL(crm.Ignored,0) AS Ignored ,
               crm.Checker,
               CASE WHEN @UserRole=1 AND crm.ProvinceID IS NULL THEN 1 ELSE crm.ProvinceID END AS ProvinceID
        FROM bodb_CRM.dbo.crmCustomer crm WITH (NOLOCK) 
             LEFT JOIN bodb02.dbo.custinfo ci WITH (NOLOCK) ON crm.CreatorID = ci.custID
             LEFT JOIN bodb_CRM.dbo.crmCountry ct WITH (NOLOCK) ON ct.CountryID = crm.CountryID                        
        WHERE crm.custID = @custID

    END

    -- Return customer language information
    SELECT cl.LanguageID FROM bodb_CRM.dbo.crmCustomerLanguage cl WITH (NOLOCK) WHERE CustID = @custID


    --------------------
    -- DROP temp tables

    DROP TABLE #tmpUserSitePermission
    DROP TABLE #tmpSite
    DROP TABLE #tmpSitePermission

END
GO