SET QUOTED_IDENTIFIER ON; 
GO
SET ANSI_NULLS ON; 
GO

ALTER PROCEDURE	dbo.Acc_CRM_CommunicationLogIns
					@CustID				INT
				,	@RelatedCustID		VARCHAR(500)	= NULL
				,	@LanguageID			INT
				,	@CountryID			INT
				,	@FeedbackDate		DATETIME
				,	@ResolutionDate		DATETIME
				,	@CommunicationID	INT
				,	@StationID			INT
				,	@MainCategoryID		INT 
				,	@SubCategoryID		INT
				,	@SiteID				INT
				,	@RoleID				INT
				,	@ProductID			INT
				,	@SubProductID		INT
				,	@BetTypeID			INT
				,	@ResponseID			INT
				,	@StatusID			INT
				,	@Description		NVARCHAR(MAX)
				,	@Solution			NVARCHAR(MAX)
				,	@Subject			NVARCHAR(200)
				,	@LicenseeType		INT				= 0
				,	@UserID				INT
				,	@IP					VARCHAR(15)
				,	@ErrCode			INT				= 0		OUTPUT
				,	@ErrMsg				NVARCHAR(4000)	= ''	OUTPUT
AS
/*
	Created:	20140121@Dom
	Task :		Insert new customer log
	DB:			DBCRM.bodb_CRM
	Original:

	Revisions:
		- 20141118@Dom:		add more fields of communication tool
		- 20160308@Billy:	Integrate Sub-Product field - [Redmine: #52998]

	Param's Explanation:
*/
BEGIN
	IF	ISNULL(@CommunicationID, 0) = 0 
	OR	ISNULL(@MainCategoryID, 0) = 0 
	OR	ISNULL(@SubCategoryID, 0) = 0 
	OR	ISNULL(@StatusID, 0) = 0 
	OR	ISNULL(@LanguageID, 0) = 0
	OR	ISNULL(@RoleID, 0) = 0
	OR	ISNULL(@ResponseID, 0) = 0
	OR	ISNULL(@StationID, 0) = 0
	BEGIN
		SELECT	@ErrCode = 100
			,	@ErrMsg = 'Incorrect Data.';

		RETURN;
	END;

	IF	NOT EXISTS(SELECT 1 FROM crmCustomer(NOLOCK) WHERE CustID = @CustID)
	BEGIN
		EXECUTE	Acc_CRM_CopyCustomerInformation
					@CustID		= @CustID
				,	@UserID		= @UserID
				,	@IP			= @IP
				,	@ErrCode	= @ErrCode		OUTPUT
				,	@ErrMsg		= @ErrMsg		OUTPUT;

		IF	@ErrCode <> 0
			RETURN;
	END;

	DECLARE	@FeedbackID INT;

	DECLARE	@TitleID				INT
		,	@FirstName				NVARCHAR(100)
		,	@LastName				NVARCHAR(100)
		,	@Phone					NVARCHAR(100)
		,	@PhoneCountryCode		NVARCHAR(20)
		,	@PhoneAreaCode			NVARCHAR(20)
		,	@Phone2					NVARCHAR(100)
		,	@Phone2CountryCode		NVARCHAR(20)
		,	@Phone2AreaCode			NVARCHAR(20)
		,	@Phone3					NVARCHAR(100)
		,	@Phone3CountryCode		NVARCHAR(20)
		,	@Phone3AreaCode			NVARCHAR(20)
		,	@MobilePhone			NVARCHAR(100)
		,	@MobilePhoneCountryCode	NVARCHAR(20)
		,	@MobilePhoneAreaCode	NVARCHAR(20)
		,	@Fax					NVARCHAR(100)
		,	@FaxCountryCode			NVARCHAR(20)
		,	@FaxAreaCode			NVARCHAR(20)
		,	@Email					NVARCHAR(508)
		,	@Skype					NVARCHAR(200)
		,	@MSN					NVARCHAR(200)
		,	@Pic1					NVARCHAR(200)
		,	@Pic2					NVARCHAR(200)
		,	@Pic3					NVARCHAR(200)
		,	@Pic4					NVARCHAR(200)
		,	@Passport				NVARCHAR(200)
		,	@Birthday				SMALLDATETIME
		,	@BettingCode			NVARCHAR(100)
		,	@RefCode2				NVARCHAR(100)
		,	@IsVip					BIT
		,	@Line1					NVARCHAR(200)
		,	@Line2					NVARCHAR(200)
		,	@Line3					NVARCHAR(200)
		,	@City					NVARCHAR(200)
		,	@Postcode				NVARCHAR(200)
		,	@State					NVARCHAR(200)
		,	@BankLine1				NVARCHAR(200)
		,	@BankLine2				NVARCHAR(200)
		,	@BankLine3				NVARCHAR(200)
		,	@BankCity				NVARCHAR(200)
		,	@BankCode				NVARCHAR(200)
		,	@BankState				NVARCHAR(200)
		,	@WhatsApp				NVARCHAR(100)	= NULL
		,	@Line					NVARCHAR(100)	= NULL
		,	@WeChat					NVARCHAR(100)	= NULL
		,	@Yahoo					NVARCHAR(100)	= NULL
		,	@QQ						NVARCHAR(100)	= NULL
		,	@BBM					NVARCHAR(100)	= NULL;
	
	SELECT	@TitleID				= TitleID
		,	@FirstName				= FirstName
		,	@LastName				= LastName
		,	@Phone					= Phone
		,	@PhoneCountryCode		= PhoneCountryCode
		,	@PhoneAreaCode			= PhoneAreaCode
		,	@Phone2					= Phone2
		,	@Phone2CountryCode		= Phone2CountryCode
		,	@Phone2AreaCode			= Phone2AreaCode
		,	@Phone3					= Phone3
		,	@Phone3CountryCode		= Phone3CountryCode
		,	@Phone3AreaCode			= Phone3AreaCode
		,	@MobilePhone			= MobilePhone
		,	@MobilePhoneCountryCode	= MobilePhoneCountryCode
		,	@MobilePhoneAreaCode	= MobilePhoneAreaCode
		,	@Fax					= Fax
		,	@FaxCountryCode			= FaxCountryCode
		,	@FaxAreaCode			= FaxAreaCode
		,	@Email					= Email
		,	@Skype					= Skype
		,	@MSN					= MSN
		,	@Pic1					= Pic1
		,	@Pic2					= Pic2
		,	@Pic3					= Pic3
		,	@Pic4					= Pic4
		,	@Passport				= Passport
		,	@Birthday				= Birthday
		,	@BettingCode			= RefCode1
		,	@RefCode2				= RefCode2
		,	@IsVip					= IsVip
		,	@Line1					= Line1
		,	@Line2					= Line2
		,	@Line3					= Line3
		,	@City					= City
		,	@Postcode				= PostCode
		,	@State					= State
		,	@BankLine1				= BankLine1
		,	@BankLine2				= BankLine2
		,	@BankLine3				= BankLine3
		,	@BankCity				= BankCity
		,	@BankCode				= BankCode
		,	@BankState				= BankState
		,	@WhatsApp				= WhatsApp
		,	@Line					= Line
		,	@WeChat					= WeChat
		,	@Yahoo					= Yahoo
		,	@QQ						= QQ
		,	@BBM					= BBM
	FROM	crmCustomer WITH (NOLOCK)
	WHERE	CustID = @CustID;

	INSERT INTO	crmFeedback	(
					CustID
				,	TitleID
				,	FirstName
				,	LastName
				,	Phone
				,	MobilePhone
				,	Fax
				,	Email
				,	LanguageID
				,	CountryID
				,	CreateDate
				,	CreatorID
				,	FeedbackDate
				,	ResolutionDate
				,	CommunicationID
				,	StationID
				,	MainCategoryID
				,	SubCategoryID
				,	SiteID
				,	RoleID
				,	ProductID
				,	SubProductID
				,	BetTypeID
				,	ResponseID
				,	StatusID
				,	Description
				,	Solution
				,	Subject--
				,	Skype
				,	MSN
				,	Pic1
				,	Pic2
				,	Pic3
				,	PhoneCountryCode
				,	PhoneAreaCode
				,	Phone2
				,	Phone2CountryCode
				,	Phone2AreaCode
				,	Phone3
				,	Phone3CountryCode
				,	Phone3AreaCode
				,	MobilePhoneCountryCode
				,	MobilePhoneAreaCode
				,	FaxCountryCode
				,	FaxAreaCode
				,	Pic4
				,	Passport
				,	RefCode1
				,	RefCode2
				,	Birthday
				,	IsVip
				,	Line1
				,	Line2
				,	Line3
				,	City
				,	Postcode
				,	State
				,	BankLine1
				,	BankLine2
				,	BankLine3
				,	BankCity
				,	BankCode
				,	BankState
				,	LicenseeType			
				,	WhatsApp		
				,	Line			
				,	WeChat			
				,	Yahoo			
				,	QQ				
				,	BBM
				)			
    SELECT	@CustID
		,	@TitleID
		,	@FirstName
		,	@LastName
		,	@Phone
		,	@MobilePhone
		,	@Fax
		,	@Email
		,	@LanguageID
		,	@CountryID
		,	GETDATE()
		,	@UserID
		,	@FeedbackDate
		,	@ResolutionDate
		,	@CommunicationID
		,	@StationID
		,	@MainCategoryID
		,	@SubCategoryID
		,	@SiteID
		,	@RoleID
		,	@ProductID
		,	@SubProductID
		,	@BetTypeID
		,	@ResponseID
		,	@StatusID
		,	@Description
		,	@Solution
		,	@Subject
		,	@Skype
		,	@MSN
		,	@Pic1
		,	@Pic2
		,	@Pic3
		,	@PhoneCountryCode
		,	@PhoneAreaCode
		,	@Phone2
		,	@Phone2CountryCode
		,	@Phone2AreaCode
		,	@Phone3
		,	@Phone3CountryCode
		,	@Phone3AreaCode
		,	@MobilePhoneCountryCode
		,	@MobilePhoneAreaCode
		,	@FaxCountryCode
		,	@FaxAreaCode
		,	@Pic4
		,	@Passport
		,	@BettingCode
		,	@RefCode2
		,	@Birthday
		,	@IsVip
		,	@Line1
		,	@Line2
		,	@Line3
		,	@City
		,	@Postcode
		,	@State
		,	@BankLine1
		,	@BankLine2
		,	@BankLine3
		,	@BankCity
		,	@BankCode
		,	@BankState
		,	@LicenseeType		
		,	@WhatsApp	
		,	@Line
		,	@WeChat		
		,	@Yahoo
		,	@QQ
		,	@BBM;

	IF	@@ERROR <> 0
	BEGIN
		SELECT	@ErrCode = 102
			,	@ErrMsg = 'Insert feedback unsuccessfuly.';

		RETURN;
	END;
	
	SELECT	@FeedbackID = @@identity;

	INSERT INTO crmFeedbackCustomer
		(	FeedbackID , CustID , IsRelated)
	SELECT	@FeedbackID, @CustID, 0;

	IF	@@ERROR <> 0
	BEGIN
		-- Rollback
		DELETE FROM crmFeedback 
		WHERE	FeedbackID = @FeedbackID;

		SELECT	@ErrCode = 103
			,	@ErrMsg = 'Insert feedback unsuccessfuly.';

		RETURN;
	END;

	IF	@RelatedCustID IS NOT NULL AND @RelatedCustID <> ''
	BEGIN
		DECLARE	@relatedCustomer TABLE(CustID INT);

		INSERT INTO @relatedCustomer
		SELECT	CONVERT(INT, val)
		FROM	dbo.f_split(@RelatedCustID, ',');

		-- Insert feedback related
		INSERT INTO crmFeedbackCustomer
					(	FeedbackID , CustID, IsRelated)	
		SELECT DISTINCT	@FeedbackID, CustID, 1
		FROM	@relatedCustomer 
		WHERE	CustID <> @CustID;

		IF	@@ERROR <> 0
		BEGIN
			-- Rollback
			DELETE FROM crmFeedback 
			WHERE	FeedbackID = @FeedbackID;

			DELETE FROM crmFeedbackCustomer 
			WHERE	FeedbackID = @FeedbackID;

			SELECT	@ErrCode = 105
				,	@ErrMsg = 'Insert feedback unsuccessfuly.';

			RETURN;
		END;
	END;

	-- Write Log
	DECLARE	@LogElement XML;

	SELECT	@LogElement =
					'<Acc_CRM_CommunicationLogIns>' + 
						'<TitleID>'						+ ISNULL(CONVERT(VARCHAR(5),@TitleID),'')						+ '</TitleID>' +
						'<FirstName>'					+ ISNULL(dbo.f_EncodeXMLValue(@FirstName),'')					+ '</FirstName>' +
						'<LastName>'					+ ISNULL(dbo.f_EncodeXMLValue(@LastName),'')					+ '</LastName>' +
						'<Birthday>'					+ ISNULL(CONVERT(VARCHAR(20),@Birthday,107),'')					+ '</Birthday>' +
						'<Phone>'						+ ISNULL(dbo.f_EncodeXMLValue(@Phone),'')						+ '</Phone>' +
						'<PhoneCountryCode>'			+ ISNULL(dbo.f_EncodeXMLValue(@PhoneCountryCode),'')			+ '</PhoneCountryCode>' +
						'<PhoneAreaCode>'				+ ISNULL(dbo.f_EncodeXMLValue(@PhoneAreaCode),'')				+ '</PhoneAreaCode>' +
						'<Phone2>'						+ ISNULL(dbo.f_EncodeXMLValue(@Phone2),'')						+ '</Phone2>' +
						'<Phone2CountryCode>'			+ ISNULL(dbo.f_EncodeXMLValue(@Phone2CountryCode),'')			+ '</Phone2CountryCode>' +
						'<Phone2AreaCode>'				+ ISNULL(dbo.f_EncodeXMLValue(@Phone2AreaCode),'')				+ '</Phone2AreaCode>' +
						'<Phone3>'						+ ISNULL(dbo.f_EncodeXMLValue(@Phone3),'')						+ '</Phone3>' +
						'<Phone3CountryCode>'			+ ISNULL(dbo.f_EncodeXMLValue(@Phone3CountryCode),'')			+ '</Phone3CountryCode>' +
						'<Phone3AreaCode>'				+ ISNULL(dbo.f_EncodeXMLValue(@Phone3AreaCode),'')				+ '</Phone3AreaCode>' +
						'<MobilePhone>'					+ ISNULL(dbo.f_EncodeXMLValue(@MobilePhone),'')					+ '</MobilePhone>' +
						'<MobilePhoneCountryCode>'		+ ISNULL(dbo.f_EncodeXMLValue(@MobilePhoneCountryCode),'')		+ '</MobilePhoneCountryCode>' +
						'<MobilePhoneAreaCode>'			+ ISNULL(dbo.f_EncodeXMLValue(@MobilePhoneAreaCode),'')			+ '</MobilePhoneAreaCode>' +
						'<Fax>'							+ ISNULL(dbo.f_EncodeXMLValue(@Fax),'')							+ '</Fax>' +
						'<FaxCountryCode>'				+ ISNULL(dbo.f_EncodeXMLValue(@FaxCountryCode),'')				+ '</FaxCountryCode>' +
						'<FaxAreaCode>'					+ ISNULL(dbo.f_EncodeXMLValue(@FaxAreaCode),'')					+ '</FaxAreaCode>' +						
						'<Email>'						+ ISNULL(dbo.f_EncodeXMLValue(@Email),'')						+ '</Email>' +
						'<Skype>'						+ ISNULL(dbo.f_EncodeXMLValue(@Skype),'')						+ '</Skype>' +
						'<MSN>'							+ ISNULL(dbo.f_EncodeXMLValue(@MSN),'')							+ '</MSN>' +	
						'<BettingCode>'					+ ISNULL(dbo.f_EncodeXMLValue(@BettingCode),'')					+ '</BettingCode>' +	
						'<RefCode2>'					+ ISNULL(dbo.f_EncodeXMLValue(@RefCode2),'')					+ '</RefCode2>' +	
						'<IsVip>'						+ ISNULL(CONVERT(VARCHAR(10),@IsVip),'')						+ '</IsVip>' +
						'<LanguageID>'					+ ISNULL(CONVERT(VARCHAR(10),@LanguageID),'')					+ '</LanguageID>' +
						'<CountryID>'					+ ISNULL(CONVERT(VARCHAR(10),@CountryID),'')					+ '</CountryID>' +
						'<Subject>'						+ ISNULL(dbo.f_EncodeXMLValue(@Subject),'')						+ '</Subject>' +
						'<Creator>'						+ ISNULL(CONVERT(VARCHAR(10),@UserID),'')						+ '</Creator>' +
						'<FeedbackDate>'				+ ISNULL(CONVERT(VARCHAR(20),@FeedbackDate),'')					+ '</FeedbackDate>' +
						'<ResolutionDate>'				+ ISNULL(CONVERT(VARCHAR(20),@ResolutionDate),'')				+ '</ResolutionDate>' +
						'<CommunicationID>'				+ ISNULL(CONVERT(VARCHAR(10),@CommunicationID),'')				+ '</CommunicationID>' +
						'<StationID>'					+ ISNULL(CONVERT(VARCHAR(10),@StationID),'')					+ '</StationID>' +
						'<MainCategoryID>'				+ ISNULL(CONVERT(VARCHAR(10),@MainCategoryID),'')				+ '</MainCategoryID>' +
						'<SubCategoryID>'				+ ISNULL(CONVERT(VARCHAR(10),@SubCategoryID),'')				+ '</SubCategoryID>' +
						'<SiteID>'						+ ISNULL(CONVERT(VARCHAR(10),@SiteID),'')						+ '</SiteID>' +
						'<RoleID>'						+ ISNULL(CONVERT(VARCHAR(10),@RoleID),'')						+ '</RoleID>' +
						'<ProductID>'					+ ISNULL(CONVERT(VARCHAR(10),@ProductID),'')					+ '</ProductID>' +
						'<SubProductID>'				+ ISNULL(CONVERT(VARCHAR(10),@SubProductID),'')					+ '</SubProductID>' +
						'<BettypeID>'					+ ISNULL(CONVERT(VARCHAR(10),@BettypeID),'')					+ '</BettypeID>' +
						'<ResponseID>'					+ ISNULL(CONVERT(VARCHAR(10),@ResponseID),'')					+ '</ResponseID>' +
						'<StatusID>'					+ ISNULL(CONVERT(VARCHAR(10),@StatusID),'')						+ '</StatusID>' +
						'<RelatedCustID>'				+ ISNULL(@RelatedCustID,'')										+ '</RelatedCustID>' +				
						'<Pic1>'						+ ISNULL(dbo.f_EncodeXMLValue(@Pic1),'')						+ '</Pic1>' +
						'<Pic2>'						+ ISNULL(dbo.f_EncodeXMLValue(@Pic2),'')						+ '</Pic2>' +
						'<Pic3>'						+ ISNULL(dbo.f_EncodeXMLValue(@Pic3),'')						+ '</Pic3>' +
						'<Pic4>'						+ ISNULL(dbo.f_EncodeXMLValue(@Pic4),'')						+ '</Pic4>' +
						'<Passport>'					+ ISNULL(dbo.f_EncodeXMLValue(@Passport),'')					+ '</Passport>' +
						'<Line1>'						+ ISNULL(dbo.f_EncodeXMLValue(@Line1),'')						+ '</Line1>' +
						'<Line2>'						+ ISNULL(dbo.f_EncodeXMLValue(@Line2),'')						+ '</Line2>' +
						'<Line3>'						+ ISNULL(dbo.f_EncodeXMLValue(@Line3),'')						+ '</Line3>' +
						'<City>'						+ ISNULL(dbo.f_EncodeXMLValue(@City),'')						+ '</City>' +
						'<Postcode>'					+ ISNULL(dbo.f_EncodeXMLValue(@Postcode),'')					+ '</Postcode>' +
						'<State>'						+ ISNULL(dbo.f_EncodeXMLValue(@State),'')						+ '</State>' +
						'<BankLine1>'					+ ISNULL(dbo.f_EncodeXMLValue(@BankLine1),'')					+ '</BankLine1>' +
						'<BankLine2>'					+ ISNULL(dbo.f_EncodeXMLValue(@BankLine2),'')					+ '</BankLine2>' +
						'<BankLine3>'					+ ISNULL(dbo.f_EncodeXMLValue(@BankLine3),'')					+ '</BankLine3>' +
						'<BankCity>'					+ ISNULL(dbo.f_EncodeXMLValue(@BankCity),'')					+ '</BankCity>' +
						'<BankCode>'					+ ISNULL(dbo.f_EncodeXMLValue(@BankCode),'')					+ '</BankCode>' +
						'<BankState>'					+ ISNULL(dbo.f_EncodeXMLValue(@BankState),'')					+ '</BankState>' +
						'<Remark>'						+ ISNULL(dbo.f_EncodeXMLValue(@Description),'')					+ '</Remark>' +
						'<Solution>'					+ ISNULL(dbo.f_EncodeXMLValue(@Solution),'')					+ '</Solution>' +
						'<LicenseeType>'				+ ISNULL(CONVERT(VARCHAR(10),@LicenseeType),'')					+ '</LicenseeType>' +
						'<WhatsApp>'					+ ISNULL(dbo.f_EncodeXMLValue(@WhatsApp),'')					+ '</WhatsApp>' +
						'<Line>'						+ ISNULL(dbo.f_EncodeXMLValue(@Line),'')						+ '</Line>' +
						'<WeChat>'						+ ISNULL(dbo.f_EncodeXMLValue(@WeChat),'')						+ '</WeChat>' +
						'<Yahoo>'						+ ISNULL(dbo.f_EncodeXMLValue(@Yahoo),'')						+ '</Yahoo>' +
						'<QQ>'							+ ISNULL(dbo.f_EncodeXMLValue(@QQ),'')							+ '</QQ>' +
						'<BBM>'							+ ISNULL(dbo.f_EncodeXMLValue(@BBM),'')							+ '</BBM>' +
					'</Acc_CRM_CommunicationLogIns>';

	EXECUTE	dbo.WriteLog_UserLog_crmLogFeedback
				@UserID = @UserID
			,	@FeedbackID = @FeedbackID
			,	@CustID = @CustID
			,	@ActionID = 202
			,	@IP = @IP
			,	@Description = @Description
			,	@Solution = @Solution
			,	@Review =  NULL
			,	@NewValues = @LogElement;
END;					
GO

GRANT EXECUTE ON dbo.Acc_CRM_CommunicationLogIns TO bodbAdminNet;
GO
GRANT VIEW DEFINITION ON dbo.Acc_CRM_CommunicationLogIns TO vnteam;
GO
