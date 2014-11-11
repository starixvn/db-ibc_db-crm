
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

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
	@BettingCode				NVARCHAR(100)	= NULL,
	@RefCode2					NVARCHAR(100)	= NULL,
	@Passport					NVARCHAR(100),
	@IsVip						BIT,
	@SiteID						INT,
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
		@BettingCode_Old				NVARCHAR(100)	= NULL,
		@RefCode2_Old					NVARCHAR(100)	= NULL,
		@Passport_Old					NVARCHAR(100),
		@IsVip_Old						BIT,
		@SiteID_Old						INT
	
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
		@BettingCode_Old				= RefCode1,
		@RefCode2_Old					= RefCode2,
		@Passport_Old					= Passport,
		@IsVip_Old						= IsVip,
		@SiteID_Old						= SiteID
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
		RefCode1				= @BettingCode,
		RefCode2				= @RefCode2,
		Passport				= @Passport,
		IsVip					= @IsVip,
		SiteID					= @SiteID
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
END


GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_CustomerShortUpd] TO [bodbAdminNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_CustomerShortUpd] TO [vnteam]
GO 
