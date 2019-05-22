/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE Acc_CRM_CustomerCommLogDefaultInfo_Sel
	@CustID   INT,
	@UserRole INT
AS
BEGIN	
/*
	Created: Winnie
	Date: 20190510
	Task : update customer basic info
	DB: DB052.bodb_CRM
	Original:
	
    Revisions:         
			- 20190506@Winnie: CN88 Permission RedmineID: #112637
*/
	SET NOCOUNT ON

	DECLARE @SiteID INT,
			@CountryName varchar(100),
			@CountryID int,
			@IsGroupHeadLine BIT,
			@DefaultLanguage INT = 0

	SELECT @IsGroupHeadLine=ISNULL(IsGroupHeadLine,0) FROM bodb02.dbo.custAccount WITH(NOLOCK) WHERE custid=@CustID AND IsGroupHeadLine=1

	IF (@CustID < 0 OR EXISTS(SELECT 1 FROM crmCustomer(NOLOCK) WHERE CustID = @CustID))
	BEGIN
		SELECT * 
		INTO #CustomerLanguage1
		FROM crmCustomerLanguage(NOLOCK) 
		WHERE CustID = @CustID

		IF(EXISTS(SELECT TOP 1 1 FROM #CustomerLanguage1 WHERE  LanguageID = 12000))
		BEGIN
			SELECT @DefaultLanguage = 12000 
		END

		ELSE IF(EXISTS(SELECT TOP 1 1 FROM #CustomerLanguage1 WHERE LanguageID = 12001))
		BEGIN
			SELECT @DefaultLanguage = 12001
		END

		ELSE IF(EXISTS(SELECT TOP 1 1 FROM #CustomerLanguage1 WHERE LanguageID = 12002))
		BEGIN
			SELECT @DefaultLanguage = 12002
		END

		ELSE
		BEGIN 
			SELECT @DefaultLanguage = (SELECT TOP 1 LanguageID FROM #CustomerLanguage1)
		END


		SELECT  
			c.CustID, 
			c.CountryID, 
			CASE WHEN @UserRole=1 AND c.ProvinceID IS NULL THEN 1 ELSE c.ProvinceID END AS ProvinceID,
			c.SiteID,
			CASE 	WHEN cust.roleid=1 AND @UserRole=2 THEN 7000
					WHEN cust.roleid=2 AND @UserRole=2 THEN 7001
					WHEN cust.roleid=3 AND @UserRole=2 THEN 7002
					WHEN cust.roleid=4 AND @UserRole=2 THEN 7003
					WHEN (cust.roleid NOT IN(1,2,3,4) OR cust.roleid IS NULL) AND @UserRole=2 THEN 7004
					WHEN cust.roleid=1 AND @UserRole=1 THEN 7011
					WHEN cust.roleid=2 AND @UserRole=1 THEN 7007
					WHEN cust.roleid=3 AND @UserRole=1 THEN 7008
					WHEN cust.roleid=4 AND @UserRole=1 THEN 7009
					WHEN cust.roleid=0 AND @UserRole=1 THEN 7006
					WHEN (cust.roleid NOT IN(0,1,2,3,4) OR cust.roleid IS NULL) AND @UserRole=1 THEN 7010 END AS RoleID,
			--@IsGroupHeadLine IsGroupHeadLine,
			@DefaultLanguage DefaultLanguage,
			c.LicenseeType LicenseeTypeId
		FROM 
			crmCustomer c WITH(NOLOCK) 
			LEFT JOIN bodb02.dbo.customer cust WITH(NOLOCK) ON c.CustID = cust.custID
		WHERE 
			c.CustID = @CustID AND((c.SiteID=33002 AND @UserRole=1) OR(c.siteID<>33002 AND @UserRole=2))



	END
	ELSE
	BEGIN
		IF NOT EXISTS (SELECT 1 FROM crmCustomer WITH(NOLOCK) WHERE CustID = @CustID)
		BEGIN
			IF (SELECT roleid from bodb02.dbo.customer WITH(NOLOCK) WHERE custid = @CustID) = 1
			BEGIN
				SELECT @SiteID = SettingID 
				FROM crmSetting WITH(NOLOCK) 
				WHERE SettingValue = 
									(SELECT s.site 
									 FROM bodb02.dbo.customer c WITH(NOLOCK) 
											INNER JOIN bodb02.dbo.customer s WITH(NOLOCK) ON c.srecommend = s.custid
									 WHERE c.custid = @CustID)
					AND SettingName IN( 'Site','SiteCategory')
			END
			ELSE
			BEGIN
				SELECT @SiteID = SettingID 
				FROM crmSetting WITH(NOLOCK) 
				WHERE SettingValue = 
									(SELECT site 
									 FROM bodb02.dbo.customer c WITH(NOLOCK)
									 WHERE c.custid = @CustID)
					AND SettingName IN( 'Site','SiteCategory')

			END

			SELECT @CountryName = Country,
					@CountryID = c.CountryID
			FROM bodb02.dbo.Customer cm WITH(NOLOCK)
			INNER JOIN crmCountry c ON cm.country = c.CountryName
			WHERE cm.custid = @custID
		END

		-- Return Customer Language
		SELECT * 
		INTO #CustomerLanguage
		FROM crmCustomerLanguage(NOLOCK) 
		WHERE CustID = @CustID

		IF(EXISTS(SELECT TOP 1 1 FROM #CustomerLanguage WHERE  LanguageID = 12000))
		BEGIN
			SELECT @DefaultLanguage = 12000 
		END

		ELSE IF(EXISTS(SELECT TOP 1 1 FROM #CustomerLanguage WHERE LanguageID = 12001))
		BEGIN
			SELECT @DefaultLanguage = 12001
		END

		ELSE IF(EXISTS(SELECT TOP 1 1 FROM #CustomerLanguage WHERE LanguageID = 12002))
		BEGIN
			SELECT @DefaultLanguage = 12002
		END

		ELSE
		BEGIN 
			SELECT @DefaultLanguage = (SELECT TOP 1 LanguageID FROM #CustomerLanguage)
		END

		CREATE TABLE #Super(CustID INT PRIMARY KEY)
		INSERT INTO #Super(CustID)
		SELECT Custid FROM bodb02.dbo.CustSuper WITH(NOLOCK)
		WHERE UplineId IS NOT NULL

		SELECT 
			ci.CustID, 
			ISNULL(c.CountryID,@CountryID) CountryID, 
			CASE WHEN @UserRole=1 AND c.ProvinceID IS NULL THEN 1 ELSE c.ProvinceID END AS ProvinceID,
			ISNULL(c.SiteID,@SiteID) SiteID,
			CASE 	WHEN ci.roleid=1 AND @UserRole=2 THEN 7000
					WHEN ci.roleid=2 AND @UserRole=2 THEN 7001
					WHEN ci.roleid=3 AND @UserRole=2 THEN 7002
					WHEN ci.roleid=4 AND @UserRole=2 THEN 7003
					WHEN (ci.roleid NOT IN(1,2,3,4) OR ci.roleid IS NULL) AND @UserRole=2 THEN 7004
					WHEN ci.roleid=1 AND @UserRole=1 THEN 7011
					WHEN ci.roleid=2 AND @UserRole=1 THEN 7007
					WHEN ci.roleid=3 AND @UserRole=1 THEN 7008
					WHEN ci.roleid=4 AND @UserRole=1 THEN 7009
					WHEN ci.roleid=0 AND @UserRole=1 THEN 7006
					WHEN (ci.roleid NOT IN(0,1,2,3,4) OR ci.roleid IS NULL) AND @UserRole=1 THEN 7010 END AS RoleID,
			--@IsGroupHeadLine IsGroupHeadLine,
			@DefaultLanguage DefaultLanguage,
			ISNULL(c.LicenseeType,0) LicenseeTypeId
		FROM 
			bodb02.dbo.customer ci WITH(NOLOCK) 
			LEFT JOIN crmCustomer c WITH(NOLOCK) ON ci.custid = c.CustID
		WHERE 
			ci.custid = @CustID
			AND((@UserRole=1 AND (ci.srecommend IN(SELECT Custid FROM #Super) OR ci.srecommend=0)) OR( @UserRole=2) AND ci.srecommend<>0 AND ci.srecommend NOT IN(SELECT Custid FROM #Super))

		

	END
END

GO

 GRANT EXECUTE ON [dbo].[Acc_CRM_CustomerCommLogDefaultInfo_Sel] TO [bodbAdminNet]
GO 
