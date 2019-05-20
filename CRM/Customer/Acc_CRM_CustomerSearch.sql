/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_CustomerSearch]
(
	@Username	NVARCHAR(50) = '',
	@IsGuest	BIT = 0,
	@UserRole   TINYINT
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
	- 20141118@Dom: Return PIC Name
	- 20160916@Winnie: Include 'Checker' and 'Ignored Accounts' RedmineID: #64067
	- 20180924@Winnie: Search Chinese RedmineID: #99982
	- 20190506@Winnie: CN88 Permission RedmineID: #112637
Param's Explanation:	
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @custID INT,
			@SiteID INT,
			@RoleID TINYINT,
			@CountryName varchar(100),
			@CountryID int,
			@IsGroupHeadLine BIT
	
	CREATE TABLE #SuperCN88(CustID INT PRIMARY KEY)
	INSERT INTO #SuperCN88(CustID)
	SELECT CustID FROM bodb02.dbo.CustSuper WITH(NOLOCK) 
	WHERE UplineId IS NOT NULL

	IF @IsGuest = 0
	BEGIN
		PRINT 'search by username';
		EXEC DBACC.bodb02.dbo.Acc_UserInfoSel --- search by username
			@Username = @Username,	
			@IsNickName = 0,	
			@UserID = @custID OUTPUT,
			@RoleID = @RoleID OUTPUT,
			@UserRole=@UserRole		
		
		IF @custID IS NULL    --- search by nickname
		BEGIN
			PRINT 'search by nickname';
			EXEC DBACC.bodb02.dbo.Acc_UserInfoSel 
			@Username = @Username,	
			@IsNickName = 1,	
			@UserID = @custID OUTPUT,
			@RoleID = @RoleID OUTPUT,
			@UserRole=@UserRole				
		END
		
		IF @custID IS NULL    --- search by phone in IBC
		BEGIN
			PRINT 'search by phone in IBC';	
			SELECT @custID = c.custID ,
			@RoleID = RoleID 
			FROM bodb02.dbo.Customer(NOLOCK) c
			WHERE c.phone = @UserName OR c.mobilephone = @username	
				AND (@UserRole=0 
				OR(@UserRole=1 AND (c.srecommend=0 OR EXISTS (SELECT TOP 1 1 FROM #SuperCN88 WITH(NOLOCK) WHERE CustId=c.srecommend)))
				OR(@UserRole=2 AND NOT EXISTS (SELECT TOP 1 1 FROM #SuperCN88 WITH(NOLOCK) WHERE CustId=srecommend))
				)	
		END					
		
		IF @custID IS NULL    --- search by phone in CRM
		BEGIN
			PRINT 'search by phone in CRM';	
			SELECT	@custID = custID 
			FROM crmCustomer WITH (NOLOCK) 
			WHERE (
					UserName = @UserName
					OR PhoneCountryCode+PhoneAreaCode+Phone = @username
						OR Phone2CountryCode+Phone2AreaCode+Phone2 = @username
						OR Phone3CountryCode+Phone3AreaCode+Phone3 = @username
						OR MobilePhoneCountryCode+MobilePhoneAreaCode+MobilePhone = @username
				) 
				AND CustID > 0
				AND ((@UserRole=2 AND SiteID<>33002) 
					OR (@UserRole=1 AND SiteID=33002) 
					OR @UserRole=0)
		END

		IF @custID IS NULL    --search all system but cannot find Customer -> Quit Execution
		BEGIN
			PRINT 'No Customer' ;
			RETURN;
		END
		
	
--=====================END SEARCH CROSS SYSTEM===================================================

--=====================RETURN RESULT=============================================================

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
			-----return customer
			SELECT @CountryName = Country,
					@CountryID = c.CountryID
			FROM bodb02.dbo.Customer cm WITH(NOLOCK)
			INNER JOIN crmCountry c ON cm.country = c.CountryName
			WHERE cm.custid = @custID
			
			print 'search in IBC'

			SELECT @IsGroupHeadLine=ISNULL(IsGroupHeadLine,0) FROM bodb02.dbo.custAccount WITH(NOLOCK) WHERE custid=@CustID AND IsGroupHeadLine=1

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
			crm.Pic1Name, 
			crm.Pic2Name, 
			crm.Pic3Name,
			crm.Pic4Name,
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
			CASE WHEN c.roleid=1 AND @UserRole=2 THEN 7000
				 WHEN c.roleid=2 AND @UserRole=2  THEN 7001
				 WHEN c.roleid=3 AND @UserRole=2  THEN 7002
				 WHEN c.roleid=4 AND @UserRole=2  THEN 7003
				 WHEN c.roleid NOT IN(1,2,3,4) AND @UserRole=2  THEN 7004
				 WHEN c.roleid=1 AND @UserRole=1  THEN 7011
				 WHEN c.roleid=2 AND @UserRole=1  THEN 7007
				 WHEN c.roleid=3 AND @UserRole=1  THEN 7008
				 WHEN c.roleid=4 AND @UserRole=1  THEN 7009
				 WHEN c.roleid=0 AND @UserRole=1  THEN 7006	
				 WHEN c.roleid NOT IN(1,2,3,4,0) AND @UserRole=1 THEN 7010
			END AS RoleID,
			c.danger,
			c.danger2,
			c.danger3,
			CASE WHEN c.Closed = 0 and ISNULL(c.reject,0) = 0 THEN 1 ELSE 0 END Active,
			CASE WHEN c.Closed = 1 THEN 1 ELSE 0 END Closed,
			CASE WHEN ISNULL(c.reject,0) = 1 and c.Closed = 0 THEN 1 ELSE 0 END Suspended,
			@IsGroupHeadLine IsGroupHeadLine,
			ISNULL(crm.LicenseeType,0) LicenseeType,
			'' WhatsApp,
			'' Line,
			'' WeChat,
			'' Yahoo,
			'' QQ,
			'' BBM,
			ISNULL(crm.Ignored,0) AS Ignored ,
			crm.Checker
		FROM 
			bodb02.dbo.custinfo c WITH(NOLOCK) 
					--INNER JOIN bodb02.dbo.customer ci WITH(NOLOCK) ON c.custid=ci.custid
					--LEFT JOIN crmsetting s WITH(NOLOCK) ON ci.site=crmSeeting
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

			SELECT @IsGroupHeadLine=ISNULL(IsGroupHeadLine,0) FROM bodb02.dbo.custAccount WITH(NOLOCK) WHERE custid=@CustID AND IsGroupHeadLine=1

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
			crm.Pic1Name, 
			crm.Pic2Name, 
			crm.Pic3Name,
			crm.Pic4Name,
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
			CASE WHEN c.roleid=1 AND @UserRole=2 THEN 7000
				 WHEN c.roleid=2 AND @UserRole=2  THEN 7001
				 WHEN c.roleid=3 AND @UserRole=2  THEN 7002
				 WHEN c.roleid=4 AND @UserRole=2  THEN 7003
				 WHEN c.roleid NOT IN(1,2,3,4) AND @UserRole=2  THEN 7004
				 WHEN c.roleid=1 AND @UserRole=1  THEN 7011
				 WHEN c.roleid=2 AND @UserRole=1  THEN 7007
				 WHEN c.roleid=3 AND @UserRole=1  THEN 7008
				 WHEN c.roleid=4 AND @UserRole=1  THEN 7009
				 WHEN c.roleid=0 AND @UserRole=1  THEN 7006
				 WHEN c.roleid NOT IN(1,2,3,4,0) AND @UserRole=1 THEN 7010
			END AS RoleID,
			c.danger,
			c.danger2,
			c.danger3,
			CASE WHEN c.Closed = 0 and ISNULL(c.reject,0) = 0 THEN 1 ELSE 0 END Active,
			CASE WHEN c.Closed = 1 THEN 1 ELSE 0 END Closed,
			CASE WHEN ISNULL(c.reject,0) = 1 and c.Closed = 0 THEN 1 ELSE 0 END Suspended,
			@IsGroupHeadLine IsGroupHeadLine,
			ISNULL(crm.LicenseeType,0) LicenseeType,
			ISNULL(crm.WhatsApp,'') WhatsApp,
			ISNULL(crm.Line,'') Line,
			ISNULL(crm.WeChat,'') WeChat,
			ISNULL(crm.Yahoo,'') Yahoo,
			ISNULL(crm.QQ,'') QQ,
			ISNULL(crm.BBM,'') BBM,
			ISNULL(crm.Ignored,0) AS Ignored ,
			crm.Checker
		FROM 
			crmCustomer crm WITH(NOLOCK) 
						LEFT JOIN bodb02.dbo.custinfo ci WITH(NOLOCK) ON crm.CreatorID = ci.custID
						LEFT JOIN crmCountry ct WITH(NOLOCK) ON ct.CountryID = crm.CountryID
						LEFT JOIN bodb02.dbo.customer cm WITH(NOLOCK) ON cm.custid = crm.custID			
						LEFT JOIN bodb02.dbo.custinfo c WITH(NOLOCK) ON c.custid = crm.CustID		
														
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
				OR PhoneCountryCode+PhoneAreaCode+Phone = @username
					OR Phone2CountryCode+Phone2AreaCode+Phone2 = @username
					OR Phone3CountryCode+Phone3AreaCode+Phone3 = @username
					OR MobilePhoneCountryCode+MobilePhoneAreaCode+MobilePhone = @username
			) 
			AND custID < 0
			AND ((@UserRole=2 AND SiteID<>33002) 
				OR (@UserRole=1 AND SiteID=33002) 
				OR @UserRole=0)

		IF(@custID IS NULL) RETURN;

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
			crm.Pic1Name, 
			crm.Pic2Name, 
			crm.Pic3Name,
			crm.Pic4Name,
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
			CASE WHEN @UserRole=2 THEN 7004
				 WHEN @UserRole=1 THEN 7010 END AS roleID,
			danger = NULL,
			danger2 = NULL,
			danger3 = NULL,
			Active = NULL,
			Closed = NULL,
			Suspended = NULL,
			CAST(0 as BIT) IsGroupHeadLine,
			ISNULL(crm.LicenseeType,0) LicenseeType,
			ISNULL(crm.WhatsApp,'') WhatsApp,
			ISNULL(crm.Line,'') Line,
			ISNULL(crm.WeChat,'') WeChat,
			ISNULL(crm.Yahoo,'') Yahoo,
			ISNULL(crm.QQ,'') QQ,
			ISNULL(crm.BBM,'') BBM,
			ISNULL(crm.Ignored,0) AS Ignored ,
			crm.Checker
		FROM 
			crmCustomer crm WITH(NOLOCK) 
						LEFT JOIN bodb02.dbo.custinfo ci WITH(NOLOCK) ON crm.CreatorID = ci.custID
						LEFT JOIN crmCountry ct WITH(NOLOCK) ON ct.CountryID = crm.CountryID						
														
		WHERE 
			crm.custID = @custID

		--2nd Record Set
		SELECT cl.LanguageID FROM crmCustomerLanguage cl WITH (NOLOCK) WHERE CustID = @custID
	END	
END

GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_CustomerSearch] TO [bodbAdminNet]
GO 
