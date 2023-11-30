/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE dbo.Acc_CRM_SiteSel @LicenseeType TINYINT      = 0,
                                    @SiteLabel    VARCHAR(MAX) = NULL,
                                    @UserRole     TINYINT      = 2,
                                    @Lang         VARCHAR(10)  ='en-US'
AS

/*
    Created:  20140522@Dom
    Task:     Get all site
    DB:       DBCRM/bodb_CRM
    Original:

    Revisions:
        - 20150403@Elodie: Filter by licensee type
        - 20160328@Billy:  Integrate Sub-Product Setting - [Redmine: #50691]
        - 20190507@Winnie: CN88     [RedmineID:#112637]
        - 20220202@Tacy:   Split 789y site [RedmineID: #182438]
        - 20231107@Ned.Le: CRM - Category/sub-category/admin tool (Setting Management) can show by Alphabet (#193380)
        - 20231128@Ned.Le: CRM - Security improvement - Separate accessible data for Credit Sites (#197343)

    Param's Explanation:
        - @LicenseeType = 0: Both
                          1: Credit
                          2: Licensee
        - @Lang = en-US
                  zh-TW
                  zh-CN
        - @SiteLabel: Value depend on user's permission and maybe NULL

    Example: EXEC Acc_CRM_SiteSel_UAT3 @LicenseeType=1, @UserRole=2, @SiteLabel=NULL
*/

BEGIN

    SET NOCOUNT ON

    -- Prepare data
    CREATE TABLE #tmpSiteLabel (SiteLabel VARCHAR(50))

    INSERT INTO #tmpSiteLabel (SiteLabel)
    SELECT value SiteLabel
    FROM STRING_SPLIT(@SiteLabel, ',')

    -- Return data
    IF (@UserRole=2)
    BEGIN
        SELECT s.SiteLabel,
               s.SiteID,
               s.SiteName,
               s.IsLicensee,
               s.IsActive
        FROM (
                 SELECT s.ExtraInfo SiteLabel,
                        s.SettingID SiteID,
                        CASE WHEN @Lang='zh-TW' THEN ISNULL(s.SettingValueCT,s.SettingValue)
                             WHEN @Lang='zh-CN' THEN ISNULL(s.SettingValueCS,s.SettingValue)
                             ELSE s.SettingValue END SiteName,
                        CASE sr.ParentID WHEN 33000 THEN 1
                                         WHEN 33001 THEN 0
                                         ELSE -1 END IsLicensee,
                        s.IsActive IsActive
                 FROM bodb_CRM.dbo.crmSettingRelation sr WITH (NOLOCK)
                      INNER JOIN bodb_CRM.dbo.crmSetting s WITH (NOLOCK) ON sr.SettingID = s.SettingID AND s.SettingName = 'Site'
                 WHERE ParentID IN (33000, 33001)
             ) s
             LEFT JOIN #tmpSiteLabel sl ON s.SiteLabel = sl.SiteLabel
        WHERE s.IsLicensee = CASE WHEN @LicenseeType = 0 THEN s.IsLicensee WHEN @LicenseeType = 1 THEN 0 ELSE 1 END
              AND (ISNULL(s.SiteLabel, '') = CASE WHEN @LicenseeType = 0 THEN CASE WHEN s.IsLicensee = 0 THEN sl.SiteLabel ELSE ISNULL(s.SiteLabel, '') END
                                                  WHEN @LicenseeType = 1 THEN sl.SiteLabel
                                                  WHEN @LicenseeType = 2 THEN ISNULL(s.SiteLabel, '') END)
        ORDER BY s.IsActive DESC,
                 s.IsLicensee,
                 s.SiteName
    END
    ELSE IF (@UserRole=1)
    BEGIN
        SELECT NULL SiteLabel,
               s.SettingID SiteID,
               CASE WHEN @Lang='zh-TW' THEN ISNULL(s.SettingValueCT,s.SettingValue)
                    WHEN @Lang='zh-CN' THEN ISNULL(s.SettingValueCS,s.SettingValue)
                    ELSE s.SettingValue END SiteName, 
               0 IsLicensee,
               s.IsActive
        FROM bodb_CRM.dbo.crmSetting s WITH (NOLOCK)
        WHERE s.SettingID = 33002
        ORDER BY SiteName
    END

    -- Drop data
    DROP TABLE #tmpSiteLabel

END
GO