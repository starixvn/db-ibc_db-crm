/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_PicRoleSel]
	@Type INT
AS
/*
Created: 20200506@Malcolm
Task : CRM - PIC and Headlin -> PIC Management -> Edit
DB: DBCRM/bodb_CRM
Original:

	Revisions:
		- 20210801@Malcolm: Initialize SP [RedmineID: #151509]
	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON

	SELECT s.SettingID AS [Role], s.SettingValue AS [RoleName], s.DisplayOrder
	FROM dbo.crmSetting s WITH(NOLOCK)
		INNER JOIN dbo.crmSettingRelation r WITH(NOLOCK) ON r.SettingID = s.SettingID
	WHERE r.ParentID = @Type AND s.SettingName = 'PICRole'

END