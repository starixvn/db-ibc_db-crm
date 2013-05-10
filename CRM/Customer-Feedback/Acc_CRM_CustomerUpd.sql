ALTER PROCEDURE [dbo].[Acc_CRM_CustomerUpd]
(
	@UserID				INT,
	@CustID				INT,
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
	@CreatorID			INT				= NULL,
	@IP					VARCHAR(15),
	@ErrCode			INT				= 0 OUTPUT,
	@ErrMsg				NVARCHAR(4000)	= '' OUTPUT	
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
	
	UPDATE crmCustomer WITH(ROWLOCK,UPDLOCK)
	SET 
		TitleID				= @TitleID,
		FirstName			= @FirstName,
		LastName			= @LastName,
		Phone				= @Phone,
		MobilePhone			= @MobilePhone,
		Fax					= @Fax,
		Email				= @Email,
		Skype				= @Skype,
		msn					= @MSN,
		Birthday			= @Birthday,
		RefCode1			= @BettingCode,
		RefCode2			= @RefCode2,
		Pic1				= @Pic1,
		Pic2				= @Pic2,
		Pic3				= @Pic3,
		LanguageID			= @LanguageID,
		Question			= @Question,
		Answer				= @Answer,
		CountryID			= @CountryID,
		IsVIP				= @IsVIP,		
		SiteID				= @SiteID,
		Wire_BankName		= @Wire_BankName,
		Wire_BankAddress	= @Wire_BankAddress,
		Wire_SwiftCode		= @Wire_SwiftCode,
		Wire_AccountName	= @Wire_AccountName,
		Wire_AccountNo		= @Wire_AccountNo,
		AccountHolderName	= @AccountHolderName,
		Remark2				= @SpecialRemark,
		Remark				= @Remark,
		CreatorID			= @CreatorID
	WHERE CustID = @CustID
	
	IF @@error <> 0
	BEGIN
		SELECT @ErrCode = 101
		SELECT @ErrMsg = 'Update Customer unsuccessfuly.'
		RETURN
	END

	-- write log
	DECLARE @LogElement XML

	SELECT @LogElement =
					'<Acc_CRM_CustomerUpd>' + --SP Name
						'<FirstName>'		+ ISNULL([dbo].[f_EncodeXMLValue](@FirstName),'')			+ '</FirstName>' +
						'<LastName>'		+ ISNULL([dbo].[f_EncodeXMLValue](@LastName),'')			+ '</LastName>' +
						'<TitleID>'			+ ISNULL(CONVERT(VARCHAR(10),@TitleID),'')					+ '</TitleID>' +
						'<Birthday>'		+ ISNULL(CONVERT(VARCHAR(30),@Birthday),'')					+ '</Birthday>' +
						'<LanguageID>'		+ ISNULL(CONVERT(VARCHAR(10),@LanguageID),'')				+ '</LanguageID>' +
						'<Phone>'			+ ISNULL(@Phone,'')											+ '</Phone>' +
						'<MobilePhone>'		+ ISNULL(@MobilePhone,'')									+ '</MobilePhone>' +
						'<Fax>'				+ ISNULL(@Fax,'')											+ '</Fax>' +
						'<Email>'			+ ISNULL([dbo].[f_EncodeXMLValue](@Email),'')				+ '</Email>' +
						'<Skype>'			+ ISNULL(@Skype,'')											+ '</Skype>' +
						'<MSN>'				+ ISNULL(@MSN,'')											+ '</MSN>' +
						'<BettingCode>'		+ ISNULL(@BettingCode,'')									+ '</BettingCode>' +
						'<RefCode2>'		+ ISNULL(@RefCode2,'')										+ '</RefCode2>' +
						'<Pic1>'			+ ISNULL([dbo].[f_EncodeXMLValue](@Pic1),'')				+ '</Pic1>' +
						'<Pic2>'			+ ISNULL([dbo].[f_EncodeXMLValue](@Pic2),'')				+ '</Pic2>' +
						'<Pic3>'			+ ISNULL([dbo].[f_EncodeXMLValue](@Pic3),'')				+ '</Pic3>' +
						'<Question>'		+ ISNULL([dbo].[f_EncodeXMLValue](@Question),'')			+ '</Question>' +
						'<Answer>'			+ ISNULL([dbo].[f_EncodeXMLValue](@Answer),'')				+ '</Answer>' +
						'<CountryID>'		+ ISNULL(CONVERT(VARCHAR(10),@CountryID),'')				+ '</CountryID>' +
						'<IsVIP>'			+ ISNULL(CONVERT(VARCHAR(1),@IsVIP),'')						+ '</IsVIP>' +
						'<SiteID>'			+ ISNULL(CONVERT(VARCHAR(10),@SiteID),'')					+ '</SiteID>' +
						'<Wire_BankName>'	+ ISNULL([dbo].[f_EncodeXMLValue](@Wire_BankName),'')		+ '</Wire_BankName>' +
						'<Wire_BankAddress>'+ ISNULL([dbo].[f_EncodeXMLValue](@Wire_BankAddress),'')	+ '</Wire_BankAddress>' +
						'<Wire_AccountName>'+ ISNULL(@Wire_AccountName,'')								+ '</Wire_AccountName>' +
						'<Wire_AccountNo>'	+ ISNULL(@Wire_AccountNo,'')								+ '</Wire_AccountNo>' +
						'<Wire_SwiftCode>'	+ ISNULL(@Wire_SwiftCode,'')								+ '</Wire_SwiftCode>' +
						'<AccountHolderName>'	+ ISNULL(@AccountHolderName,'')							+ '</AccountHolderName>' +	
						'<Remark2>'			+ ISNULL([dbo].[f_EncodeXMLValue](@SpecialRemark),'')		+ '</Remark2>' +
						'<Remark>'			+ ISNULL([dbo].[f_EncodeXMLValue](@Remark),'')				+ '</Remark>' +
						'<CreatorID>'		+ ISNULL(CONVERT(VARCHAR(10),@CreatorID),'')				+ '</CreatorID>' +
					'</Acc_CRM_CustomerUpd>'
				

	EXEC [dbo].[WriteLog_UserLog_crmLogCustomer]
					@CustID = @CustID, 
					@UserID = @UserID, 
					@ActionID = 101, 
					@IP = @IP, 
					@Doing = @LogElement
END

GO
GRANT EXECUTE ON [dbo].[Acc_CRM_CustomerUpd] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_CustomerUpd] TO [vnteam]