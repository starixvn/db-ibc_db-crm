/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_CustomerIns_New]
(
	@UserID						INT,
	@CustID						INT OUTPUT,
	@UserName					NVARCHAR(50),
	@FirstName					NVARCHAR(50)	= NULL,
	@LastName					NVARCHAR(50)	= NULL,
	@TitleID					INT				= NULL,
	@Birthday					SMALLDATETIME	= NULL,
	@LanguageID					VARCHAR(1000)	= NULL,
	@Phone						NVARCHAR(50)	= NULL,
	@PhoneCountryCode			NVARCHAR(20)	= NULL,
	@PhoneAreaCode				NVARCHAR(20)	= NULL,
	@Phone2						NVARCHAR(50)	= NULL,
	@Phone2CountryCode			NVARCHAR(20)	= NULL,
	@Phone2AreaCode				NVARCHAR(20)	= NULL,
	@Phone3						NVARCHAR(50)	= NULL,
	@Phone3CountryCode			NVARCHAR(20)	= NULL,
	@Phone3AreaCode				NVARCHAR(20)	= NULL,
	@Passport					NVARCHAR(100)	= NULL,
	@MobilePhone				NVARCHAR(50)	= NULL,
	@MobilePhoneCountryCode		NVARCHAR(20)	= NULL,
	@MobilePhoneAreaCode		NVARCHAR(20)	= NULL,
	@Fax						NVARCHAR(50)	= NULL,
	@FaxCountryCode				NVARCHAR(20)	= NULL,
	@FaxAreaCode				NVARCHAR(20)	= NULL,
	@Email						NVARCHAR(254)	= NULL,
	@Skype						NVARCHAR(100)	= NULL,
	@MSN						NVARCHAR(100)	= NULL,
	@BettingCode				NVARCHAR(50)	= NULL,
	@RefCode2					NVARCHAR(50)	= NULL,
	@Pic1						NVARCHAR(100)	= NULL,
	@Pic2						NVARCHAR(100)	= NULL,
	@Pic3						NVARCHAR(100)	= NULL,
	@Pic4						NVARCHAR(100)	= NULL,
	@Pic1Name					NVARCHAR(100)	= NULL,
	@Pic2Name					NVARCHAR(100)	= NULL,
	@Pic3Name					NVARCHAR(100)	= NULL,
	@Pic4Name					NVARCHAR(100)	= NULL,
	@Line1						NVARCHAR(100)	= NULL,
	@Line2						NVARCHAR(100)	= NULL,
	@Line3						NVARCHAR(100)	= NULL,
	@City						NVARCHAR(200)	= NULL,
	@PostCode					NVARCHAR(100)	= NULL,
	@State						NVARCHAR(100)	= NULL,
	@BankLine1					NVARCHAR(100)	= NULL,
	@BankLine2					NVARCHAR(100)	= NULL,
	@BankLine3					NVARCHAR(100)	= NULL,
	@BankCity					NVARCHAR(100)	= NULL,
	@BankCode					NVARCHAR(100)	= NULL,
	@BankCountryID				INT				= NULL,
	@BankState					NVARCHAR(100)	= NULL,
	@Question					NVARCHAR(300)	= NULL,
	@Answer						NVARCHAR(300)	= NULL,
	@CountryID					INT				= NULL,
	@IsVIP						BIT				= 0,
	@SiteID						INT				= NULL,
	@Wire_BankName				NVARCHAR(100)	= NULL,
	@Wire_BankAddress			NVARCHAR(200)	= NULL,
	@Wire_AccountName			NVARCHAR(100)	= NULL,
	@Wire_AccountNo				NVARCHAR(50)	= NULL,
	@Wire_SwiftCode				NVARCHAR(50)	= NULL,
	@AccountHolderName			NVARCHAR(100)	= NULL,
	@SpecialRemark				XML				= NULL,	
	@Remark						XML				= NULL,	
	@IsVerifyEmail				BIT				= 0,
	@IsVerifyPassport			BIT				= 0,
	@IsVerifyBirthday			BIT				= 0,
	@IsVerifySecretCode			BIT				= 0,
	@IsVerifyBetCredit			BIT				= 0,
	@IsVerifyGivenCredit		BIT				= 0,
	@CreatorID					INT,
	@LicenseeType				INT				= 0,
	@WhatsApp					NVARCHAR(100)	= NULL,
	@Line						NVARCHAR(100)	= NULL,
	@WeChat						NVARCHAR(100)	= NULL,
	@Yahoo						NVARCHAR(100)	= NULL,
	@QQ							NVARCHAR(100)	= NULL,
	@BBM						NVARCHAR(100)	= NULL,
	@Ignored					BIT	= 0,	
	@ProvinceID					INT=NULL,
	@IntroducedBy				NVARCHAR(50)	= NULL,	
	@IP							VARCHAR(15),
	@ErrCode					INT				= 0 OUTPUT,
	@ErrMsg						NVARCHAR(4000)	= '' OUTPUT	
)
AS
/*
Created: Lukas
Date: 20101022
Task : update customer info
DB: DB052.bodb_CRM
Original:

Revisions:
	- 20110704@Lukas: add two more params @msn, @skype
	- 20120327@Elodie: change data type of @Skype, @MSN, @Pic1, @Pic2, @Pic3 params to NVARCHAR(500)
					   change DB06 to DB052
	- 20120404@Elodie: change data type of @Skype, @MSN, @Pic1, @Pic2, @Pic3 params to NVARCHAR(100)
	- 20120529@Elodie: encode some parameters to write log in XML format, such as Question, Answer, Pic1, ...
	- 20140123@Dom: update remark and language
	- 20141118@Dom: Add new PIC name
	- 20160915@Winnie: Return  'Checker' and 'Ignored Accounts' RedmineID #64067
	- 20170511@Winnie: Duplicate & Missing Special Remark [RedmineID: #76399]
	- 20170914@Winnie: Remove  'Checker' add IntroducedBy RedmineID #82040
	- 20190506@Winnie: CN88 Permission RedmineID: #112637
	- 20190807@Winnie: Fix SP when create account in CRM system: VIP = 0 instead of VIP = NULL RedmineID: #109775
	- 20221013@Winfred: Fix SP when create account duplicate in CRM RedmineID: #179044
Param's Explanation:
	
*/
BEGIN	
	SET NOCOUNT ON

	SELECT	@ErrCode	= 0,
			@ErrMsg		= ''
	
	IF EXISTS (SELECT 1 FROM crmCustomer WITH(NOLOCK) WHERE CustID = @CustID)
	BEGIN
		SELECT @ErrCode = 100
		SELECT @ErrMsg = 'Customer existed already.'
		RETURN
	END
	
	IF NOT EXISTS (SELECT 1 FROM bodb02.dbo.custinfo WITH(NOLOCK) WHERE CustID = @CustID)
	BEGIN
		SELECT @ErrCode = 101
		SELECT @ErrMsg = 'Customer does not exist in IBC system.'
		RETURN
	END
	
	-- check later
	IF @SiteID IS NULL
	BEGIN 
		SELECT @SiteID=site.SiteID FROM bodb02.dbo.CustInfo c WITH(NOLOCK)
		INNER JOIN bodb02.dbo.Customer super WITH(NOLOCK) ON c.srecommend = super.custid
		INNER JOIN crmSite site WITH(NOLOCK) ON site.sitename = super.site
		WHERE c.custid = @CustID
	END
	
	INSERT INTO crmCustomer
				(	
					CustID, 
					UserName, 
					TitleID, 
					FirstName, 
					LastName, 
					Phone, 
					PhoneCountryCode, 
					PhoneAreaCode, 
					Phone2, 
					Phone2CountryCode, 
					Phone2AreaCode, 
					Phone3,
					Phone3CountryCode, 
					Phone3AreaCode, 
					Passport, 
					MobilePhone, 
					MobilePhoneCountryCode, 
					MobilePhoneAreaCode, 
					Fax, 
					FaxCountryCode, 
					FaxAreaCode, 
					Email, 
					Skype,
					msn,
					Birthday,
					RefCode1, 
					RefCode2, 
					Pic1, 
					Pic2, 
					Pic3,
					Pic4,
					Pic1Name, 
					Pic2Name, 
					Pic3Name,
					Pic4Name,
					Line1,
					Line2,
					Line3,
					City,
					Postcode,
					State,
					Question, 
					Answer, 
					CountryID, 
					IsVIP,
					SiteID, 
					Wire_BankName, 
					Wire_BankAddress, 
					Wire_SwiftCode, 
					Wire_AccountName,
					Wire_AccountNo, 
					AccountHolderName,
					BankLine1,
					BankLine2,
					BankLine3,
					BankCountryID,
					BankCity,
					BankCode,
					BankState,
					CreateDate, 
					CreatorID,
					IsVerifyEmail,
					IsVerifyPassport,
					IsVerifyBirthday,
					IsVerifySecretCode,
					IsVerifyBetCredit,
					IsVerifyGivenCredit,
					LicenseeType,
					WhatsApp,
					Line,
					WeChat,
					Yahoo,
					QQ,
					BBM,
					[IntroducedBy],
					Ignored,
					ProvinceID
				)
			SELECT @CustID, 
					@UserName, 
					@TitleID, 
					@FirstName, 
					@LastName, 
					@Phone, 
					@PhoneCountryCode, 
					@PhoneAreaCode, 
					@Phone2, 
					@Phone2CountryCode, 
					@Phone2AreaCode, 
					@Phone3,
					@Phone3CountryCode, 
					@Phone3AreaCode, 
					@Passport, 
					@MobilePhone, 
					@MobilePhoneCountryCode, 
					@MobilePhoneAreaCode, 
					@Fax, 
					@FaxCountryCode, 
					@FaxAreaCode, 
					@Email, 
					@Skype,
					@MSN,
					@Birthday,
					@BettingCode, 
					@RefCode2, 
					@Pic1, 
					@Pic2, 
					@Pic3, 
					@Pic4,
					@Pic1Name, 
					@Pic2Name, 
					@Pic3Name, 
					@Pic4Name,
					@Line1,
					@Line2,
					@Line3,
					@City,
					@Postcode,
					@State,
					@Question, 
					@Answer, 
					@CountryID, 
					@IsVIP,
					@SiteID, 
					@Wire_BankName, 
					@Wire_BankAddress, 
					@Wire_SwiftCode, 
					@Wire_AccountName,
					@Wire_AccountNo, 
					@AccountHolderName,
					@BankLine1,
					@BankLine2,
					@BankLine3,
					@BankCountryID,
					@BankCity,
					@BankCode,
					@BankState,
					GETDATE(), 
					@CreatorID,
					@IsVerifyEmail,
					@IsVerifyPassport,
					@IsVerifyBirthday,
					@IsVerifySecretCode,
					@IsVerifyBetCredit,
					@IsVerifyGivenCredit,
					@LicenseeType,
					@WhatsApp,
					@Line,
					@WeChat,
					@Yahoo,
					@QQ,
					@BBM,
					@IntroducedBy,
					@Ignored,
					@ProvinceID
			WHERE NOT EXISTS (SELECT 1 FROM crmCustomer WITH(NOLOCK) WHERE CustID = @CustID)
	
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrCode = 102
		SELECT @ErrMsg = 'create new customer unsuccessfuly.'
		RETURN
	END

	IF @@ERROR <> 0
	BEGIN
		DELETE crmCustomer WHERE CustID = @CustID
		SELECT @ErrCode = 102
		SELECT @ErrMsg = 'create new customer unsuccessfuly.'
		RETURN
	END

	DELETE crmCustomerLanguage WITH(ROWLOCK,UPDLOCK) WHERE CustID = @CustID
	INSERT INTO crmCustomerLanguage( CustID,LanguageID)
	SELECT @CustID, Val from dbo.f_split(@LanguageID,',')

	IF @@error <> 0
	BEGIN
		DELETE crmCustomer WHERE CustID = @CustID
		SELECT @ErrCode = 102
		SELECT @ErrMsg = 'create new customer unsuccessfuly.'
		RETURN
	END

	INSERT INTO crmCustomerSearch(CustID,UserName,SearchCount,PhoneNumber1,PhoneNumber2,PhoneNumber3,MobilePhone)
	SELECT @CustID, @UserName,0
		,PhoneNumber1 = ISNULL(@PhoneCountryCode,'') + ISNULL(@PhoneAreaCode,'') + ISNULL(@Phone,'')
		,PhoneNumber2 = ISNULL(@Phone2CountryCode,'') + ISNULL(@Phone2AreaCode,'') + ISNULL(@Phone2,'')
		,PhoneNumber3 = ISNULL(@Phone3CountryCode,'') + ISNULL(@Phone3AreaCode,'') + ISNULL(@Phone3,'')
		,MobilePhone = ISNULL(@MobilePhoneCountryCode,'') + ISNULL(@MobilePhoneAreaCode,'') + ISNULL(@MobilePhone,'')
	WHERE NOT EXISTS (SELECT 1 FROM crmCustomerSearch WITH(NOLOCK) WHERE CustID = @CustID)

	IF @@ERROR <> 0
	BEGIN
		DELETE crmCustomer WHERE CustID = @CustID
		DELETE crmCustomerLanguage WITH(ROWLOCK,UPDLOCK) WHERE CustID = @CustID
		SELECT @ErrCode = 102
		SELECT @ErrMsg = 'create new customer unsuccessfuly.'
		RETURN
	END

	-- write log
	DECLARE @LogElement XML

	SELECT @LogElement = 				
					'<Acc_CRM_CustomerIns_New>'			+ --SP Name
						'<UserName>'				+ ISNULL(@UserName,'')											+ '</UserName>' +
						'<FirstName>'				+ ISNULL([dbo].[f_EncodeXMLValue](@FirstName),'')				+ '</FirstName>' +
						'<LastName>'				+ ISNULL([dbo].[f_EncodeXMLValue](@LastName),'')				+ '</LastName>' +
						'<TitleID>'					+ ISNULL(CONVERT(VARCHAR(10),@TitleID),'')						+ '</TitleID>' +
						'<Birthday>'				+ ISNULL(CONVERT(VARCHAR(30),@Birthday),'')						+ '</Birthday>' +
						'<LanguageID>'				+ ISNULL(@LanguageID,'')										+ '</LanguageID>' +
						'<Phone>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Phone),'')					+ '</Phone>' +
						'<PhoneCountryCode>'		+ ISNULL([dbo].[f_EncodeXMLValue](@PhoneCountryCode),'')		+ '</PhoneCountryCode>' +
						'<PhoneAreaCode>'			+ ISNULL([dbo].[f_EncodeXMLValue](@PhoneAreaCode),'')			+ '</PhoneAreaCode>' +
						'<Phone2>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Phone2),'')					+ '</Phone2>' +
						'<Phone2CountryCode>'		+ ISNULL([dbo].[f_EncodeXMLValue](@Phone2CountryCode),'')		+ '</Phone2CountryCode>' +
						'<Phone2AreaCode>'			+ ISNULL([dbo].[f_EncodeXMLValue](@Phone2AreaCode),'')			+ '</Phone2AreaCode>' +
						'<Phone3>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Phone3),'')					+ '</Phone3>' +
						'<Phone3CountryCode>'		+ ISNULL([dbo].[f_EncodeXMLValue](@Phone3CountryCode),'')		+ '</Phone3CountryCode>' +
						'<Phone3AreaCode>'			+ ISNULL([dbo].[f_EncodeXMLValue](@Phone3AreaCode),'')			+ '</Phone3AreaCode>' +
						'<Passport>'				+ ISNULL(@Passport,'')											+ '</Passport>' +
						'<MobilePhone>'				+ ISNULL([dbo].[f_EncodeXMLValue](@MobilePhone),'')				+ '</MobilePhone>' +
						'<MobilePhoneCountryCode>'	+ ISNULL([dbo].[f_EncodeXMLValue](@MobilePhoneCountryCode),'')	+ '</MobilePhoneCountryCode>' +
						'<MobilePhoneAreaCode>'		+ ISNULL([dbo].[f_EncodeXMLValue](@MobilePhoneAreaCode),'')		+ '</MobilePhoneAreaCode>' +
						'<Fax>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Fax),'')						+ '</Fax>' +
						'<FaxCountryCode>'			+ ISNULL([dbo].[f_EncodeXMLValue](@FaxCountryCode),'')			+ '</FaxCountryCode>' +
						'<FaxAreaCode>'				+ ISNULL([dbo].[f_EncodeXMLValue](@FaxAreaCode),'')				+ '</FaxAreaCode>' +
						'<Email>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Email),'')					+ '</Email>' +
						'<Skype>'					+ ISNULL(@Skype,'')												+ '</Skype>' +
						'<MSN>'						+ ISNULL(@MSN,'')												+ '</MSN>' +
						'<BettingCode>'				+ ISNULL(@BettingCode,'')										+ '</BettingCode>' +
						'<RefCode2>'				+ ISNULL(@RefCode2,'')											+ '</RefCode2>' +
						'<Pic1>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Pic1),'')					+ '</Pic1>' +
						'<Pic2>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Pic2),'')					+ '</Pic2>' +
						'<Pic3>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Pic3),'')					+ '</Pic3>' +
						'<Pic4>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Pic4),'')					+ '</Pic4>' +
						'<Pic1Name>'				+ ISNULL([dbo].[f_EncodeXMLValue](@Pic1Name),'')				+ '</Pic1Name>' +
						'<Pic2Name>'				+ ISNULL([dbo].[f_EncodeXMLValue](@Pic2Name),'')				+ '</Pic2Name>' +
						'<Pic3Name>'				+ ISNULL([dbo].[f_EncodeXMLValue](@Pic3Name),'')				+ '</Pic3Name>' +
						'<Pic4Name>'				+ ISNULL([dbo].[f_EncodeXMLValue](@Pic4Name),'')				+ '</Pic4Name>' +
						'<Line1>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Line1),'')					+ '</Line1>' +
						'<Line2>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Line2),'')					+ '</Line2>' +
						'<Line3>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Line3),'')					+ '</Line3>' +
						'<City>'					+ ISNULL([dbo].[f_EncodeXMLValue](@City),'')					+ '</City>' +
						'<Postcode>'				+ ISNULL([dbo].[f_EncodeXMLValue](@Postcode),'')				+ '</Postcode>' +
						'<State>'					+ ISNULL([dbo].[f_EncodeXMLValue](@State),'')					+ '</State>' +
						'<BankLine1>'				+ ISNULL([dbo].[f_EncodeXMLValue](@BankLine1),'')				+ '</BankLine1>' +
						'<BankLine2>'				+ ISNULL([dbo].[f_EncodeXMLValue](@BankLine2),'')				+ '</BankLine2>' +
						'<BankLine3>'				+ ISNULL([dbo].[f_EncodeXMLValue](@BankLine3),'')				+ '</BankLine3>' +
						'<BankCity>'				+ ISNULL([dbo].[f_EncodeXMLValue](@BankCity),'')				+ '</BankCity>' +
						'<BankCode>'				+ ISNULL([dbo].[f_EncodeXMLValue](@BankCode),'')				+ '</BankCode>' +
						'<BankState>'				+ ISNULL([dbo].[f_EncodeXMLValue](@BankCode),'')				+ '</BankState>' +
						'<Question>'				+ ISNULL([dbo].[f_EncodeXMLValue](@Question),'')				+ '</Question>' +
						'<Answer>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Answer),'')					+ '</Answer>' +
						'<CountryID>'				+ ISNULL(CONVERT(VARCHAR(10),@CountryID),'')					+ '</CountryID>' +
						'<IsVIP>'					+ ISNULL(CONVERT(VARCHAR(1),@IsVIP),'')							+ '</IsVIP>' +					
						'<SiteID>'					+ ISNULL(CONVERT(VARCHAR(10),@SiteID),'')						+ '</SiteID>' +
						'<BankName>'				+ ISNULL([dbo].[f_EncodeXMLValue](@Wire_BankName),'')			+ '</BankName>' +
						'<BankAddress>'				+ ISNULL([dbo].[f_EncodeXMLValue](@Wire_BankAddress),'')		+ '</BankAddress>' +
						'<AccountName>'				+ ISNULL(@Wire_AccountName,'')									+ '</AccountName>' +
						'<AccountNo>'				+ ISNULL(@Wire_AccountNo,'')									+ '</AccountNo>' +
						'<SwiftCode>'				+ ISNULL(@Wire_SwiftCode,'')									+ '</SwiftCode>' +
						'<AccountHolderName>'		+ ISNULL(@AccountHolderName,'')									+ '</AccountHolderName>' +	
						--CAST(@SpecialRemark AS VARCHAR(1000)) +
						--CAST(@Remark AS VARCHAR(1000)) +
						'<CreatorID>'				+ ISNULL(CONVERT(VARCHAR(10),@CreatorID),'')					+ '</CreatorID>' +
						'<IsVerifyEmail>'			+ ISNULL(CONVERT(VARCHAR(10),@IsVerifyEmail),'')				+ '</IsVerifyEmail>' +
						'<IsVerifyPassport>'		+ ISNULL(CONVERT(VARCHAR(10),@IsVerifyPassport),'')				+ '</IsVerifyPassport>' +
						'<IsVerifyBirthday>'		+ ISNULL(CONVERT(VARCHAR(10),@IsVerifyBirthday),'')				+ '</IsVerifyBirthday>' +
						'<IsVerifySecretCode>'		+ ISNULL(CONVERT(VARCHAR(10),@IsVerifySecretCode),'')			+ '</IsVerifySecretCode>' +
						'<IsVerifyBetCredit>'		+ ISNULL(CONVERT(VARCHAR(10),@IsVerifyBetCredit),'')			+ '</IsVerifyBetCredit>' +
						'<LicenseeType>'			+ ISNULL(CONVERT(VARCHAR(10),@LicenseeType),'')					+ '</LicenseeType>' +
						'<WhatsApp>'				+ ISNULL([dbo].[f_EncodeXMLValue](@WhatsApp),'')				+ '</WhatsApp>' +
						'<Line>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Line),'')					+ '</Line>' +
						'<WeChat>'					+ ISNULL([dbo].[f_EncodeXMLValue](@WeChat),'')					+ '</WeChat>' +
						'<Yahoo>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Yahoo),'')					+ '</Yahoo>' +
						'<QQ>'						+ ISNULL([dbo].[f_EncodeXMLValue](@QQ),'')						+ '</QQ>' +
						'<BBM>'						+ ISNULL([dbo].[f_EncodeXMLValue](@BBM),'')						+ '</BBM>' +
						'<IntroducedBy>'			+ ISNULL([dbo].[f_EncodeXMLValue](@IntroducedBy),'')	+ '</IntroducedBy>' +
						'<Ignored>'					+ ISNULL(CONVERT(VARCHAR(10),@Ignored),'')						+ '</Ignored>' +
						'<ProvinceID>'				+ ISNULL(CONVERT(VARCHAR(20),@ProvinceID),'')					+ '</ProvinceID>' +
					'</Acc_CRM_CustomerIns_New>' 
				

	EXEC [dbo].[WriteLog_UserLog_crmLogCustomer]
					@CustID = @CustID, 
					@UserID = @UserID, 
					@ActionID = 100, 
					@IP = @IP, 
					@NewValues = @LogElement
END


GO