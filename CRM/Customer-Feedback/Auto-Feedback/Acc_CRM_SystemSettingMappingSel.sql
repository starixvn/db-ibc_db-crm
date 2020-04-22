/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_SystemSettingMappingSel] 	
	@Settings VARCHAR(MAX) = ''
AS
/*
	Created: 20200418@Johnson
	Task : get system setting mapping for service auto feedback
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20200418@Johnson: Initial sp [redmine:#130949]
	Param's Explanation:
		- @Settings ='SubProduct,Bettype'
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @tmpSetting TABLE(SettingName VARCHAR(50))
	
	INSERT INTO @tmpSetting(SettingName)
	SELECT val
	FROM f_CRM_strSplit(@Settings,',')
	
	IF EXISTS (SELECT 1 FROM @tmpSetting WHERE SettingName IN ('SubProduct','Bettype'))
	BEGIN
		SELECT s.SettingID, s.SettingName, s.SettingValue, m.SettingSource
		FROM crmSetting s WITH(NOLOCK)
			LEFT JOIN crmSettingMapping m WITH(NOLOCK) ON s.SettingID = m.SettingID
		WHERE s.SettingName IN (SELECT SettingName FROM @tmpSetting WHERE SettingName IN ('SubProduct','Bettype')) 
			AND s.isActive = 1
			AND s.SiteOffer = 2--MBC
		ORDER BY SettingName, SettingSource	
	END
	
	IF EXISTS (SELECT 1 FROM @tmpSetting WHERE SettingName IN ('Site')) 
	BEGIN
		SELECT s.SettingID, s.SettingName, s.SettingValue, m.site as SettingSource, m.custid as LicenseeManagerID, l.username as LicenseeManager
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
	