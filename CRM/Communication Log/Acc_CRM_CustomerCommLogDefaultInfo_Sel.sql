/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE Acc_CRM_CustomerCommLogDefaultInfo_Sel
	@CustID INT
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
			c.SiteID,
			CASE cust.roleid	
					WHEN 1 THEN 7000
					WHEN 2 THEN 7001
					WHEN 3 THEN 7002
					WHEN 4 THEN 7003
					WHEN 0 THEN 7006
					ELSE 7004 END as RoleID,
			--@IsGroupHeadLine IsGroupHeadLine,
			@DefaultLanguage DefaultLanguage,
			c.LicenseeType LicenseeTypeId
		FROM 
			crmCustomer c WITH(NOLOCK) 
			LEFT JOIN bodb02.dbo.customer cust WITH(NOLOCK) ON c.CustID = cust.custID
		WHERE 
			c.CustID = @CustID



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
					AND SettingName = 'Site'
			END
			ELSE
			BEGIN
				SELECT @SiteID = SettingID 
				FROM crmSetting WITH(NOLOCK) 
				WHERE SettingValue = 
									(SELECT site 
									 FROM bodb02.dbo.customer c WITH(NOLOCK)
									 WHERE c.custid = @CustID)
					AND SettingName = 'Site'

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

		SELECT 
			ci.CustID, 
			ISNULL(c.CountryID,@CountryID) CountryID, 
			ISNULL(c.SiteID,@SiteID) SiteID,
			CASE ci.roleid	WHEN 1 THEN 7000
							WHEN 2 THEN 7001
							WHEN 3 THEN 7002
							WHEN 4 THEN 7003
							WHEN 0 THEN 7006
							ELSE 7004 
			END AS RoleID,
			--@IsGroupHeadLine IsGroupHeadLine,
			@DefaultLanguage DefaultLanguage,
			ISNULL(c.LicenseeType,0) LicenseeTypeId
		FROM 
			bodb02.dbo.customer ci WITH(NOLOCK) 
			LEFT JOIN crmCustomer c WITH(NOLOCK) ON ci.custid = c.CustID
		WHERE 
			ci.custid = @CustID

		

	END
END

GO

 GRANT EXECUTE ON [dbo].[Acc_CRM_CustomerCommLogDefaultInfo_Sel] TO [bodbAdminNet]
GO 
