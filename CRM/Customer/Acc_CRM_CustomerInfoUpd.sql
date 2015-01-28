
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.Acc_CRM_CustomerInfoUpd    Script Date: 3/26/2014 6:06:05 PM ******/
ALTER PROCEDURE [dbo].[Acc_CRM_CustomerInfoUpd]
(
	@UserID						INT,
	@CustID						INT,
	@UserName					NVARCHAR(50),
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
	@SpecialRemark				NVARCHAR(1000)	= NULL,	
	@Remark						NVARCHAR(1000)	= NULL,	
	@IsUpdateUserName			BIT				= 0,
	@CreatorID					INT,
	@IP							VARCHAR(15),
	@ErrCode					INT				= 0 OUTPUT,
	@ErrMsg						NVARCHAR(4000)	= '' OUTPUT	
)
AS
/*
	Created: Lukas
	Date: 20101123
	Task : update customer info
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20110701@Lukas: support update username for guest
		- 20120327@Elodie: change data type of @Skype, @MSN, @Pic1, @Pic2, @Pic3 params to NVARCHAR(500)
						   change DB06 to DB052
		- 20120327@Elodie: change data type of @Skype, @MSN, @Pic1, @Pic2, @Pic3 params to NVARCHAR(100)
		- 20130121@Johnson: change link server DB03 to DBPOLICY
		- 20140303@Dom: Modify for new structure
		- 20141208@Dom: Remove policy checking
	Param's Explanation:
	
*/
BEGIN	
	SET NOCOUNT ON

	SELECT	@ErrCode	= 0,
			@ErrMsg		= ''

	--Check permission
--	EXEC DBPOLICY.bodb02.dbo.Acc_Con_CheckPermission @custid=@UserID,@funcname='[CustomerInfo]',@ErrCode=@ErrCode OUTPUT,@ErrMsg=@ErrMsg OUTPUT
--	IF @ErrCode <> 0
--		RETURN

	IF NOT EXISTS (SELECT 1 FROM crmCustomer WITH(NOLOCK) WHERE CustID = @CustID)
	BEGIN
		--- create new customer
		EXEC [dbo].[Acc_CRM_CustomerIns]
				@CustID, 
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
				@Line1,
				@Line2,
				@Line3,
				@City,
				@Postcode,
				@State,
				@BankLine1,
				@BankLine2,
				@BankLine3,
				@BankCity,
				@BankCode,
				@BankState,
				@LanguageID, 
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
				@SpecialRemark,
				@Remark,  					
				@CreatorID			= @CreatorID,
				@IP					= @IP,
				@ErrCode			= @ErrCode OUTPUT,
				@ErrMsg				= @ErrMsg OUTPUT
		IF @ErrCode <> 0
		BEGIN
			--SELECT @ErrCode = 100
			RETURN
		END
	END
	ELSE   --- if exist
	BEGIN
		EXEC [dbo].[Acc_CRM_CustomerUpd]
				@UserID						= @UserID,
				@CustID						= @CustID,
				@FirstName					= @FirstName,
				@LastName					= @LastName,
				@TitleID					= @TitleID,
				@Birthday					= @Birthday,
				@LanguageID					= @LanguageID,
				@Phone						= @Phone,	
				@PhoneCountryCode			= @PhoneCountryCode,	
				@PhoneAreaCode				= @PhoneAreaCode,	
				@Phone2						= @Phone2,	
				@Phone2CountryCode			= @Phone2CountryCode,	
				@Phone2AreaCode				= @Phone2AreaCode,	
				@Phone3						= @Phone3,	
				@Phone3CountryCode			= @Phone3CountryCode,	
				@Phone3AreaCode				= @Phone3AreaCode,	
				@Passport					= @Passport,	
				@MobilePhone				= @MobilePhone,
				@MobilePhoneCountryCode		= @MobilePhoneCountryCode,
				@MobilePhoneAreaCode		= @MobilePhoneAreaCode,
				@Fax						= @Fax,
				@FaxCountryCode				= @FaxCountryCode,
				@FaxAreaCode				= @FaxAreaCode,
				@Email						= @Email,
				@Skype						= @Skype,
				@MSN						= @MSN,
				@BettingCode				= @BettingCode,
				@RefCode2					= @RefCode2,
				@Pic1						= @Pic1,
				@Pic2						= @Pic2,
				@Pic3						= @Pic3,
				@Pic4						= @Pic4,
				@Line1						= @Line1,
				@Line2						= @Line2,
				@Line3						= @Line3,
				@City						= @City,
				@PostCode					= @PostCode,
				@State						= @State,
				@BankLine1					= @BankLine1,
				@BankLine2					= @BankLine2,
				@BankLine3					= @BankLine3,
				@BankCity					= @BankCity,
				@BankCode					= @BankCode,
				@BankState					= @BankState,
				@Question					= @Question,
				@Answer						= @Answer,
				@CountryID					= @CountryID,
				@IsVIP						= @IsVIP,
				@SiteID						= @SiteID,
				@Wire_BankName				= @Wire_BankName,
				@Wire_BankAddress			= @Wire_BankAddress,
				@Wire_AccountName			= @Wire_AccountName,
				@Wire_AccountNo				= @Wire_AccountNo,
				@Wire_SwiftCode				= @Wire_SwiftCode,
				@AccountHolderName			= @AccountHolderName,	
				@SpecialRemark				= @SpecialRemark,
				@Remark						= @Remark,
				@CreatorID			= @CreatorID,
				@IP					= @IP,
				@ErrCode			= @ErrCode OUTPUT,
				@ErrMsg				= @ErrMsg OUTPUT	
		IF @ErrCode <> 0
		BEGIN
			--SELECT @ErrCode = 101
			RETURN
		END
	END
	IF @IsUpdateUserName = 1
	BEGIN
		EXEC [dbo].[Acc_CRM_GuestUpdUserName]
				@UserID		= @UserID,
				@CustID		= @CustID,	
				@UserName	= @UserName,
				@IP			= @IP,
				@ErrCode	= @ErrCode OUTPUT,
				@ErrMsg		= @ErrMsg OUTPUT
		IF @ErrCode <> 0
		BEGIN
			--SELECT @ErrCode = 103
			RETURN
		END
	END
END



GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_CustomerInfoUpd] TO [bodbAdminNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_CustomerInfoUpd] TO [vnteam]
GO 
