/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_PicSel]
	@Username VARCHAR(30) = '',
	@IsActive INT = 1
AS
/*
Created: 20200511@Malcolm
Task :  CRM - Staff/Boss Management of headline
DB: DBCRM/bodb_CRM
Original:

	Revisions:
		- 20200511@Malcolm: Get information of PIC [Redmine: #108739]
	Param's Explanation:
		@IsActive = 0 : Load all PIC which is inactive
		          = 1 : Load all PIC which is active
				  = 2 : Load all PIC
		
*/
BEGIN 
	SET NOCOUNT ON

	SELECT @IsActive = ISNULL(@IsActive,0), @Username = ISNULL(@Username,'')

	SELECT PicID,
		   Username,
		   s.SettingValue AS RoleName 
	FROM dbo.crmPIC p WITH(NOLOCK)
		LEFT JOIN dbo.crmSetting s WITH(NOLOCK) ON p.Role = s.SettingID
	WHERE (@Username = '' OR p.Username LIKE '%'+@Username + '%') 
		AND (@IsActive = 2 OR p.IsActive = @IsActive)

END