/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Acc_CRM_SystemSettingMappingSel] 	
	@SettingName VARCHAR(50) = ''
AS
/*
	Created: 20200418@@Johnson
	Task : get system setting mapping for service auto feedback
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20200418@@Johnson: Initial sp [redmine:#130949]
	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON

	IF @SettingName IN ('SubProduct','Bettype')
	BEGIN
		SELECT s.SettingID, s.SettingName, m.SettingSource
		FROM crmSetting s WITH(NOLOCK)
			LEFT JOIN crmSettingMapping m WITH(NOLOCK) ON s.SettingID = m.SettingID
		WHERE s.SettingName = @SettingName
			AND s.isActive = 1
			AND s.SiteOffer = 2--MBC
		ORDER BY SettingName, SettingSource	
	END
	ELSE IF @SettingName = 'Site'
	BEGIN
		SELECT s.SettingID, s.SettingName, m.site as SettingSource, c.username as LicenseeManager
		FROM crmSetting p WITH(NOLOCK)
			INNER JOIN crmSettingRelation r WITH(NOLOCK) on p.SettingID = r.ParentID
			INNER JOIN crmSetting s WITH(NOLOCK) ON r.SettingID = s.SettingID 
			LEFT JOIN crmLicenseeMapping m WITH(NOLOCK) ON s.SettingID = m.SettingID
			LEFT JOIN crmCustomer l WITH(NOLOCK) ON m.custid = l.custid
		WHERE p.SettingName = 'SiteCategory'
			AND p.SettingValue = 'LicenseeSite'
			AND s.isActive = 1
			AND s.SiteOffer = 2--MBC
		ORDER BY SettingName, SettingSource			
	END
END
	