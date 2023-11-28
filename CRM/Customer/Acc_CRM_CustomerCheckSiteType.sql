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
*/

BEGIN

    SET NOCOUNT ON

    -- #tmpSite
    CREATE TABLE #tmpSite (
        SiteID     INT,
        SiteName   NVARCHAR(100),
        SiteLabel  VARCHAR(50),
        IsLicensee INT
    )

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
                WHEN sr.ParentID = 33002 THEN 0
                ELSE -1 END IsLicensee
    FROM bodb_CRM.dbo.crmSettingRelation sr WITH (NOLOCK)
         INNER JOIN	bodb_CRM.dbo.crmSetting s WITH(NOLOCK) ON sr.SettingID = s.SettingID AND s.SettingName = 'Site'
    WHERE sr.ParentID IN (33000, 33001, 33002)

    CREATE CLUSTERED INDEX CIX_tmpSite ON #tmpSite(SiteID)

    -- #tmpCustInfo
    CREATE TABLE #tmpCustInfo (
        CustID    INT,
        Username  NVARCHAR(200),
        SiteType  INT,
        SiteLabel VARCHAR(50)
    )

    IF NOT EXISTS (SELECT TOP 1 1 FROM #tmpCustInfo)
    BEGIN
        INSERT INTO #tmpCustInfo (
            CustID,
            Username,
            SiteType,
            SiteLabel
        )
        SELECT c.custid CustID,
               c.username Username,
               CASE WHEN s.IsLicensee = 0 THEN 1
                    WHEN s.IsLicensee = 1 THEN 2
                    ELSE 0 END SiteType,
               s.SiteLabel
        FROM bodb02.dbo.Customer c WITH (NOLOCK)
             LEFT JOIN #tmpSite s ON c.site = s.SiteName
        WHERE c.custid = @custID
    END

    IF NOT EXISTS (SELECT TOP 1 1 FROM #tmpCustInfo)
    BEGIN
        INSERT INTO #tmpCustInfo (
            CustID,
            Username,
            SiteType,
            SiteLabel
        )
        SELECT c.CustID CustID,
               c.UserName Username,
               CASE WHEN s.IsLicensee = 0 THEN 1
                    WHEN s.IsLicensee = 1 THEN 2
                    ELSE 0 END SiteType,
               s.SiteLabel
        FROM bodb_CRM.dbo.crmCustomer c WITH (NOLOCK)
             LEFT JOIN #tmpSite s ON c.SiteID = s.SiteID
        WHERE c.CustID = @CustID
    END

    -- Check and return data
    IF NOT EXISTS (SELECT TOP 1 1 FROM #tmpCustInfo)
    BEGIN
        SET @ErrCode = 101
        SET @ErrMsg = 'This CustID is not exists'
        RETURN
    END

    SELECT SiteType, SiteLabel FROM #tmpCustInfo

    -- Drop temp tables
    DROP TABLE #tmpSite
    DROP TABLE #tmpCustInfo

END
GO