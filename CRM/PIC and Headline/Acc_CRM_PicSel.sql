/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_PicSel]
	@Username VARCHAR(30) = '',
	@IsActive BIT = NULL
AS
/*
Created: 20200511@Malcolm
Task :  CRM - Staff/Boss Management of headline
DB: DBCRM/bodb_CRM
Original:

	Revisions:
		- 20200511@Malcolm: Get information of PIC [Redmine: #108739]
		- 20201013@Malcolm : change data type of @IsActive from TINYINT to BIT [Redmine: #130544]
		- 20210731@Malcolm : Add alias and get Pic type [RedmineId : #151509] 
	Param's Explanation:
		@IsActive = 0 : Load all PIC which is inactive
		          = 1 : Load all PIC which is active
				  = NULL : Load all PIC
		
*/
BEGIN 
	SET NOCOUNT ON

	SELECT @Username = ISNULL(@Username,'')

	SELECT p.PicID,
		   p.Username,
		   p.Role AS Role,
		   s.SettingValue AS RoleName,
		   p.PicType,
		   pt.SettingValue AS PicTypeName
	FROM dbo.crmPIC p WITH(NOLOCK)
		LEFT JOIN dbo.crmSetting s WITH(NOLOCK) ON p.Role = s.SettingID
		LEFT JOIN dbo.crmSetting pt WITH(NOLOCK) ON p.PicType = pt.SettingID
	WHERE (@Username = '' OR p.Username LIKE '%'+@Username + '%') 
		AND (@IsActive IS NULL OR p.IsActive = @IsActive)

END