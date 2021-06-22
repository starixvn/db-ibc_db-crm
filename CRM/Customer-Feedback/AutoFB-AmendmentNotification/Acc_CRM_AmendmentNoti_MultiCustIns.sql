/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_AmendmentNoti_MultiCustIns]
(
	@RelatedCustomers			VARCHAR(MAX)	= NULL,
	@UserID						INT = 0,
	@CreatorID					INT  = 0 ,
	@IP							VARCHAR(15),
	@ErrCode					INT				= 0 OUTPUT,
	@ErrMsg						NVARCHAR(4000)	= '' OUTPUT	
)
AS
/*
Created: Winfred	
Date: 20210312
Task : Sync Related Customers
DB: DB052.bodb_CRM
Original:

Revisions:
	- 20210312@Winfred: Sync Multiple Related Customers RedmineID: #147470
Param's Explanation:
	
*/
BEGIN	
	SET NOCOUNT ON

	SELECT	@ErrCode	= 0,
			@ErrMsg		= ''
	
	CREATE TABLE #tblRelatedCustomer (CustId INT, 
									RelatedCustId INT, 
									Username NVARCHAR(50),
									TitleID INT,
									FirstName NVARCHAR(100),
									LastName NVARCHAR(100),
									phone NVARCHAR(100),
									MobilePhone NVARCHAR(100),
									Fax NVARCHAR(100),
									Email NVARCHAR(100),
									Birthday SMALLDATETIME,
									CountryID INT,
									SiteID INT,	
									isFinished BIT DEFAULT(0)
									)
	IF ISNULL(@RelatedCustomers, '') <> ''
	BEGIN
		CREATE CLUSTERED INDEX ix_RelatedCustId ON #tblRelatedCustomer (RelatedCustId)	
		DECLARE @iDoc INT , @CreateDate DATETIME
		EXEC sp_xml_preparedocument @iDoc OUTPUT
			,@RelatedCustomers

		INSERT INTO #tblRelatedCustomer (CustId, RelatedCustId, Username)
		SELECT CustId, RelatedCustId, Username
		FROM OPENXML(@iDoc, '/ROOT/Row', 1) WITH (CustId INT, RelatedCustId INT, Username NVARCHAR(50))

		EXEC sp_xml_removedocument @iDoc
		-- delete exist customer
		DELETE B FROM #tblRelatedCustomer B WITH(ROWLOCK, UPDLOCK) WHERE EXISTS (SELECT 1 FROM crmCustomer a WITH(NOLOCK) WHERE a.CustID = B.RelatedCustId)

		IF NOT EXISTS (SELECT 1	FROM #tblRelatedCustomer WITH(NOLOCK) ) RETURN
	
		IF EXISTS (SELECT 1	FROM #tblRelatedCustomer a  WITH(NOLOCK)
							WHERE  NOT EXISTS (SELECT 1
												FROM bodb02.dbo.custinfo c WITH (NOLOCK)
												WHERE c.CustID = a.RelatedCustID)
						 ) 
		BEGIN
			SELECT @ErrCode = 101
			SELECT @ErrMsg = 'Customer does not exist in IBC system.'
			RETURN
		END				
	
		UPDATE t
		SET t.FirstName = c.FirstName,
			t.LastName = c.LastName, 
			t.phone = c.phone,
			t.MobilePhone = c.MobilePhone,
			t.Fax = c.Fax,
			t.Email = c.Email,
			t.Birthday = c.Birthday,
			t.CountryID = ct.CountryID,
			t.SiteID = (SELECT SettingID 
						FROM crmSetting WITH(NOLOCK) 
						WHERE SettingValue = ISNULL(c.site,ag.site)
							AND SettingName IN( 'Site','SiteCategory')
						)
		FROM #tblRelatedCustomer t WITH(NOLOCK) 
			INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON t.RelatedCustId = c.custid
			LEFT JOIN bodb02.dbo.Customer ag WITH(NOLOCK) ON c.recommend = ag.custid
			LEFT JOIN crmCountry ct WITH(NOLOCK) ON c.country = ct.CountryName
		
		UPDATE t
		SET t.SiteID = site.SiteID
		FROM #tblRelatedCustomer t WITH(NOLOCK) 
		INNER JOIN bodb02.dbo.CustInfo c WITH(NOLOCK) ON t.RelatedCustId = c.custid
		INNER JOIN bodb02.dbo.Customer super WITH(NOLOCK) ON c.srecommend = super.custid
		INNER JOIN crmSite site WITH(NOLOCK) ON site.sitename = super.site
		WHERE t.SiteID IS NULL
		
		INSERT INTO crmCustomer
				(	
					CustID, 
					UserName, 
					FirstName, 
					LastName, 
					Phone,  
					MobilePhone, 
					Fax, 
					Email,
					Birthday,
					CountryID, 
					IsVIP,
					SiteID,
					CreateDate, 
					CreatorID
				)
			SELECT
					t.RelatedCustId, 
					UserName, 
					FirstName, 
					LastName, 
					Phone, 
					MobilePhone, 
					Fax, 
					Email, 
					Birthday,
					CountryID, 
					0 AS IsVIP,
					SiteID, 
					GETDATE() AS CreateDate, 
					@CreatorID AS CreatorID
			FROM #tblRelatedCustomer t  WITH(NOLOCK)	
						 
		IF @@ERROR <> 0
		BEGIN
			SELECT @ErrCode = 102
			SELECT @ErrMsg = 'create new customer unsuccessfuly.'
			
			DELETE CA FROM crmCustomer  CA WITH(ROWLOCK, UPDLOCK)
			WHERE EXISTS (SELECT 1
						  FROM #tblRelatedCustomer B  WITH(NOLOCK)
						  WHERE CA.CustID = B.RelatedCustId)
			
			RETURN
		END
		
		INSERT INTO crmCustomerSearch(CustID,UserName,SearchCount,PhoneNumber1,PhoneNumber2,PhoneNumber3,MobilePhone)
		SELECT t.RelatedCustId, UserName,0 AS SearchCount
		,ISNULL(Phone,'') AS PhoneNumber1
		,'' AS PhoneNumber2
		,'' AS PhoneNumber3
		,ISNULL(MobilePhone,'') AS MobilePhone
		FROM #tblRelatedCustomer t  WITH(NOLOCK)	

		IF @@ERROR <> 0
		BEGIN
			DELETE CA FROM crmCustomer  CA WITH(ROWLOCK, UPDLOCK)
			WHERE EXISTS (SELECT 1
						  FROM #tblRelatedCustomer B  WITH(NOLOCK)
						  WHERE CA.CustID = B.RelatedCustId)
			
			DELETE CA FROM crmCustomerSearch  CA WITH(ROWLOCK, UPDLOCK)
			WHERE EXISTS (SELECT 1
						  FROM #tblRelatedCustomer B  WITH(NOLOCK)  
						  WHERE CA.CustID = B.RelatedCustId)					  
			SELECT @ErrCode = 102
			SELECT @ErrMsg = 'create new customer unsuccessfuly.'
			RETURN
		END
		SET @CreateDate = GETDATE()	
		INSERT INTO crmLogCustomer  
		(  
		 LogDate,   
		 CustID,   
		 UserID,   
		 ActionID,    
		 IP,   
		 Doing  
		)  
		SELECT 
			@CreateDate AS LogDate,
			RelatedCustId AS CustID,   
			@UserID AS UserID,   
			107 AS ActionID,    
			@IP AS IP, 
			CAST (				
			'<Acc_CRM_AmendmentNoti_MultiCustIns>'			+ --SP Name
				'<UserName>'				+ ISNULL(UserName,'')											+ '</UserName>' +
				'<FirstName>'				+ ISNULL([dbo].[f_EncodeXMLValue](FirstName),'')				+ '</FirstName>' +
				'<LastName>'				+ ISNULL([dbo].[f_EncodeXMLValue](LastName),'')					+ '</LastName>' +
				'<TitleID>'					+ ''			+ '</TitleID>' +
				'<Birthday>'				+ ISNULL(CONVERT(VARCHAR(30),Birthday),'')						+ '</Birthday>' +
				'<LanguageID>'				+ ''			+ '</LanguageID>' +
				'<Phone>'					+ ISNULL([dbo].[f_EncodeXMLValue](Phone),'')					+ '</Phone>' +
				'<PhoneCountryCode>'		+ ''			+ '</PhoneCountryCode>' +
				'<PhoneAreaCode>'			+ ''			+ '</PhoneAreaCode>' +
				'<Phone2>'					+ ''			+ '</Phone2>' +
				'<Phone2CountryCode>'		+ ''			+ '</Phone2CountryCode>' +
				'<Phone2AreaCode>'			+ ''			+ '</Phone2AreaCode>' +
				'<Phone3>'					+ ''			+ '</Phone3>' +
				'<Phone3CountryCode>'		+ ''			+ '</Phone3CountryCode>' +
				'<Phone3AreaCode>'			+ ''			+ '</Phone3AreaCode>' +
				'<Passport>'				+ ''			+ '</Passport>' +
				'<MobilePhone>'				+ ISNULL([dbo].[f_EncodeXMLValue](MobilePhone),'')				+ '</MobilePhone>' +
				'<MobilePhoneCountryCode>'	+ ''			+ '</MobilePhoneCountryCode>' +
				'<MobilePhoneAreaCode>'		+ ''			+ '</MobilePhoneAreaCode>' +
				'<Fax>'						+ ISNULL([dbo].[f_EncodeXMLValue](Fax),'')						+ '</Fax>' +
				'<FaxCountryCode>'			+ ''			+ '</FaxCountryCode>' +
				'<FaxAreaCode>'				+ ''			+ '</FaxAreaCode>' +
				'<Email>'					+ ISNULL([dbo].[f_EncodeXMLValue](Email),'')					+ '</Email>' +
				'<Skype>'					+ ''			+ '</Skype>' +
				'<MSN>'						+ ''			+ '</MSN>' +
				'<BettingCode>'				+ ''			+ '</BettingCode>' +
				'<RefCode2>'				+ ''			+ '</RefCode2>' +
				'<Pic1>'					+ ''			+ '</Pic1>' +
				'<Pic2>'					+ ''			+ '</Pic2>' +
				'<Pic3>'					+ ''			+ '</Pic3>' +
				'<Pic4>'					+ ''			+ '</Pic4>' +
				'<Pic1Name>'				+ ''			+ '</Pic1Name>' +
				'<Pic2Name>'				+ ''			+ '</Pic2Name>' +
				'<Pic3Name>'				+ ''			+ '</Pic3Name>' +
				'<Pic4Name>'				+ ''			+ '</Pic4Name>' +
				'<Line1>'					+ ''			+ '</Line1>' +
				'<Line2>'					+ ''			+ '</Line2>' +
				'<Line3>'					+ ''			+ '</Line3>' +
				'<City>'					+ ''			+ '</City>' +
				'<Postcode>'				+ ''			+ '</Postcode>' +
				'<State>'					+ ''			+ '</State>' +
				'<BankLine1>'				+ ''			+ '</BankLine1>' +
				'<BankLine2>'				+ ''			+ '</BankLine2>' +
				'<BankLine3>'				+ ''			+ '</BankLine3>' +
				'<BankCity>'				+ ''			+ '</BankCity>' +
				'<BankCode>'				+ ''			+ '</BankCode>' +
				'<BankState>'				+ ''			+ '</BankState>' +
				'<Question>'				+ ''			+ '</Question>' +
				'<Answer>'					+ ''			+ '</Answer>' +
				'<CountryID>'				+ ISNULL(CONVERT(VARCHAR(10),CountryID),'')					+ '</CountryID>' +
				'<IsVIP>'					+ '0'			+ '</IsVIP>' +	
				'<SiteID>'					+ ISNULL(CONVERT(VARCHAR(10),SiteID),'')						+ '</SiteID>' +
				'<BankName>'				+ ''	+ '</BankName>' +
				'<BankAddress>'				+ ''	+ '</BankAddress>' +
				'<AccountName>'				+ ''	+ '</AccountName>' +
				'<AccountNo>'				+ ''	+ '</AccountNo>' +
				'<SwiftCode>'				+ ''	+ '</SwiftCode>' +
				'<AccountHolderName>'		+ ''	+ '</AccountHolderName>' +	
				'<CreatorID>'				+ ISNULL(CONVERT(VARCHAR(10),@CreatorID),'')					+ '</CreatorID>' +
				'<IsVerifyEmail>'			+''		+ '</IsVerifyEmail>' +
				'<IsVerifyPassport>'		+ ''	+ '</IsVerifyPassport>' +
				'<IsVerifyBirthday>'		+ ''	+ '</IsVerifyBirthday>' +
				'<IsVerifySecretCode>'		+ ''	+ '</IsVerifySecretCode>' +
				'<IsVerifyBetCredit>'		+ ''	+ '</IsVerifyBetCredit>' +
				'<LicenseeType>'			+ ''	+ '</LicenseeType>' +
				'<WhatsApp>'				+ ''	+ '</WhatsApp>' +
				'<Line>'					+ ''	+ '</Line>' +
				'<WeChat>'					+ ''	+ '</WeChat>' +
				'<Yahoo>'					+ ''	+ '</Yahoo>' +
				'<QQ>'						+ ''	+ '</QQ>' +
				'<BBM>'						+ ''	+ '</BBM>' +
				'<IntroducedBy>'			+ ''	+ '</IntroducedBy>' +
				'<Ignored>'					+ ''	+ '</Ignored>' +
				'<ProvinceID>'				+ ''	+ '</ProvinceID>' +
			'</Acc_CRM_AmendmentNoti_MultiCustIns>'  AS XML) AS Doing
			FROM #tblRelatedCustomer t WITH(NOLOCK)

	END
END	
