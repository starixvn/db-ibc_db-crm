/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE [dbo].[Acc_CRM_SettingRelationSel]
	@UserRole		INT
AS

/*
Created: Lukas
Date: 20101104
Task : Get Setting relation list
DB: DB06.bodb_CRM
Original:

Revisions:
	- 20190506@Winnie: CN88 Permission RedmineID: #112637
    - 20231107@Ned.Le: CRM - Category/sub-category/admin tool (Setting Management) can show by Alphabet (#193380)

Param's Explanation:	
*/

BEGIN
	SET NOCOUNT ON
	
	SELECT	rel.SettingID, 
			rel.ParentID
	FROM 
		crmSettingRelation rel WITH(NOLOCK) 
				INNER JOIN crmSetting s WITH(NOLOCK) ON rel.SettingID = s.SettingID
				INNER JOIN crmSetting p WITH(NOLOCK) ON rel.SettingID = p.SettingID
	WHERE
		s.IsActive = 1
		AND
		p.IsActive = 1
		AND s.SiteOffer=@UserRole
	ORDER BY 
		SettingID, ParentID
END
GO
GRANT EXECUTE ON [dbo].[Acc_CRM_SettingRelationSel] TO [bodbAdminNet]
GO
