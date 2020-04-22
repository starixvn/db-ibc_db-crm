/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.Acc_CRM_SourceLicenseeMappingSel	
AS
/*
	Created: 20200421@Johnson	
	Task: get Licensee mapping  
	DB:	DBCRM/bodb_CRM
	Original:
	
	Revisions:
		- 20200422@Johnson: initial sp [redmine:#130949]
	
	Parameter's Explanations:
*/	
BEGIN
	SET NOCOUNT ON;
	
	SELECT s.SettingID, s.SettingValue as setting, m.site as SettingSource, l.username as LicenseeManager
	FROM crmSetting p WITH(NOLOCK)
		INNER JOIN crmSettingRelation r WITH(NOLOCK) on p.SettingID = r.ParentID
		INNER JOIN crmSetting s WITH(NOLOCK) ON r.SettingID = s.SettingID 
		LEFT JOIN crmLicenseeMapping m WITH(NOLOCK) ON s.SettingID = m.SettingID			
		LEFT JOIN crmCustomer l WITH(NOLOCK) ON m.custid = l.custid
	WHERE p.SettingName = 'SiteCategory'
		AND p.SettingValue = 'LicenseeSite'
		AND s.isActive = 1
		AND s.SiteOffer = 2--MBC
	ORDER BY Setting, SettingSource	
END	