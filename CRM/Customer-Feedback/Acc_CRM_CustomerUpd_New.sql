ALTER PROCEDURE [dbo].[Acc_CRM_CustomerUpd_New]
(
	@UserID						INT,
	@CustID						INT,
	@FirstName					NVARCHAR(50)	= NULL,
	@LastName					NVARCHAR(50)	= NULL,
	@TitleID					INT				= NULL,
	@BirthDay					SMALLDATETIME	= NULL,
	@LanguageID					VARCHAR(1000)	= NULL,
	@Phone						NVARCHAR(50)	= '',	
	@PhoneCountryCode			NVARCHAR(20)	= '',	
	@PhoneAreaCode				NVARCHAR(20)	= '',	
	@Phone2						NVARCHAR(50)	= '',	
	@Phone2CountryCode			NVARCHAR(20)	= '',	
	@Phone2AreaCode				NVARCHAR(20)	= '',	
	@Phone3						NVARCHAR(50)	= '',	
	@Phone3CountryCode			NVARCHAR(20)	= '',	
	@Phone3AreaCode				NVARCHAR(20)	= '',	
	@Passport					NVARCHAR(50)	= NULL,	
	@MobilePhone				NVARCHAR(50)	= '',
	@MobilePhoneCountryCode		NVARCHAR(20)	= '',
	@MobilePhoneAreaCode		NVARCHAR(20)	= '',
	@Fax						NVARCHAR(50)	= NULL,
	@FaxCountryCode				NVARCHAR(20)	= NULL,
	@FaxAreaCode				NVARCHAR(20)	= NULL,
	@Email						NVARCHAR(254)	= NULL,
	@Skype						NVARCHAR(100)	= NULL,
	@MSN						NVARCHAR(100)	= NULL,
	@Pic1						NVARCHAR(100)	= NULL,
	@Pic2						NVARCHAR(100)	= NULL,
	@Pic3						NVARCHAR(100)	= NULL,
	@Pic4						NVARCHAR(100)	= NULL,
	@Pic1Name					NVARCHAR(100)	= NULL,
	@Pic2Name					NVARCHAR(100)	= NULL,
	@Pic3Name					NVARCHAR(100)	= NULL,
	@Pic4Name					NVARCHAR(100)	= NULL,
	@SiteID						INT				= NULL,
	@BettingCode				NVARCHAR(100)	= NULL,
	@RefCode2					NVARCHAR(100)	= NULL,
	---Home Address
	@Line1						NVARCHAR(100)	= NULL,
	@Line2						NVARCHAR(100)	= NULL,
	@Line3						NVARCHAR(100)	= NULL,
	@City						NVARCHAR(200)	= NULL,
	@CountryID					INT				= NULL,
	@PostCode					NVARCHAR(100)	= NULL,
	@State						NVARCHAR(100)	= NULL,
	-- Extra Info
	@Question					NVARCHAR(600)	= NULL,
	@Answer						NVARCHAR(600)	= NULL,
	@IsVIP						BIT				= 0,
	@SpecialRemark				XML				= NULL,
	@Remark						XML				= NULL,
	--Bank Info
	@AccountHolderName			NVARCHAR(100)	= NULL,	
	@Wire_BankName				NVARCHAR(100)	= NULL,
	@Wire_BankAddress			NVARCHAR(400)	= NULL,
	@Wire_AccountNo				NVARCHAR(50)	= NULL,
	@Wire_SwiftCode				NVARCHAR(50)	= NULL,
	@BankLine1					NVARCHAR(100)	= NULL,
	@BankLine2					NVARCHAR(100)	= NULL,
	@BankLine3					NVARCHAR(100)	= NULL,
	@BankCity					NVARCHAR(100)	= NULL,
	@BankCode					NVARCHAR(100)	= NULL,
	@BankState					NVARCHAR(100)	= NULL,
	@BankCountryID				INT				= NULL,
	@Wire_AccountName			NVARCHAR(200)	= NULL,
	@LicenseeType				INT				= 0,
	@WhatsApp					NVARCHAR(100)	= NULL,
	@Line						NVARCHAR(100)	= NULL,
	@WeChat						NVARCHAR(100)	= NULL,
	@Yahoo						NVARCHAR(100)	= NULL,
	@QQ							NVARCHAR(100)	= NULL,
	@BBM						NVARCHAR(100)	= NULL,
	@IP							VARCHAR(15),
	@ErrCode					INT				= 0 OUTPUT,
	@ErrMsg						NVARCHAR(4000)	= '' OUTPUT	
)
AS

