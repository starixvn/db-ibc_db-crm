ALTER PROCEDURE	Acc_CRM_LicenseeTypeSel
AS
/*
	Created:	Lukas
	Date:		20141118
	Task:		get list Licensee Type
	DB:			DBCRM/bodb_CRM
	Original:

	Revisions:
	Param's Explanation:
*/
BEGIN
	SELECT	SettingID		LicenseeType
		,	SettingValue	Licensee
	FROM	dbo.crmSetting AS cs WITH (NOLOCK)
	WHERE	settingname = 'LicenseeType'
		AND	cs.IsActive = 1
END
GO