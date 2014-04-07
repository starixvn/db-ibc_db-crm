ALTER PROCEDURE [dbo].[Acc_CRM_CustomerIns]
(
	@UserID				INT,
	@CustID				INT,
	@UserName			NVARCHAR(50),
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
Date: 20101022
Task : update customer info
DB: DB052.bodb_CRM
Original:

Revisions:
	- 20110704@Lukas: add two more params @msn, @skype
	- 20120327@Elodie: change data type of @Skype, @MSN, @Pic1, @Pic2, @Pic3 params to NVARCHAR(500)
					   change DB06 to DB052
	- 20120404@Elodie: change data type of @Skype, @MSN, @Pic1, @Pic2, @Pic3 params to NVARCHAR(100)
	- 20120529@Elodie: encode some parameters to write log in XML format, such as Question, Answer, Pic1, ...
	- 20140303@Dom: Modify for new structure
Param's Explanation:
	
*/
BEGIN	
	SET NOCOUNT ON

	SELECT	@ErrCode	= 0,
			@ErrMsg		= ''

	IF EXISTS (SELECT 1 FROM crmCustomer WITH(NOLOCK) WHERE CustID = @CustID)
	BEGIN
		SELECT @ErrCode = 100
		SELECT @ErrMsg = 'Customer existed already.'
		RETURN
	END
	
	IF NOT EXISTS (SELECT 1 FROM bodb02.dbo.custinfo WITH(NOLOCK) WHERE CustID = @CustID)
	BEGIN
		SELECT @ErrCode = 101
		SELECT @ErrMsg = 'Customer does not exist in IBC system.'
		RETURN
	END
		
	INSERT INTO crmCustomer
				(	
					CustID, 
					UserName, 
					TitleID, 
					FirstName, 
					LastName, 
					Phone, 
					MobilePhone, 
					Fax, 
					Email, 
					Skype,
					msn,
					Birthday,
					RefCode1, 
					RefCode2, 
					Pic1, 
					Pic2, 
					Pic3, 
					LanguageID, 
					Question, 
					Answer, 
					CountryID, 
					IsVIP,
					SiteID, 
					Wire_BankName, 
					Wire_BankAddress, 
					Wire_SwiftCode, 
					Wire_AccountName,
					Wire_AccountNo, 
					AccountHolderName,
					Remark2,
					Remark, 
					CreateDate, 
					CreatorID
				)
			VALUES
				( 
					@CustID, 
					@UserName, 
					@TitleID, 
					@FirstName, 
					@LastName, 
					@Phone, 
					@MobilePhone, 
					@Fax, 
					@Email, 
					@Skype,
					@MSN,
					@Birthday,
					@BettingCode, 
					@RefCode2, 
					@Pic1, 
					@Pic2, 
					@Pic3, 
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
					GETDATE(), 
					@CreatorID
				)
	
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrCode = 102
		SELECT @ErrMsg = 'create new customer unsuccessfuly.'
		RETURN
	END

	-- write log
	DECLARE @LogElement XML

	SELECT @LogElement = 				
					'<Acc_CRM_CustomerIns>' + --SP Name
						'<UserName>'		+ ISNULL(@UserName,'')										+ '</UserName>' +
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
						'<BankName>'	+ ISNULL([dbo].[f_EncodeXMLValue](@Wire_BankName),'')			+ '</BankName>' +
						'<BankAddress>'+ ISNULL([dbo].[f_EncodeXMLValue](@Wire_BankAddress),'')			+ '</BankAddress>' +
						'<AccountName>'+ ISNULL(@Wire_AccountName,'')									+ '</AccountName>' +
						'<AccountNo>'	+ ISNULL(@Wire_AccountNo,'')									+ '</AccountNo>' +
						'<SwiftCode>'	+ ISNULL(@Wire_SwiftCode,'')									+ '</SwiftCode>' +
						'<AccountHolderName>'	+ ISNULL(@AccountHolderName,'')							+ '</AccountHolderName>' +	
						'<Remark2>'			+ ISNULL([dbo].[f_EncodeXMLValue](@SpecialRemark),'')		+ '</Remark2>' +
						'<Remark>'			+ ISNULL([dbo].[f_EncodeXMLValue](@Remark),'')				+ '</Remark>' +
						'<CreatorID>'		+ ISNULL(CONVERT(VARCHAR(10),@CreatorID),'')				+ '</CreatorID>' +
					'</Acc_CRM_CustomerIns>' 
				

	EXEC [dbo].[WriteLog_UserLog_crmLogCustomer]
					@CustID = @CustID, 
					@UserID = @UserID, 
					@ActionID = 100, 
					@IP = @IP, 
					@NewValues = @LogElement
END


GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_CustomerIns] TO [bodbAdminNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_CustomerIns] TO [vnteam]
GO 
