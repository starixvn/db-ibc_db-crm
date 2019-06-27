/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_InformHeadlineStatusSel]
	@Mode		BIT = 0,
	@UserRole	TINYINT=2
AS
/*
	Created: Elodie
	Date: 20150331
	Task : get inform headline status
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:	
		- 20190506@Winnie:  CN88 Permission RedmineID: #112637
	Param's Explanation:			
*/
BEGIN
	IF @Mode = 0
		SELECT SettingID, SettingValue
		FROM crmSetting s WITH (NOLOCK) 
		WHERE s.SettingName = 'InformHeadlineStatus' AND s.SettingID NOT IN( 45007,45015)
			AND s.SiteOffer=@UserRole
	ELSE
		SELECT SettingID, SettingValue
		FROM crmSetting s WITH (NOLOCK) 
		WHERE s.SettingName = 'InformHeadlineStatus'
			AND s.SiteOffer=@UserRole
END

GO 
GRANT EXECUTE ON [dbo].[Acc_CRM_InformHeadlineStatusSel] TO [bodbAdminNet]
GO 
