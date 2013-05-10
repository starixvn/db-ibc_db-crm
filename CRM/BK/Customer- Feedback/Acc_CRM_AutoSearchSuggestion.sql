 ALTER PROCEDURE [dbo].[Acc_CRM_AutoSearchSuggestion]
(
	@Username	VARCHAR(50) = '',
	@IsGuest	BIT = 0
)
AS
/*
Created: Elodie
Date: 20120309
Task : support auto search suggestion for Search function
DB: DB052.bodb_CRM
Original:

Revisions:	
	
Param's Explanation:	
	• @IsGuest: search by real customer or guest
*/
BEGIN
	SET NOCOUNT ON	
	IF @IsGuest = 0
	BEGIN
		DECLARE @UserNameTable TABLE (UserName varchar(50))
		Declare @Rows int

		INSERT INTO @UserNameTable 
					SELECT TOP 10 Username 
					FROM DB06.bodb02.dbo.CustInfo WITH (NOLOCK) 
					WHERE UserName LIKE @Username + '%'
					ORDER BY UserName

		select @Rows = 10 - count(1) from @UserNameTable 
		IF @Rows > 0
			INSERT INTO @UserNameTable 
						SELECT TOP (@Rows) Username2 
						FROM DB06.bodb02.dbo.Customer WITH (NOLOCK) 
						WHERE username2 LIKE @Username +'%'
						ORDER BY Username2

		SELECT UserName from @UserNameTable ORDER BY UserName
	END
	ELSE --@IsGuest = 1
	BEGIN
		SELECT TOP 10 Username 
		FROM crmCustomer WITH (NOLOCK) 
		WHERE UserName LIKE @Username + '%' AND custID < 0
		ORDER BY UserName
	END	
END

GO
GRANT EXECUTE ON [dbo].[Acc_CRM_AutoSearchSuggestion] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_AutoSearchSuggestion] TO [vnteam]