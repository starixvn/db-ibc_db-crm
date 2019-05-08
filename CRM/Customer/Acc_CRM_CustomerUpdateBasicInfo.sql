/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROC [dbo].[Acc_CRM_CustomerUpdateBasicInfo]
	@Site					INT,
	@FirstName				NVARCHAR(100),
	@LastName				NVARCHAR(100),
	@Language				VARCHAR(500),
	@CountryID				INT,
	@Phone					NVARCHAR(100),
	@PhoneCountryCode		NVARCHAR(20),
	@PhoneAreaCode			NVARCHAR(20),
	@Phone2					NVARCHAR(100),
	@Phone2CountryCode		NVARCHAR(20),
	@Phone2AreaCode			NVARCHAR(20),
	@Phone3					NVARCHAR(100),
	@Phone3CountryCode		NVARCHAR(20),
	@Phone3AreaCode			NVARCHAR(20),
	@MobilePhone			NVARCHAR(100),
	@MobilePhoneCountryCode	NVARCHAR(20),
	@MobilePhoneAreaCode	NVARCHAR(20),
	@Email					NVARCHAR(100),
	@MSN					NVARCHAR(100),
	@Skype					NVARCHAR(100),
	@Pic1					NVARCHAR(200) = NULL,
	@Pic2					NVARCHAR(200) = NULL,
	@Pic3					NVARCHAR(200) = NULL,
	@Pic4					NVARCHAR(200) = NULL,
	@Pic1Name				NVARCHAR(200)='',
	@Pic2Name				NVARCHAR(200)='',
	@Pic3Name				NVARCHAR(200)='',
	@Pic4Name				NVARCHAR(200)='',
	@CustID					INT,
	@UserID					INT,
	@IP						VARCHAR(15),
	@ErrCode				INT				= 0 OUTPUT,
	@ErrMsg					NVARCHAR(4000)	= '' OUTPUT,
	@UserRole				TINYINT
AS
/*
Created: Dom
Date: 20140110
Task : update customer basic info
DB: DB052.bodb_CRM
Original:

Revisions:
	- 20140827@Dom: [Redmine #18632] Update phone number in custsearch
	- 20141118@Dom: Add new PIC name
	- 20190506@Winnie: CN88 Permission RedmineID: #112637
*/
	SET NOCOUNT ON

	SELECT	@ErrCode	= 0,
			@ErrMsg		= ''

DECLARE @UserName	NVARCHAR(100),
		@srecommend INT,
		@SiteID		INT

SELECT @UserName = username,@srecommend=srecommend
FROM bodb02.dbo.Customer(NOLOCK)
WHERE custid = @CustID

IF @srecommend IS NOT NULL
BEGIN
	IF (@UserRole=1 AND NOT EXISTS(SELECT TOP 1 1 FROM bodb02.dbo.CS_CustSuper WITH(NOLOCK) WHERE CustId=@srecommend))
		OR  (@UserRole=2 AND EXISTS(SELECT TOP 1 1 FROM bodb02.dbo.CS_CustSuper WITH(NOLOCK) WHERE CustId=@srecommend))
	BEGIN
		SELECT @ErrCode=100
		SELECT @ErrMsg='You need permission'
		RETURN
	END

END
ELSE
BEGIN
	SELECT @SiteID=SiteID FROM crmCustomer WITH(NOLOCK) WHERE CustID=@CustID
