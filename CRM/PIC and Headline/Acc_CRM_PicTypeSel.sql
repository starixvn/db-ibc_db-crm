/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_PicTypeSel]
AS
/*
Created: 20210726@Malcolm
Task :  CRM - PIC and Headline -> PIC Management -> Edit PIC -> Get Pic Type
DB: DBCRM/bodb_CRM
Original:

	Revisions:
		- 20210726@Malcolm: Get Pic type [Redmine: #151509]
	Param's Explanation:

		
*/
BEGIN
	SET NOCOUNT ON

	SELECT s.SettingId AS Type, s.SettingValue AS [TypeName], s.DisplayOrder
	FROM crmSetting s WITH(NOLOCK)
	WHERE s.SettingName = 'PICType' AND s.IsActive = 1

END