/*
Created: Dom
Date: 20140124
Task : update customer info
DB: DBCRM.bodb_CRM
Original:

Revisions:
	- 20140827@Dom: [Redmine #18632] Update phone number in custsearch
	- 20141118@Dom: add more fields of communication tool
Param's Explanation:
	
*/
BEGIN	
	SET NOCOUNT ON

	SELECT	@ErrCode	= 0,
			@ErrMsg		= ''

	IF NOT EXISTS (SELECT CustID FROM crmCustomer WITH(NOLOCK) WHERE CustID = @CustID)
	BEGIN
		print 'insert new'
		DECLARE @UserName varchar(30)
		SELECT @UserName = UserName FROM bodb02.dbo.Customer(NOLOCK) WHERE custid = @CustID
		EXEC Acc_CRM_CustomerIns_New
			@UserID							= @UserID,				
			@CustID							= @CustID OUTPUT,						
			@UserName						= @UserName,
			@FirstName						= @FirstName,
			@LastName						= @LastName,
			@TitleID						= @TitleID,
			@Birthday						= @Birthday,
			@LanguageID						= @LanguageID,
			@Phone							= @Phone,
			@PhoneCountryCode				= @PhoneCountryCode,
			@PhoneAreaCode					= @PhoneAreaCode,
			@Phone2							= @Phone2,
			@Phone2CountryCode				= @Phone2CountryCode,
			@Phone2AreaCode					= @Phone2AreaCode,
			@Phone3							= @Phone3,
			@Phone3CountryCode				= @Phone3CountryCode,
			@Phone3AreaCode					= @Phone3AreaCode,
			@Passport						= @Passport,
			@MobilePhone					= @MobilePhone,
			@MobilePhoneCountryCode			= @MobilePhoneCountryCode,
			@MobilePhoneAreaCode			= @MobilePhoneAreaCode,
			@Fax							= @Fax,
			@FaxCountryCode					= @FaxCountryCode,
			@FaxAreaCode					= @FaxAreaCode,
			@Email							= @Email,
			@Skype							= @Skype,
			@MSN							= @MSN,
			@BettingCode					= @BettingCode,
			@RefCode2						= @RefCode2,
			@Pic1							= @Pic1,
			@Pic2							= @Pic2,
			@Pic3							= @Pic3,
			@Pic4							= @Pic4,
			@Pic1Name						= @Pic1Name,
			@Pic2Name						= @Pic2Name,
			@Pic3Name						= @Pic3Name,
			@Pic4Name						= @Pic4Name,
			@Line1							= @Line1,
			@Line2							= @Line2,
			@Line3							= @Line3,
			@City							= @City,
			@PostCode						= @PostCode,
			@State							= @State,
			@BankLine1						= @BankLine1,
			@BankLine2						= @BankLine2,
			@BankLine3						= @BankLine3,
			@BankCity						= @BankCity,
			@BankCode						= @BankCode,
			@BankCountryID					= @BankCountryID,
			@BankState						= @BankState,
			@Question						= @Question,
			@Answer							= @Answer,
			@CountryID						= @CountryID,
			@IsVIP							= @IsVIP,
			@SiteID							= @SiteID,
			@Wire_BankName					= @Wire_BankName,
			@Wire_BankAddress				= @Wire_BankAddress,
			@Wire_AccountName				= @Wire_AccountName,
			@Wire_AccountNo					= @Wire_AccountNo,
			@Wire_SwiftCode					= @Wire_SwiftCode,
			@AccountHolderName				= @AccountHolderName,
			@SpecialRemark					= @SpecialRemark,	
			@Remark							= @Remark,	
			@CreatorID						= @UserID,
			@LicenseeType					= @LicenseeType,
			@WhatsApp						= @WhatsApp,
			@Line							= @Line,
			@WeChat							= @WeChat,
			@Yahoo							= @Yahoo,
			@QQ								= @QQ,
			@BBM							= @BBM,
			@IP								= @IP,
			@ErrCode						= @ErrCode OUTPUT,
			@ErrMsg							= @ErrMsg OUTPUT
		
		IF @ErrCode <> 0
		BEGIN
			SELECT @ErrCode = 101
			SELECT @ErrMsg = 'Cannot insert customer.'
			RETURN
		END

		DELETE crmCustomerLanguage WITH(ROWLOCK,UPDLOCK) WHERE CustID = @CustID
		INSERT INTO crmCustomerLanguage( CustID,LanguageID)
		SELECT @CustID, Val from dbo.f_split(@LanguageID,',')

		IF @@error <> 0
		BEGIN
			DELETE crmCustomer WHERE CustID = @CustID
			SELECT @ErrCode = 101
			SELECT @ErrMsg = 'Update Customer unsuccessfuly.'
			RETURN
		END

		--------Update language for Old System------
		IF(EXISTS(SELECT TOP 1 1 FROM dbo.strSplit(@LanguageID,',') WHERE SettingID = 12000))
		BEGIN
			UPDATE crmCustomer WITH(ROWLOCK,UPDLOCK) SET LanguageID = 12000 WHERE CustID = @CustID
		END

		ELSE IF(EXISTS(SELECT TOP 1 1 FROM dbo.strSplit(@LanguageID,',') WHERE SettingID = 12001))
		BEGIN
			UPDATE crmCustomer WITH(ROWLOCK,UPDLOCK) SET LanguageID = 12001 WHERE CustID = @CustID
		END

		ELSE IF(EXISTS(SELECT TOP 1 1 FROM dbo.strSplit(@LanguageID,',') WHERE SettingID = 12002))
		BEGIN
			UPDATE crmCustomer WITH(ROWLOCK,UPDLOCK) SET LanguageID = 12002 WHERE CustID = @CustID
		END

		ELSE
		BEGIN 
			UPDATE crmCustomer WITH(ROWLOCK,UPDLOCK) SET LanguageID = (SELECT TOP 1 SettingID FROM dbo.strSplit(@LanguageID,',')) WHERE CustID = @CustID
		END

		RETURN -- Completed insert
	END
	PRINT 'update new'
	----Store Old Value
	DECLARE @CustID_Old						INT,
			@FirstName_Old					NVARCHAR(50),
			@LastName_Old					NVARCHAR(50),
			@TitleID_Old					INT,
			@Birthday_Old					DATETIME,
			@IsVIP_Old						BIT,
			@BettingCode_Old				NVARCHAR(100),
			@RefCode2_Old					NVARCHAR(100),
			@LanguageID_Old					VARCHAR(1000),
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
			@Pic1_Old						NVARCHAR(100),
			@Pic2_Old						NVARCHAR(100),
			@Pic3_Old						NVARCHAR(100),
			@Pic4_Old						NVARCHAR(100),
			@Pic1Name_Old					NVARCHAR(100),
			@Pic2Name_Old					NVARCHAR(100),
			@Pic3Name_Old					NVARCHAR(100),
			@Pic4Name_Old					NVARCHAR(100),
			@SiteID_Old						INT			,
			---Home Address
			@Line1_Old						NVARCHAR(100),
			@Line2_Old						NVARCHAR(100),
			@Line3_Old						NVARCHAR(100),
			@City_Old						NVARCHAR(200),
			@CountryID_Old					INT			 ,
			@PostCode_Old					NVARCHAR(100),
			@State_Old						NVARCHAR(100),
			--Bank Info								
			@AccountHolderName_Old			NVARCHAR(100),	
			@Wire_BankName_Old				NVARCHAR(100),
			@Wire_AccountNo_Old				NVARCHAR(50),
			@Wire_SwiftCode_Old				NVARCHAR(50),
			@BankLine1_Old					NVARCHAR(100),
			@BankLine2_Old					NVARCHAR(100),
			@BankLine3_Old					NVARCHAR(100),
			@BankCity_Old					NVARCHAR(100),
			@BankCode_Old					NVARCHAR(100),
			@BankState_Old					NVARCHAR(100),
			@BankCountryID_Old				INT,
			@LicenseeType_Old				INT,
			@WhatsApp_Old					NVARCHAR(100)	= NULL,
			@Line_Old						NVARCHAR(100)	= NULL,
			@WeChat_Old						NVARCHAR(100)	= NULL,
			@Yahoo_Old						NVARCHAR(100)	= NULL,
			@QQ_Old							NVARCHAR(100)	= NULL,
			@BBM_Old						NVARCHAR(100)	= NULL
			

	SELECT 
		@FirstName_Old						= FirstName,
		@LastName_Old						= LastName,
		@TitleID_Old						= TitleID,
		@Birthday_Old						= Birthday,
		@IsVIP_Old							= IsVip,
		@BettingCode_Old					= RefCode1,
		@RefCode2_Old						= RefCode2,
		@Phone_Old							= Phone,
		@PhoneCountryCode_Old				= PhoneCountryCode,
		@PhoneAreaCode_Old					= PhoneAreaCode,
		@Phone2_Old							= Phone2,	
		@Phone2CountryCode_Old				= Phone2CountryCode,
		@Phone2AreaCode_Old					= Phone2AreaCode,
		@Phone3_Old							= Phone3,
		@Phone3CountryCode_Old				= Phone3CountryCode,
		@Phone3AreaCode_Old					= Phone3AreaCode,	
		@Passport_Old						= Passport,
		@MobilePhone_Old					= MobilePhone,
		@MobilePhoneCountryCode_Old			= MobilePhoneCountryCode,
		@MobilePhoneAreaCode_Old			= MobilePhoneAreaCode,
		@Fax_Old							= Fax,
		@FaxCountryCode_Old					= FaxCountryCode,
		@FaxAreaCode_Old					= FaxAreaCode,
		@Email_Old							= Email,
		@Skype_Old							= Skype,
		@msn_Old							= MSN,
		@Pic1_Old							= Pic1,
		@Pic2_Old							= Pic2,
		@Pic3_Old							= Pic3,
		@Pic4_Old							= Pic4,	
		@Pic1Name_Old						= Pic1Name,
		@Pic2Name_Old						= Pic2Name,
		@Pic3Name_Old						= Pic3Name,
		@Pic4Name_Old						= Pic4Name,	
		@Line1_Old							= Line1,
		@Line2_Old							= Line2,
		@Line3_Old							= Line3,
		@City_Old							= City,
		@Postcode_Old						= Postcode,
		@State_Old							= State,
		@CountryID_Old						= CountryID,
		@SiteID_Old							= SiteID,
		@BankCountryID_Old					= BankCountryID,
		@Wire_BankName_Old					= Wire_BankName,
		@Wire_SwiftCode_Old					= Wire_SwiftCode,
		@Wire_AccountNo_Old					= Wire_AccountNo,
		@AccountHolderName_Old				= AccountHolderName,
		@BankLine1_Old						= BankLine1,
		@BankLine2_Old						= BankLine2,
		@BankLine3_Old						= BankLine3,
		@BankCity_Old						= BankCity,
		@BankCode_Old						= BankCode,
		@BankState_Old						= BankState,
		@LicenseeType_Old					= LicenseeType,
		@WhatsApp_Old						= WhatsApp,
		@Line_Old							= Line,
		@WeChat_Old							= WeChat,
		@Yahoo_Old							= Yahoo,
		@QQ_Old								= QQ,
		@BBM_Old							= BBM
	FROM crmCustomer WITH(NOLOCK)
	WHERE CustID = @CustID --Old Values

	SELECT @LanguageID_Old = ''
	SELECT @LanguageID_Old = @LanguageID_Old + CAST(c.LanguageID AS VARCHAR(100))+','
	FROM crmCustomerLanguage(NOLOCK) c WHERE CustID = @CustID

	IF ISNULL(@LanguageID_Old,'')<> ''
	SELECT @LanguageID_Old = LEFT(@LanguageID_Old,LEN(@LanguageID_Old)-1)

	
	UPDATE crmCustomer WITH(ROWLOCK,UPDLOCK)
	SET 
		FirstName					= @FirstName,
		LastName					= @LastName,
		TitleID						= @TitleID,
		Birthday					= @Birthday,
		IsVIP						= @IsVip,
		RefCode1					= @BettingCode,
		RefCode2					= @RefCode2,
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
		Pic1						= @Pic1,
		Pic2						= @Pic2,
		Pic3						= @Pic3,
		Pic4						= @Pic4,	
		Pic1Name					= @Pic1Name,
		Pic2Name					= @Pic2Name,
		Pic3Name					= @Pic3Name,
		Pic4Name					= @Pic4Name,
		Line1						= @Line1,
		Line2						= @Line2,
		Line3						= @Line3,
		City						= @City,
		Postcode					= @Postcode,
		State						= @State,
		CountryID					= @CountryID,
		SiteID						= @SiteID,
		BankCountryID				= @BankCountryID,
		Wire_BankName				= @Wire_BankName,
		Wire_SwiftCode				= @Wire_SwiftCode,
		Wire_AccountNo				= @Wire_AccountNo,
		AccountHolderName			= @AccountHolderName,
		BankLine1					= @BankLine1,
		BankLine2					= @BankLine2,
		BankLine3					= @BankLine3,
		BankCity					= @BankCity,
		BankCode					= @BankCode,
		BankState					= @BankState,
		LicenseeType				= @LicenseeType,
		WhatsApp					= @WhatsApp,
		Line						= @Line,
		WeChat						= @WeChat,
		Yahoo						= @Yahoo,
		QQ							= @QQ,
		BBM							= @BBM
	WHERE CustID = @CustID
	
	select @birthday

	IF @@error <> 0
	BEGIN
		SELECT @ErrCode = 101
		SELECT @ErrMsg = 'Update Customer unsuccessfuly.'
		RETURN
	END

	DELETE crmCustomerLanguage WITH(ROWLOCK,UPDLOCK) WHERE CustID = @CustID
	INSERT INTO crmCustomerLanguage( CustID,LanguageID)
	SELECT @CustID, Val from dbo.f_split(@LanguageID,',')

	IF @@error <> 0
	BEGIN
		SELECT @ErrCode = 101
		SELECT @ErrMsg = 'Update Customer unsuccessfuly.'
		RETURN
	END
	
	-- Update CustSearch
	UPDATE crmCustomerSearch WITH(ROWLOCK,UPDLOCK)
	SET PhoneNumber1 = ISNULL(@PhoneCountryCode,'') + ISNULL(@PhoneAreaCode,'') + ISNULL(@Phone,'')
		,PhoneNumber2 = ISNULL(@Phone2CountryCode,'') + ISNULL(@Phone2AreaCode,'') + ISNULL(@Phone2,'')
		,PhoneNumber3 = ISNULL(@Phone3CountryCode,'') + ISNULL(@Phone3AreaCode,'') + ISNULL(@Phone3,'')
		,MobilePhone = ISNULL(@MobilePhoneCountryCode,'') + ISNULL(@MobilePhoneAreaCode,'') + ISNULL(@MobilePhone,'')
	WHERE CustID = @CustID
	AND (
			ISNULL(@PhoneCountryCode,'') <> ISNULL(@PhoneCountryCode_Old,'')
		OR ISNULL(@PhoneAreaCode,'') <> ISNULL(@PhoneAreaCode_Old,'')
		OR ISNULL(@Phone,'') <> ISNULL(@Phone_Old,'')
		OR ISNULL(@Phone2CountryCode,'') <> ISNULL(@Phone2CountryCode_Old ,'')
		OR ISNULL(@Phone2AreaCode,'') <> ISNULL(@Phone2AreaCode ,'')
		OR ISNULL(@Phone2 ,'')<> ISNULL(@Phone2_Old,'')
		OR ISNULL(@Phone3CountryCode,'') <> ISNULL(@Phone3CountryCode_Old ,'')
		OR ISNULL(@Phone3AreaCode,'') <> ISNULL(@Phone3AreaCode ,'')
		OR ISNULL(@Phone3,'') <> ISNULL(@Phone3_Old,'')
		OR ISNULL(@MobilePhoneCountryCode,'') <> ISNULL(@MobilePhoneCountryCode_Old ,'')
		OR ISNULL(@MobilePhoneAreaCode,'') <> ISNULL(@MobilePhoneAreaCode ,'')
		OR ISNULL(@MobilePhone,'') <> ISNULL(@MobilePhone_Old,'')
	)
	
	--------Update language for Old System------
	IF(EXISTS(SELECT TOP 1 1 FROM dbo.strSplit(@LanguageID,',') WHERE SettingID = 12000))
	BEGIN
		UPDATE crmCustomer WITH(ROWLOCK,UPDLOCK) SET LanguageID = 12000 WHERE CustID = @CustID
	END

	ELSE IF(EXISTS(SELECT TOP 1 1 FROM dbo.strSplit(@LanguageID,',') WHERE SettingID = 12001))
	BEGIN
		UPDATE crmCustomer WITH(ROWLOCK,UPDLOCK) SET LanguageID = 12001 WHERE CustID = @CustID
	END

	ELSE IF(EXISTS(SELECT TOP 1 1 FROM dbo.strSplit(@LanguageID,',') WHERE SettingID = 12002))
	BEGIN
		UPDATE crmCustomer WITH(ROWLOCK,UPDLOCK) SET LanguageID = 12002 WHERE CustID = @CustID
	END

	ELSE
	BEGIN 
		UPDATE crmCustomer WITH(ROWLOCK,UPDLOCK) SET LanguageID = (SELECT TOP 1 SettingID FROM dbo.strSplit(@LanguageID,',')) WHERE CustID = @CustID
	END


	-- write log
	DECLARE @NewValues XML,@OldValues XML

	SELECT @OldValues =
					'<Acc_CRM_CustomerUpd_New>'				+ --SP Name
							'<FirstName>'					+ ISNULL([dbo].[f_EncodeXMLValue](@FirstName_Old),'')							+ '</FirstName>' +
							'<LastName>'					+ ISNULL([dbo].[f_EncodeXMLValue](@LastName_Old),'')							+ '</LastName>' +
							'<TitleID>'						+ ISNULL(CONVERT(VARCHAR(10),@TitleID_Old),'')									+ '</TitleID>' +
							'<Birthday>'					+ ISNULL(CONVERT(VARCHAR(20),@Birthday_Old,107),'')								+ '</Birthday>' +
							'<IsVIP>'						+ ISNULL(CONVERT(VARCHAR(10),@IsVIP_Old),'')									+ '</IsVIP>' +
							'<BettingCode>'					+ ISNULL([dbo].[f_EncodeXMLValue](@BettingCode_Old),'')							+ '</BettingCode>' +
							'<RefCode2>'					+ ISNULL([dbo].[f_EncodeXMLValue](@RefCode2_Old),'')							+ '</RefCode2>' +
							'<LanguageID>'					+ ISNULL([dbo].[f_EncodeXMLValue](@LanguageID_Old),'')							+ '</LanguageID>' +
							'<Phone>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Phone_Old),'')								+ '</Phone>' +
							'<PhoneCountryCode>'			+ ISNULL([dbo].[f_EncodeXMLValue](@PhoneCountryCode_Old),'')					+ '</PhoneCountryCode>' +
							'<PhoneAreaCode>'				+ ISNULL([dbo].[f_EncodeXMLValue](@PhoneAreaCode_Old),'')						+ '</PhoneAreaCode>' +
							'<Phone2>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Phone2_Old),'')								+ '</Phone2>' +
							'<Phone2CountryCode>'			+ ISNULL([dbo].[f_EncodeXMLValue](@Phone2CountryCode_Old),'')					+ '</Phone2CountryCode>' +
							'<Phone2AreaCode>'				+ ISNULL([dbo].[f_EncodeXMLValue](@Phone2AreaCode_Old),'')						+ '</Phone2AreaCode>' +
							'<Phone3>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Phone3_Old),'')								+ '</Phone3>' +
							'<Phone3CountryCode>'			+ ISNULL([dbo].[f_EncodeXMLValue](@Phone3CountryCode_Old),'')					+ '</Phone3CountryCode>' +
							'<Phone3AreaCode>'				+ ISNULL([dbo].[f_EncodeXMLValue](@Phone3AreaCode_Old),'')						+ '</Phone3AreaCode>' +
							'<Passport>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Passport_Old),'')							+ '</Passport>' +
							'<MobilePhone>'					+ ISNULL([dbo].[f_EncodeXMLValue](@MobilePhone_Old),'')							+ '</MobilePhone>' +
							'<MobilePhoneCountryCode>'		+ ISNULL([dbo].[f_EncodeXMLValue](@MobilePhoneCountryCode_Old),'')				+ '</MobilePhoneCountryCode>' +
							'<MobilePhoneAreaCode>'			+ ISNULL([dbo].[f_EncodeXMLValue](@MobilePhoneAreaCode_Old),'')					+ '</MobilePhoneAreaCode>' +
							'<Fax>'							+ ISNULL([dbo].[f_EncodeXMLValue](@Fax_Old),'')									+ '</Fax>' +
							'<FaxCountryCode>'				+ ISNULL([dbo].[f_EncodeXMLValue](@FaxCountryCode_Old),'')						+ '</FaxCountryCode>' +
							'<FaxAreaCode>'					+ ISNULL([dbo].[f_EncodeXMLValue](@FaxAreaCode_Old),'')							+ '</FaxAreaCode>' +
							'<Email>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Email_Old),'')								+ '</Email>' +
							'<Skype>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Skype_Old),'')								+ '</Skype>' +
							'<MSN>'							+ ISNULL([dbo].[f_EncodeXMLValue](@MSN_Old),'')									+ '</MSN>' +
							'<Pic1>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Pic1_Old),'')								+ '</Pic1>' +
							'<Pic2>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Pic2_Old),'')								+ '</Pic2>' +
							'<Pic3>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Pic3_Old),'')								+ '</Pic3>' +
							'<Pic4>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Pic4_Old),'')								+ '</Pic4>' +
							'<Pic1Name>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Pic1Name_Old),'')								+ '</Pic1Name>' +
							'<Pic2Name>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Pic2Name_Old),'')								+ '</Pic2Name>' +
							'<Pic3Name>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Pic3Name_Old),'')								+ '</Pic3Name>' +
							'<Pic4Name>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Pic4Name_Old),'')								+ '</Pic4Name>' +
							'<Line1>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Line1_Old),'')								+ '</Line1>' +
							'<Line2>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Line2_Old),'')								+ '</Line2>' +
							'<Line3>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Line3_Old),'')								+ '</Line3>' +
							'<City>'						+ ISNULL([dbo].[f_EncodeXMLValue](@City_Old),'')								+ '</City>' +
							'<Postcode>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Postcode_Old),'')							+ '</Postcode>' +
							'<State>'						+ ISNULL([dbo].[f_EncodeXMLValue](@State_Old),'')								+ '</State>' +
							'<BankLine1>'					+ ISNULL([dbo].[f_EncodeXMLValue](@BankLine1_Old),'')							+ '</BankLine1>' +
							'<BankLine2>'					+ ISNULL([dbo].[f_EncodeXMLValue](@BankLine2_Old),'')							+ '</BankLine2>' +
							'<BankLine3>'					+ ISNULL([dbo].[f_EncodeXMLValue](@BankLine3_Old),'')							+ '</BankLine3>' +
							'<BankCity>'					+ ISNULL([dbo].[f_EncodeXMLValue](@BankCity_Old),'')							+ '</BankCity>' +
							'<BankCode>'					+ ISNULL([dbo].[f_EncodeXMLValue](@BankCode_Old),'')							+ '</BankCode>' +
							'<BankState>'					+ ISNULL([dbo].[f_EncodeXMLValue](@BankState_Old),'')							+ '</BankState>' +
							'<BankCountryID>'				+ ISNULL([dbo].[f_EncodeXMLValue](@BankCountryID_Old),'')						+ '</BankCountryID>' +
							'<CountryID>'					+ ISNULL(CONVERT(VARCHAR(10),@CountryID_Old),'')								+ '</CountryID>' +			
							'<SiteID>'						+ ISNULL(CONVERT(VARCHAR(10),@SiteID_Old),'')									+ '</SiteID>' +
							'<BankName>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Wire_BankName_Old),'')						+ '</BankName>' +
							'<AccountNo>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Wire_AccountNo_Old),'')						+ '</AccountNo>' +
							'<SwiftCode>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Wire_SwiftCode_Old),'')						+ '</SwiftCode>' +
							'<AccountHolderName>'			+ ISNULL([dbo].[f_EncodeXMLValue](@AccountHolderName_Old),'')					+ '</AccountHolderName>' +	
							'<LicenseeType>'				+ ISNULL(CONVERT(VARCHAR(10),@LicenseeType_Old),'')								+ '</LicenseeType>' +
							'<WhatsApp>'					+ ISNULL([dbo].[f_EncodeXMLValue](@WhatsApp_Old),'')							+ '</WhatsApp>' +
							'<Line>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Line_Old),'')								+ '</Line>' +
							'<WeChat>'						+ ISNULL([dbo].[f_EncodeXMLValue](@WeChat_Old),'')								+ '</WeChat>' +
							'<Yahoo>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Yahoo_Old),'')								+ '</Yahoo>' +
							'<QQ>'							+ ISNULL([dbo].[f_EncodeXMLValue](@QQ_Old),'')									+ '</QQ>' +
							'<BBM>'							+ ISNULL([dbo].[f_EncodeXMLValue](@BBM_Old),'')									+ '</BBM>' +
				'</Acc_CRM_CustomerUpd_New>'

	SELECT @NewValues =
				'<Acc_CRM_CustomerUpd_New>'				+ --SP Name
						'<FirstName>'					+ ISNULL([dbo].[f_EncodeXMLValue](@FirstName),'')									+ '</FirstName>' +
						'<LastName>'					+ ISNULL([dbo].[f_EncodeXMLValue](@LastName),'')									+ '</LastName>' +
						'<TitleID>'						+ ISNULL(CONVERT(VARCHAR(10),@TitleID),'')											+ '</TitleID>' +
						'<Birthday>'					+ ISNULL(CONVERT(VARCHAR(20),@Birthday,107),'')										+ '</Birthday>' +
						'<IsVIP>'						+ ISNULL(CONVERT(VARCHAR(10),@IsVIP),'')											+ '</IsVIP>' +
						'<BettingCode>'					+ ISNULL([dbo].[f_EncodeXMLValue](@BettingCode),'')									+ '</BettingCode>' +
						'<RefCode2>'					+ ISNULL([dbo].[f_EncodeXMLValue](@RefCode2),'')									+ '</RefCode2>' +
						'<LanguageID>'					+ ISNULL([dbo].[f_EncodeXMLValue](@LanguageID),'')									+ '</LanguageID>' +
						'<Phone>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Phone),'')										+ '</Phone>' +
						'<PhoneCountryCode>'			+ ISNULL([dbo].[f_EncodeXMLValue](@PhoneCountryCode),'')							+ '</PhoneCountryCode>' +
						'<PhoneAreaCode>'				+ ISNULL([dbo].[f_EncodeXMLValue](@PhoneAreaCode),'')								+ '</PhoneAreaCode>' +
						'<Phone2>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Phone2),'')										+ '</Phone2>' +
						'<Phone2CountryCode>'			+ ISNULL([dbo].[f_EncodeXMLValue](@Phone2CountryCode),'')							+ '</Phone2CountryCode>' +
						'<Phone2AreaCode>'				+ ISNULL([dbo].[f_EncodeXMLValue](@Phone2AreaCode),'')								+ '</Phone2AreaCode>' +
						'<Phone3>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Phone3),'')										+ '</Phone3>' +
						'<Phone3CountryCode>'			+ ISNULL([dbo].[f_EncodeXMLValue](@Phone3CountryCode),'')							+ '</Phone3CountryCode>' +
						'<Phone3AreaCode>'				+ ISNULL([dbo].[f_EncodeXMLValue](@Phone3AreaCode),'')								+ '</Phone3AreaCode>' +
						'<Passport>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Passport),'')									+ '</Passport>' +
						'<MobilePhone>'					+ ISNULL([dbo].[f_EncodeXMLValue](@MobilePhone),'')									+ '</MobilePhone>' +
						'<MobilePhoneCountryCode>'		+ ISNULL([dbo].[f_EncodeXMLValue](@MobilePhoneCountryCode),'')						+ '</MobilePhoneCountryCode>' +
						'<MobilePhoneAreaCode>'			+ ISNULL([dbo].[f_EncodeXMLValue](@MobilePhoneAreaCode),'')							+ '</MobilePhoneAreaCode>' +
						'<Fax>'							+ ISNULL([dbo].[f_EncodeXMLValue](@Fax),'')											+ '</Fax>' +
						'<FaxCountryCode>'				+ ISNULL([dbo].[f_EncodeXMLValue](@FaxCountryCode),'')								+ '</FaxCountryCode>' +
						'<FaxAreaCode>'					+ ISNULL([dbo].[f_EncodeXMLValue](@FaxAreaCode),'')									+ '</FaxAreaCode>' +
						'<Email>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Email),'')										+ '</Email>' +
						'<Skype>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Skype),'')										+ '</Skype>' +
						'<MSN>'							+ ISNULL([dbo].[f_EncodeXMLValue](@MSN),'')											+ '</MSN>' +
						'<Pic1>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Pic1),'')										+ '</Pic1>' +
						'<Pic2>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Pic2),'')										+ '</Pic2>' +
						'<Pic3>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Pic3),'')										+ '</Pic3>' +
						'<Pic4>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Pic4),'')										+ '</Pic4>' +
						'<Pic1Name>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Pic1Name),'')									+ '</Pic1Name>' +
						'<Pic2Name>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Pic2Name),'')									+ '</Pic2Name>' +
						'<Pic3Name>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Pic3Name),'')									+ '</Pic3Name>' +
						'<Pic4Name>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Pic4Name),'')									+ '</Pic4Name>' +
						'<Line1>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Line1),'')										+ '</Line1>' +
						'<Line2>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Line2),'')										+ '</Line2>' +
						'<Line3>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Line3),'')										+ '</Line3>' +
						'<City>'						+ ISNULL([dbo].[f_EncodeXMLValue](@City),'')										+ '</City>' +
						'<Postcode>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Postcode),'')									+ '</Postcode>' +
						'<State>'						+ ISNULL([dbo].[f_EncodeXMLValue](@State),'')										+ '</State>' +
						'<BankLine1>'					+ ISNULL([dbo].[f_EncodeXMLValue](@BankLine1),'')									+ '</BankLine1>' +
						'<BankLine2>'					+ ISNULL([dbo].[f_EncodeXMLValue](@BankLine2),'')									+ '</BankLine2>' +
						'<BankLine3>'					+ ISNULL([dbo].[f_EncodeXMLValue](@BankLine3),'')									+ '</BankLine3>' +
						'<BankCity>'					+ ISNULL([dbo].[f_EncodeXMLValue](@BankCity),'')									+ '</BankCity>' +
						'<BankCode>'					+ ISNULL([dbo].[f_EncodeXMLValue](@BankCode),'')									+ '</BankCode>' +
						'<BankState>'					+ ISNULL([dbo].[f_EncodeXMLValue](@BankState),'')									+ '</BankState>' +
						'<BankCountryID>'				+ ISNULL([dbo].[f_EncodeXMLValue](@BankCountryID),'')								+ '</BankCountryID>' +
						'<CountryID>'					+ ISNULL(CONVERT(VARCHAR(10),@CountryID),'')										+ '</CountryID>' +			
						'<SiteID>'						+ ISNULL(CONVERT(VARCHAR(10),@SiteID),'')											+ '</SiteID>' +
						'<BankName>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Wire_BankName),'')								+ '</BankName>' +
						'<AccountNo>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Wire_AccountNo),'')								+ '</AccountNo>' +
						'<SwiftCode>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Wire_SwiftCode),'')								+ '</SwiftCode>' +
						'<AccountHolderName>'			+ ISNULL([dbo].[f_EncodeXMLValue](@AccountHolderName),'')							+ '</AccountHolderName>' +	
						'<LicenseeType>'				+ ISNULL(CONVERT(VARCHAR(10),@LicenseeType),'')										+ '</LicenseeType>' +
						'<WhatsApp>'					+ ISNULL([dbo].[f_EncodeXMLValue](@WhatsApp),'')									+ '</WhatsApp>' +
						'<Line>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Line),'')										+ '</Line>' +
						'<WeChat>'						+ ISNULL([dbo].[f_EncodeXMLValue](@WeChat),'')										+ '</WeChat>' +
						'<Yahoo>'						+ ISNULL([dbo].[f_EncodeXMLValue](@Yahoo),'')										+ '</Yahoo>' +
						'<QQ>'							+ ISNULL([dbo].[f_EncodeXMLValue](@QQ),'')											+ '</QQ>' +
						'<BBM>'							+ ISNULL([dbo].[f_EncodeXMLValue](@BBM),'')											+ '</BBM>' +
			'</Acc_CRM_CustomerUpd_New>'
				

	EXEC [dbo].[WriteLog_UserLog_crmLogCustomer]
					@CustID = @CustID, 
					@UserID = @UserID, 
					@ActionID = 101, 
					@IP = @IP, 
					@NewValues=@NewValues,
					@OldValues=@OldValues
END

--select top 1 * from crmLogCustomer ORDER by LogDate DESC
GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_CustomerUpd_New] TO [bodbAdminNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_CustomerUpd_New] TO [vnteam]
GO 

select * from crmcustomer where username='test'