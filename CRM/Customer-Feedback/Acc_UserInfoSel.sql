/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_UserInfoSel]
	@UserName VARCHAR(50),
	@isNickName	 BIT = 0,
	@UserID int OUTPUT,
	@RoleID tinyint OUTPUT,
	@UserRole TINYINT = 0
AS
/*
	Created: 20101027@Lukas
	Task : get user info (admin info) - crm
	DB: DBACC/BODB02
	Original:

	Revisions:
		- 20120309@Lukas: Get user info by nickname
		- 20190506@Winnie: CN88 Permission RedmineID: #112637
		- 20190705@Elodie: Get CN88 customer status [RedmineID: #112637]
	Param's Explanation:

*/
SET NOCOUNT ON
BEGIN
	IF @isNickName = 0 	
		SELECT @UserID = CustID, @RoleID = roleid
		FROM customer WITH(NOLOCK)
		WHERE UserName = @UserName
			AND ((@UserRole=1 AND site = 'CN88') OR (@UserRole=2 AND site <> 'CN88'))
	ELSE 
		SELECT @UserID = CustID, @RoleID = roleid
		FROM customer WITH(NOLOCK)
		WHERE UserName2 = @UserName
			AND ((@UserRole=1 AND site = 'CN88') OR (@UserRole=2 AND site <> 'CN88'))
END
GO
