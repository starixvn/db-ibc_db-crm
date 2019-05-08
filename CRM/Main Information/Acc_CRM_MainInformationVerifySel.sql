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
			CASE c.roleid	WHEN 1 THEN 7000
							WHEN 2 THEN 7001
							WHEN 3 THEN 7002
							WHEN 4 THEN 7003
							WHEN 0 THEN 7006
							ELSE 7004 
			END AS RoleID,
			@IsCredit		IsCredit
	FROM bodb02.dbo.Customer(NOLOCK)c
	INNER JOIN bodb02.dbo.custInfo(NOLOCK) ci ON ci.custid = c.custid
	WHERE c.custid = @CustID 
		AND(@UserRole=0 
			OR(@UserRole=1 AND c.srecommend IN(SELECT CustID FROM bodb02.dbo.CS_CustSuper WITH(NOLOCK))) 
			OR(@UserRole=2 AND c.srecommend NOT IN(SELECT CustID FROM bodb02.dbo.CS_CustSuper WITH(NOLOCK))) )
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
			CASE ci.roleid	WHEN 1 THEN 7000
							WHEN 2 THEN 7001
							WHEN 3 THEN 7002
							WHEN 4 THEN 7003
							WHEN 0 THEN 7006
							ELSE 7004 
			END AS RoleID,
			@IsCredit		IsCredit
	FROM crmCustomer(NOLOCK) c
	INNER JOIN bodb02.dbo.custInfo(NOLOCK) ci ON ci.custid = c.custid
	WHERE c.custid = @CustID
		AND(@UserRole=0 
			OR (@UserRole=1 AND c.SiteID=33002)
			OR (@UserRole=2 AND c.SiteID<>33002)
			)
END


GO
 
 GRANT EXECUTE ON [dbo].[Acc_CRM_MainInformationVerifySel] TO [bodbAdminNet]
GO 
