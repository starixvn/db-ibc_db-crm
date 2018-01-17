/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet,vnteam" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE	dbo.Acc_CRM_GuestFeedbackIns (
					@UserID						INT
				,	@UserName					NVARCHAR(50)
				,	@FirstName					NVARCHAR(50)	= NULL
				,	@LastName					NVARCHAR(50)	= NULL
				,	@TitleID					INT				= NULL
				,	@Birthday					SMALLDATETIME	= NULL
				,	@LanguageID					INT				= NULL
				,	@Phone						NVARCHAR(50)	= NULL
				,	@PhoneCountryCode			NVARCHAR(20)	= NULL
				,	@PhoneAreaCode				NVARCHAR(20)	= NULL
				,	@Phone2						NVARCHAR(50)	= NULL
				,	@Phone2CountryCode			NVARCHAR(20)	= NULL
				,	@Phone2AreaCode				NVARCHAR(20)	= NULL
				,	@Phone3						NVARCHAR(50)	= NULL
				,	@Phone3CountryCode			NVARCHAR(20)	= NULL
				,	@Phone3AreaCode				NVARCHAR(20)	= NULL
				,	@Passport					NVARCHAR(100)	= NULL
				,	@MobilePhone				NVARCHAR(50)	= NULL
				,	@MobilePhoneCountryCode		NVARCHAR(20)	= NULL
				,	@MobilePhoneAreaCode		NVARCHAR(20)	= NULL
				,	@Fax						NVARCHAR(50)	= NULL
				,	@FaxCountryCode				NVARCHAR(20)	= NULL
				,	@FaxAreaCode				NVARCHAR(20)	= NULL
				,	@Email						NVARCHAR(254)	= NULL
				,	@Skype						NVARCHAR(100)	= NULL
				,	@MSN						NVARCHAR(100)	= NULL
				,	@BettingCode				NVARCHAR(50)	= NULL
				,	@RefCode2					NVARCHAR(50)	= NULL
				,	@Pic1						NVARCHAR(100)	= NULL
				,	@Pic2						NVARCHAR(100)	= NULL
				,	@Pic3						NVARCHAR(100)	= NULL
				,	@Pic4						NVARCHAR(100)	= NULL
				,	@Pic1Name					NVARCHAR(100)	= NULL
				,	@Pic2Name					NVARCHAR(100)	= NULL
				,	@Pic3Name					NVARCHAR(100)	= NULL
				,	@Pic4Name					NVARCHAR(100)	= NULL
				,	@Line1						NVARCHAR(100)	= NULL
				,	@Line2						NVARCHAR(100)	= NULL
				,	@Line3						NVARCHAR(100)	= NULL
				,	@City						NVARCHAR(200)	= NULL
				,	@PostCode					NVARCHAR(100)	= NULL
				,	@State						NVARCHAR(100)	= NULL
				,	@BankLine1					NVARCHAR(100)	= NULL
				,	@BankLine2					NVARCHAR(100)	= NULL
				,	@BankLine3					NVARCHAR(100)	= NULL
				,	@BankCity					NVARCHAR(100)	= NULL
				,	@BankCode					NVARCHAR(100)	= NULL
				,	@BankCountryID				INT				= NULL
				,	@BankState					NVARCHAR(100)	= NULL
				,	@Question					NVARCHAR(300)	= NULL
				,	@Answer						NVARCHAR(300)	= NULL
				,	@CountryID					INT
				,	@IsVip						BIT				= NULL
				,	@SiteID						INT				= 0
				,	@Wire_BankName				NVARCHAR(100)	= NULL
				,	@Wire_BankAddress			NVARCHAR(200)	= NULL
				,	@Wire_AccountName			NVARCHAR(100)	= NULL
				,	@Wire_AccountNo				NVARCHAR(50)	= NULL
				,	@Wire_SwiftCode				NVARCHAR(50)	= NULL
				,	@AccountHolderName			NVARCHAR(100)	= NULL
				,	@SpecialRemark				XML				= NULL
				,	@Remark						XML				= NULL
				,	@IsVerifyEmail				BIT				= 0
				,	@IsVerifyPassport			BIT				= 0
				,	@IsVerifyBirthday			BIT				= 0
				,	@IsVerifySecretCode			BIT				= 0
				,	@IsVerifyBetCredit			BIT				= 0
				,	@IsVerifyGivenCredit		BIT				= 0
				,	@Subject					NVARCHAR(200)	= NULL
				,	@CreatorID					INT
				,	@FeedbackDate				DATETIME		= NULL
				,	@ResolutionDate				DATETIME
				,	@CommunicationID			INT
				,	@StationID					INT
				,	@MainCategoryID				INT
				,	@SubCategoryID				INT
				,	@RoleID						INT				= 7004
				,	@ProductID					INT
				,	@SubProductID				INT
				,	@BettypeID					INT
				,	@ResponseID					INT
				,	@StatusID					INT
				,	@RelatedCustID				NVARCHAR(500)	= NULL
				,	@Description				NVARCHAR(MAX)
				,	@AutoField					NVARCHAR(MAX)	= NULL
				,	@Solution					NVARCHAR(MAX)	= ''
				,	@IsReviewed					BIT
				,	@Review						NVARCHAR(MAX)	= ''
				,	@ReviewerID					INT				= NULL
				,	@LicenseeType				INT				= 0
				,	@WhatsApp					NVARCHAR(100)	= NULL
				,	@Line						NVARCHAR(100)	= NULL
				,	@WeChat						NVARCHAR(100)	= NULL
				,	@Yahoo						NVARCHAR(100)	= NULL
				,	@QQ							NVARCHAR(100)	= NULL
				,	@BBM						NVARCHAR(100)	= NULL
				,	@IP							VARCHAR(15)
				,	@ErrCode					INT				= 0 OUTPUT
				,	@ErrMsg						NVARCHAR(4000)	= '' OUTPUT
				)
