/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_UserInfoSel]
	@UserName varchar(50),
	@isNickName	 BIT = 0,
	@UserID int OUTPUT,
	@RoleID tinyint OUTPUT,
	@UserRole TINYINT = 0
AS
/*
Created: 20101027@Lukas
Task : get user info (admin info) - crm
DB: DB06.BODB02
Original:

Revisions:
	- 20120309@Lukas: Get user info by nickname
	- 20190506@Winnie: CN88 Permission RedmineID: #112637
Param's Explanation:
*/
SET NOCOUNT ON
BEGIN
	IF @isNickName = 0 	
		SELECT @UserID = CustID, @RoleID = roleid
		FROM custinfo WITH(NOLOCK)
		WHERE UserName = @UserName
			AND (@UserRole=0 
				OR(@UserRole=1 AND EXISTS (SELECT TOP 1 1 FROM CS_Custsuper WITH(NOLOCK) WHERE CustId=srecommend))
				OR(@UserRole=2 AND NOT EXISTS (SELECT TOP 1 1 FROM CS_Custsuper WITH(NOLOCK) WHERE CustId=srecommend))
				OR(@UserRole=1 AND roleID=0)
				)
	ELSE 
		SELECT @UserID = CustID, @RoleID = roleid
		FROM customer WITH(NOLOCK)
		WHERE UserName2 = @UserName
			AND (@UserRole=0 
				OR(@UserRole=1 AND EXISTS (SELECT TOP 1 1 FROM CS_Custsuper WITH(NOLOCK) WHERE CustId=srecommend))
				OR(@UserRole=2 AND NOT EXISTS (SELECT TOP 1 1 FROM CS_Custsuper WITH(NOLOCK) WHERE CustId=srecommend))
				OR(@UserRole=1 AND roleID=0)
				)
END

GO
GRANT EXECUTE ON [dbo].[Acc_UserInfoSel] TO [bodbAdminNet]