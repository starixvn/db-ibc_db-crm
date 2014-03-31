
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.Acc_CRM_CustomerSearch    Script Date: 3/26/2014 6:06:05 PM ******/

CREATE PROCEDURE [dbo].[Acc_CRM_CustomerSearch]
(
	@Username	VARCHAR(50) = '',
	@IsGuest	BIT = 0
)
AS
/*
Created: Lukas
Date: 20101028
Task : search for customer
DB: DBCRM/bodb_CRM
Original:

Revisions:	
	- 20110701@Lukas: support search by nickname
	- 20110725@Lukas: Get skype, msn
	- 20110825@Kevin: add nickname column
	- 20120309@Elodie: call SP DB06.bodb02.dbo.Acc_UserInfoSel and add condition SettingName = 'Site'
	- 20120319@Elodie: change DB06 to DB052
	- 20130121@Johnson: change link server DB06 to DBACC
	- 20140303@Dom: Modify for new structure
Param's Explanation:	
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @custID INT,
			@SiteID INT,
			@RoleID TINYINT,
			@CountryName varchar(100),
			@CountryID int

	IF @IsGuest = 0
	BEGIN
		EXEC DBACC.bodb02.dbo.Acc_UserInfoSel 
			@Username = @Username,	
			@IsNickName = 0,	
			@UserID = @custID OUTPUT,
			@RoleID = @RoleID OUTPUT		
		
		IF @custID IS NULL    --- search by nickname
		BEGIN
			EXEC DBACC.bodb02.dbo.Acc_UserInfoSel 
			@Username = @Username,	
			@IsNickName = 1,	
			@UserID = @custID OUTPUT,
			@RoleID = @RoleID OUTPUT		
		END
		
		IF @custID IS NULL    --- search by phone in IBC
		BEGIN	
			SELECT @custID = c.custID ,
			@RoleID = RoleID 
			FROM bodb02.dbo.Customer(NOLOCK) c
			LEFT JOIN crmCustomer(NOLOCK) cr ON c.custid = cr.CustID
			WHERE c.phone LIKE '%'+@UserName
					OR cr.PhoneCountryCode+cr.PhoneAreaCode+cr.Phone LIKE '%'+@username
					OR cr.Phone2CountryCode+cr.Phone2AreaCode+cr.Phone2 LIKE '%'+@username
					OR cr.Phone3CountryCode+cr.Phone3AreaCode+cr.Phone3 LIKE '%'+@username
					OR cr.MobilePhoneCountryCode+cr.MobilePhoneAreaCode+cr.MobilePhone LIKE '%'+@username
					OR c.mobilephone LIKE '%'+@username		
		END					

		IF NOT EXISTS (SELECT 1 FROM crmCustomer WITH(NOLOCK) WHERE CustID = @CustID)
		BEGIN
			IF @RoleID = 1
			BEGIN
				SELECT @SiteID = SettingID 
				FROM crmSetting WITH(NOLOCK) 
				WHERE SettingValue = 
									(SELECT ag.site 
									 FROM bodb02.dbo.customer c WITH(NOLOCK) 
											INNER JOIN bodb02.dbo.customer ag WITH(NOLOCK) ON c.recommend = ag.custid
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
	-----return customer
			SELECT @CountryName = Country,
					@CountryID = c.CountryID
			FROM bodb02.dbo.Customer cm WITH(NOLOCK)
			INNER JOIN crmCountry c ON cm.country = c.CountryName
			WHERE cm.custid = @custID
			print 'search in IBC'
			SELECT	
			c.CustID, 
			c.UserName, 
			cm.UserName2,
			crm.TitleID, 
			cm.FirstName FirstName, 
			cm.LastName LastName, 
			cm.phone Phone, 
			crm.PhoneCountryCode,
			crm.PhoneAreaCode,
			crm.Phone2,
			crm.Phone2CountryCode,
			crm.Phone2AreaCode,
			crm.Phone3,
			crm.Phone3CountryCode,
			crm.Phone3AreaCode,
			cm.MobilePhone MobilePhone,
			crm.MobilePhoneCountryCode,
			crm.MobilePhoneAreaCode,
			cm.Fax Fax, 
			crm.FaxCountryCode, 
			crm.FaxAreaCode, 
			cm.Email Email, 
			crm.Skype,
			crm.msn,
			cm.Birthday Birthday, 
			crm.RefCode1, 
			crm.RefCode2, 
			crm.Pic1, 
			crm.Pic2, 
			crm.Pic3,
			crm.Pic4,
			crm.Question, 
			crm.Answer, 
			ISNULL(crm.CountryID,@CountryID) CountryID, 
			ct.CountryName,
			crm.IsVIP, 			
			ISNULL(crm.SiteID,@SiteID) as SiteID,
			crm.Wire_BankName, 
			crm.Wire_BankAddress, 
			crm.Wire_SwiftCode, 
			crm.Wire_AccountName, 
			crm.Wire_AccountNo,
			crm.Remark, 
			crm.CreateDate, 			
			ci.Username as CreatorName,
			CASE c.roleid	WHEN 1 THEN 7000
							WHEN 2 THEN 7001
							WHEN 3 THEN 7002
							WHEN 4 THEN 7003
							ELSE 7004 
			END AS RoleID,
			c.danger,
			c.danger2,
			c.danger3,
			CASE WHEN c.Closed = 0 and ISNULL(c.reject,0) = 0 THEN 1 ELSE 0 END Active,
			CASE WHEN c.Closed = 1 THEN 1 ELSE 0 END Closed,
			CASE WHEN ISNULL(c.reject,0) = 1 and c.Closed = 0 THEN 1 ELSE 0 END Suspended
		FROM 
			bodb02.dbo.custinfo c WITH(NOLOCK) 
					LEFT JOIN crmCustomer crm WITH(NOLOCK) ON c.custID = crm.custID
					LEFT JOIN bodb02.dbo.custinfo ci WITH(NOLOCK) ON crm.CreatorID = ci.custID
					LEFT JOIN crmCountry ct WITH(NOLOCK) ON ct.CountryID = crm.CountryID
					LEFT JOIN bodb02.dbo.Customer cm WITH(NOLOCK) on c.custID = cm.CustID
		WHERE 
			c.custID = @custID

		--2nd Record Set
		SELECT cl.LanguageID FROM crmCustomerLanguage cl WITH (NOLOCK) WHERE CustID = @custID
		END
		ELSE -- there is a customer in crm
		BEGIN
			print 'search in crm'
			SELECT	
			crm.CustID, 
			crm.UserName, 
			cm.username2,
			crm.TitleID, 
			crm.FirstName, 
			crm.LastName, 
			crm.Phone, 
			crm.PhoneCountryCode,
			crm.PhoneAreaCode,
			crm.Phone2,
			crm.Phone2CountryCode,
			crm.Phone2AreaCode,
			crm.Phone3,
			crm.Phone3CountryCode,
			crm.Phone3AreaCode,
			crm.MobilePhone,
			crm.MobilePhoneCountryCode,
			crm.MobilePhoneAreaCode,
			crm.Fax, 
			crm.FaxCountryCode, 
			crm.FaxAreaCode, 
			crm.Email, 
			crm.Skype,
			crm.msn,
			crm.Birthday, 
			crm.RefCode1, 
			crm.RefCode2, 
			crm.Pic1, 
			crm.Pic2, 
			crm.Pic3,
			crm.Pic4,
			crm.Question, 
			crm.Answer, 
			crm.CountryID,
			ct.CountryName, 
			crm.IsVIP,
			crm.SiteID,
			crm.Wire_BankName, 
			crm.Wire_BankAddress, 
			crm.Wire_SwiftCode, 
			crm.Wire_AccountName, 
			crm.Wire_AccountNo,
			crm.Remark, 
			crm.CreateDate, 
			ci.Username as CreatorName,
			CASE cm.roleid	WHEN 1 THEN 7000
							WHEN 2 THEN 7001
							WHEN 3 THEN 7002
							WHEN 4 THEN 7003
							ELSE 7004 
			END AS RoleID,
			danger = NULL,
			danger2 = NULL,
			danger3 = NULL,
			Active = NULL,
			Closed = NULL,
			Suspended = NULL
		FROM 
			crmCustomer crm WITH(NOLOCK) 
						LEFT JOIN bodb02.dbo.custinfo ci WITH(NOLOCK) ON crm.CreatorID = ci.custID
						LEFT JOIN crmCountry ct WITH(NOLOCK) ON ct.CountryID = crm.CountryID
						LEFT JOIN bodb02.dbo.customer cm WITH(NOLOCK) ON cm.custid = crm.custID						
														
		WHERE 
			crm.custID = @custID

		--2nd Record Set
		SELECT cl.LanguageID FROM crmCustomerLanguage cl WITH (NOLOCK) WHERE CustID = @custID
		END
	END
	ELSE IF @IsGuest=1  ---- if guest = 1
	BEGIN		
		print 'search guest'
		SELECT	@custID = custID 
		FROM crmCustomer WITH (NOLOCK) 
		WHERE (
				UserName = @UserName
				OR PhoneCountryCode+PhoneAreaCode+Phone LIKE '%'+@username
					OR Phone2CountryCode+Phone2AreaCode+Phone2 LIKE '%'+@username
					OR Phone3CountryCode+Phone3AreaCode+Phone3 LIKE '%'+@username
					OR MobilePhoneCountryCode+MobilePhoneAreaCode+MobilePhone LIKE '%'+@username
			) 
			AND custID < 0
		
		SELECT	
			crm.CustID, 
			crm.UserName, 
			crm.TitleID, 
			crm.FirstName, 
			crm.LastName, 
			crm.Phone, 
			crm.PhoneCountryCode,
			crm.PhoneAreaCode,
			crm.Phone2,
			crm.Phone2CountryCode,
			crm.Phone2AreaCode,
			crm.Phone3,
			crm.Phone3CountryCode,
			crm.Phone3AreaCode,
			crm.MobilePhone,
			crm.MobilePhoneCountryCode,
			crm.MobilePhoneAreaCode,
			crm.Fax, 
			crm.FaxCountryCode, 
			crm.FaxAreaCode, 
			crm.Email, 
			crm.Skype,
			crm.msn,
			crm.Birthday, 
			crm.RefCode1, 
			crm.RefCode2, 
			crm.Pic1, 
			crm.Pic2, 
			crm.Pic3,
			crm.Pic4,
			crm.Question, 
			crm.Answer, 
			crm.CountryID,
			ct.CountryName, 
			crm.IsVIP,
			crm.SiteID,
			crm.Wire_BankName, 
			crm.Wire_BankAddress, 
			crm.Wire_SwiftCode, 
			crm.Wire_AccountName, 
			crm.Wire_AccountNo,
			crm.Remark, 
			crm.CreateDate, 
			ci.Username as CreatorName,
			7004 as roleID,
			danger = NULL,
			danger2 = NULL,
			danger3 = NULL,
			Active = NULL,
			Closed = NULL,
			Suspended = NULL
		FROM 
			crmCustomer crm WITH(NOLOCK) 
						INNER JOIN bodb02.dbo.custinfo ci WITH(NOLOCK) ON crm.CreatorID = ci.custID
						LEFT JOIN crmCountry ct WITH(NOLOCK) ON ct.CountryID = crm.CountryID						
														
		WHERE 
			crm.custID = @custID

		--2nd Record Set
		SELECT cl.LanguageID FROM crmCustomerLanguage cl WITH (NOLOCK) WHERE CustID = @custID
	END	
END


GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_CustomerSearch] TO [bodbAdminNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_CustomerSearch] TO [vnteam]
GO 
