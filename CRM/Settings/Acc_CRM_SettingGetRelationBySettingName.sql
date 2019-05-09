/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_SettingGetRelationBySettingName]
(
	@SettingName	VARCHAR(50),
	@ParentID		INT,
	@UserRole		TINYINT
)
AS
/*
Created: 
Date: 
Task : get setting relation 
DB: DB052.bodb_CRM
Original:

Revisions:
	- 20120424@Sophia: Modify DisplayOrder and IsSub
	- 20190506@Winnie: CN88 Permission RedmineID: #112637
Param's Explanation:
	
*/
BEGIN
	SET NOCOUNT ON


	SELECT st.SettingID, st.SettingValue, CASE WHEN ISNULL(rl.ParentID,0) = 0 THEN ISNULL(st.DisplayOrder,0) ELSE ISNULL(rl.DisplayOrder,0) END DisplayOrder, 
		   CASE WHEN ISNULL(rl.ParentID,0) = 0 THEN 0 ELSE 1 END IsSub
	FROM crmSetting st WITH(NOLOCK) 
					LEFT JOIN ( SELECT	SettingID, ParentID, DisplayOrder
								FROM	crmSettingRelation rl WITH(NOLOCK)
								WHERE	ParentID = @ParentID
							  ) rl ON st.SettingID = rl.SettingID
	WHERE 
		st.SettingName = @SettingName
		AND
		st.IsActive = 1
		AND (st.SiteOffer=0 OR st.SiteOffer=@UserRole)
	ORDER BY IsSub DESC, DisplayOrder ASC, st.SettingID ASC
END

GO
GRANT EXECUTE ON [dbo].[Acc_CRM_SettingGetRelationBySettingName] TO [bodbAdminNet]
