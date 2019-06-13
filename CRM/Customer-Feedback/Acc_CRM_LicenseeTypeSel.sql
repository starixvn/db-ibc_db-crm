/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE	Acc_CRM_LicenseeTypeSel
(
@UserRole		TINYINT,
@Lang			VARCHAR(10)='en-US'
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
		,CASE		WHEN @Lang='zh-TW' THEN ISNULL(SettingValueCT,SettingValue)
					WHEN @Lang='zh-CN' THEN ISNULL(SettingValueCS,SettingValue)
											ELSE SettingValue
			END AS Licensee,
	FROM	dbo.crmSetting AS cs WITH (NOLOCK)
	WHERE	settingname = 'LicenseeType'
		AND	cs.IsActive = 1
		AND (siteOffer=@UserRole)
END
GO