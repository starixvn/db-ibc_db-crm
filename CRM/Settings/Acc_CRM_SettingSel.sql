
ALTER PROCEDURE [dbo].[Acc_CRM_SettingSel]
AS
/*
Created: Khoa
Date: 20101020
Task : Get Setting list
DB: DB052.bodb_CRM
Original:

Revisions:
	- 20120425@Sophia: Edit Order by DisplayOrder before SettingID 
Param's Explanation:
	
*/
BEGIN
	SET NOCOUNT ON
	
	SELECT 
		SettingName, 
		SettingId, 
		SettingValue, 
		DisplayOrder 
	FROM 
		crmSetting WITH(NOLOCK)
	WHERE
		IsActive = 1
	ORDER BY 
		SettingName, DisplayOrder , SettingID 
END



GO
GRANT EXECUTE ON [dbo].[Acc_CRM_SettingSel] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_SettingSel] TO [vnteam]