AS
/*
	Created:	Lukas
	Date:		20101113
	Task :		insert Guest's feedback
	DB:			DB052.bodb_CRM
	Original:

	Revisions:
		- 20110628@Kevin:	not update @RelatedCustID on [Acc_CRM_CustomerGuestIns] when insert a guest feedback
		- 20110629@Lukas:	support multiple feedback related customer
		- 20120307@Elodie:	add 3 params @Pic1, @Pic3, @Pic3
		- 20120319@Elodie:	change DB06 to DB052
		- 20120327@Elodie:	change data type of @Pic1, @Pic2, @Pic3 params to NVARCHAR(100)
							change DB06 to DB052
		- 20120418@Elodie:	change default value of @RelatedCustID param to NULL value
		- 20130121@Johnson:	change linked server DB03 to DBPOLICY
		- 20140224@Johnson:	change linked server DB03 to DBPOLICY
		- 20140303@Dom:		Modify for new structure
		- 20141118@Dom:		add more fields of communication tool
		- 20150121@Dom:		Remove Sync code for Old system
		- 20160308@Billy:	Integrate Sub-Product field - [Redmine: #52998]	 
		- 20180117@Winnie:	Add Is Related Customer - [Redmine: #88774]
	Param's Explanation:
		
*/
BEGIN	
	SET NOCOUNT ON;

	DECLARE @CustID INT;
	
	SELECT	@ErrCode = 0
		,	@ErrMsg	 = '';
	--- create account for guest
	EXECUTE	dbo.Acc_CRM_CustomerGuestIns
				@UserID						= @UserID
			,	@CustID						= @CustID					OUTPUT
			,	@UserName					= @UserName
			,	@FirstName					= @FirstName
			,	@LastName					= @LastName
			,	@TitleID					= @TitleID
			,	@Birthday					= @Birthday
			,	@LanguageID					= @LanguageID
			,	@Phone						= @Phone
			,	@PhoneCountryCode			= @PhoneCountryCode
			,	@PhoneAreaCode				= @PhoneAreaCode
			,	@Phone2						= @Phone2
			,	@Phone2CountryCode			= @Phone2CountryCode
			,	@Phone2AreaCode				= @Phone2AreaCode
			,	@Phone3						= @Phone3
			,	@Phone3CountryCode			= @Phone3CountryCode
			,	@Phone3AreaCode				= @Phone3AreaCode
			,	@Passport					= @Passport
			,	@MobilePhone				= @MobilePhone
			,	@MobilePhoneCountryCode		= @MobilePhoneCountryCode
			,	@MobilePhoneAreaCode		= @MobilePhoneAreaCode
			,	@Fax						= @Fax
			,	@FaxCountryCode				= @FaxCountryCode
			,	@FaxAreaCode				= @FaxAreaCode
			,	@Email						= @Email
			,	@Skype						= @Skype
			,	@MSN						= @MSN
			,	@BettingCode				= @BettingCode
			,	@RefCode2					= @RefCode2
			,	@Pic1						= @Pic1
			,	@Pic2						= @Pic2
			,	@Pic3						= @Pic3
			,	@Pic4						= @Pic4
			,	@Pic1name					= @Pic1Name
			,	@Pic2name					= @Pic2Name
			,	@Pic3name					= @Pic3Name
			,	@Pic4name					= @Pic4Name
			,	@Line1						= @Line1
			,	@Line2						= @Line2
			,	@Line3						= @Line3
			,	@City						= @City
			,	@PostCode					= @PostCode
			,	@State						= @State
			,	@BankLine1					= @BankLine1
			,	@BankLine2					= @BankLine2
			,	@BankLine3					= @BankLine3
			,	@BankCity					= @BankCity
			,	@BankCode					= @BankCode
			,	@BankCountryID				= @BankCountryID
			,	@BankState					= @BankState
			,	@Question					= @Question
			,	@Answer						= @Answer
			,	@CountryID					= @CountryID
			,	@IsVIP						= @IsVIP
			,	@SiteID						= @SiteID
			,	@Wire_BankName				= @Wire_BankName
			,	@Wire_BankAddress			= @Wire_BankAddress
			,	@Wire_AccountName			= @Wire_AccountName
			,	@Wire_AccountNo				= @Wire_AccountNo
			,	@Wire_SwiftCode				= @Wire_SwiftCode
			,	@AccountHolderName			= @AccountHolderName
			,	@SpecialRemark				= @SpecialRemark
			,	@Remark						= @Remark
			,	@IsVerifyEmail				= @IsVerifyEmail
			,	@IsVerifyPassport			= @IsVerifyPassport
			,	@IsVerifyBirthday			= @IsVerifyBirthday
			,	@IsVerifySecretCode			= @IsVerifySecretCode
			,	@IsVerifyBetCredit			= @IsVerifyBetCredit
			,	@IsVerifyGivenCredit		= @IsVerifyGivenCredit
			,	@CreatorID					= @CreatorID
			,	@LicenseeType				= @LicenseeType
			,	@WhatsApp					= @WhatsApp
			,	@Line						= @Line
			,	@WeChat						= @WeChat
			,	@Yahoo						= @Yahoo
			,	@QQ							= @QQ
			,	@BBM						= @BBM
			,	@IP							= @IP
			,	@ErrCode					= @ErrCode					OUTPUT
			,	@ErrMsg						= @ErrMsg					OUTPUT;					

	IF	@ErrCode <> 0
	BEGIN
		SELECT	@ErrCode = 100;

		RETURN;
	END;
	
	--------Update language for Old System------
	/*IF(EXISTS(SELECT TOP 1 1 FROM dbo.strSplit(@LanguageID,',') WHERE SettingID = 12000))
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
	END*/
		
	--- insert feedback of guest
	EXECUTE	dbo.Acc_CRM_FeedbackIns
				@UserID					= @UserID
			,	@CustID					= @CustID
			,	@UserName				= @UserName
			,	@TitleID				= @TitleID
			,	@Birthday				= @Birthday
			,	@FirstName				= @FirstName
			,	@LastName				= @LastName
			,	@Phone					= @Phone
			,	@PhoneCountryCode		= @PhoneCountryCode
			,	@PhoneAreaCode			= @PhoneAreaCode
			,	@Phone2					= @Phone2
			,	@Phone2CountryCode		= @Phone2CountryCode
			,	@Phone2AreaCode			= @Phone2AreaCode
			,	@Phone3					= @Phone3
			,	@Phone3CountryCode		= @Phone3CountryCode
			,	@Phone3AreaCode			= @Phone3AreaCode
			,	@MobilePhone			= @MobilePhone
			,	@MobilePhoneCountryCode	= @MobilePhoneCountryCode
			,	@MobilePhoneAreaCode	= @MobilePhoneAreaCode
			,	@Fax					= @Fax
			,	@FaxCountryCode			= @FaxCountryCode
			,	@FaxAreaCode			= @FaxAreaCode
			,	@Email					= @Email
			,	@Skype					= @Skype
			,	@MSN					= @MSN
			,	@CountryID				= @CountryID
			,	@Pic1					= @Pic1
			,	@Pic2					= @Pic2
			,	@Pic3					= @Pic3
			,	@Pic4					= @Pic4
			,	@Pic1Name				= @Pic1Name
			,	@Pic2Name				= @Pic2Name
			,	@Pic3Name				= @Pic3Name
			,	@Pic4Name				= @Pic4Name
			,	@Passport				= @Passport
			,	@BettingCode			= @BettingCode
			,	@RefCode2				= @RefCode2
			,	@IsVip					= @IsVip
			,	@SiteID					= @SiteID
			,	@LanguageID				= @LanguageID
			,	@CreatorID				= @CreatorID
			,	@Subject				= @Subject
			,	@FeedbackDate			= @FeedbackDate
			,	@ResolutionDate			= @ResolutionDate
			,	@CommunicationID		= @CommunicationID
			,	@StationID				= @StationID
			,	@MainCategoryID			= @MainCategoryID
			,	@SubCategoryID			= @SubCategoryID
			,	@RoleID					= @RoleID
			,	@ProductID				= @ProductID
			,	@SubProductID			= @SubProductID
			,	@BettypeID				= @BettypeID
			,	@ResponseID				= @ResponseID
			,	@StatusID				= @StatusID
			,	@RelatedCustID			= @RelatedCustID
			,	@Description			= @Description
			,	@AutoField				= @AutoField
			,	@Solution				= @Solution
			,	@IsReviewed				= @IsReviewed
			,	@Review					= @Review
			,	@ReviewerID				= @ReviewerID
			,	@LicenseeType			= @LicenseeType
			,	@WhatsApp				= @WhatsApp
			,	@Line					= @Line
			,	@WeChat					= @WeChat
			,	@Yahoo					= @Yahoo
			,	@QQ						= @QQ
			,	@BBM					= @BBM
			,	@IP						= @IP
			,	@ErrCode				= @ErrCode				OUTPUT
			,	@ErrMsg					= @ErrMsg				OUTPUT;
					  
	IF	@ErrCode <> 0
	BEGIN
		SELECT	@ErrCode = 101;

		RETURN;
	END;

END;
GO 
