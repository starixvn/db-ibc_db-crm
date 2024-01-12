/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE dbo.Acc_CRM_CustomerCheckSiteType @CustID   INT,
                                                  @ErrCode  INT            = 0  OUTPUT,
                                                  @ErrMsg   NVARCHAR(2000) = '' OUTPUT
AS

/*
    Created: Ned.Le
    Date: 20230919
    Task: Get site type (Credit or Licensee or N/A) of CustID
    DB: DBCRM.bodb_CRM

    Revisions:	
        20230919@Ned.Le: CRM - Security improvement - Separate accessible data for Credit and Licensee Users (#192556)
        20231128@Ned.Le: CRM - Security improvement - Separate accessible data for Credit Sites (#197343)

    Param's Explanation:
                          
    Example:
        DECLARE @ErrCode_out INT
        DECLARE @ErrMsg_out  NVARCHAR(2000)
        EXEC bodb_CRM.dbo.Acc_CRM_CustomerCheckSiteType @CustID   = 123456,
                                                        @ErrCode  = @ErrCode_out OUTPUT,
                                                        @ErrMsg   = @ErrMsg_out  OUTPUT
        SELECT @ErrCode_out, @ErrMsg_out
*/

BEGIN

    SET NOCOUNT ON

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
    FROM bodb_CRM.dbo.crmSetting sc
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

    -- #tmpCustInfo
    CREATE TABLE #tmpCustInfo (
        CustID         INT,
        Username       NVARCHAR(200),
        SiteType       INT,
        SitePermission VARCHAR(50)
    )

    IF NOT EXISTS (SELECT TOP 1 1 FROM #tmpCustInfo)
    BEGIN
        INSERT INTO #tmpCustInfo (
            CustID,
            Username,
            SiteType,
            SitePermission
        )
        SELECT c.custid CustID,
               c.username Username,
               CASE WHEN s.IsLicensee = 0 THEN 1
                    WHEN s.IsLicensee = 1 THEN 2
                    ELSE 0 END SiteType,
               sp.SitePermission SitePermission
        FROM bodb02.dbo.Customer c WITH (NOLOCK)
             LEFT JOIN #tmpSite s ON CASE WHEN c.site = 'IBO' THEN 'Kzing'
                                          WHEN c.site = 'KeenOcean' THEN 'LIVV88'
                                          ELSE c.site END = s.SiteName
             LEFT JOIN #tmpSitePermission sp ON s.SiteID = sp.SiteID
        WHERE c.custid = @custID
    END

    IF NOT EXISTS (SELECT TOP 1 1 FROM #tmpCustInfo)
    BEGIN
        INSERT INTO #tmpCustInfo (
            CustID,
            Username,
            SiteType,
            SitePermission
        )
        SELECT c.CustID CustID,
               c.UserName Username,
               CASE WHEN s.IsLicensee = 0 THEN 1
                    WHEN s.IsLicensee = 1 THEN 2
                    ELSE 0 END SiteType,
               sp.SitePermission SitePermission
        FROM bodb_CRM.dbo.crmCustomer c WITH (NOLOCK)
             LEFT JOIN #tmpSite s ON c.SiteID = s.SiteID
             LEFT JOIN #tmpSitePermission sp ON s.SiteID = sp.SiteID
        WHERE c.CustID = @CustID
    END

    -- Check and return data
    IF NOT EXISTS (SELECT TOP 1 1 FROM #tmpCustInfo)
    BEGIN
        SET @ErrCode = 101
        SET @ErrMsg = 'This CustID is not exists'
        RETURN
    END

    SELECT SiteType, SitePermission FROM #tmpCustInfo

    -- Drop temp tables
    DROP TABLE #tmpSite
    DROP TABLE #tmpSitePermission
    DROP TABLE #tmpCustInfo

END
GO