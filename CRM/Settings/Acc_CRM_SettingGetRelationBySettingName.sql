/*<info serverAlias="DBCRM-bodb_CRM" executers="wsv_nap,wsv_alp" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE [dbo].[Acc_CRM_SettingGetRelationBySettingName]
(
	@SettingName	VARCHAR(50),
	@ParentID		INT,
	@UserRole		TINYINT,
	@Active			TINYINT = 1,
	@Lang			VARCHAR(10)='en-US'
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
	- 20201030@Johnson: add filter IsActive [redmine: #142194]
    - 20231107@Ned.Le: CRM - Category/sub-category/admin tool (Setting Management) can show by Alphabet (#193380)
	- 20250414@Virgil: CRM - Manage SMA Feedback in effective way [Redmine: #220766]

Param's Explanation:
	- @Active = 1: get active
				= 2: get all 
*/

BEGIN
	SET NOCOUNT ON


	SELECT st.SettingID, 
			CASE	WHEN @Lang='zh-TW' THEN ISNULL(SettingValueCT,SettingValue)
					WHEN @Lang='zh-CN' THEN ISNULL(SettingValueCS,SettingValue)
											ELSE SettingValue
			END AS SettingValue,
		    CASE WHEN ISNULL(rl.ParentID,0) = 0 THEN 0 ELSE 1 END IsSub,
			IsActive
	FROM crmSetting st WITH(NOLOCK) 
					LEFT JOIN ( SELECT	SettingID, ParentID
								FROM	crmSettingRelation rl WITH(NOLOCK)
								WHERE	ParentID = @ParentID
							  ) rl ON st.SettingID = rl.SettingID
	WHERE 
		st.SettingName = @SettingName
		AND 1 = CASE WHEN (@Active = 1 AND IsActive = 1) OR @Active = 2 THEN 1 ELSE 0 END		
		AND ( st.SiteOffer=@UserRole)
	ORDER BY IsSub DESC,
             CASE WHEN @SettingName = 'Station' THEN CASE WHEN SettingValue = 'N/A' THEN '0' ELSE SettingValue END ELSE SettingValue END ASC,
             st.SettingID ASC
END
GO