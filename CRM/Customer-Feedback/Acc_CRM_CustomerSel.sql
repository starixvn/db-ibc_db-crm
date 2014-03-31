
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.Acc_CRM_CustomerSel    Script Date: 3/26/2014 6:06:05 PM ******/
CREATE PROCEDURE [dbo].[Acc_CRM_CustomerSel]
(
	@CustID	INT
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
	- 20140303@Dom: Modify for new structure
Param's Explanation:	
*/
BEGIN	
	SET NOCOUNT ON

	DECLARE @SiteID INT

	IF @CustID < 0
	BEGIN
		SELECT  
			c.CustID, 
			c.UserName, 
			c.TitleID, 
			c.FirstName, 
			c.LastName, 
			c.Phone, 
			c.MobilePhone, 
			c.Fax, 
			c.Email, 
			c.Skype,
			c.msn,
			c.Birthday,
			c.RefCode1,
			c.RefCode2, 
			c.Pic1, 
			c.Pic2, 
			c.Pic3, 
			c.LanguageID, 
			c.Question, 
			c.Answer, 
			c.CountryID, 
			c.IsVIP,
			c.SiteID,
			c.Wire_BankName, 
			c.Wire_BankAddress, 
			c.Wire_SwiftCode, 
			c.Wire_AccountName,
			c.Wire_AccountNo, 
			c.AccountHolderName,
			c.Remark2,
			c.Remark, 
			c.CreateDate, 
			c.CreatorID, 
			ci.username as CreatorName,
			0 as RoleID
		FROM 
			crmCustomer c WITH(NOLOCK) 
					LEFT JOIN bodb02.dbo.customer ci WITH(NOLOCK) ON c.CreatorID = ci.custID
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
		END

		SELECT 
			ci.CustID, 
			ci.UserName, 
			ci.UserName2,
			c.TitleID, 
			c.FirstName, 
			c.LastName, 
			c.Phone, 
			c.MobilePhone, 
			c.Fax, 
			c.Email, 
			c.Skype,
			c.msn,
			c.Birthday,
			c.RefCode1,
			c.RefCode2, 
			c.Pic1, 
			c.Pic2, 
			c.Pic3, 
			c.LanguageID, 
			c.Question, 
			c.Answer, 
			c.CountryID, 
			c.IsVIP,	
			ISNULL(c.SiteID,@SiteID) SiteID,
			c.Wire_BankName, 
			c.Wire_BankAddress, 
			c.Wire_SwiftCode, 
			c.Wire_AccountName,
			c.Wire_AccountNo, 
			c.AccountHolderName,
			c.Remark2,
			c.Remark, 
			c.CreateDate, 
			c.CreatorID,
			cr.username AS CreatorName,
			CASE ci.roleid	WHEN 1 THEN 7000
							WHEN 2 THEN 7001
							WHEN 3 THEN 7002
							WHEN 4 THEN 7003
							ELSE 7004 
			END AS RoleID
		FROM 
			bodb02.dbo.customer ci WITH(NOLOCK) 
					LEFT JOIN crmCustomer c WITH(NOLOCK) ON ci.custid = c.CustID
					LEFT JOIN bodb02.dbo.custinfo cr WITH(NOLOCK) ON c.CreatorID = cr.custID
		WHERE 
			ci.custid = @CustID
	END
END


GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_CustomerSel] TO [bodbAdminNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_CustomerSel] TO [vnteam]
GO 
