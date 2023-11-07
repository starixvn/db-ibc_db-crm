/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE [dbo].[Acc_CRM_PicRoleSel]
	@PicType INT
AS

/*
Created: 20200506@Malcolm
Task : CRM - PIC and Headlin -> PIC Management -> Edit
DB: DBCRM/bodb_CRM
Original:

	Revisions:
		- 20210801@Malcolm: Initialize SP [RedmineID: #151509]
        - 20230918@Ned.Le: CRM - Category/sub-category/admin tool (Setting Management) can show by Alphabet (#193380)

	Param's Explanation:
*/

BEGIN
	SET NOCOUNT ON

	SELECT s.SettingID, s.SettingValue
	FROM dbo.crmSetting s WITH(NOLOCK)
		INNER JOIN dbo.crmSettingRelation r WITH(NOLOCK) ON r.SettingID = s.SettingID
	WHERE r.ParentID = @PicType AND s.SettingName = 'PICRole'
    ORDER BY SettingValue
END