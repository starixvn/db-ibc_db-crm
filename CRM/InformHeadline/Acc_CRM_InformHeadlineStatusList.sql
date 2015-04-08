ALTER PROCEDURE [dbo].[Acc_CRM_InformHeadlineStatusList]
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
	SELECT SettingID, SettingValue
	FROM crmSetting s WITH (NOLOCK) 
	WHERE s.SettingName = 'InformHeadlineStatus' AND s.SettingValue <> 'Keep for reference'
END

GO 
GRANT EXECUTE ON [dbo].[Acc_CRM_InformHeadlineStatusList] TO [bodbAdminNet]
GO 
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_InformHeadlineStatusList] TO [vnteam]