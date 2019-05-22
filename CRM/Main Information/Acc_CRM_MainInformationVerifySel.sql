/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROC Acc_CRM_MainInformationVerifySel
	@CustID		INT,
	@UserRole   TINYINT
AS

/*
Created: Dom
Date: 20140212
Task : Get data for main tab
DB: DBCRM.bodb_CRM
Original:

Revisions:	
	- 20190506@Winnie: CN88 Permission RedmineID: #112637
Param's Explanation:	
*/


-------------------------------------

DECLARE @CashBalance MONEY,
		@IsCredit BIT

SELECT @CashBalance = SUM(winlost - actual_stake + playercomm)
FROM DBTXN.BODB02.dbo.Bettrans WITH(NOLOCK)
WHERE CustID = @CustID

CREATE TABLE #Super(CustID INT PRIMARY KEY)
INSERT INTO #Super(CustID)
SELECT Custid FROM bodb02.dbo.CustSuper WITH(NOLOCK)
WHERE UplineId IS NOT NULL

IF EXISTS(SELECT TOP 1 * FROM bodb02.dbo.Customer(NOLOCK) WHERE custid = @CustID AND srecommend IN(SELECT CustID FROM bodb02.dbo.Dep_CustSuper(NOLOCK)))
	SELECT @IsCredit = 0 
ELSE
	SELECT @IsCredit = 1

IF NOT EXISTS(SELECT 1 FROM crmCustomer(NOLOCK) WHERE CustID = @CustID)
BEGIN
	SELECT c.email,
			Passport			= NULL,
			SecretCode			= c.refcode1	,
			BetCredit			= ci.credit + @CashBalance ,
			GivenCredit			= ci.credit ,
			Birthday			= c.Birthday,
			IsVerifyEmail		= cast (0 as bit),
			IsVerifyPassport	= cast (0 as bit),
			IsVerifyBirthday	= cast (0 as bit),
			IsVerifySecretCode	= cast (0 as bit),
			IsVerifyBetCredit	= cast (0 as bit),
			IsVerifyGivenCredit	= cast (0 as bit),
			CASE WHEN c.roleid = 1 AND @UserRole=2 THEN 7000
				 WHEN c.roleid = 2 AND @UserRole=2 THEN 7001
				 WHEN c.roleid = 3 AND @UserRole=2 THEN 7002
				 WHEN c.roleid = 4 AND @UserRole=2 THEN 7003
				 WHEN c.roleid NOT IN(1,2,3,4) AND @UserRole=2 THEN 7004
				 WHEN c.roleid = 1 AND @UserRole=1 THEN 7011
				 WHEN c.roleid = 2 AND @UserRole=1 THEN 7007
				 WHEN c.roleid = 3 AND @UserRole=1 THEN 7008
				 WHEN c.roleid = 4 AND @UserRole=1 THEN 7009
				 WHEN c.roleid = 0 AND @UserRole=1 THEN 7006
				 WHEN c.roleid NOT IN(1,2,3,4,0) AND @UserRole=1 THEN 7010		
			END AS RoleID,
			@IsCredit		IsCredit
	FROM bodb02.dbo.Customer(NOLOCK)c
	INNER JOIN bodb02.dbo.custInfo(NOLOCK) ci ON ci.custid = c.custid
	WHERE c.custid = @CustID 
		AND((@UserRole=1 AND (c.srecommend IN(SELECT CustID FROM #Super) OR c.srecommend=0)) 
			OR(@UserRole=2 AND c.srecommend<>0 AND c.srecommend NOT IN(SELECT CustID FROM #Super)) )
END
ELSE
BEGIN
	SELECT Email				= c.email,
			Passport			= c.Passport,
			SecretCode			= c.refcode1 ,
			BetCredit			= ci.credit + @CashBalance ,
			GivenCredit			= ci.credit ,
			Birthday			= c.Birthday,
			IsVerifyEmail		= CAST(ISNULL(IsVerifyEmail,0) AS BIT),
			IsVerifyPassport	= CAST(ISNULL(IsVerifyPassport,0) AS BIT),
			IsVerifyBirthday	= CAST(ISNULL(IsVerifyBirthday,0) AS BIT),
			IsVerifySecretCode	= CAST(ISNULL(IsVerifySecretCode,0) AS BIT),
			IsVerifyBetCredit	= CAST(ISNULL(IsVerifyBetCredit,0) AS BIT),
			IsVerifyGivenCredit	= CAST(ISNULL(IsVerifyGivenCredit,0) AS BIT),
				CASE WHEN ci.roleid = 1 AND @UserRole=2 THEN 7000
				 WHEN ci.roleid = 2 AND @UserRole=2 THEN 7001
				 WHEN ci.roleid = 3 AND @UserRole=2 THEN 7002
				 WHEN ci.roleid = 4 AND @UserRole=2 THEN 7003
				 WHEN ci.roleid NOT IN(1,2,3,4) AND @UserRole=2 THEN 7004
				 WHEN ci.roleid = 1 AND @UserRole=1 THEN 7011
				 WHEN ci.roleid = 2 AND @UserRole=1 THEN 7007
				 WHEN ci.roleid = 3 AND @UserRole=1 THEN 7008
				 WHEN ci.roleid = 4 AND @UserRole=1 THEN 7009
				 WHEN ci.roleid = 0 AND @UserRole=1 THEN 7006
				 WHEN ci.roleid NOT IN(1,2,3,4,0) AND @UserRole=1 THEN 7010					
			END AS RoleID,
			@IsCredit		IsCredit
	FROM crmCustomer(NOLOCK) c
	LEFT JOIN bodb02.dbo.custInfo(NOLOCK) ci ON ci.custid = c.custid
	WHERE c.custid = @CustID
		AND(@UserRole=0 
			OR (@UserRole=1 AND c.SiteID=33002)
			OR (@UserRole=2 AND c.SiteID<>33002)
			)
END


GO
 
 GRANT EXECUTE ON [dbo].[Acc_CRM_MainInformationVerifySel] TO [bodbAdminNet]
GO 
