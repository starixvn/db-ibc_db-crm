
ALTER PROCEDURE [dbo].[Acc_CRM_SettingRelationSel]
AS
/*
Created: Lukas
Date: 20101104
Task : Get Setting relation list
DB: DB06.bodb_CRM
Original:

Revisions:
	
Param's Explanation:
	
*/
BEGIN
	SET NOCOUNT ON
	
	SELECT	rel.SettingID, 
			rel.ParentID, 
			rel.DisplayOrder 
	FROM 
		crmSettingRelation rel WITH(NOLOCK) 
				INNER JOIN crmSetting s WITH(NOLOCK) ON rel.SettingID = s.SettingID
				INNER JOIN crmSetting p WITH(NOLOCK) ON rel.SettingID = p.SettingID
	WHERE
		s.IsActive = 1
		AND
		p.IsActive = 1
	ORDER BY 
		SettingID, ParentID, DisplayOrder
END



GO
GRANT EXECUTE ON [dbo].[Acc_CRM_SettingRelationSel] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_SettingRelationSel] TO [vnteam]