END
BEGIN
	IF NOT EXISTS (SELECT 1 FROM crmCustomer WITH(NOLOCK) WHERE CustID = @CustID)
	BEGIN
		DECLARE @Birthday DATETIME
		SELECT @Birthday = birthday
		FROM bodb02.dbo.Customer(NOLOCK)
		WHERE custid = @CustID

		EXEC Acc_CRM_CustomerIns_New
			@UserID							= @UserID,				
			@CustID							= @CustID,						
			@UserName						= @UserName,
			@FirstName						= @FirstName,
			@LastName						= @LastName,
			@TitleID						= NULL,
			@Birthday						= @Birthday,
			@Phone							= @Phone,
			@PhoneCountryCode				= @PhoneCountryCode,
			@PhoneAreaCode					= @PhoneAreaCode,
			@Phone2							= @Phone2,
			@Phone2CountryCode				= @Phone2CountryCode,
			@Phone2AreaCode					= @Phone2AreaCode,
			@Phone3							= @Phone3,
			@Phone3CountryCode				= @Phone3CountryCode,
			@Phone3AreaCode					= @Phone3AreaCode,
			@Passport						= NULL,
			@MobilePhone					= @MobilePhone,
			@MobilePhoneCountryCode			= @MobilePhoneCountryCode,
			@MobilePhoneAreaCode			= @MobilePhoneAreaCode,
			@Fax							= NULL,
			@FaxCountryCode					= NULL,
			@FaxAreaCode					= NULL,
			@Email							= @Email,
			@Skype							= @Skype,
			@MSN							= @MSN,
			@BettingCode					= NULL,
			@RefCode2						= NULL,
			@Pic1							= @Pic1,
			@Pic2							= @Pic2,
			@Pic3							= @Pic3,
			@Pic4							= @Pic4,
			@Pic1Name						= @Pic1Name,
			@Pic2Name						= @Pic2Name,
			@Pic3Name						= @Pic3Name,
			@Pic4Name						= @Pic4Name,
			@Line1							= NULL,
			@Line2							= NULL,
			@Line3							= NULL,
			@City							= NULL,
			@PostCode						= NULL,
			@State							= NULL,
			@BankLine1						= NULL,
			@BankLine2						= NULL,
			@BankLine3						= NULL,
			@BankCity						= NULL,
			@BankCode						= NULL,
			@BankCountryID					= NULL,
			@BankState						= NULL,
			@Question						= NULL,
			@Answer							= NULL,
			@CountryID						= NULL,
			@IsVIP							= NULL,
			@SiteID							= NULL,
			@Wire_BankName					= NULL,
			@Wire_BankAddress				= NULL,
			@Wire_AccountName				= NULL,
			@Wire_AccountNo					= NULL,
			@Wire_SwiftCode					= NULL,
			@AccountHolderName				= NULL,
			@SpecialRemark					= NULL,	
			@Remark							= NULL,	
			@CreatorID						= @UserID,
			@IP								= @IP,
			@ErrCode						= @ErrCode OUTPUT,
			@ErrMsg							= @ErrMsg OUTPUT
		
		IF @ErrCode <> 0
		BEGIN
			SELECT @ErrCode = 101
			SELECT @ErrMsg = 'Cannot insert customer.'
			RETURN
		END

		-- UPDATE Customer Language
		DELETE crmCustomerLanguage where CustID = @CustID
		INSERT INTO crmCustomerLanguage
		SELECT @CustID,SettingID
		FROM dbo.strSplit(@Language,',')

		IF @@error <> 0
		BEGIN
			SELECT @ErrCode = 101
			SELECT @ErrMsg = 'Update Customer unsuccessfuly.'
			RETURN
		END
	END
	ELSE
	BEGIN
		
		DECLARE @Site_Old					INT,
		@FirstName_Old				NVARCHAR(100),
		@LastName_Old				NVARCHAR(100),
		@Language_Old				VARCHAR(500) = '',
		@CountryID_Old				INT,
		@Phone_Old					NVARCHAR(100),
		@PhoneCountryCode_Old		NVARCHAR(20),
		@PhoneAreaCode_Old			NVARCHAR(20),
		@Phone2_Old					NVARCHAR(100),
		@Phone2CountryCode_Old		NVARCHAR(20),
		@Phone2AreaCode_Old			NVARCHAR(20),
		@Phone3_Old					NVARCHAR(100),
		@Phone3CountryCode_Old		NVARCHAR(20),
		@Phone3AreaCode_Old			NVARCHAR(20),
		@MobilePhone_Old			NVARCHAR(100),
		@MobilePhoneCountryCode_Old	NVARCHAR(20),
		@MobilePhoneAreaCode_Old	NVARCHAR(20),
		@Email_Old					NVARCHAR(100),
		@MSN_Old					NVARCHAR(100),
		@Skype_Old					NVARCHAR(100),
		@Pic1_Old					NVARCHAR(200),
		@Pic2_Old					NVARCHAR(200),
		@Pic3_Old					NVARCHAR(200),
		@Pic4_Old					NVARCHAR(200),
		@Pic1Name_Old				NVARCHAR(200),
		@Pic2Name_Old				NVARCHAR(200),
		@Pic3Name_Old				NVARCHAR(200),
		@Pic4Name_Old				NVARCHAR(200),
		@CustID_Old					INT

		SELECT 
			@Site_Old						= SiteID,
			@FirstName_Old					= FirstName,
			@LastName_Old					= LastName,
			@CountryID_Old					= CountryID,
			@Phone_Old						= Phone,
			@PhoneCountryCode_Old			= PhoneCountryCode,
			@PhoneAreaCode_Old				= PhoneAreaCode,
			@Phone2_Old						= Phone2,
			@Phone2CountryCode_Old			= Phone2CountryCode,
			@Phone2AreaCode_Old				= Phone2AreaCode,
			@Phone3_Old						= Phone3,
			@Phone3CountryCode_Old			= Phone3CountryCode,
			@Phone3AreaCode_Old				= Phone3AreaCode,
			@MobilePhone_Old				= MobilePhone,
			@MobilePhoneCountryCode_Old		= MobilePhoneCountryCode,
			@MobilePhoneAreaCode_Old		= MobilePhoneAreaCode,
			@Email_Old						= Email,
			@MSN_Old						= MSN,	
			@Skype_Old						= Skype,
			@Pic1_Old						= Pic1,	
			@Pic2_Old						= Pic2,	
			@Pic3_Old						= Pic3,	
			@Pic4_Old						= Pic4,	
			@Pic1Name_Old					= Pic1Name,	
			@Pic2Name_Old					= Pic2Name,	
			@Pic3Name_Old					= Pic3Name,	
			@Pic4Name_Old					= Pic4name	
		FROM crmCustomer WITH(ROWLOCK,UPDLOCK)
		WHERE CustID	= @CustID

		SELECT @Language_Old = @Language_Old + cast(LanguageID as nvarchar(50))+ ','
		FROM crmCustomerLanguage(NOLOCK) WHERE CustID = @CustID

		IF ISNULL(@Language_Old,'')<>''
		SELECT @Language_Old = LEFT(@Language_Old,LEN(@Language_Old)-1)
		
		UPDATE crmCustomer WITH(ROWLOCK,UPDLOCK)
		SET SiteID						= @site,
			FirstName					= @FirstName,
			LastName					= @LastName,
			CountryID					= @CountryID,
			Phone						= @Phone,
			PhoneCountryCode			= @PhoneCountryCode,
			PhoneAreaCode				= @PhoneAreaCode,
			Phone2						= @Phone2,
			Phone2CountryCode			= @Phone2CountryCode,
			Phone2AreaCode				= @Phone2AreaCode,
			Phone3						= @Phone3,
			Phone3CountryCode			= @Phone3CountryCode,
			Phone3AreaCode				= @Phone3AreaCode,
			MobilePhone					= @MobilePhone,
			MobilePhoneCountryCode		= @MobilePhoneCountryCode,
			MobilePhoneAreaCode			= @MobilePhoneAreaCode,
			Email						= @Email,
			MSN							= @MSN,	
			Skype						= @Skype,
			Pic1						= @Pic1,	
			Pic2						= @Pic2,	
			Pic3						= @Pic3,	
			Pic4						= @Pic4,
			Pic1Name					= @Pic1Name,	
			Pic2Name					= @Pic2Name,	
			Pic3Name					= @Pic3Name,	
			Pic4Name					= @Pic4Name	
		WHERE CustID	= @CustID

		-- UPDATE Customer Language
		DELETE crmCustomerLanguage where CustID = @CustID
		INSERT INTO crmCustomerLanguage
		SELECT @CustID,SettingID
		FROM dbo.strSplit(@Language,',')

		IF @@error <> 0
		BEGIN
			SELECT @ErrCode = 101
			SELECT @ErrMsg = 'Update Customer unsuccessfuly.'
			RETURN
		END

		-- Update CustSearch
		UPDATE crmCustomerSearch WITH(ROWLOCK,UPDLOCK)
		SET PhoneNumber1 = @PhoneCountryCode+@PhoneAreaCode+@Phone
			,PhoneNumber2 = @Phone2CountryCode+@Phone2AreaCode+@Phone2
			,PhoneNumber3 = @Phone3CountryCode+@Phone3AreaCode+@Phone3
			,MobilePhone = @MobilePhoneCountryCode+@MobilePhoneAreaCode+@MobilePhone
		WHERE CustID = @CustID
		AND (
				ISNULL(@PhoneCountryCode,'')		<> ISNULL(@PhoneCountryCode_Old,'')
			OR ISNULL(@PhoneAreaCode,'')			<> ISNULL(@PhoneAreaCode_Old,'')
			OR ISNULL(@Phone,'')					<> ISNULL(@Phone_Old,'')
			OR ISNULL(@Phone2CountryCode,'')		<> ISNULL(@Phone2CountryCode_Old,'')
			OR ISNULL(@Phone2AreaCode,'')			<> ISNULL(@Phone2AreaCode,'')
			OR ISNULL(@Phone2,'')					<> ISNULL(@Phone2_Old,'')
			OR ISNULL(@Phone3CountryCode,'')		<> ISNULL(@Phone3CountryCode_Old,'')
			OR ISNULL(@Phone3AreaCode,'')			<> ISNULL(@Phone3AreaCode,'')
			OR ISNULL(@Phone3,'')					<> ISNULL(@Phone3_Old,'')
			OR ISNULL(@MobilePhoneCountryCode,'')	<> ISNULL(@MobilePhoneCountryCode_Old,'')
			OR ISNULL(@MobilePhoneAreaCode,'')		<> ISNULL(@MobilePhoneAreaCode,'') 
			OR ISNULL(@MobilePhone,'')				<> ISNULL(@MobilePhone_Old,'')
		)
		
		IF @@error <> 0
		BEGIN
			SELECT @ErrCode = 101
			SELECT @ErrMsg = 'Update Customer unsuccessfuly.'
			RETURN
		END

	--------Update language for Old System------
	/*IF(EXISTS(SELECT TOP 1 1 FROM dbo.strSplit(@Language,',') WHERE SettingID = 12000))
	BEGIN
		UPDATE crmCustomer WITH(ROWLOCK,UPDLOCK) SET LanguageID = 12000 WHERE CustID = @CustID
	END

	ELSE IF(EXISTS(SELECT TOP 1 1 FROM dbo.strSplit(@Language,',') WHERE SettingID = 12001))
	BEGIN
		UPDATE crmCustomer WITH(ROWLOCK,UPDLOCK) SET LanguageID = 12001 WHERE CustID = @CustID
	END

	ELSE IF(EXISTS(SELECT TOP 1 1 FROM dbo.strSplit(@Language,',') WHERE SettingID = 12002))
	BEGIN
		UPDATE crmCustomer WITH(ROWLOCK,UPDLOCK) SET LanguageID = 12002 WHERE CustID = @CustID
	END

	ELSE
	BEGIN 
		UPDATE crmCustomer WITH(ROWLOCK,UPDLOCK) SET LanguageID = (SELECT TOP 1 SettingID FROM dbo.strSplit(@Language,',')) WHERE CustID = @CustID
	END*/

	-- write log
	DECLARE @NewValues XML,@OldValues XML
	SELECT @OldValues =
					'<Acc_CRM_CustomerUpdateBasicInfo>' + --SP Name
						'<SiteID>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Site_Old),'')					+ '</SiteID>'	+
						'<FirstName>'				+ ISNULL([dbo].[f_EncodeXMLValue](@FirstName_Old),'')				+ '</FirstName>'+
						'<LastName>'				+ ISNULL([dbo].[f_EncodeXMLValue](@LastName_Old),'')				+ '</LastName>'	+
						'<CountryID>'				+ CAST(ISNULL(@CountryID_Old,0) AS VARCHAR(20))						+ '</CountryID>'+
						'<LanguageID>'				+ CAST(ISNULL(@Language_Old,'') AS VARCHAR(2000))						+ '</LanguageID>'+
						'<Phone>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Phone_Old),'')					+ '</Phone>'+
						'<PhoneCountryCode>'		+ ISNULL([dbo].[f_EncodeXMLValue](@PhoneCountryCode_Old),'')		+ '</PhoneCountryCode>'	+
						'<PhoneAreaCode>'			+ ISNULL([dbo].[f_EncodeXMLValue](@PhoneAreaCode_Old),'')			+ '</PhoneAreaCode>'+
						'<Phone2>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Phone2_Old),'')					+ '</Phone2>'+
						'<Phone2CountryCode>'		+ ISNULL([dbo].[f_EncodeXMLValue](@Phone2CountryCode_Old),'')		+ '</Phone2CountryCode>'	+
						'<Phone2AreaCode>'			+ ISNULL([dbo].[f_EncodeXMLValue](@Phone2AreaCode_Old),'')			+ '</Phone2AreaCode>'	+
						'<Phone3>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Phone3_Old),'')					+ '</Phone3>'	+
						'<Phone3CountryCode>'		+ ISNULL([dbo].[f_EncodeXMLValue](@Phone3CountryCode_Old),'')		+ '</Phone3CountryCode>'	+
						'<Phone3AreaCode>'			+ ISNULL([dbo].[f_EncodeXMLValue](@Phone3AreaCode_Old),'')			+ '</Phone3AreaCode>'	+
						'<MobilePhone>'				+ ISNULL([dbo].[f_EncodeXMLValue](@MobilePhone_Old),'')				+ '</MobilePhone>'	+
						'<MobilePhoneCountryCode>'	+ ISNULL([dbo].[f_EncodeXMLValue](@MobilePhoneCountryCode_Old),'')	+ '</MobilePhoneCountryCode>'	+
						'<MobilePhoneAreaCode>'		+ ISNULL([dbo].[f_EncodeXMLValue](@MobilePhoneAreaCode_Old),'')		+ '</MobilePhoneAreaCode>'	+
						'<Email>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Email_Old),'')					+ '</Email>'	+
						'<MSN>'						+ ISNULL([dbo].[f_EncodeXMLValue](@MSN_Old),'')						+ '</MSN>'		+
						'<Skype>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Skype_Old),'')					+ '</Skype>'	+
						'<Pic1>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Pic1_Old),'')					+ '</Pic1>'		+
						'<Pic2>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Pic2_Old),'')					+ '</Pic2>'		+
						'<Pic3>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Pic3_Old),'')					+ '</Pic3>'		+
						'<Pic4>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Pic4_Old),'')					+ '</Pic4>'		+
						'<Pic1Name>'				+ ISNULL([dbo].[f_EncodeXMLValue](@Pic1Name_Old),'')				+ '</Pic1Name>'		+
						'<Pic2Name>'				+ ISNULL([dbo].[f_EncodeXMLValue](@Pic2Name_Old),'')				+ '</Pic2Name>'		+
						'<Pic3Name>'				+ ISNULL([dbo].[f_EncodeXMLValue](@Pic3Name_Old),'')				+ '</Pic3Name>'		+
						'<Pic4Name>'				+ ISNULL([dbo].[f_EncodeXMLValue](@Pic4Name_Old),'')				+ '</Pic4Name>'		+
					'</Acc_CRM_CustomerUpdateBasicInfo>'

	SELECT @NewValues =
					'<Acc_CRM_CustomerUpdateBasicInfo>' + --SP Name
						'<SiteID>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Site),'')					+ '</SiteID>'	+
						'<FirstName>'				+ ISNULL([dbo].[f_EncodeXMLValue](@FirstName),'')				+ '</FirstName>'+
						'<LastName>'				+ ISNULL([dbo].[f_EncodeXMLValue](@LastName),'')				+ '</LastName>'	+
						'<CountryID>'				+ CAST(ISNULL(@CountryID,0) AS VARCHAR(20))						+ '</CountryID>'	+
						'<LanguageID>'				+ CAST(ISNULL(@Language,'') AS VARCHAR(2000))						+ '</LanguageID>'	+
						'<Phone>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Phone),'')					+ '</Phone>'	+
						'<PhoneCountryCode>'		+ ISNULL([dbo].[f_EncodeXMLValue](@PhoneCountryCode),'')		+ '</PhoneCountryCode>'	+
						'<PhoneAreaCode>'			+ ISNULL([dbo].[f_EncodeXMLValue](@PhoneAreaCode),'')			+ '</PhoneAreaCode>'	+
						'<Phone2>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Phone2),'')					+ '</Phone2>'	+
						'<Phone2CountryCode>'		+ ISNULL([dbo].[f_EncodeXMLValue](@Phone2CountryCode),'')		+ '</Phone2CountryCode>'	+
						'<Phone2AreaCode>'			+ ISNULL([dbo].[f_EncodeXMLValue](@Phone2AreaCode),'')			+ '</Phone2AreaCode>'	+
						'<Phone3>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Phone3),'')					+ '</Phone3>'	+
						'<Phone3CountryCode>'		+ ISNULL([dbo].[f_EncodeXMLValue](@Phone3CountryCode),'')		+ '</Phone3CountryCode>'	+
						'<Phone3AreaCode>'			+ ISNULL([dbo].[f_EncodeXMLValue](@Phone3AreaCode),'')			+ '</Phone3AreaCode>'	+
						'<MobilePhone>'				+ ISNULL([dbo].[f_EncodeXMLValue](@MobilePhone),'')				+ '</MobilePhone>'	+
						'<MobilePhoneCountryCode>'	+ ISNULL([dbo].[f_EncodeXMLValue](@MobilePhoneCountryCode),'')	+ '</MobilePhoneCountryCode>'	+
						'<MobilePhoneAreaCode>'		+ ISNULL([dbo].[f_EncodeXMLValue](@MobilePhoneAreaCode),'')		+ '</MobilePhoneAreaCode>'	+
						'<Email>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Email),'')					+ '</Email>'	+
						'<MSN>'						+ ISNULL([dbo].[f_EncodeXMLValue](@MSN),'')						+ '</MSN>'		+
						'<Skype>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Skype),'')					+ '</Skype>'	+
						'<Pic1>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Pic1),'')					+ '</Pic1>'		+
						'<Pic2>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Pic2),'')					+ '</Pic2>'		+
						'<Pic3>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Pic3),'')					+ '</Pic3>'		+
						'<Pic4>'					+ ISNULL([dbo].[f_EncodeXMLValue](@Pic4),'')					+ '</Pic4>'		+
						'<Pic1Name>'				+ ISNULL([dbo].[f_EncodeXMLValue](@Pic1Name),'')				+ '</Pic1Name>'		+
						'<Pic2Name>'				+ ISNULL([dbo].[f_EncodeXMLValue](@Pic2Name),'')				+ '</Pic2Name>'		+
						'<Pic3Name>'				+ ISNULL([dbo].[f_EncodeXMLValue](@Pic3Name),'')				+ '</Pic3Name>'		+
						'<Pic4Name>'				+ ISNULL([dbo].[f_EncodeXMLValue](@Pic4Name),'')				+ '</Pic4Name>'		+
					'</Acc_CRM_CustomerUpdateBasicInfo>'

	EXEC [dbo].[WriteLog_UserLog_crmLogCustomer]
				@CustID = @CustID, 
				@UserID = @UserID, 
				@ActionID = 105, 
				@IP = @IP, 
				@NewValues = @NewValues,
				@OldValues = @OldValues
	
	END
END
GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_CustomerUpdateBasicInfo] TO [bodbAdminNet]
GO 
