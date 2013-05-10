 ALTER PROCEDURE [dbo].[Acc_CRM_CustomerSelUserSearch]
	@userid int,
	@username nvarchar(50),
	@IsGuest	BIT = 0
AS
/*
Created: 20120403@Elodie
Task : support auto search suggestion for Search function.
DB: DBCRM/bodb_CRM
Original:

Revisions:
	- 20120423@Elodie: not search by guest
	- 20130121@Johnson: change link server DB06 to DBACC
Param's Explanation:
	• @userid: User who are logging in.
	• @username: the search term.
	• @IsGuest: search by real customer or guest
*/
BEGIN
	SET NOCOUNT ON	
	DECLARE @UserNameTable TABLE (UserName varchar(50), SearchCount int)		
	Declare @Rows int

	IF @IsGuest = 0
	BEGIN		
		INSERT INTO @UserNameTable (UserName, SearchCount)
					SELECT TOP 10 Username, SearchCount 
					FROM crmCustSearch WITH (NOLOCK) 
					WHERE UserID = @userid and CustID > 0 and UserName LIKE '%' + @Username + '%'
					ORDER BY SearchCount DESC

		select @Rows = 10 - count(1) from @UserNameTable 
		IF @Rows > 0
			INSERT INTO @UserNameTable (UserName, SearchCount)
						SELECT TOP (@Rows) Username, -1 as SearchCount
						FROM DBACC.bodb02.dbo.Custinfo WITH (NOLOCK) 
						WHERE username LIKE @Username +'%' 
							  and username not in (SELECT UserName from @UserNameTable)
						ORDER BY Username

		SELECT UserName from @UserNameTable ORDER BY SearchCount DESC, UserName
	END
--	ELSE --@IsGuest = 1
--	BEGIN		
--		INSERT INTO @UserNameTable (UserName, SearchCount)
--					SELECT TOP 10 Username, SearchCount 
--					FROM crmCustSearch WITH (NOLOCK) 
--					WHERE UserID = @userid and CustID < 0 and UserName LIKE '%' + @Username + '%'
--					ORDER BY SearchCount DESC
--		
--		select @Rows = 10 - count(1) from @UserNameTable 
--		IF @Rows > 0
--			INSERT INTO @UserNameTable (UserName, SearchCount)
--						SELECT TOP (@Rows) Username, -1 as SearchCount
--						FROM crmCustomer WITH (NOLOCK) 
--						WHERE username LIKE @Username +'%' 
--							  AND custID < 0
--							  AND username not in (SELECT UserName from @UserNameTable)
--						ORDER BY Username	
--
--		SELECT UserName from @UserNameTable ORDER BY SearchCount DESC, UserName	
--	END	
END

GO
GRANT EXECUTE ON [dbo].[Acc_CRM_CustomerSelUserSearch] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_CustomerSelUserSearch] TO [vnteam]



