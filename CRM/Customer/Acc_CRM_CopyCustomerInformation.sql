/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
/****** Object:  Stored Procedure dbo.Acc_CRM_CopyCustomerInformation    Script Date: 3/26/2014 6:06:04 PM ******/
CREATE PROCEDURE Acc_CRM_CopyCustomerInformation
	@CustID				INT,
	@UserID				INT,
	@IP					VARCHAR(15),
	@ErrCode			INT				= 0 OUTPUT,
	@ErrMsg				NVARCHAR(4000)	= '' OUTPUT

AS
/*
Created: Dom
Date: 20140212
Task : Copy Basic customer info from IBC to CRM
DB: DBCRM.bodb_CRM
Original:

Revisions:	
	- 20190711@Winnie: CRM - Enhance Inform Headline RedmineID:##109775
Param's Explanation:	
*/

DECLARE @FirstName		nvarchar(100),
			@LastName		nvarchar(100),
			@UserName		varchar(30),
			@Phone			nvarchar(100),
			@Fax			nvarchar(100),
			@MobilePhone	nvarchar(100),
			@Email			nvarchar(100),
			@Address		nvarchar(80),
			@City			nvarchar(50),
			@PostCode		nvarchar(50),
			@State			nvarchar(50),
			@CountryID		int,
			@Birthday		datetime,
			@RefCode1		nvarchar(100),
			@RefCode2		nvarchar(100)
				
SELECT @FirstName		= firstname,
		@LastName		= lastname,
		@UserName		= username,
		@Phone			= Phone,
		@Fax			= fax,
		@MobilePhone	= mobilephone,
		@Email			= email,
		@Address		= address,
		@City			= city,
		@PostCode		= postal,
		@State			= state,
		@CountryID		= ct.CountryID,
		@Birthday		= c.birthday,
		@RefCode1		= c.RefCode1,
		@RefCode2		= c.refcode2
FROM bodb02.dbo.Customer(NOLOCK) c
LEFT JOIN crmCountry(NOLOCK) ct ON ct.CountryName = c.country
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
			@PhoneCountryCode				= NULL,
			@PhoneAreaCode					= NULL,
			@Phone2							= NULL,
			@Phone2CountryCode				= NULL,
			@Phone2AreaCode					= NULL,
			@Phone3							= NULL,
			@Phone3CountryCode				= NULL,
			@Phone3AreaCode					= NULL,
			@Passport						= NULL,
			@MobilePhone					= @MobilePhone,
			@MobilePhoneCountryCode			= NULL,
			@MobilePhoneAreaCode			= NULL,
			@Fax							= @Fax,
			@FaxCountryCode					= NULL,
			@FaxAreaCode					= NULL,
			@Email							= @Email,
			@Skype							= NULL,
			@MSN							= NULL,
			@BettingCode					= @RefCode1,
			@RefCode2						= @RefCode2,
			@Pic1							= NULL,
			@Pic2							= NULL,
			@Pic3							= NULL,
			@Pic4							= NULL,
			@Line1							= NULL,
			@Line2							= NULL,
			@Line3							= NULL,
			@City							= @City,
			@PostCode						= @PostCode,
			@State							= @State,
			@BankLine1						= NULL,
			@BankLine2						= NULL,
			@BankLine3						= NULL,
			@BankCity						= NULL,
			@BankCode						= NULL,
			@BankCountryID					= NULL,
			@BankState						= NULL,
			@Question						= NULL,
			@Answer							= NULL,
			@CountryID						= @CountryID,
			@IsVIP							= 0,
			@SiteID							= NULL,
			@Wire_BankName					= NULL,
			@Wire_BankAddress				= NULL,
			@Wire_AccountName				= NULL,
			@Wire_AccountNo					= NULL,
			@Wire_SwiftCode					= NULL,
			@AccountHolderName				= NULL,
			@SpecialRemark					= NULL,	
			@Remark							= NULL,	
			@IsVerifyEmail					= 0,
			@IsVerifyPassport				= 0,
			@IsVerifyBirthday				= 0,
			@IsVerifySecretCode				= 0,
			@IsVerifyBetCredit				= 0,
			@IsVerifyGivenCredit			= 0,
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


GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_CopyCustomerInformation] TO [bodbAdminNet]
GO 
