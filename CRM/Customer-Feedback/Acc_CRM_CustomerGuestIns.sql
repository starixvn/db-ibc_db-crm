ALTER PROCEDURE [dbo].[Acc_CRM_CustomerGuestIns]
(
	@UserID						INT,
	@CustID						INT OUTPUT,
	@UserName					NVARCHAR(50),
	@FirstName					NVARCHAR(50)	= NULL,
	@LastName					NVARCHAR(50)	= NULL,
	@TitleID					INT				= NULL,
	@Birthday					SMALLDATETIME	= NULL,
	@LanguageID					NVARCHAR(1000)	= NULL,
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
	@IsVIP						BIT				= NULL,
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
	@IP							VARCHAR(15),
	@ErrCode					INT = 0 OUTPUT,
	@ErrMsg						NVARCHAR(4000) = '' OUTPUT	
)
AS
/*
Created: 20101026@Lukas
Task : INSERT NEW GUEST
DB: DB052.bodb_CRM
Original:

Revisions:
	- 20110726@Lukas: including skype, msn into guest info
	- 20120327@Elodie: change data type of @Skype, @MSN, @Pic1, @Pic2, @Pic3 params to NVARCHAR(500)
					   change DB06 to DB052
	- 20120404@Elodie: change data type of @Skype, @MSN, @Pic1, @Pic2, @Pic3 params to NVARCHAR(100)		
	- 20120529@Elodie: encode some parameters to write log in XML format, such as Question, Answer, Pic1, ...
	- 20140303@Dom: Modify for new structure
Param's Explanation:
	
*/
BEGIN	
	SET NOCOUNT ON
	
	SELECT	@ErrCode	= 0,
			@ErrMsg		= ''

	IF EXISTS (SELECT 1 FROM crmCustomer WITH(NOLOCK) WHERE UserName = @UserName AND CustID < 0)
	BEGIN
		SELECT @ErrCode = 100
		SELECT @ErrMsg = 'Username already existed.'
		RETURN
	END
	
	--- get GuestID
	SELECT @CustID = MIN(CustID) - 1 FROM crmCustomer WITH(NOLOCK)

	INSERT INTO crmCustomer
				(	CustID,
					UserName,
					FirstName,
					LastName,
					TitleID,
					Birthday,
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
					MSN,
					RefCode1,
					RefCode2,
					Pic1,
					Pic2,
					Pic3,
					Pic4,
					Line1,
					Line2,
					Line3,
					City,
					PostCode,
					State,
					BankLine1,
					BankLine2,
					BankLine3,
					BankCity,
					BankCode,
					BankCountryID,
					BankState,
					Question,
					Answer,
					CountryID,
					IsVIP,
					SiteID,
					Wire_BankName,
					Wire_BankAddress,
					Wire_AccountName,
					Wire_AccountNo,
					Wire_SwiftCode,
					AccountHolderName,
					IsVerifyEmail,
					IsVerifyPassport,
					IsVerifyBirthday,
					IsVerifySecretCode,
					IsVerifyBetCredit,
					IsVerifyGivenCredit,
					CreatorID,
					CreateDate
				)
			VALUES 
				( 
					@CustID,
					@UserName,
					@FirstName,
					@LastName,
					@TitleID,
					@Birthday,
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
					@BettingCode,
					@RefCode2,
					@Pic1,
					@Pic2,
					@Pic3,
					@Pic4,
					@Line1,
					@Line2,
					@Line3,
					@City,
					@PostCode,
					@State,
					@BankLine1,
					@BankLine2,
					@BankLine3,
					@BankCity,
					@BankCode,
					@BankCountryID,
					@BankState,
					@Question,
					@Answer,
					@CountryID,
					@IsVIP,
					@SiteID,
					@Wire_BankName,
					@Wire_BankAddress,
					@Wire_AccountName,
					@Wire_AccountNo,
					@Wire_SwiftCode,
					@AccountHolderName,
					@IsVerifyEmail,
					@IsVerifyPassport,
					@IsVerifyBirthday,
					@IsVerifySecretCode,
					@IsVerifyBetCredit,
					@IsVerifyGivenCredit,
					@CreatorID,
					getdate()
				)
	
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrCode = 102
		SELECT @ErrMsg = 'create guest unsuccessfuly.'
		RETURN
	END
	DELETE crmCustomerLanguage WITH(ROWLOCK,UPDLOCK) WHERE CustID = @CustID
	INSERT INTO crmCustomerLanguage( CustID,LanguageID)
	SELECT @CustID, Val from dbo.f_split(@LanguageID,',')

	IF @@error <> 0
	BEGIN
		DELETE crmCustomer WHERE CustID = @CustID
		SELECT @ErrCode = 102
		SELECT @ErrMsg = 'create guest unsuccessfuly.'
		RETURN
	END

	INSERT INTO crmCustomerSearch(CustID,UserName,SearchCount,PhoneNumber1,PhoneNumber2,PhoneNumber3,MobilePhone)
	SELECT @CustID, @UserName,0
		,PhoneNumber1 = ISNULL(@PhoneCountryCode,'') + ISNULL(@PhoneAreaCode,'') + ISNULL(@Phone,'')
		,PhoneNumber2 = ISNULL(@Phone2CountryCode,'') + ISNULL(@Phone2AreaCode,'') + ISNULL(@Phone2,'')
		,PhoneNumber3 = ISNULL(@Phone3CountryCode,'') + ISNULL(@Phone3AreaCode,'') + ISNULL(@Phone3,'')
		,MobilePhone = ISNULL(@MobilePhoneCountryCode,'') + ISNULL(@MobilePhoneAreaCode,'') + ISNULL(@MobilePhone,'')

	IF @@error <> 0
	BEGIN
		DELETE crmCustomer WHERE CustID = @CustID
		DELETE crmCustomerLanguage WITH(ROWLOCK,UPDLOCK) WHERE CustID = @CustID
		SELECT @ErrCode = 102
		SELECT @ErrMsg = 'create guest unsuccessfuly.'
		RETURN
	END

	-- write log
	DECLARE @LogElement XML

	SELECT @LogElement = 				
					'<Acc_CRM_CustomerGuestIns>' + --SP Name
						'<UserName>'				+ ISNULL(@UserName,'')										+ '</UserName>' +
						'<FirstName>'				+ ISNULL([dbo].[f_EncodeXMLValue](@FirstName),'')			+ '</FirstName>' +
						'<LastName>'				+ ISNULL([dbo].[f_EncodeXMLValue](@LastName),'')			+ '</LastName>' +
						'<TitleID>'					+ ISNULL(CONVERT(VARCHAR(10),@TitleID),'')					+ '</TitleID>' +
						'<Birthday>'				+ ISNULL(CONVERT(VARCHAR(30),@Birthday),'')					+ '</Birthday>' +
						'<LanguageID>'				+ ISNULL(@LanguageID,'')									+ '</LanguageID>' +
						'<Phone>'					+ ISNULL(@Phone,'')											+ '</Phone>' +
						'<PhoneCountryCode>'		+ ISNULL(@PhoneCountryCode,'')								+ '</PhoneCountryCode>' +
						'<PhoneAreaCode>'			+ ISNULL(@PhoneAreaCode,'')									+ '</PhoneAreaCode>' +
						'<Phone2>'					+ ISNULL(@Phone2,'')										+ '</Phone2>' +
						'<Phone2CountryCode>'		+ ISNULL(@Phone2CountryCode,'')								+ '</Phone2CountryCode>' +
						'<Phone2AreaCode>'			+ ISNULL(@Phone2AreaCode,'')								+ '</Phone2AreaCode>' +
						'<Phone3>'					+ ISNULL(@Phone3,'')										+ '</Phone3>' +
						'<Phone3CountryCode>'		+ ISNULL(@Phone3CountryCode,'')								+ '</Phone3CountryCode>' +
						'<Phone3AreaCode>'			+ ISNULL(@Phone3AreaCode,'')								+ '</Phone3AreaCode>' +
						'<Passport>'				+ ISNULL(@Passport,'')										+ '</Passport>' +
						'<MobilePhone>'				+ ISNULL(@MobilePhone,'')									+ '</MobilePhone>' +
						'<MobilePhoneCountryCode>'	+ ISNULL(@MobilePhoneCountryCode,'')						+ '</MobilePhoneCountryCode>' +
						'<MobilePhoneAreaCode>'		+ ISNULL(@MobilePhoneAreaCode,'')							+ '</MobilePhoneAreaCode>' +
						'<Fax>'						+ ISNULL(@Fax,'')											+ '</Fax>' +
						'<FaxCountryCode>'			+ ISNULL(@FaxCountryCode,'')								+ '</FaxCountryCode>' +
						'<FaxAreaCode>'				+ ISNULL(@FaxAreaCode,'')									+ '</FaxAreaCode>' +
						'<Email>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Email),'')				+ '</Email>' +
						'<Skype>'					+ ISNULL(@Skype,'')											+ '</Skype>' +
						'<MSN>'						+ ISNULL(@MSN,'')											+ '</MSN>' +
						'<BettingCode>'				+ ISNULL(@BettingCode,'')									+ '</BettingCode>' +
						'<RefCode2>'				+ ISNULL(@RefCode2,'')										+ '</RefCode2>' +
						'<Pic1>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Pic1),'')				+ '</Pic1>' +
						'<Pic2>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Pic2),'')				+ '</Pic2>' +
						'<Pic3>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Pic3),'')				+ '</Pic3>' +
						'<Pic4>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Pic4),'')				+ '</Pic4>' +
						'<Line1>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Line1),'')				+ '</Line1>' +
						'<Line2>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Line2),'')				+ '</Line2>' +
						'<Line3>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Line3),'')				+ '</Line3>' +
						'<City>'					+ ISNULL([dbo].[f_EncodeXMLValue](@City),'')				+ '</City>' +
						'<Postcode>'				+ ISNULL([dbo].[f_EncodeXMLValue](@Postcode),'')			+ '</Postcode>' +
						'<State>'					+ ISNULL([dbo].[f_EncodeXMLValue](@State),'')				+ '</State>' +
						'<BankLine1>'				+ ISNULL([dbo].[f_EncodeXMLValue](@BankLine1),'')			+ '</BankLine1>' +
						'<BankLine2>'				+ ISNULL([dbo].[f_EncodeXMLValue](@BankLine2),'')			+ '</BankLine2>' +
						'<BankLine3>'				+ ISNULL([dbo].[f_EncodeXMLValue](@BankLine3),'')			+ '</BankLine3>' +
						'<BankCity>'				+ ISNULL([dbo].[f_EncodeXMLValue](@BankCity),'')			+ '</BankCity>' +
						'<BankCode>'				+ ISNULL([dbo].[f_EncodeXMLValue](@BankCode),'')			+ '</BankCode>' +
						'<BankState>'				+ ISNULL([dbo].[f_EncodeXMLValue](@BankCode),'')			+ '</BankState>' +
						'<Question>'				+ ISNULL([dbo].[f_EncodeXMLValue](@Question),'')			+ '</Question>' +
						'<Answer>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Answer),'')				+ '</Answer>' +
						'<CountryID>'				+ ISNULL(CONVERT(VARCHAR(10),@CountryID),'')				+ '</CountryID>' +
						'<IsVIP>'					+ ISNULL(CONVERT(VARCHAR(1),@IsVIP),'')						+ '</IsVIP>' +					
						'<SiteID>'					+ ISNULL(CONVERT(VARCHAR(10),@SiteID),'')					+ '</SiteID>' +
						'<BankName>'				+ ISNULL([dbo].[f_EncodeXMLValue](@Wire_BankName),'')		+ '</BankName>' +
						'<BankAddress>'				+ ISNULL([dbo].[f_EncodeXMLValue](@Wire_BankAddress),'')	+ '</BankAddress>' +
						'<AccountName>'				+ ISNULL(@Wire_AccountName,'')								+ '</AccountName>' +
						'<AccountNo>'				+ ISNULL(@Wire_AccountNo,'')								+ '</AccountNo>' +
						'<SwiftCode>'				+ ISNULL(@Wire_SwiftCode,'')								+ '</SwiftCode>' +
						'<AccountHolderName>'		+ ISNULL(@AccountHolderName,'')								+ '</AccountHolderName>' +	
						--CAST(@SpecialRemark AS VARCHAR(1000)) +
						--CAST(@Remark AS VARCHAR(1000)) +
						'<CreatorID>'				+ ISNULL(CONVERT(VARCHAR(10),@CreatorID),'')				+ '</CreatorID>' +
						'<IsVerifyEmail>'			+ ISNULL(CONVERT(VARCHAR(10),@IsVerifyEmail),'')			+ '</IsVerifyEmail>' +
						'<IsVerifyPassport>'		+ ISNULL(CONVERT(VARCHAR(10),@IsVerifyPassport),'')			+ '</IsVerifyPassport>' +
						'<IsVerifyBirthday>'		+ ISNULL(CONVERT(VARCHAR(10),@IsVerifyBirthday),'')			+ '</IsVerifyBirthday>' +
						'<IsVerifySecretCode>'		+ ISNULL(CONVERT(VARCHAR(10),@IsVerifySecretCode),'')		+ '</IsVerifySecretCode>' +
						'<IsVerifyBetCredit>'		+ ISNULL(CONVERT(VARCHAR(10),@IsVerifyBetCredit),'')		+ '</IsVerifyBetCredit>' +
					'</Acc_CRM_CustomerGuestIns>'
				

	EXEC [dbo].[WriteLog_UserLog_crmLogCustomer]
					@CustID = @CustID, 
					@UserID = @UserID, 
					@ActionID = 102, 
					@IP = @IP, 
					@NewValues = @LogElement
END


GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_CustomerGuestIns] TO [bodbAdminNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_CustomerGuestIns] TO [vnteam]
GO 
