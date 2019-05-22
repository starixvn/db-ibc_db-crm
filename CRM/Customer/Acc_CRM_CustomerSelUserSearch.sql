/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_CustomerSelUserSearch]
	@userid		INT,
	@username	NVARCHAR(50),
	@IsGuest	BIT = 0,
	@UserRole   TINYINT
AS
/*
Created: 20120403@Elodie
Task : support auto search suggestion for Search function.
DB: DBCRM/bodb_CRM
Original:

Revisions:
	- 20120423@Elodie: not search by guest
	- 20130121@Johnson: change link server DB06 to DBACC
	- 20140807@Dom: [Feature #18632] Customize Auto-suggestion for Phone number and add more Communication Types to Customer info
	- 20180924@Winnie: Search Chinese RedmineID: #99982
	- 20190506@Winnie: CN88 Permission RedmineID: #112637
Param's Explanation:
	• @userid: User who are logging in.
	• @username: the search term.
	• @IsGuest: search by real customer or guest
	@UserRole = 0 : Manager 
	@UserRole = 1 : CN88 staff
	@UserRole = 2 : Company staff
*/
BEGIN
	SET NOCOUNT ON	
	DECLARE @UserNameTable TABLE (UserName nvarchar(50), SearchCount int)
	Declare @Rows int
	CREATE TABLE #SuperCN88(CustID INT PRIMARY KEY)
	INSERT INTO #SuperCN88(CustID)
	SELECT CustID FROM bodb02.dbo.CustSuper WITH(NOLOCK) 
	WHERE UplineId IS NOT NULL

	IF @IsGuest = 0
	BEGIN		
		INSERT INTO @UserNameTable (UserName, SearchCount)
		SELECT TOP 10 cs.Username, SearchCount 
		FROM crmCustomerSearch cs WITH (NOLOCK) 
			INNER JOIN crmCustomer c WITH(NOLOCK) ON cs.CustID=c.CustID
		WHERE cs.CustID > 0 
				and (
						cs.UserName LIKE @Username + '%'
							OR PhoneNumber1 = @Username
							OR PhoneNumber2 = @Username
							OR PhoneNumber3 = @Username
							OR cs.MobilePhone = @Username
					)
				AND ((@UserRole=2 AND c.SiteID<>33002) 
						OR (@UserRole=1 AND c.SiteID=33002) 
						OR @UserRole=0)
		ORDER BY SearchCount DESC

		SELECT @Rows = 10 - count(1) FROM @UserNameTable 
		IF @Rows > 0
			INSERT INTO @UserNameTable (UserName, SearchCount)
			SELECT TOP (@Rows) Username, -1 as SearchCount
			FROM DBACC.bodb02.dbo.Custinfo WITH (NOLOCK) 
			WHERE username LIKE @Username +'%' 
					and username not in (SELECT UserName from @UserNameTable)
					AND ((@UserRole=2 AND srecommend<>0 AND srecommend NOT IN(SELECT custid FROM #SuperCN88 WITH(NOLOCK))) 
							OR (@UserRole=1 AND (srecommend IN(SELECT custid FROM #SuperCN88 WITH(NOLOCK)) OR srecommend=0))
					)
			ORDER BY Username
			
		SELECT UserName FROM @UserNameTable ORDER BY SearchCount DESC, UserName
	END
	ELSE
	BEGIN
		INSERT INTO @UserNameTable (UserName, SearchCount)
		SELECT TOP 10 cs.Username, SearchCount 
		FROM crmCustomerSearch cs WITH (NOLOCK) 
			INNER JOIN crmCustomer c WITH(NOLOCK) ON cs.CustID=c.CustID
		WHERE cs.CustID < 0
			AND 
			(
				cs.UserName LIKE @Username + '%'
				OR PhoneNumber1 = @Username
				OR PhoneNumber2 = @Username
				OR PhoneNumber3 = @Username
				OR cs.MobilePhone = @Username
			)
			AND ((@UserRole=2 AND c.SiteID<>33002) 
					OR (@UserRole=1 AND c.SiteID=33002) 
					OR @UserRole=0)
		ORDER BY SearchCount DESC

		SELECT UserName from @UserNameTable ORDER BY SearchCount DESC, UserName
	END
END

GO
GRANT EXECUTE ON [dbo].[Acc_CRM_CustomerSelUserSearch] TO [bodbAdminNet]
GO
