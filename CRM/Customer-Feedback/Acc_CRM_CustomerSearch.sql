
ALTER PROCEDURE [dbo].[Acc_CRM_CustomerSearch]
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
Param's Explanation:	
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @custID INT,
			@SiteID INT,
			@RoleID TINYINT

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
		END

		SELECT	
			c.CustID, 
			c.UserName, 
			cm.UserName2,
			crm.TitleID, 
			crm.FirstName, 
			crm.LastName, 
			crm.Phone, 
			crm.MobilePhone,
			crm.Fax, 
			crm.Email, 
			crm.Skype,
			crm.msn,
			crm.Birthday, 
			crm.RefCode1, 
			crm.RefCode2, 
			crm.Pic1, 
			crm.Pic2, 
			crm.Pic3,
			crm.LanguageID, 
			crm.Question, 
			crm.Answer, 
			crm.CountryID, 
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
			CASE ci.roleid	WHEN 1 THEN 7000
							WHEN 2 THEN 7001
							WHEN 3 THEN 7002
							WHEN 4 THEN 7003
							ELSE 7004 
			END AS RoleID
		FROM 
			bodb02.dbo.custinfo c WITH(NOLOCK) 
					LEFT JOIN crmCustomer crm WITH(NOLOCK) ON c.custID = crm.custID
					LEFT JOIN bodb02.dbo.custinfo ci WITH(NOLOCK) ON crm.CreatorID = ci.custID
					LEFT JOIN crmCountry ct WITH(NOLOCK) ON ct.CountryID = crm.CountryID
					Left JOIN bodb02.dbo.Customer cm WITH(NOLOCK) on c.custID = cm.CustID
		WHERE 
			c.custID = @custID
	END
	ELSE   ---- if guest = 1
	BEGIN		
		SELECT	@custID = custID FROM crmCustomer WITH (NOLOCK) WHERE UserName = @UserName AND custID < 0
		SELECT	
			crm.CustID, 
			crm.UserName, 
			crm.TitleID, 
			crm.FirstName, 
			crm.LastName, 
			crm.Phone, 
			crm.MobilePhone,
			crm.Fax, 
			crm.Email, 
			crm.Skype,
			crm.msn,
			crm.Birthday, 
			crm.RefCode1, 
			crm.RefCode2, 
			crm.Pic1, 
			crm.Pic2, 
			crm.Pic3,
			crm.LanguageID, 
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
			7004 as roleID
		FROM 
			crmCustomer crm WITH(NOLOCK) 
						INNER JOIN bodb02.dbo.custinfo ci WITH(NOLOCK) ON crm.CreatorID = ci.custID
						LEFT JOIN crmCountry ct WITH(NOLOCK) ON ct.CountryID = crm.CountryID						
														
		WHERE 
			crm.custID = @custID
	END	
END

GO
GRANT EXECUTE ON [dbo].[Acc_CRM_CustomerSearch] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_CustomerSearch] TO [vnteam]