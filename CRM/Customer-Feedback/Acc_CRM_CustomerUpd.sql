ALTER PROCEDURE [dbo].[Acc_CRM_CustomerUpd]
(
	@UserID						INT,
	@CustID						INT,
	@FirstName					NVARCHAR(50)	= NULL,
	@LastName					NVARCHAR(50)	= NULL,
	@TitleID					INT				= NULL,
	@Birthday					SMALLDATETIME	= NULL,
	@LanguageID					INT				= NULL,
	@Phone						NVARCHAR(50)	= NULL,	
	@PhoneCountryCode			NVARCHAR(20)	= NULL,	
	@PhoneAreaCode				NVARCHAR(20)	= NULL,	
	@Phone2						NVARCHAR(50)	= NULL,	
	@Phone2CountryCode			NVARCHAR(20)	= NULL,	
	@Phone2AreaCode				NVARCHAR(20)	= NULL,	
	@Phone3						NVARCHAR(50)	= NULL,	
	@Phone3CountryCode			NVARCHAR(20)	= NULL,	
	@Phone3AreaCode				NVARCHAR(20)	= NULL,	
	@Passport					NVARCHAR(50)	= NULL,	
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
	@BankState					NVARCHAR(100)	= NULL,
	@Question					NVARCHAR(300)	= NULL,
	@Answer						NVARCHAR(300)	= NULL,
	@CountryID					INT				= NULL,
	@IsVIP						BIT				= NULL,
	@SiteID						INT				= NULL,
	@BankCountryID				INT				= NULL,
	@Wire_BankName				NVARCHAR(100)	= NULL,
	@Wire_BankAddress			NVARCHAR(200)	= NULL,
	@Wire_AccountName			NVARCHAR(100)	= NULL,
	@Wire_AccountNo				NVARCHAR(50)	= NULL,
	@Wire_SwiftCode				NVARCHAR(50)	= NULL,
	@AccountHolderName			NVARCHAR(100)	= NULL,	
	@SpecialRemark				XML				= NULL,
	@Remark						XML				= NULL,
	@CreatorID					INT				= NULL,
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
	- 20110725@Lukas: add skype, msn info
	- 20120327@Elodie: change data type of @Skype, @MSN, @Pic1, @Pic2, @Pic3 params to NVARCHAR(500)
					   change DB06 to DB052
	- 20120404@Elodie: change data type of @Skype, @MSN, @Pic1, @Pic2, @Pic3 params to NVARCHAR(100)
	- 20120529@Elodie: encode some parameters to write log in XML format, such as Question, Answer, Pic1, ...
	- 20140221@Dom: Update log writing
Param's Explanation:
	
*/
BEGIN	
	SET NOCOUNT ON

	SELECT	@ErrCode	= 0,
			@ErrMsg		= ''

	IF NOT EXISTS (SELECT 1 FROM crmCustomer WITH(NOLOCK) WHERE CustID = @CustID)
	BEGIN
		SELECT @ErrCode = 100
		SELECT @ErrMsg = 'Customer does not exist.'
		RETURN
	END
	
	DECLARE @FirstName_Old		NVARCHAR(50),
		@LastName_Old					NVARCHAR(50),
		@TitleID_Old					INT,
		@Birthday_Old					SMALLDATETIME,
		@LanguageID_Old					INT,
		@Phone_Old						NVARCHAR(50),	
		@PhoneCountryCode_Old			NVARCHAR(20),	
		@PhoneAreaCode_Old				NVARCHAR(20),	
		@Phone2_Old						NVARCHAR(50),	
		@Phone2CountryCode_Old			NVARCHAR(20),	
		@Phone2AreaCode_Old				NVARCHAR(20),	
		@Phone3_Old						NVARCHAR(50),	
		@Phone3CountryCode_Old			NVARCHAR(20),	
		@Phone3AreaCode_Old				NVARCHAR(20),	
		@Passport_Old					NVARCHAR(50),	
		@MobilePhone_Old				NVARCHAR(50),
		@MobilePhoneCountryCode_Old		NVARCHAR(20),
		@MobilePhoneAreaCode_Old		NVARCHAR(20),
		@Fax_Old						NVARCHAR(50),
		@FaxCountryCode_Old				NVARCHAR(20),
		@FaxAreaCode_Old				NVARCHAR(20),
		@Email_Old						NVARCHAR(254),
		@Skype_Old						NVARCHAR(100),
		@MSN_Old						NVARCHAR(100),
		@BettingCode_Old				NVARCHAR(50),
		@RefCode2_Old					NVARCHAR(50),
		@Pic1_Old						NVARCHAR(100),
		@Pic2_Old						NVARCHAR(100),
		@Pic3_Old						NVARCHAR(100),
		@Pic4_Old						NVARCHAR(100),
		@Line1_Old						NVARCHAR(100),
		@Line2_Old						NVARCHAR(100),
		@Line3_Old						NVARCHAR(100),
		@City_Old						NVARCHAR(200),
		@PostCode_Old					NVARCHAR(100),
		@State_Old						NVARCHAR(100),
		@BankLine1_Old					NVARCHAR(100),
		@BankLine2_Old					NVARCHAR(100),
		@BankLine3_Old					NVARCHAR(100),
		@BankCity_Old					NVARCHAR(100),
		@BankCode_Old					NVARCHAR(100),
		@BankState_Old					NVARCHAR(100),
		@Question_Old					NVARCHAR(300),
		@Answer_Old						NVARCHAR(300),
		@CountryID_Old					INT,
		@IsVIP_Old						BIT,
		@SiteID_Old						INT,
		@BankCountryID_Old				INT,
		@Wire_BankName_Old				NVARCHAR(100),
		@Wire_BankAddress_Old			NVARCHAR(200),
		@Wire_AccountName_Old			NVARCHAR(100),
		@Wire_AccountNo_Old				NVARCHAR(50),
		@Wire_SwiftCode_Old				NVARCHAR(50),
		@AccountHolderName_Old			NVARCHAR(100),	
		@SpecialRemark_Old				XML,
		@Remark_Old						XML,
		@CreatorID_Old					INT

	SELECT @FirstName_Old				= FirstName,
		@LastName_Old					= LastName,
		@TitleID_Old					= TitleID,
		@Birthday_Old					= Birthday,
		@LanguageID_Old					= LanguageID,
		@Phone_Old						= Phone,
		@PhoneCountryCode_Old			= PhoneCountryCode,
		@PhoneAreaCode_Old				= PhoneAreaCode,
		@Phone2_Old						= Phone2,
		@Phone2CountryCode_Old			= Phone2CountryCode,
		@Phone2AreaCode_Old				= Phone2AreaCode,
		@Phone3_Old						= Phone3,
		@Phone3CountryCode_Old			= Phone3CountryCode,
		@Phone3AreaCode_Old				= Phone3AreaCode,
		@Passport_Old					= Passport,
		@MobilePhone_Old				= MobilePhone,
		@MobilePhoneCountryCode_Old		= MobilePhoneCountryCode,
		@MobilePhoneAreaCode_Old		= MobilePhoneAreaCode,
		@Fax_Old						= Fax,
		@FaxCountryCode_Old				= FaxCountryCode,
		@FaxAreaCode_Old				= FaxAreaCode,
		@Email_Old						= Email,
		@Skype_Old						= Skype,
		@MSN_Old						= MSN,
		@BettingCode_Old				= RefCode1,
		@RefCode2_Old					= RefCode2,
		@Pic1_Old						= Pic1,
		@Pic2_Old						= Pic2,
		@Pic3_Old						= Pic3,
		@Pic4_Old						= Pic4,
		@Line1_Old						= Line1,
		@Line2_Old						= Line2,
		@Line3_Old						= Line3,
		@City_Old						= City,
		@PostCode_Old					= PostCode,
		@State_Old						= State,
		@BankLine1_Old					= BankLine1,
		@BankLine2_Old					= BankLine2,
		@BankLine3_Old					= BankLine3,
		@BankCity_Old					= BankCity,
		@BankCode_Old					= BankCode,
		@BankState_Old					= BankState,
		@Question_Old					= Question,
		@Answer_Old						= Answer,
		@CountryID_Old					= CountryID,
		@IsVIP_Old						= IsVIP,
		@SiteID_Old						= SiteID,
		@BankCountryID_Old				= BankCountryID,
		@Wire_BankName_Old				= Wire_BankName,
		@Wire_BankAddress_Old			= Wire_BankAddress,
		@Wire_AccountName_Old			= Wire_AccountName,
		@Wire_AccountNo_Old				= Wire_AccountNo,
		@Wire_SwiftCode_Old				= Wire_SwiftCode,
		@AccountHolderName_Old			= AccountHolderName,
		@CreatorID_Old					= CreatorID
	FROM crmCustomer WITH(NOLOCK)
	WHERE CustID = @CustID

	UPDATE crmCustomer WITH(ROWLOCK,UPDLOCK)
	SET 
		TitleID						= @TitleID,
		FirstName					= @FirstName,
		LastName					= @LastName,
		Phone						= @Phone,
		PhoneCountryCode			= @PhoneCountryCode,
		PhoneAreaCode				= @PhoneAreaCode,
		Phone2						= @Phone2,	
		Phone2CountryCode			= @Phone2CountryCode,
		Phone2AreaCode				= @Phone2AreaCode,
		Phone3						= @Phone3,
		Phone3CountryCode			= @Phone3CountryCode,
		Phone3AreaCode				= @Phone3AreaCode,	
		Passport					= @Passport,
		MobilePhone					= @MobilePhone,
		MobilePhoneCountryCode		= @MobilePhoneCountryCode,
		MobilePhoneAreaCode			= @MobilePhoneAreaCode,
		Fax							= @Fax,
		FaxCountryCode				= @FaxCountryCode,
		FaxAreaCode					= @FaxAreaCode,
		Email						= @Email,
		Skype						= @Skype,
		msn							= @MSN,
		Birthday					= @Birthday,
		RefCode1					= @BettingCode,
		RefCode2					= @RefCode2,
		Pic1						= @Pic1,
		Pic2						= @Pic2,
		Pic3						= @Pic3,
		Pic4						= @Pic4,	
		Line1						= @Line1,
		Line2						= @Line2,
		Line3						= @Line3,
		City						= @City,
		Postcode					= @Postcode,
		State						= @State,
		LanguageID					= @LanguageID,
		Question					= @Question,
		Answer						= @Answer,
		CountryID					= @CountryID,
		IsVIP						= @IsVIP,		
		SiteID						= @SiteID,
		BankCountryID				= @BankCountryID,
		Wire_BankName				= @Wire_BankName,
		Wire_BankAddress			= @Wire_BankAddress,
		Wire_SwiftCode				= @Wire_SwiftCode,
		Wire_AccountName			= @Wire_AccountName,
		Wire_AccountNo				= @Wire_AccountNo,
		AccountHolderName			= @AccountHolderName,
		BankLine1					= @BankLine1,
		BankLine2					= @BankLine2,
		BankLine3					= @BankLine3,
		BankCity					= @BankCity,
		BankCode					= @BankCode,
		BankState					= @BankState
	WHERE CustID = @CustID
	
	IF @@error <> 0
	BEGIN
		SELECT @ErrCode = 101
		SELECT @ErrMsg = 'Update Customer unsuccessfuly.'
		RETURN
	END

	-- write log
	DECLARE @NewValues XML,@OldValues XML

	SELECT @OldValues =
					'<Acc_CRM_CustomerUpd>'				+ --SP Name
						'<FirstName>'					+ ISNULL([dbo].[f_EncodeXMLValue](@FirstName_Old),'')			+ '</FirstName>' +
						'<LastName>'					+ ISNULL([dbo].[f_EncodeXMLValue](@LastName_Old),'')			+ '</LastName>' +
						'<TitleID>'						+ ISNULL(CONVERT(VARCHAR(10),@TitleID_Old),'')					+ '</TitleID>' +
						'<Birthday>'					+ ISNULL(CONVERT(VARCHAR(30),@Birthday_Old,107),'')					+ '</Birthday>' +
						'<LanguageID>'					+ ISNULL(CONVERT(VARCHAR(10),@LanguageID_Old),'')				+ '</LanguageID>' +
						'<Phone>'						+ ISNULL(@Phone_Old,'')											+ '</Phone>' +
						'<PhoneCountryCode>'			+ ISNULL(@PhoneCountryCode_Old,'')								+ '</PhoneCountryCode>' +
						'<PhoneAreaCode>'				+ ISNULL(@PhoneAreaCode_Old,'')									+ '</PhoneAreaCode>' +
						'<Phone2>'						+ ISNULL(@Phone2_Old,'')										+ '</Phone2>' +
						'<Phone2CountryCode>'			+ ISNULL(@Phone2CountryCode_Old,'')								+ '</Phone2CountryCode>' +
						'<Phone2AreaCode>'				+ ISNULL(@Phone2AreaCode_Old,'')								+ '</Phone2AreaCode>' +
						'<Phone3>'						+ ISNULL(@Phone3_Old,'')										+ '</Phone3>' +
						'<Phone3CountryCode>'			+ ISNULL(@Phone3CountryCode_Old,'')								+ '</Phone3CountryCode>' +
						'<Phone3AreaCode>'				+ ISNULL(@Phone3AreaCode_Old,'')								+ '</Phone3AreaCode>' +
						'<Passport>'					+ ISNULL(@Passport_Old,'')										+ '</Passport>' +
						'<MobilePhone>'					+ ISNULL(@MobilePhone_Old,'')									+ '</MobilePhone>' +
						'<MobilePhoneCountryCode>'		+ ISNULL(@MobilePhoneCountryCode_Old,'')						+ '</MobilePhoneCountryCode>' +
						'<MobilePhoneAreaCode>'			+ ISNULL(@MobilePhoneAreaCode_Old,'')							+ '</MobilePhoneAreaCode>' +
						'<Fax>'							+ ISNULL(@Fax_Old,'')											+ '</Fax>' +
						'<FaxCountryCode>'				+ ISNULL(@FaxCountryCode_Old,'')								+ '</FaxCountryCode>' +
						'<FaxAreaCode>'					+ ISNULL(@FaxAreaCode_Old,'')									+ '</FaxAreaCode>' +
						'<Email>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Email_Old),'')				+ '</Email>' +
						'<Skype>'						+ ISNULL(@Skype_Old,'')											+ '</Skype>' +
						'<MSN>'							+ ISNULL(@MSN_Old,'')											+ '</MSN>' +
						'<BettingCode>'					+ ISNULL(@BettingCode_Old,'')									+ '</BettingCode>' +
						'<RefCode2>'					+ ISNULL(@RefCode2_Old,'')										+ '</RefCode2>' +
						'<Pic1>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Pic1_Old),'')				+ '</Pic1>' +
						'<Pic2>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Pic2_Old),'')				+ '</Pic2>' +
						'<Pic3>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Pic3_Old),'')				+ '</Pic3>' +
						'<Pic4>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Pic4_Old),'')				+ '</Pic4>' +
						'<Line1>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Line1_Old),'')				+ '</Line1>' +
						'<Line2>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Line2_Old),'')				+ '</Line2>' +
						'<Line3>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Line3_Old),'')				+ '</Line3>' +
						'<City>'						+ ISNULL([dbo].[f_EncodeXMLValue](@City_Old),'')				+ '</City>' +
						'<Postcode>'					+ ISNULL([dbo].[f_EncodeXMLValue](@PostCode_Old),'')			+ '</Postcode>' +
						'<State>'						+ ISNULL([dbo].[f_EncodeXMLValue](@State_Old),'')				+ '</State>' +
						'<BankLine1>'					+ ISNULL([dbo].[f_EncodeXMLValue](@BankLine1_Old),'')			+ '</BankLine1>' +
						'<BankLine2>'					+ ISNULL([dbo].[f_EncodeXMLValue](@BankLine2_Old),'')			+ '</BankLine2>' +
						'<BankLine3>'					+ ISNULL([dbo].[f_EncodeXMLValue](@BankLine3_Old),'')			+ '</BankLine3>' +
						'<BankCity>'					+ ISNULL([dbo].[f_EncodeXMLValue](@BankCity_Old),'')			+ '</BankCity>' +
						'<BankCode>'					+ ISNULL([dbo].[f_EncodeXMLValue](@BankCode_Old),'')			+ '</BankCode>' +
						'<BankState>'					+ ISNULL([dbo].[f_EncodeXMLValue](@BankCode_Old),'')			+ '</BankState>' +
						'<Question>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Question_Old),'')			+ '</Question>' +
						'<Answer>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Answer_Old),'')				+ '</Answer>' +
						'<CountryID>'					+ ISNULL(CONVERT(VARCHAR(10),@CountryID_Old),'')				+ '</CountryID>' +
						'<IsVIP>'						+ ISNULL(CONVERT(VARCHAR(1),@IsVIP_Old),'')						+ '</IsVIP>' +					
						'<SiteID>'						+ ISNULL(CONVERT(VARCHAR(10),@SiteID_Old),'')					+ '</SiteID>' +
						'<Wire_BankName>'				+ ISNULL([dbo].[f_EncodeXMLValue](@Wire_BankName_Old),'')		+ '</Wire_BankName>' +
						'<Wire_BankAddress>'			+ ISNULL([dbo].[f_EncodeXMLValue](@Wire_BankAddress_Old),'')	+ '</Wire_BankAddress>' +
						'<Wire_AccountName>'			+ ISNULL(@Wire_AccountName_Old,'')								+ '</Wire_AccountName>' +
						'<Wire_AccountNo>'				+ ISNULL(@Wire_AccountNo_Old,'')								+ '</Wire_AccountNo>' +
						'<Wire_SwiftCode>'				+ ISNULL(@Wire_SwiftCode_Old,'')								+ '</Wire_SwiftCode>' +
						'<AccountHolderName>'			+ ISNULL(@AccountHolderName_Old,'')							+ '</AccountHolderName>' +	
					'</Acc_CRM_CustomerUpd>'

	SELECT @NewValues =
					'<Acc_CRM_CustomerUpd>'				+ --SP Name
						'<FirstName>'					+ ISNULL([dbo].[f_EncodeXMLValue](@FirstName),'')			+ '</FirstName>' +
						'<LastName>'					+ ISNULL([dbo].[f_EncodeXMLValue](@LastName),'')			+ '</LastName>' +
						'<TitleID>'						+ ISNULL(CONVERT(VARCHAR(10),@TitleID),'')					+ '</TitleID>' +
						'<Birthday>'					+ ISNULL(CONVERT(VARCHAR(30),@Birthday,107),'')					+ '</Birthday>' +
						'<LanguageID>'					+ ISNULL(CONVERT(VARCHAR(10),@LanguageID),'')				+ '</LanguageID>' +
						'<Phone>'						+ ISNULL(@Phone,'')											+ '</Phone>' +
						'<PhoneCountryCode>'			+ ISNULL(@PhoneCountryCode,'')								+ '</PhoneCountryCode>' +
						'<PhoneAreaCode>'				+ ISNULL(@PhoneAreaCode,'')									+ '</PhoneAreaCode>' +
						'<Phone2>'						+ ISNULL(@Phone2,'')										+ '</Phone2>' +
						'<Phone2CountryCode>'			+ ISNULL(@Phone2CountryCode,'')								+ '</Phone2CountryCode>' +
						'<Phone2AreaCode>'				+ ISNULL(@Phone2AreaCode,'')								+ '</Phone2AreaCode>' +
						'<Phone3>'						+ ISNULL(@Phone3,'')										+ '</Phone3>' +
						'<Phone3CountryCode>'			+ ISNULL(@Phone3CountryCode,'')								+ '</Phone3CountryCode>' +
						'<Phone3AreaCode>'				+ ISNULL(@Phone3AreaCode,'')								+ '</Phone3AreaCode>' +
						'<Passport>'					+ ISNULL(@Passport,'')										+ '</Passport>' +
						'<MobilePhone>'					+ ISNULL(@MobilePhone,'')									+ '</MobilePhone>' +
						'<MobilePhoneCountryCode>'		+ ISNULL(@MobilePhoneCountryCode,'')						+ '</MobilePhoneCountryCode>' +
						'<MobilePhoneAreaCode>'			+ ISNULL(@MobilePhoneAreaCode,'')							+ '</MobilePhoneAreaCode>' +
						'<Fax>'							+ ISNULL(@Fax,'')											+ '</Fax>' +
						'<FaxCountryCode>'				+ ISNULL(@FaxCountryCode,'')								+ '</FaxCountryCode>' +
						'<FaxAreaCode>'					+ ISNULL(@FaxAreaCode,'')									+ '</FaxAreaCode>' +
						'<Email>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Email),'')				+ '</Email>' +
						'<Skype>'						+ ISNULL(@Skype,'')											+ '</Skype>' +
						'<MSN>'							+ ISNULL(@MSN,'')											+ '</MSN>' +
						'<BettingCode>'					+ ISNULL(@BettingCode,'')									+ '</BettingCode>' +
						'<RefCode2>'					+ ISNULL(@RefCode2,'')										+ '</RefCode2>' +
						'<Pic1>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Pic1),'')				+ '</Pic1>' +
						'<Pic2>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Pic2),'')				+ '</Pic2>' +
						'<Pic3>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Pic3),'')				+ '</Pic3>' +
						'<Pic4>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Pic4),'')				+ '</Pic4>' +
						'<Line1>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Line1),'')				+ '</Line1>' +
						'<Line2>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Line2),'')				+ '</Line2>' +
						'<Line3>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Line3),'')				+ '</Line3>' +
						'<City>'						+ ISNULL([dbo].[f_EncodeXMLValue](@City),'')				+ '</City>' +
						'<Postcode>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Postcode),'')			+ '</Postcode>' +
						'<State>'						+ ISNULL([dbo].[f_EncodeXMLValue](@State),'')				+ '</State>' +
						'<BankLine1>'					+ ISNULL([dbo].[f_EncodeXMLValue](@BankLine1),'')			+ '</BankLine1>' +
						'<BankLine2>'					+ ISNULL([dbo].[f_EncodeXMLValue](@BankLine2),'')			+ '</BankLine2>' +
						'<BankLine3>'					+ ISNULL([dbo].[f_EncodeXMLValue](@BankLine3),'')			+ '</BankLine3>' +
						'<BankCity>'					+ ISNULL([dbo].[f_EncodeXMLValue](@BankCity),'')			+ '</BankCity>' +
						'<BankCode>'					+ ISNULL([dbo].[f_EncodeXMLValue](@BankCode),'')			+ '</BankCode>' +
						'<BankState>'					+ ISNULL([dbo].[f_EncodeXMLValue](@BankCode),'')			+ '</BankState>' +
						'<Question>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Question),'')			+ '</Question>' +
						'<Answer>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Answer),'')				+ '</Answer>' +
						'<CountryID>'					+ ISNULL(CONVERT(VARCHAR(10),@CountryID),'')				+ '</CountryID>' +
						'<IsVIP>'						+ ISNULL(CONVERT(VARCHAR(1),@IsVIP),'')						+ '</IsVIP>' +					
						'<SiteID>'						+ ISNULL(CONVERT(VARCHAR(10),@SiteID),'')					+ '</SiteID>' +
						'<BankName>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Wire_BankName),'')		+ '</BankName>' +
						'<BankAddress>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Wire_BankAddress),'')	+ '</BankAddress>' +
						'<AccountName>'					+ ISNULL(@Wire_AccountName,'')								+ '</AccountName>' +
						'<AccountNo>'					+ ISNULL(@Wire_AccountNo,'')								+ '</AccountNo>' +
						'<SwiftCode>'					+ ISNULL(@Wire_SwiftCode,'')								+ '</SwiftCode>' +
						'<AccountHolderName>'			+ ISNULL(@AccountHolderName,'')								+ '</AccountHolderName>' +	
						'<CreatorID>'					+ ISNULL(CONVERT(VARCHAR(10),@CreatorID),'')				+ '</CreatorID>' +
					'</Acc_CRM_CustomerUpd>'
				

	EXEC [dbo].[WriteLog_UserLog_crmLogCustomer]
					@CustID = @CustID, 
					@UserID = @UserID, 
					@ActionID = 101, 
					@IP = @IP, 
					@NewValues = @NewValues,
					@OldValues = @OldValues
END


GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_CustomerUpd] TO [bodbAdminNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_CustomerUpd] TO [vnteam]
GO 
