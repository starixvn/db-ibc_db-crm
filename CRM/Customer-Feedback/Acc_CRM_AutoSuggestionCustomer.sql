 ALTER PROCEDURE [dbo].[Acc_CRM_AutoSuggestionCustomer]
(
	@Username	VARCHAR(50) = ''
)
AS
/*
Created: Elodie
Date: 20120406
Task : support auto suggestion customer for verified related customer function
DB: DBCRM/bodb_CRM
Original:

Revisions:	
	- 20130121@Johnson: Change link server DB06 to DBACC
Param's Explanation:	
	
*/
BEGIN
	SET NOCOUNT ON	
		DECLARE @UserNameTable TABLE (UserName varchar(50))
		Declare @Rows int

		INSERT INTO @UserNameTable 
					SELECT TOP 10 Username 
					FROM DBACC.bodb02.dbo.CustInfo WITH (NOLOCK) 
					WHERE UserName LIKE @Username + '%'
					ORDER BY UserName

		select @Rows = 10 - count(1) from @UserNameTable 
		IF @Rows > 0
			-- get guest
			INSERT INTO @UserNameTable 
						SELECT TOP (@Rows) Username 
						FROM crmCustomer WITH (NOLOCK) 
						WHERE UserName LIKE @Username +'%'
							  and UserName not in (SELECT UserName from @UserNameTable)
						ORDER BY UserName

		SELECT UserName from @UserNameTable ORDER BY UserName	
END

GO
GRANT EXECUTE ON [dbo].[Acc_CRM_AutoSuggestionCustomer] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_AutoSuggestionCustomer] TO [vnteam]


