ALTER PROCEDURE [dbo].[Acc_UserInfoSel]
	@UserName varchar(50),
	@isNickName	 BIT = 0,
	@UserID int OUTPUT,
	@RoleID tinyint OUTPUT	
AS
/*
Created: 20101027@Lukas
Task : get user info (admin info) - crm
DB: DB06.BODB02
Original:

Revisions:
	- 20120309@Lukas: Get user info by nickname
Param's Explanation:
*/
SET NOCOUNT ON
BEGIN
	IF @isNickName = 0 	
		SELECT @UserID = CustID, @RoleID = roleid
		FROM custinfo WITH(NOLOCK)
		WHERE UserName = @UserName
	ELSE 
		SELECT @UserID = CustID, @RoleID = roleid
		FROM customer WITH(NOLOCK)
		WHERE UserName2 = @UserName
END


GO
GRANT VIEW DEFINITION ON [dbo].[Acc_UserInfoSel] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[Acc_UserInfoSel] TO [bodbAdminNet]