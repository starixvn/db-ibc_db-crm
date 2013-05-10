ALTER PROCEDURE [dbo].[Acc_CRM_CustomerInfoUpd]
(
	@UserID				INT,
	@CustID				INT,
	@UserName			NVARCHAR(50),
	@IsUpdateUserName	BIT				= 0,
	@FirstName			NVARCHAR(50)	= NULL,
	@LastName			NVARCHAR(50)	= NULL,
	@TitleID			INT				= NULL,
	@Birthday			SMALLDATETIME	= NULL,
	@LanguageID			INT				= NULL,
	@Phone				NVARCHAR(50)	= NULL,
	@MobilePhone		NVARCHAR(50)	= NULL,
	@Fax				NVARCHAR(50)	= NULL,
	@Email				NVARCHAR(254)	= NULL,
	@Skype				NVARCHAR(100)	= NULL,
	@MSN				NVARCHAR(100)	= NULL,
	@BettingCode		NVARCHAR(50)	= NULL,
	@RefCode2			NVARCHAR(50)	= NULL,
	@Pic1				NVARCHAR(100)	= NULL,
	@Pic2				NVARCHAR(100)	= NULL,
	@Pic3				NVARCHAR(100)	= NULL,
	@Question			NVARCHAR(300)	= NULL,
	@Answer				NVARCHAR(300)	= NULL,
	@CountryID			INT				= NULL,
	@IsVIP				BIT				= NULL,	
	@SiteID				INT				= NULL,
	@Wire_BankName		NVARCHAR(100)	= NULL,
	@Wire_BankAddress	NVARCHAR(200)	= NULL,
	@Wire_AccountName	NVARCHAR(100)	= NULL,
	@Wire_AccountNo		NVARCHAR(50)	= NULL,
	@Wire_SwiftCode		NVARCHAR(50)	= NULL,
	@AccountHolderName	NVARCHAR(100)	= NULL,
	@SpecialRemark		NVARCHAR(1000)	= NULL,
	@Remark				NVARCHAR(1000)	= NULL,	
	@CreatorID			INT,
	@IP					VARCHAR(15),
	@ErrCode			INT				= 0 OUTPUT,
	@ErrMsg				NVARCHAR(4000)	= '' OUTPUT	
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
	Param's Explanation:
	
*/
BEGIN	
	SET NOCOUNT ON

	SELECT	@ErrCode	= 0,
			@ErrMsg		= ''

	--Check permission
	EXEC DBPOLICY.bodb02.dbo.Acc_Con_CheckPermission @custid=@UserID,@funcname='[CustomerInfo]',@ErrCode=@ErrCode OUTPUT,@ErrMsg=@ErrMsg OUTPUT
	IF @ErrCode <> 0
		RETURN

	IF NOT EXISTS (SELECT 1 FROM crmCustomer WITH(NOLOCK) WHERE CustID = @CustID)
	BEGIN
		--- create new customer
		EXEC [dbo].[Acc_CRM_CustomerIns]
				@UserID				= @UserID, 
				@CustID				= @CustID,
				@UserName			= @UserName,
				@FirstName			= @FirstName,
				@LastName			= @LastName,
				@TitleID			= @TitleID,
				@Birthday			= @Birthday,
				@LanguageID			= @LanguageID,
				@Phone				= @Phone,
				@MobilePhone		= @MobilePhone,
				@Fax				= @Fax,
				@Email				= @Email,
				@Skype				= @Skype,
				@MSN				= @MSN,
				@BettingCode		= @BettingCode,
				@RefCode2			= @RefCode2,
				@Pic1				= @Pic1,
				@Pic2				= @Pic2,
				@Pic3				= @Pic3,
				@Question			= @Question,
				@Answer				= @Answer,
				@CountryID			= @CountryID,
				@IsVIP				= @IsVIP,			
				@SiteID				= @SiteID,
				@Wire_BankName		= @Wire_BankName,
				@Wire_BankAddress	= @Wire_BankAddress,
				@Wire_AccountName	= @Wire_AccountName,
				@Wire_AccountNo		= @Wire_AccountNo,
				@Wire_SwiftCode		= @Wire_SwiftCode,
				@AccountHolderName	= @AccountHolderName,
				@SpecialRemark		= @SpecialRemark,
				@Remark				= @Remark,					
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
				@UserID				= @UserID,
				@CustID				= @CustID,
				@FirstName			= @FirstName,
				@LastName			= @LastName,
				@TitleID			= @TitleID,
				@Birthday			= @Birthday,
				@LanguageID			= @LanguageID,
				@Phone				= @Phone,
				@MobilePhone		= @MobilePhone,
				@Fax				= @Fax,
				@Email				= @Email,
				@Skype				= @Skype,
				@MSN				= @MSN,
				@BettingCode		= @BettingCode,
				@RefCode2			= @RefCode2,
				@Pic1				= @Pic1,
				@Pic2				= @Pic2,
				@Pic3				= @Pic3,
				@Question			= @Question,
				@Answer				= @Answer,
				@CountryID			= @CountryID,
				@IsVIP				= @IsVIP,
				@SiteID				= @SiteID,
				@Wire_BankName		= @Wire_BankName,
				@Wire_BankAddress	= @Wire_BankAddress,
				@Wire_AccountName	= @Wire_AccountName,
				@Wire_AccountNo		= @Wire_AccountNo,
				@Wire_SwiftCode		= @Wire_SwiftCode,
				@AccountHolderName	= @AccountHolderName,
				@SpecialRemark		= @SpecialRemark,
				@Remark				= @Remark,
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
GRANT EXECUTE ON [dbo].[Acc_CRM_CustomerInfoUpd] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_CustomerInfoUpd] TO [vnteam] 