/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
USE bodb_CRM
GO 
ALTER PROCEDURE [dbo].[Acc_CRM_CustomerSel_New]
(
	@CustID				INT,
	@DefaultLanguage	INT = 0 OUTPUT,
	@UserRole			TINYINT
)
AS
/*
Created: Lukas
Date: 20101022
Task : Get customer info
DB: DB052.bodb_CRM
Original:

Revisions:	
	- 20110725@Lukas: get skype, msn
	- 20110825@Kevin: add nickname column
	- 20120329@Elodie: change DB06 to DB052				   
	- 20121120@Lukas: correct join condition (wrong alias)
	- 20140120@Dom: add more information of customer
	- 20140508@Dom: Add group headline
	- 20141118@Dom: Return PIC Name
	- 20160915@Winnie: Return  'Checker' and 'Ignored Accounts' RedmineID #64067
	- 20170911@Winnie: Get Introduced By RedmineID #82040
	- 20190506@Winnie: CN88 Permission RedmineID: #112637
Param's Explanation:	
*/
BEGIN	
	SET NOCOUNT ON

	DECLARE @SiteID INT,
			@CountryName varchar(100),
			@CountryID int,
			@IsGroupHeadLine BIT

	SELECT @IsGroupHeadLine=ISNULL(IsGroupHeadLine,0) FROM bodb02.dbo.custAccount WITH(NOLOCK) WHERE custid=@CustID AND IsGroupHeadLine=1

	CREATE TABLE #SuperCN88(CustID INT PRIMARY KEY)
	INSERT INTO #SuperCN88(CustID)
	SELECT CustID FROM bodb02.dbo.CustSuper WITH(NOLOCK) 
	WHERE UplineId IS NOT NULL

	IF (@CustID < 0 OR EXISTS(SELECT 1 FROM crmCustomer(NOLOCK) WHERE CustID = @CustID))
	BEGIN
		SELECT  
			c.CustID, 
			c.UserName, 
			'' UserName2,
			c.TitleID, 
			c.FirstName, 
			c.LastName, 
			c.Phone, 
			c.PhoneCountryCode, 
			c.PhoneAreaCode, 
			c.Phone2,
			c.Phone2CountryCode,
			c.Phone2AreaCode,
			c.Phone3,
			c.Phone3CountryCode,
			c.Phone3AreaCode,
			c.Passport,
			c.MobilePhone, 
			c.MobilePhoneCountryCode, 
			c.MobilePhoneAreaCode, 
			c.Fax, 
			c.FaxCountryCode, 
			c.FaxAreaCode, 
			c.RefCode1,
			c.RefCode2,
			c.State,
			c.PostCode,
			c.City,
			c.Email, 
			c.Skype,
			c.msn,
			c.Birthday,
			c.Pic1, 
			c.Pic2, 
			c.Pic3, 
			c.Pic4,
			c.Pic1Name, 
			c.Pic2Name, 
			c.Pic3Name, 
			c.Pic4Name,
			c.Line1,
			c.Line2,
			c.Line3,
			c.Question, 
			c.Answer, 
			c.CountryID, 
			c.IsVIP,
			c.SiteID,
			c.Wire_BankName, 
			c.Wire_SwiftCode, 
			c.Wire_AccountName,
			c.Wire_AccountNo, 
			c.BankCity,
			c.BankCode,
			c.BankState,
			c.BankLine1,
			c.BankLine2,
			c.BankLine3,
			c.BankCountryID,
			c.AccountHolderName,
			--c.Remark2,
			--c.Remark, 
			c.CreateDate, 
			c.CreatorID, 
			ci.username as CreatorName,
			CASE 
					WHEN cust.roleid = 1 AND @UserRole=2  THEN 7000
					WHEN cust.roleid = 2 AND @UserRole=2  THEN 7001
					WHEN cust.roleid = 3 AND @UserRole=2  THEN 7002
					WHEN cust.roleid = 4 AND @UserRole=2  THEN 7003
					WHEN cust.roleid NOT IN(1,2,3,4) AND @UserRole=2 THEN 7004
					WHEN cust.roleid = 1 AND @UserRole=1  THEN 7011
					WHEN cust.roleid = 2 AND @UserRole=1  THEN 7007
					WHEN cust.roleid = 3 AND @UserRole=1  THEN 7008
					WHEN cust.roleid = 4 AND @UserRole=1  THEN 7009
					WHEN cust.roleid = 0 AND @UserRole=1  THEN 7006
					WHEN cust.roleid NOT IN(1,2,3,4,0) AND @UserRole=1 THEN 7010
					END AS RoleID,
			@IsGroupHeadLine IsGroupHeadLine,
			ISNULL(c.LicenseeType,0) LicenseeType,
			ISNULL(c.WhatsApp,'') WhatsApp,
			ISNULL(c.Line,'') Line,
			ISNULL(c.WeChat,'') WeChat,
			ISNULL(c.Yahoo,'') Yahoo,
			ISNULL(c.QQ,'') QQ,
			ISNULL(c.BBM,'') BBM,
			ISNULL(c.Ignored,0) AS Ignored,
			ch.username AS Checker,
			c.IntroducedBy,
			CASE WHEN @UserRole=1 AND c.ProvinceID IS NULL THEN 1 ELSE c.ProvinceID END AS ProvinceID
		FROM 
			crmCustomer c WITH(NOLOCK) 
			LEFT JOIN bodb02.dbo.customer ci WITH(NOLOCK) ON c.CreatorID = ci.custID
			LEFT JOIN bodb02.dbo.customer cust WITH(NOLOCK) ON c.CustID = cust.custID
			LEFT JOIN bodb02.dbo.custAccount ca WITH(NOLOCK) ON c.CustID = ca.custID
			LEFT JOIN bodb02.dbo.customer ch WITH(NOLOCK) ON ch.CustID = ca.checker
		WHERE 
			c.CustID = @CustID
			AND ((@UserRole=1 AND c.SiteID=33002) OR (@UserRole=2 AND c.SiteID<>33002))
		-- Return Customer Language
		SELECT * 
		INTO #CustomerLanguage1
		FROM crmCustomerLanguage(NOLOCK) 
		WHERE CustID = @CustID

		select * from #CustomerLanguage1

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

		SELECT 
			ci.CustID, 
			ci.UserName, 
			ci.UserName2,
			c.TitleID, 
			ISNULL(c.FirstName,ci.firstname) FirstName, 
			ISNULL(c.LastName, ci.LastName) LastName,
			ISNULL(c.Phone, ci.Phone) Phone, 
			c.PhoneCountryCode, 
			c.PhoneAreaCode, 
			c.Phone2,
			c.Phone2CountryCode, 
			c.Phone2AreaCode, 
			c.Phone3,
			c.Phone3CountryCode, 
			c.Phone3AreaCode, 
			ISNULL(c.MobilePhone,ci.mobilephone)MobilePhone, 
			c.MobilePhoneCountryCode,
			c.MobilePhoneAreaCode,
			c.Passport,
			ISNULL(c.Line1,ci.address) Line1,
			c.Line2,
			c.Line3,
			ISNULL(c.Fax,ci.fax) Fax, 
			c.FaxCountryCode,
			c.FaxAreaCode,
			ci.RefCode1,
			ci.RefCode2,
			ISNULL(c.State,ci.state) State,
			ISNULL(c.PostCode, ci.postal) PostCode,
			ISNULL(c.City,ci.city) City,
			ISNULL(c.Email,ci.Email) Email, 
			c.Skype,
			c.msn,
			ISNULL(c.Birthday,ci.birthday) Birthday,
			c.Pic1, 
			c.Pic2, 
			c.Pic3, 
			c.Pic4,
			c.Pic1Name, 
			c.Pic2Name, 
			c.Pic3Name, 
			c.Pic4Name,
			c.Question, 
			c.Answer, 
			ISNULL(c.CountryID,@CountryID) CountryID, 
			c.IsVIP,	
			ISNULL(c.SiteID,@SiteID) SiteID,
			c.Wire_BankName, 
			c.Wire_SwiftCode, 
			c.Wire_AccountName,
			c.Wire_AccountNo, 
			c.BankCity,
			c.BankCode,
			c.BankState,
			c.BankLine1,
			c.BankLine2,
			c.BankLine3,
			c.BankCountryID,
			c.AccountHolderName,
			--c.Remark2,
			--c.Remark, 
			c.CreateDate, 
			c.CreatorID,
			cr.username AS CreatorName,
			CASE	WHEN ci.roleid = 1 AND @UserRole=2  THEN 7000
					WHEN ci.roleid = 2 AND @UserRole=2  THEN 7001
					WHEN ci.roleid = 3 AND @UserRole=2  THEN 7002
					WHEN ci.roleid = 4 AND @UserRole=2  THEN 7003
					WHEN ci.roleid NOT IN(1,2,3,4) AND @UserRole=2 THEN 7004 
					WHEN ci.roleid = 1 AND @UserRole=1  THEN 7011
					WHEN ci.roleid = 2 AND @UserRole=1  THEN 7007
					WHEN ci.roleid = 3 AND @UserRole=1  THEN 7008
					WHEN ci.roleid = 4 AND @UserRole=1  THEN 7009
					WHEN ci.roleid = 0 AND @UserRole=1  THEN 7006
					WHEN ci.roleid NOT IN(1,2,3,4,0) AND @UserRole=1 THEN 7010
					END AS RoleID,
			@IsGroupHeadLine IsGroupHeadLine,
			0 as LicenseeType,
			ISNULL(c.WhatsApp,'') WhatsApp,
			ISNULL(c.Line,'') Line,
			ISNULL(c.WeChat,'') WeChat,
			ISNULL(c.Yahoo,'') Yahoo,
			ISNULL(c.QQ,'') QQ,
			ISNULL(c.BBM,'') BBM,
			ISNULL(c.Ignored,0) AS Ignored,
			ch.Username AS Checker,
			c.IntroducedBy,
			CASE WHEN @UserRole=1 AND c.ProvinceID IS NULL THEN 1 ELSE c.ProvinceID END AS ProvinceID
		FROM 
			bodb02.dbo.customer ci WITH(NOLOCK) 
			LEFT JOIN crmCustomer c WITH(NOLOCK) ON ci.custid = c.CustID
			LEFT JOIN bodb02.dbo.custinfo cr WITH(NOLOCK) ON c.CreatorID = cr.custID
			LEFT JOIN bodb02.dbo.custAccount ca WITH(NOLOCK) ON c.CustID = ca.custID
			LEFT JOIN bodb02.dbo.customer ch WITH(NOLOCK) ON ch.CustID = ca.checker
		WHERE 
			ci.custid = @CustID
			AND ((@UserRole=1 AND ( ci.srecommend IN(SELECT custid FROM #SuperCN88 WITH(NOLOCK)) OR ci.srecommend=0)) OR (@UserRole=2 AND ci.srecommend NOT IN(SELECT custid FROM #SuperCN88)))
		-- Return Customer Language
		SELECT * 
		INTO #CustomerLanguage
		FROM crmCustomerLanguage(NOLOCK) 
		WHERE CustID = @CustID

		select * from #CustomerLanguage

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

	END
END


GO
