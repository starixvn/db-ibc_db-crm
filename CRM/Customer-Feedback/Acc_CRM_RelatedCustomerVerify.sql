ALTER PROC [dbo].[Acc_CRM_RelatedCustomerVerify]
(
	@UserName	NVARCHAR(MAX) = ''	
)
AS
/*
	Created: Lukas
	Date: 20110629
	Task : verify list of related customer
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20120131@Lukas: verify guest user
		- 20120405@Elodie: return 2 CustID if username is real customer as well as guest
		- 20120409@Elodie: return username and custid = 0 if customer doesn't exist
		- 20121115@Lukas: change the query to use index on DB06
		- 20130121@Johnson: change linked server DB06 to DBACC
	Param's Explanation:	
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @tmpCustomer TABLE(UserName VARCHAR(50))
	DECLARE @Customer TABLE(CustID INT, UserName VARCHAR(50))

	INSERT INTO @tmpCustomer(UserName)
	SELECT ltrim(rtrim(val)) UserName
	FROM dbo.f_split(@UserName,',')		
	
	--INSERT INTO @Customer(CustID, UserName)
	--SELECT c.custid, c.username 
	--FROM bodb02.dbo.Customer c WITH (NOLOCK) INNER JOIN @tmpCustomer tc on c.username = tc.UserName
	INSERT INTO @Customer(CustID, UserName)
	SELECT c.custid, c.username 
	FROM DBACC.bodb02.dbo.Customer c WITH (NOLOCK)
	WHERE username IN ( SELECT username FROM @tmpCustomer)
	
	
	INSERT INTO @Customer(CustID, UserName)
	SELECT c.custid, c.username 
	FROM crmCustomer c WITH (NOLOCK) INNER JOIN @tmpCustomer tc on c.username = tc.UserName
	WHERE c.CustID < 0	

	INSERT INTO @Customer(CustID, UserName)
	SELECT 0, tc.username 
	FROM @tmpCustomer tc 
	WHERE tc.UserName NOT IN (SELECT UserName 
							  from @Customer)

	SELECT CustID, UserName as val
	FROM @Customer
	ORDER BY UserName 
END

GO
GRANT EXECUTE ON [dbo].[Acc_CRM_RelatedCustomerVerify] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_RelatedCustomerVerify] TO [vnteam]