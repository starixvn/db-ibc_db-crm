
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.Acc_CRM_CustomerShortUpd    Script Date: 3/26/2014 6:06:06 PM ******/
CREATE PROCEDURE [dbo].[Acc_CRM_CustomerShortUpd]
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
Task : update feedback info
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
