/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.Acc_CRM_SettingSel
(
@UserRole   TINYINT
)
AS
/*
	Created:	Khoa
	Date:		20101020
	Task :		Get Setting list
	DB:			DB052.bodb_CRM
	Original:

	Revisions:
		- 20120425@Sophia:	Edit Order by DisplayOrder before SettingID 
		- 20160301@Billy:	Support Active/Inactive function - [Redmine: #53173]
		- 20190506@Winnie: CN88 Permission RedmineID: #112637
	Param's Explanation:
	
*/
BEGIN
	SET NOCOUNT ON;
	
	SELECT	cs.SettingName
		,	cs.SettingID
		,	cs.SettingValue
		,	cs.DisplayOrder
		,	cs.IsActive
	FROM	dbo.crmSetting AS cs WITH(NOLOCK)
	WHERE cs.SiteOffer=@UserRole
	ORDER BY cs.IsActive DESC, cs.SettingName, cs.DisplayOrder, cs.SettingID;
END;
GO

GRANT EXECUTE ON dbo.Acc_CRM_SettingSel TO [bodbAdminNet];
GO
