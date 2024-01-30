/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE dbo.Acc_CRM_SiteSel_InformHeadline
AS

/*
    Created: 20240125@Ned.Le
    Task:    Get list of credit site for function inform headline
    DB:      DBCRM/bodb_CRM

    Revisions:
        20240125@Ned.Le: CRM - Security improvement - Separate accessible data for Credit Sites (#197343)

    Example:
        EXEC bodb_CRM.dbo.Acc_CRM_SiteSel_InformHeadline
*/

BEGIN

    SET NOCOUNT ON

    SELECT si.SettingID SiteID,
           si.SettingValue SiteName,
           0 IsLicensee,
           si.IsActive IsActive,
           si.ExtraInfo SiteLabel,
           sc.SiteOffer SiteOffer
    FROM bodb_CRM.dbo.crmSettingRelation sr WITH (NOLOCK)
         INNER JOIN bodb_CRM.dbo.crmSetting sc WITH (NOLOCK) ON sc.SettingName = 'SiteCategory' AND sr.ParentID = sc.SettingID
         INNER JOIN	bodb_CRM.dbo.crmSetting si WITH (NOLOCK) ON si.SettingName = 'Site' AND sr.SettingID = si.SettingID
    WHERE sr.ParentID IN (33001)

END
GO