/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE	Acc_CRM_LicenseeTypeSel
(
@UserRole		TINYINT
)
AS
/*
	Created:	Lukas
	Date:		20141118
	Task:		get list Licensee Type
	DB:			DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20190507@Winnie:	CN88 	[RedmineID:#112637]
	Param's Explanation:
*/
BEGIN
	SELECT	SettingID		LicenseeType
		,	SettingValue	Licensee
	FROM	dbo.crmSetting AS cs WITH (NOLOCK)
	WHERE	settingname = 'LicenseeType'
		AND	cs.IsActive = 1
		AND (siteOffer=@UserRole OR SiteOffer=0 OR @UserRole=0)
END
GO