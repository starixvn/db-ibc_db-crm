/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_CustomerShortUpd]
(
	@UserID						INT,
	@CustID						INT,
	@FirstName					NVARCHAR(50),
	@LastName					NVARCHAR(50),
	@TitleID					INT,
	@Birthday					DATETIME,
	@Phone						NVARCHAR(100),
	@PhoneCountryCode			NVARCHAR(40),
	@PhoneAreaCode				NVARCHAR(40),
	@Phone2						NVARCHAR(100),
	@Phone2CountryCode			NVARCHAR(40),
	@Phone2AreaCode				NVARCHAR(40),
	@Phone3						NVARCHAR(100),
	@Phone3CountryCode			NVARCHAR(40),
	@Phone3AreaCode				NVARCHAR(40),
	@MobilePhone				NVARCHAR(100),
	@MobilePhoneCountryCode		NVARCHAR(40),
	@MobilePhoneAreaCode		NVARCHAR(40),
	@Fax						NVARCHAR(50),
	@FaxCountryCode				NVARCHAR(40),
	@FaxAreaCode				NVARCHAR(40),
	@Email						NVARCHAR(254),	
	@Skype						NVARCHAR(100),
	@MSN						NVARCHAR(100),
	@IP							VARCHAR(15),
	@Pic1						NVARCHAR(100)	= NULL,
	@Pic2						NVARCHAR(100)	= NULL,
	@Pic3						NVARCHAR(100)	= NULL,
	@Pic4						NVARCHAR(100)	= NULL,
	@Pic1Name					NVARCHAR(100)	= NULL,
	@Pic2Name					NVARCHAR(100)	= NULL,
	@Pic3Name					NVARCHAR(100)	= NULL,
	@Pic4Name					NVARCHAR(100)	= NULL,
	@BettingCode				NVARCHAR(100)	= NULL,
	@RefCode2					NVARCHAR(100)	= NULL,
	@Passport					NVARCHAR(100),
	@IsVip						BIT,
	@SiteID						INT,
	@LicenseeType				INT				= 0,
	@WhatsApp					NVARCHAR(100)	= NULL,
	@Line						NVARCHAR(100)	= NULL,
	@WeChat						NVARCHAR(100)	= NULL,
	@Yahoo						NVARCHAR(100)	= NULL,
	@QQ							NVARCHAR(100)	= NULL,
	@BBM						NVARCHAR(100)	= NULL,
	@ErrCode					INT OUTPUT,
	@ErrMsg						NVARCHAR(4000) OUTPUT
)
AS
/*
Created: Lukas
Date: 20101023
Task : Short Info Customer
DB: DB052.bodb_CRM
Original:

Revisions:
	- 20110725@Lukas: add skype, msn info
	- 20120307@Elodie: add 3 params @Pic1, @Pic3, @Pic3
	- 20120319@Elodie: change DB06 to DB052
	- 20120327@Elodie: change data type of @Skype, @MSN, @Pic1, @Pic2, @Pic3 params to NVARCHAR(500)
	- 20120404@Elodie: change data type of @Skype, @MSN, @Pic1, @Pic2, @Pic3 params to NVARCHAR(100)
	- 20140303@Dom: Modify for new structure
	- 20230412@Winfred: NAP CRM - Some of our Headline Contact info was missing in CRM [redmine:#186726]
Param's Explanation:
	
*/
BEGIN

	SET NOCOUNT ON
	DECLARE @FirstName_Old					NVARCHAR(50),
		@LastName_Old					NVARCHAR(50),
		@TitleID_Old					INT,
		@Birthday_Old					DATETIME,
		@Phone_Old						NVARCHAR(100),
		@PhoneCountryCode_Old			NVARCHAR(40),
		@PhoneAreaCode_Old				NVARCHAR(40),
		@Phone2_Old						NVARCHAR(100),
		@Phone2CountryCode_Old			NVARCHAR(40),
		@Phone2AreaCode_Old				NVARCHAR(40),
		@Phone3_Old						NVARCHAR(100),
		@Phone3CountryCode_Old			NVARCHAR(40),
		@Phone3AreaCode_Old				NVARCHAR(40),
		@MobilePhone_Old				NVARCHAR(100),
		@MobilePhoneCountryCode_Old		NVARCHAR(40),
		@MobilePhoneAreaCode_Old		NVARCHAR(40),
		@Fax_Old						NVARCHAR(50),
		@FaxCountryCode_Old				NVARCHAR(40),
		@FaxAreaCode_Old				NVARCHAR(40),
		@Email_Old						NVARCHAR(254),	
		@Skype_Old						NVARCHAR(100),
		@MSN_Old						NVARCHAR(100),
		@IP_Old							VARCHAR(15),
		@Pic1_Old						NVARCHAR(100)	= NULL,
		@Pic2_Old						NVARCHAR(100)	= NULL,
		@Pic3_Old						NVARCHAR(100)	= NULL,
		@Pic4_Old						NVARCHAR(100)	= NULL,
		@Pic1Name_Old					NVARCHAR(100)	= NULL,
		@Pic2Name_Old					NVARCHAR(100)	= NULL,
		@Pic3Name_Old					NVARCHAR(100)	= NULL,
		@Pic4Name_Old					NVARCHAR(100)	= NULL,
		@BettingCode_Old				NVARCHAR(100)	= NULL,
		@RefCode2_Old					NVARCHAR(100)	= NULL,
		@Passport_Old					NVARCHAR(100),
		@IsVip_Old						BIT,
		@SiteID_Old						INT,
		@LicenseeType_Old				INT				= 0,
		@WhatsApp_Old					NVARCHAR(100)	= NULL,
		@Line_Old						NVARCHAR(100)	= NULL,
		@WeChat_Old						NVARCHAR(100)	= NULL,
		@Yahoo_Old						NVARCHAR(100)	= NULL,
		@QQ_Old							NVARCHAR(100)	= NULL,
		@BBM_Old						NVARCHAR(100)	= NULL
	
	SELECT	@FirstName_Old				= FirstName,
		@LastName_Old					= LastName,
		@TitleID_Old					= TitleID,
		@Birthday_Old					= Birthday,
		@Phone_Old						= Phone,
		@PhoneAreaCode_Old				= PhoneAreaCode,
		@PhoneCountryCode_Old			= PhoneCountryCode,
		@Phone2_Old						= Phone2,
		@Phone2AreaCode_Old				= Phone2AreaCode,
		@Phone2CountryCode_Old			= Phone2CountryCode,
		@Phone3_Old						= Phone3,
		@Phone3AreaCode_Old				= Phone3AreaCode,
		@Phone3CountryCode_Old			= Phone3CountryCode,
		@MobilePhone_Old				= MobilePhone,
		@MobilePhoneAreaCode_Old		= MobilePhoneAreaCode,
		@MobilePhoneCountryCode_Old		= MobilePhoneCountryCode,
		@Fax_Old						= Fax,
		@FaxAreaCode_Old				= FaxAreaCode,
		@FaxCountryCode_Old				= FaxCountryCode,
		@Email_Old						= Email,
		@Skype_Old						= Skype,
		@MSN_Old						= MSN,
		@Pic1_Old						= Pic1,
		@Pic2_Old						= Pic2,
		@Pic3_Old						= Pic3,
		@Pic4_Old						= Pic4,
		@Pic1Name_Old					= Pic1Name,
		@Pic2Name_Old					= Pic2Name,
		@Pic3Name_Old					= Pic3Name,
		@Pic4Name_Old					= Pic4Name,
		@BettingCode_Old				= RefCode1,
		@RefCode2_Old					= RefCode2,
		@Passport_Old					= Passport,
		@IsVip_Old						= IsVip,
		@SiteID_Old						= SiteID,
		@LicenseeType_Old				= LicenseeType,	
		@WhatsApp_Old					= WhatsApp,		
		@Line_Old						= Line,			
		@WeChat_Old						= WeChat,			
		@Yahoo_Old						= Yahoo,			
		@QQ_Old							= QQ,				
		@BBM_Old						= BBM			
	FROM crmCustomer WITH(NOLOCK)
	WHERE CustID = @CustID

	UPDATE crmCustomer WITH(ROWLOCK,UPDLOCK)
	SET	FirstName				= @FirstName,
		LastName				= @LastName,
		TitleID					= @TitleID,
		Birthday				= @Birthday,
		Phone					= @Phone,
		PhoneAreaCode			= @PhoneAreaCode,
		PhoneCountryCode		= @PhoneCountryCode,
		Phone2					= @Phone2,
		Phone2AreaCode			= @Phone2AreaCode,
		Phone2CountryCode		= @Phone2CountryCode,
		Phone3					= @Phone3,
		Phone3AreaCode			= @Phone3AreaCode,
		Phone3CountryCode		= @Phone3CountryCode,
		MobilePhone				= @MobilePhone,
		MobilePhoneAreaCode		= @MobilePhoneAreaCode,
		MobilePhoneCountryCode	= @MobilePhoneCountryCode,
		Fax						= @Fax,
		FaxAreaCode				= @FaxAreaCode,
		FaxCountryCode			= @FaxCountryCode,
		Email					= @Email,
		Skype					= @Skype,
		MSN						= @MSN,
		Pic1					= @Pic1,
		Pic2					= @Pic2,
		Pic3					= @Pic3,
		Pic4					= @Pic4,
		Pic1Name				= @Pic1Name,
		Pic2Name				= @Pic2Name,
		Pic3Name				= @Pic3Name,
		Pic4Name				= @Pic4Name,
		RefCode1				= @BettingCode,
		RefCode2				= @RefCode2,
		Passport				= @Passport,
		IsVip					= @IsVip,
		SiteID					= @SiteID,
		LicenseeType			= @LicenseeType,
		WhatsApp				= @WhatsApp,
		Line					= @Line,
		WeChat					= @WeChat,
		Yahoo					= @Yahoo,
		QQ						= @QQ,
		BBM						= @BBM
	WHERE CustID = @CustID

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
		
	IF @@error <> 0
	BEGIN
		SELECT @ErrCode = 101
		SELECT @ErrMsg = 'Update Customer unsuccessfuly.'
		RETURN
	END

	
	-- write log
	DECLARE	@OldValues	XML
		,	@NewValues	XML;
	SELECT	@OldValues = 				
					'<Acc_CRM_CustomerShortUpd>' + --SP Name
						'<TitleID>'						+ ISNULL(CONVERT(VARCHAR(5),@TitleID_Old),'')					+ '</TitleID>' +
						'<FirstName>'					+ ISNULL(dbo.f_EncodeXMLValue(@FirstName_Old),'')				+ '</FirstName>' +
						'<LastName>'					+ ISNULL(dbo.f_EncodeXMLValue(@LastName_Old),'')				+ '</LastName>' +
						'<Birthday>'					+ ISNULL(CONVERT(VARCHAR(20),@Birthday_Old,107),'')				+ '</Birthday>' +
						'<Phone>'						+ ISNULL(dbo.f_EncodeXMLValue(@Phone_Old),'')					+ '</Phone>' +
						'<PhoneCountryCode>'			+ ISNULL(dbo.f_EncodeXMLValue(@PhoneCountryCode_Old),'')		+ '</PhoneCountryCode>' +
						'<PhoneAreaCode>'				+ ISNULL(dbo.f_EncodeXMLValue(@PhoneAreaCode_Old),'')			+ '</PhoneAreaCode>' +
						'<Phone2>'						+ ISNULL(dbo.f_EncodeXMLValue(@Phone2_Old),'')					+ '</Phone2>' +
						'<Phone2CountryCode>'			+ ISNULL(dbo.f_EncodeXMLValue(@Phone2CountryCode_Old),'')		+ '</Phone2CountryCode>' +
						'<Phone2AreaCode>'				+ ISNULL(dbo.f_EncodeXMLValue(@Phone2AreaCode_Old),'')			+ '</Phone2AreaCode>' +
						'<Phone3>'						+ ISNULL(dbo.f_EncodeXMLValue(@Phone3_Old),'')					+ '</Phone3>' +
						'<Phone3CountryCode>'			+ ISNULL(dbo.f_EncodeXMLValue(@Phone3CountryCode_Old),'')		+ '</Phone3CountryCode>' +
						'<Phone3AreaCode>'				+ ISNULL(dbo.f_EncodeXMLValue(@Phone3AreaCode_Old),'')			+ '</Phone3AreaCode>' +
						'<MobilePhone>'					+ ISNULL(dbo.f_EncodeXMLValue(@MobilePhone_Old),'')				+ '</MobilePhone>' +
						'<MobilePhoneCountryCode>'		+ ISNULL(dbo.f_EncodeXMLValue(@MobilePhoneCountryCode_Old),'')	+ '</MobilePhoneCountryCode>' +
						'<MobilePhoneAreaCode>'			+ ISNULL(dbo.f_EncodeXMLValue(@MobilePhoneAreaCode_Old),'')		+ '</MobilePhoneAreaCode>' +
						'<Fax>'							+ ISNULL(dbo.f_EncodeXMLValue(@Fax_Old),'')						+ '</Fax>' +
						'<FaxCountryCode>'				+ ISNULL(dbo.f_EncodeXMLValue(@FaxCountryCode_Old),'')			+ '</FaxCountryCode>' +
						'<FaxAreaCode>'					+ ISNULL(dbo.f_EncodeXMLValue(@FaxAreaCode_Old),'')				+ '</FaxAreaCode>' +						
						'<Email>'						+ ISNULL(dbo.f_EncodeXMLValue(@Email_Old),'')					+ '</Email>' +
						'<Skype>'						+ ISNULL(dbo.f_EncodeXMLValue(@Skype_Old),'')					+ '</Skype>' +
						'<MSN>'							+ ISNULL(dbo.f_EncodeXMLValue(@MSN_Old),'')						+ '</MSN>' +	
						'<Pic1>'						+ ISNULL(dbo.f_EncodeXMLValue(@Pic1_Old),'')					+ '</Pic1>' +
						'<Pic2>'						+ ISNULL(dbo.f_EncodeXMLValue(@Pic2_Old),'')					+ '</Pic2>' +
						'<Pic3>'						+ ISNULL(dbo.f_EncodeXMLValue(@Pic3_Old),'')					+ '</Pic3>' +
						'<Pic4>'						+ ISNULL(dbo.f_EncodeXMLValue(@Pic4_Old),'')					+ '</Pic4>' +
						'<Pic1Name>'					+ ISNULL(dbo.f_EncodeXMLValue(@Pic1Name_Old),'')				+ '</Pic1Name>' +
						'<Pic2Name>'					+ ISNULL(dbo.f_EncodeXMLValue(@Pic2Name_Old),'')				+ '</Pic2Name>' +
						'<Pic3Name>'					+ ISNULL(dbo.f_EncodeXMLValue(@Pic3Name_Old),'')				+ '</Pic3Name>' +
						'<Pic4Name>'					+ ISNULL(dbo.f_EncodeXMLValue(@Pic4Name_Old),'')				+ '</Pic4Name>' +
						'<BettingCode>'					+ ISNULL(dbo.f_EncodeXMLValue(@BettingCode_Old),'')				+ '</BettingCode>' +	
						'<RefCode2>'					+ ISNULL(dbo.f_EncodeXMLValue(@RefCode2_Old),'')				+ '</RefCode2>' +	
						'<Passport>'					+ ISNULL(dbo.f_EncodeXMLValue(@Passport_Old),'')				+ '</Passport>' +
						'<IsVip>'						+ ISNULL(CONVERT(VARCHAR(10),@IsVip_Old),'')					+ '</IsVip>' +
						'<SiteID>'						+ ISNULL(CONVERT(VARCHAR(10),@SiteID_Old),'')					+ '</SiteID>' +
						'<LicenseeType>'				+ ISNULL(CONVERT(VARCHAR(10),@LicenseeType_Old),'')				+ '</LicenseeType>' +
						'<WhatsApp>'					+ ISNULL(dbo.f_EncodeXMLValue(@WhatsApp_Old),'')				+ '</WhatsApp>' +
						'<Line>'						+ ISNULL(dbo.f_EncodeXMLValue(@Line_Old),'')					+ '</Line>' +
						'<WeChat>'						+ ISNULL(dbo.f_EncodeXMLValue(@WeChat_Old),'')					+ '</WeChat>' +
						'<Yahoo>'						+ ISNULL(dbo.f_EncodeXMLValue(@Yahoo_Old),'')					+ '</Yahoo>' +
						'<QQ>'							+ ISNULL(dbo.f_EncodeXMLValue(@QQ_Old),'')						+ '</QQ>' +
						'<BBM>'							+ ISNULL(dbo.f_EncodeXMLValue(@BBM_Old),'')						+ '</BBM>' +
					'</Acc_CRM_CustomerShortUpd>';

	SELECT @NewValues = 				
					'<Acc_CRM_CustomerShortUpd>' + --SP Name
						'<TitleID>'						+ ISNULL(CONVERT(VARCHAR(5),@TitleID),'')					+ '</TitleID>' +
						'<FirstName>'					+ ISNULL(dbo.f_EncodeXMLValue(@FirstName),'')				+ '</FirstName>' +
						'<LastName>'					+ ISNULL(dbo.f_EncodeXMLValue(@LastName),'')				+ '</LastName>' +
						'<Birthday>'					+ ISNULL(CONVERT(VARCHAR(20),@Birthday,107),'')				+ '</Birthday>' +
						'<Phone>'						+ ISNULL(dbo.f_EncodeXMLValue(@Phone),'')					+ '</Phone>' +
						'<PhoneCountryCode>'			+ ISNULL(dbo.f_EncodeXMLValue(@PhoneCountryCode),'')		+ '</PhoneCountryCode>' +
						'<PhoneAreaCode>'				+ ISNULL(dbo.f_EncodeXMLValue(@PhoneAreaCode),'')			+ '</PhoneAreaCode>' +
						'<Phone2>'						+ ISNULL(dbo.f_EncodeXMLValue(@Phone2),'')					+ '</Phone2>' +
						'<Phone2CountryCode>'			+ ISNULL(dbo.f_EncodeXMLValue(@Phone2CountryCode),'')		+ '</Phone2CountryCode>' +
						'<Phone2AreaCode>'				+ ISNULL(dbo.f_EncodeXMLValue(@Phone2AreaCode),'')			+ '</Phone2AreaCode>' +
						'<Phone3>'						+ ISNULL(dbo.f_EncodeXMLValue(@Phone3),'')					+ '</Phone3>' +
						'<Phone3CountryCode>'			+ ISNULL(dbo.f_EncodeXMLValue(@Phone3CountryCode),'')		+ '</Phone3CountryCode>' +
						'<Phone3AreaCode>'				+ ISNULL(dbo.f_EncodeXMLValue(@Phone3AreaCode),'')			+ '</Phone3AreaCode>' +
						'<MobilePhone>'					+ ISNULL(dbo.f_EncodeXMLValue(@MobilePhone),'')				+ '</MobilePhone>' +
						'<MobilePhoneCountryCode>'		+ ISNULL(dbo.f_EncodeXMLValue(@MobilePhoneCountryCode),'')	+ '</MobilePhoneCountryCode>' +
						'<MobilePhoneAreaCode>'			+ ISNULL(dbo.f_EncodeXMLValue(@MobilePhoneAreaCode),'')		+ '</MobilePhoneAreaCode>' +
						'<Fax>'							+ ISNULL(dbo.f_EncodeXMLValue(@Fax),'')						+ '</Fax>' +
						'<FaxCountryCode>'				+ ISNULL(dbo.f_EncodeXMLValue(@FaxCountryCode),'')			+ '</FaxCountryCode>' +
						'<FaxAreaCode>'					+ ISNULL(dbo.f_EncodeXMLValue(@FaxAreaCode),'')				+ '</FaxAreaCode>' +						
						'<Email>'						+ ISNULL(dbo.f_EncodeXMLValue(@Email),'')					+ '</Email>' +
						'<Skype>'						+ ISNULL(dbo.f_EncodeXMLValue(@Skype),'')					+ '</Skype>' +
						'<MSN>'							+ ISNULL(dbo.f_EncodeXMLValue(@MSN),'')						+ '</MSN>' +	
						'<Pic1>'						+ ISNULL(dbo.f_EncodeXMLValue(@Pic1),'')					+ '</Pic1>' +
						'<Pic2>'						+ ISNULL(dbo.f_EncodeXMLValue(@Pic2),'')					+ '</Pic2>' +
						'<Pic3>'						+ ISNULL(dbo.f_EncodeXMLValue(@Pic3),'')					+ '</Pic3>' +
						'<Pic4>'						+ ISNULL(dbo.f_EncodeXMLValue(@Pic4),'')					+ '</Pic4>' +
						'<Pic1Name>'					+ ISNULL(dbo.f_EncodeXMLValue(@Pic1Name),'')				+ '</Pic1Name>' +
						'<Pic2Name>'					+ ISNULL(dbo.f_EncodeXMLValue(@Pic2Name),'')				+ '</Pic2Name>' +
						'<Pic3Name>'					+ ISNULL(dbo.f_EncodeXMLValue(@Pic3Name),'')				+ '</Pic3Name>' +
						'<Pic4Name>'					+ ISNULL(dbo.f_EncodeXMLValue(@Pic4Name),'')				+ '</Pic4Name>' +
						'<BettingCode>'					+ ISNULL(dbo.f_EncodeXMLValue(@BettingCode),'')				+ '</BettingCode>' +	
						'<RefCode2>'					+ ISNULL(dbo.f_EncodeXMLValue(@RefCode2),'')				+ '</RefCode2>' +	
						'<Passport>'					+ ISNULL(dbo.f_EncodeXMLValue(@Passport),'')				+ '</Passport>' +
						'<IsVip>'						+ ISNULL(CONVERT(VARCHAR(10),@IsVip),'')					+ '</IsVip>' +
						'<SiteID>'						+ ISNULL(CONVERT(VARCHAR(10),@SiteID),'')					+ '</SiteID>' +
						'<LicenseeType>'				+ ISNULL(CONVERT(VARCHAR(10),@LicenseeType),'')				+ '</LicenseeType>' +
						'<WhatsApp>'					+ ISNULL(dbo.f_EncodeXMLValue(@WhatsApp),'')				+ '</WhatsApp>' +
						'<Line>'						+ ISNULL(dbo.f_EncodeXMLValue(@Line),'')					+ '</Line>' +
						'<WeChat>'						+ ISNULL(dbo.f_EncodeXMLValue(@WeChat),'')					+ '</WeChat>' +
						'<Yahoo>'						+ ISNULL(dbo.f_EncodeXMLValue(@Yahoo),'')					+ '</Yahoo>' +
						'<QQ>'							+ ISNULL(dbo.f_EncodeXMLValue(@QQ),'')						+ '</QQ>' +
						'<BBM>'							+ ISNULL(dbo.f_EncodeXMLValue(@BBM),'')						+ '</BBM>' +
					'</Acc_CRM_CustomerShortUpd>';

	EXECUTE	dbo.WriteLog_UserLog_crmLogCustomer
				@UserID = @UserID
			,	@CustID = @CustID
			,	@ActionID = 108
			,	@IP = @IP
			,	@NewValues = @NewValues
			,	@OldValues = @OldValues;
END
GO

