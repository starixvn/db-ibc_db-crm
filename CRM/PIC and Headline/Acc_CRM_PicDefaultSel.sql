/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_PicDefaultSel]
	@HeadlineID INT
AS
/*
Created: 20200717@Malcolm
Task :  Get default PICs of a headline
DB: DBCRM/bodb_CRM
Original:

	Revisions:
		- 20200717@Malcolm: Get default PICs of a headline [Redmine: #137144]
	Param's Explanation:
		
*/
BEGIN 
	SET NOCOUNT ON

	SELECT @HeadlineID = ISNULL(@HeadlineID,0)

	SELECT d.PicID AS PicID, p.Username AS PicName, p.Role AS 'RoleId', s.SettingValue AS 'RoleName'
	FROM dbo.crmPICDefault d WITH(NOLOCK)
		INNER JOIN dbo.crmPIC p WITH(NOLOCK) ON d.PicID = p.PicID
		INNER JOIN dbo.crmSetting s WITH(NOLOCK) ON p.Role = s.SettingID
	WHERE d.HeadlineID = @HeadlineID
	FOR XML PATH('DefaultPIC'),ROOT('R')
END
GO
