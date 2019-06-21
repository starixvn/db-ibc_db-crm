/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_CN88_SettingNameSelByName]
@SettingName			VARCHAR(50)
AS
/*
	Created:	Winnie
	Date:		20190614
	Task :		Get Setting list
	DB:			DBCRM.bodb_CRM
	Original:

	Revisions:
		- 20190506@Winnie: CN88 AdminTool RedmineID: #112637
	Param's Explanation:
	
*/
BEGIN
	SET NOCOUNT ON;	
	SELECT DISTINCT SettingName,SettingNameCS,SettingNameCT
	FROM	dbo.crmSetting AS cs WITH(NOLOCK)
	WHERE cs.SiteOffer=1 AND SettingName=@SettingName
	
END;
