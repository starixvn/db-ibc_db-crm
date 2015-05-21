ALTER PROCEDURE [dbo].[Acc_CRM_InformHeadlineStatusSel]
	@Mode BIT = 0
AS
/*
	Created: Elodie
	Date: 20150331
	Task : get inform headline status
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:	
	
	Param's Explanation:			
*/
BEGIN
	IF @Mode = 0
		SELECT SettingID, SettingValue
		FROM crmSetting s WITH (NOLOCK) 
		WHERE s.SettingName = 'InformHeadlineStatus' AND s.SettingID <> 45007
	ELSE
		SELECT SettingID, SettingValue
		FROM crmSetting s WITH (NOLOCK) 
		WHERE s.SettingName = 'InformHeadlineStatus'
END

GO 
GRANT EXECUTE ON [dbo].[Acc_CRM_InformHeadlineStatusSel] TO [bodbAdminNet]
GO 
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_InformHeadlineStatusSel] TO [vnteam]