SET QUOTED_IDENTIFIER ON; 
GO
SET ANSI_NULLS ON; 
GO

ALTER PROCEDURE	dbo.Acc_CRM_FeedbackUpd (
					@UserID						INT
				,	@FeedbackID					INT
				,	@CustID						INT
				,	@TitleID					INT
				,	@Birthday					DATETIME
				,	@FirstName					NVARCHAR(50)
				,	@LastName					NVARCHAR(50)
				,	@Phone						NVARCHAR(100)
				,	@PhoneCountryCode			NVARCHAR(40)
				,	@PhoneAreaCode				NVARCHAR(40)
				,	@Phone2						NVARCHAR(100)
				,	@Phone2CountryCode			NVARCHAR(40)
				,	@Phone2AreaCode				NVARCHAR(40)
				,	@Phone3						NVARCHAR(100)
				,	@Phone3CountryCode			NVARCHAR(40)
				,	@Phone3AreaCode				NVARCHAR(40)
				,	@MobilePhone				NVARCHAR(100)
				,	@MobilePhoneCountryCode		NVARCHAR(40)
				,	@MobilePhoneAreaCode		NVARCHAR(40)
				,	@Fax						NVARCHAR(50)
				,	@FaxCountryCode				NVARCHAR(40)
				,	@FaxAreaCode				NVARCHAR(40)
				,	@Email						NVARCHAR(254)
				,	@Skype						NVARCHAR(100)
				,	@MSN						NVARCHAR(100)
				,	@LanguageID					INT
				,	@CountryID					INT
				,	@Subject					NVARCHAR(200)	= NULL
				,	@FeedbackDate				DATETIME
				,	@ResolutionDate				DATETIME
				,	@CommunicationID			INT
				,	@StationID					INT
				,	@MainCategoryID				INT
				,	@SubCategoryID				INT
				,	@SiteID						INT
				,	@RoleID						INT
				,	@ProductID					INT
				,	@SubProductID				INT		
				,	@BettypeID					INT
				,	@ResponseID					INT
				,	@StatusID					INT
				,	@Description				NVARCHAR(MAX)
				,	@Solution					NVARCHAR(MAX)
				,	@UpdateReviewedMode			TINYINT			= 0
				,	@IsReviewed					BIT				= 0
				,	@Review						NVARCHAR(MAX)	= NULL
				,	@ReviewerID					INT				= NULL
				,	@BettingCode				NVARCHAR(100)	= NULL
				,	@RefCode2					NVARCHAR(100)	= NULL
				,	@Passport					NVARCHAR(100)	= NULL
				,	@IsVip						BIT
				,	@IP							VARCHAR(15)	
				,	@Pic1						NVARCHAR(100)	= NULL
				,	@Pic2						NVARCHAR(100)	= NULL
				,	@Pic3						NVARCHAR(100)	= NULL
				,	@Pic4						NVARCHAR(100)	= NULL
				,	@Pic1Name					NVARCHAR(100)	= NULL
				,	@Pic2Name					NVARCHAR(100)	= NULL
				,	@Pic3Name					NVARCHAR(100)	= NULL
				,	@Pic4Name					NVARCHAR(100)	= NULL
				,	@RelatedCustID				NVARCHAR(MAX)	= NULL
				,	@LicenseeType				INT				= 0
				,	@WhatsApp					NVARCHAR(100)	= NULL
				,	@Line						NVARCHAR(100)	= NULL
				,	@WeChat						NVARCHAR(100)	= NULL
				,	@Yahoo						NVARCHAR(100)	= NULL
				,	@QQ							NVARCHAR(100)	= NULL
				,	@BBM						NVARCHAR(100)	= NULL
				,	@ErrCode					INT				= 0		OUTPUT
				,	@ErrMsg						NVARCHAR(4000)	= ''	OUTPUT	
)
AS
/*
	Created:	Lukas
	Date:		20101023
	Task:		update feedback
	DB:			DB052.bodb_CRM
	Original:

	Revisions:
		- 20120307@Elodie:	add 3 params @Pic1, @Pic3, @Pic3
		- 20120319@Elodie:	change DB06 to DB052
		- 20120327@Elodie:	change data type of @Pic1, @Pic2, @Pic3 params to NVARCHAR(100)
		- 20120529@Elodie:	encode some parameters to write log in XML format, such as Subject, Pic1, Pic2, ...
		- 20131108@Kathy:	check required fields update to zero [Redmine:#7206]
		- 20140303@Dom:		Modify for new structure
		- 20141118@Dom:		add more fields of communication tool
		- 20160308@Billy:	Integrate Sub-Product field - [Redmine: #52998]

	Param's Explanation:
		- @UpdateReviewedMode: Kind of update review
			0	Do nothing
			1	Update review
			2	remove review
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @SolveDate	DATETIME;

	
	SELECT	@ErrCode	= 0
		,	@ErrMsg		= '';

	IF	NOT EXISTS (SELECT 1 FROM crmFeedback WITH (NOLOCK) WHERE FeedbackID = @FeedbackID)
	BEGIN
		SELECT	@ErrCode = 100
			,	@ErrMsg = 'Feedback does not exist.';

		RETURN;
	END;

	IF	ISNULL(@CommunicationID, 0) = 0 
	OR	ISNULL(@MainCategoryID, 0) = 0 
	OR	ISNULL(@SubCategoryID, 0) = 0 
	OR	ISNULL(@StatusID, 0) = 0 
	OR	ISNULL(@LanguageID, '') = ''
	OR	ISNULL(@RoleID, 0) = 0
	OR	ISNULL(@ResponseID, 0) = 0
	OR	ISNULL(@StationID, 0) = 0
	BEGIN
		SELECT	@ErrCode = 100
			,	@ErrMsg = 'Incorrect Data.';

		RETURN;
	END;

	SELECT	@SolveDate	= CASE	WHEN @UpdateReviewedMode = 0 THEN SolveDate 
								WHEN @UpdateReviewedMode = 1 THEN GETDATE() 
								WHEN @UpdateReviewedMode = 2 THEN NULL 
								ELSE SolveDate
						  END
		,	@Review		= CASE	WHEN @UpdateReviewedMode = 0 THEN Review 
								WHEN @UpdateReviewedMode = 1 THEN @Review 
								WHEN @UpdateReviewedMode = 2 THEN NULL
								ELSE Review 
						  END
		,	@IsReviewed = CASE	WHEN @UpdateReviewedMode = 0 THEN IsReviewed 
								WHEN @UpdateReviewedMode = 1 THEN 1
								WHEN @UpdateReviewedMode = 2 THEN 0
								ELSE IsReviewed 
						  END
		,	@ReviewerID = CASE	WHEN @UpdateReviewedMode = 0 THEN ReviewerID 
								WHEN @UpdateReviewedMode = 1 THEN @ReviewerID
								WHEN @UpdateReviewedMode = 2 THEN NULL
								ELSE ReviewerID 
						  END
	FROM	crmFeedback WITH (NOLOCK)
	WHERE	FeedbackID = @FeedbackID;

	DECLARE	@TitleID_Old					INT
		,	@Birthday_Old					DATETIME
		,	@FirstName_Old					NVARCHAR(50)
		,	@LastName_Old					NVARCHAR(50)
		,	@Phone_Old						NVARCHAR(100)
		,	@PhoneCountryCode_Old			NVARCHAR(40)
		,	@PhoneAreaCode_Old				NVARCHAR(40)
		,	@Phone2_Old						NVARCHAR(100)
		,	@Phone2CountryCode_Old			NVARCHAR(40)
		,	@Phone2AreaCode_Old				NVARCHAR(40)
		,	@Phone3_Old						NVARCHAR(100)
		,	@Phone3CountryCode_Old			NVARCHAR(40)
		,	@Phone3AreaCode_Old				NVARCHAR(40)
		,	@MobilePhone_Old				NVARCHAR(100)
		,	@MobilePhoneCountryCode_Old		NVARCHAR(40)
		,	@MobilePhoneAreaCode_Old		NVARCHAR(40)
		,	@Fax_Old						NVARCHAR(50)
		,	@FaxCountryCode_Old				NVARCHAR(40)
		,	@FaxAreaCode_Old				NVARCHAR(40)
		,	@Email_Old						NVARCHAR(254)
		,	@Skype_Old						NVARCHAR(100)
		,	@MSN_Old						NVARCHAR(100)
		,	@LanguageID_Old					INT
		,	@CountryID_Old					INT
		,	@Subject_Old					NVARCHAR(200)	= NULL
		,	@FeedbackDate_Old				DATETIME
		,	@ResolutionDate_Old				DATETIME
		,	@CommunicationID_Old			INT
		,	@StationID_Old					INT
		,	@MainCategoryID_Old				INT
		,	@SubCategoryID_Old				INT
		,	@SiteID_Old						INT
		,	@RoleID_Old						INT
		,	@ProductID_Old					INT
		,	@SubProductID_Old				INT
		,	@BettypeID_Old					INT
		,	@ResponseID_Old					INT
		,	@StatusID_Old					INT
		,	@Description_Old				NVARCHAR(MAX)
		,	@Solution_Old					NVARCHAR(MAX)
		,	@UpdateReviewedMode_Old			TINYINT			= 0
		,	@IsReviewed_Old					BIT				= 0
		,	@Review_Old						NVARCHAR(MAX)	= NULL
		,	@ReviewerID_Old					INT				= NULL
		,	@BettingCode_Old				NVARCHAR(100)	= NULL
		,	@RefCode2_Old					NVARCHAR(100)	= NULL
		,	@Passport_Old					NVARCHAR(100)	= NULL
		,	@IsVip_Old						BIT
		,	@IP_Old							VARCHAR(15)	
		,	@Pic1_Old						NVARCHAR(100)	= NULL
		,	@Pic2_Old						NVARCHAR(100)	= NULL
		,	@Pic3_Old						NVARCHAR(100)	= NULL
		,	@Pic4_Old						NVARCHAR(100)	= NULL
		,	@SolveDate_old					DATETIME
		,	@Creator_Old					INT
		,	@Pic1Name_Old					NVARCHAR(100)	= NULL
		,	@Pic2Name_Old					NVARCHAR(100)	= NULL
		,	@Pic3Name_Old					NVARCHAR(100)	= NULL
		,	@Pic4Name_Old					NVARCHAR(100)	= NULL
		,	@LicenseeType_Old				INT				= 0
		,	@WhatsApp_Old					NVARCHAR(100)	= NULL
		,	@Line_Old						NVARCHAR(100)	= NULL
		,	@WeChat_Old						NVARCHAR(100)	= NULL
		,	@Yahoo_Old						NVARCHAR(100)	= NULL
		,	@QQ_Old							NVARCHAR(100)	= NULL
		,	@BBM_Old						NVARCHAR(100)	= NULL;

	SELECT	@TitleID_Old					= TitleID
		,	@Birthday_Old					= Birthday
		,	@FirstName_Old					= FirstName
		,	@LastName_Old					= LastName
		,	@Phone_Old						= Phone
		,	@PhoneCountryCode_Old			= PhoneCountryCode
		,	@PhoneAreaCode_Old				= PhoneAreaCode
		,	@Phone2_Old						= Phone2
		,	@Phone2CountryCode_Old			= Phone2CountryCode
		,	@Phone2AreaCode_Old				= Phone2AreaCode
		,	@Phone3_Old						= Phone3
		,	@Phone3CountryCode_Old			= Phone3CountryCode
		,	@Phone3AreaCode_Old				= Phone3AreaCode
		,	@MobilePhone_Old				= MobilePhone
		,	@MobilePhoneCountryCode_Old		= MobilePhoneCountryCode
		,	@MobilePhoneAreaCode_Old		= MobilePhoneAreaCode
		,	@Fax_Old						= Fax
		,	@FaxCountryCode_Old				= FaxCountryCode
		,	@FaxAreaCode_Old				= FaxAreaCode
		,	@Email_Old						= Email
		,	@Skype_Old						= Skype
		,	@msn_Old						= MSN
		,	@CountryID_Old					= CountryID
		,	@LanguageID_Old					= LanguageID
		,	@Subject_Old					= Subject
		,	@FeedbackDate_Old				= FeedbackDate
		,	@ResolutionDate_Old				= ResolutionDate
		,	@SolveDate_Old					= SolveDate
		,	@CommunicationID_Old			= CommunicationID
		,	@StationID_Old					= StationID
		,	@MainCategoryID_Old				= MainCategoryID
		,	@SubCategoryID_Old				= SubCategoryID
		,	@SiteID_Old						= SiteID
		,	@RoleID_Old						= RoleID
		,	@ProductID_Old					= ProductID
		,	@SubProductID_Old				= SubProductID
		,	@BetTypeID_Old					= BetTypeID
		,	@ResponseID_Old					= ResponseID
		,	@StatusID_Old					= StatusID
		,	@Description_Old				= Description
		,	@Solution_Old					= Solution
		,	@IsReviewed_Old					= IsReviewed
		,	@Review_Old						= Review
		,	@ReviewerID_Old					= ReviewerID
		,	@Pic1_Old						= Pic1
		,	@Pic2_Old						= Pic2
		,	@Pic3_Old						= Pic3
		,	@Pic4_Old						= Pic4
		,	@BettingCode_Old				= RefCode1
		,	@RefCode2_Old					= RefCode2
		,	@Passport_Old					= Passport
		,	@IsVip_Old						= IsVip
		,	@SolveDate_old					= @SolveDate
		,	@Creator_Old					= CreatorID
		,	@Pic1Name_Old					= Pic1Name
		,	@Pic2Name_Old					= Pic2Name
		,	@Pic3Name_Old					= Pic3Name
		,	@Pic4Name_Old					= Pic4Name
		,	@LicenseeType_Old				= LicenseeType
		,	@WhatsApp_Old					= WhatsApp
		,	@Line_Old						= Line
		,	@WeChat_Old						= WeChat
		,	@Yahoo_Old						= Yahoo
		,	@QQ_Old							= QQ
		,	@BBM_Old						= BBM
	FROM	crmFeedback WITH (NOLOCK)
	WHERE	FeedbackID = @FeedbackID;

	DECLARE	@RelatedCustID_Old varchar(max) = '';

	SELECT	@RelatedCustID_Old = '';

	SELECT	@RelatedCustID_Old = @RelatedCustID_Old + CAST(c.CustID AS VARCHAR(100)) + ','
	FROM	crmFeedbackCustomer(NOLOCK) c
	WHERE	c.FeedbackID = @FeedbackID
		AND	c.IsRelated = 1;

	IF	ISNULL(@RelatedCustID_Old, '') <> ''
	SELECT	@RelatedCustID_Old = LEFT(@RelatedCustID_Old, LEN(@RelatedCustID_Old) - 1);

	--- update feedback
	UPDATE crmFeedback WITH (ROWLOCK, UPDLOCK)
	SET	CustID						= @CustID
	,	TitleID						= @TitleID
	,	Birthday					= @Birthday
	,	FirstName					= @FirstName
	,	LastName					= @LastName
	,	Phone						= @Phone
	,	PhoneCountryCode			= @PhoneCountryCode
	,	PhoneAreaCode				= @PhoneAreaCode
	,	Phone2						= @Phone2
	,	Phone2CountryCode			= @Phone2CountryCode
	,	Phone2AreaCode				= @Phone2AreaCode
	,	Phone3						= @Phone3
	,	Phone3CountryCode			= @Phone3CountryCode
	,	Phone3AreaCode				= @Phone3AreaCode
	,	MobilePhone					= @MobilePhone
	,	MobilePhoneCountryCode		= @MobilePhoneCountryCode
	,	MobilePhoneAreaCode			= @MobilePhoneAreaCode
	,	Fax							= @Fax
	,	FaxCountryCode				= @FaxCountryCode
	,	FaxAreaCode					= @FaxAreaCode
	,	Email						= @Email
	,	Skype						= @Skype
	,	msn							= @MSN
	,	CountryID					= @CountryID
	,	LanguageID					= @LanguageID
	,	Subject						= @Subject
	,	FeedbackDate				= @FeedbackDate
	,	ResolutionDate				= @ResolutionDate
	,	SolveDate					= @SolveDate
	,	CommunicationID				= @CommunicationID
	,	StationID					= @StationID
	,	MainCategoryID				= @MainCategoryID
	,	SubCategoryID				= @SubCategoryID
	,	SiteID						= @SiteID
	,	RoleID						= @RoleID
	,	ProductID					= @ProductID
	,	SubProductID				= @SubProductID
	,	BetTypeID					= @BetTypeID
	,	ResponseID					= @ResponseID
	,	StatusID					= @StatusID
	,	Description					= @Description
	,	Solution					= @Solution
	,	IsReviewed					= @IsReviewed
	,	Review						= @Review
	,	ReviewerID					= @ReviewerID
	,	Pic1						= @Pic1
	,	Pic2						= @Pic2
	,	Pic3						= @Pic3
	,	Pic4						= @Pic4
	,	RefCode1					= @BettingCode
	,	RefCode2					= @RefCode2
	,	Passport					= @Passport
	,	IsVip						= @IsVip
	,	Pic1Name					= @Pic1Name
	,	Pic2Name					= @Pic2Name
	,	Pic3Name					= @Pic3Name
	,	Pic4Name					= @Pic4Name
	,	LicenseeType				= @LicenseeType
	,	WhatsApp					= @WhatsApp
	,	Line						= @Line
	,	WeChat						= @WeChat
	,	Yahoo						= @Yahoo
	,	QQ							= @QQ
	,	BBM							= @BBM
	WHERE	FeedbackID = @FeedbackID;
	 
	IF	@@ERROR <> 0
	BEGIN
		SELECT	@ErrCode = 101
			,	@ErrMsg = 'updated feedback unsuccessfuly.';

		RETURN;
	END;

	-- write log
	DECLARE	@OldValues	XML
		,	@NewValues	XML;
	SELECT	@OldValues = 				
					'<Acc_CRM_FeedbackUpd>' + --SP Name
						'<TitleID>'						+ ISNULL(CONVERT(VARCHAR(5),@TitleID_Old),'')					+ '</TitleID>' +
						'<FirstName>'					+ ISNULL(dbo.f_EncodeXMLValue(@FirstName_Old),'')				+ '</FirstName>' +
						'<LastName>'					+ ISNULL(dbo.f_EncodeXMLValue(@LastName_Old),'')				+ '</LastName>' +
						'<Birthday>'					+ ISNULL(CONVERT(VARCHAR(20),@Birthday_Old,107),'')				+ '</Birthday>' +
						'<Phone>'						+ ISNULL(dbo.f_EncodeXMLValue(@Phone_Old),'')					+ '</Phone>' +
						'<PhoneCountryCode>'			+ ISNULL(dbo.f_EncodeXMLValue(@PhoneCountryCode_Old),'')		+ '</PhoneCountryCode>' +
						'<PhoneAreaCode>'				+ ISNULL(dbo.f_EncodeXMLValue(@PhoneAreaCode_Old),'')			+ '</PhoneAreaCode>' +
						'<Phone2>'						+ ISNULL(dbo.f_EncodeXMLValue(@Phone2_Old),'')					+ '</Phone2>' +
						'<Phone2CountryCode>'			+ ISNULL(dbo.f_EncodeXMLValue(@Phone2CountryCode_Old),'')		+ '</Phone2CountryCode>' +
						'<Phone2AreaCode>'				+ ISNULL(dbo.f_EncodeXMLValue(@Phone2AreaCode_Old),'')			+ '</Phone2AreaCode>' +
						'<Phone3>'						+ ISNULL(dbo.f_EncodeXMLValue(@Phone3_Old),'')					+ '</Phone3>' +
						'<Phone3CountryCode>'			+ ISNULL(dbo.f_EncodeXMLValue(@Phone3CountryCode_Old),'')		+ '</Phone3CountryCode>' +
						'<Phone3AreaCode>'				+ ISNULL(dbo.f_EncodeXMLValue(@Phone3AreaCode_Old),'')			+ '</Phone3AreaCode>' +
						'<MobilePhone>'					+ ISNULL(dbo.f_EncodeXMLValue(@MobilePhone_Old),'')				+ '</MobilePhone>' +
						'<MobilePhoneCountryCode>'		+ ISNULL(dbo.f_EncodeXMLValue(@MobilePhoneCountryCode_Old),'')	+ '</MobilePhoneCountryCode>' +
						'<MobilePhoneAreaCode>'			+ ISNULL(dbo.f_EncodeXMLValue(@MobilePhoneAreaCode_Old),'')		+ '</MobilePhoneAreaCode>' +
						'<Fax>'							+ ISNULL(dbo.f_EncodeXMLValue(@Fax_Old),'')						+ '</Fax>' +
						'<FaxCountryCode>'				+ ISNULL(dbo.f_EncodeXMLValue(@FaxCountryCode_Old),'')			+ '</FaxCountryCode>' +
						'<FaxAreaCode>'					+ ISNULL(dbo.f_EncodeXMLValue(@FaxAreaCode_Old),'')				+ '</FaxAreaCode>' +						
						'<Email>'						+ ISNULL(dbo.f_EncodeXMLValue(@Email_Old),'')					+ '</Email>' +
						'<Skype>'						+ ISNULL(dbo.f_EncodeXMLValue(@Skype_Old),'')					+ '</Skype>' +
						'<MSN>'							+ ISNULL(dbo.f_EncodeXMLValue(@MSN_Old),'')						+ '</MSN>' +	
						'<BettingCode>'					+ ISNULL(dbo.f_EncodeXMLValue(@BettingCode_Old),'')				+ '</BettingCode>' +	
						'<RefCode2>'					+ ISNULL(dbo.f_EncodeXMLValue(@RefCode2_Old),'')				+ '</RefCode2>' +	
						'<IsVip>'						+ ISNULL(CONVERT(VARCHAR(10),@IsVip_Old),'')					+ '</IsVip>' +
						'<LanguageID>'					+ ISNULL(CONVERT(VARCHAR(10),@LanguageID_Old),'')				+ '</LanguageID>' +
						'<CountryID>'					+ ISNULL(CONVERT(VARCHAR(10),@CountryID_Old),'')				+ '</CountryID>' +
						'<Subject>'						+ ISNULL(dbo.f_EncodeXMLValue(@Subject_Old),'')					+ '</Subject>' +
						'<Creator>'						+ ISNULL(CONVERT(VARCHAR(10),@Creator_Old),'')					+ '</Creator>' +
						'<FeedbackDate>'				+ ISNULL(CONVERT(VARCHAR(20),@FeedbackDate_Old),'')				+ '</FeedbackDate>' +
						'<ResolutionDate>'				+ ISNULL(CONVERT(VARCHAR(20),@ResolutionDate_Old),'')			+ '</ResolutionDate>' +
						'<CommunicationID>'				+ ISNULL(CONVERT(VARCHAR(10),@CommunicationID_Old),'')			+ '</CommunicationID>' +
						'<StationID>'					+ ISNULL(CONVERT(VARCHAR(10),@StationID_Old),'')				+ '</StationID>' +
						'<MainCategoryID>'				+ ISNULL(CONVERT(VARCHAR(10),@MainCategoryID_Old),'')			+ '</MainCategoryID>' +
						'<SubCategoryID>'				+ ISNULL(CONVERT(VARCHAR(10),@SubCategoryID_Old),'')			+ '</SubCategoryID>' +
						'<SiteID>'						+ ISNULL(CONVERT(VARCHAR(10),@SiteID_Old),'')					+ '</SiteID>' +
						'<RoleID>'						+ ISNULL(CONVERT(VARCHAR(10),@RoleID_Old),'')					+ '</RoleID>' +
						'<ProductID>'					+ ISNULL(CONVERT(VARCHAR(10),@ProductID_Old),'')				+ '</ProductID>' +
						'<SubProductID>'				+ ISNULL(CONVERT(VARCHAR(10),@SubProductID_Old),'')				+ '</SubProductID>' +
						'<BettypeID>'					+ ISNULL(CONVERT(VARCHAR(10),@BettypeID_Old),'')				+ '</BettypeID>' +
						'<ResponseID>'					+ ISNULL(CONVERT(VARCHAR(10),@ResponseID_Old),'')				+ '</ResponseID>' +
						'<StatusID>'					+ ISNULL(CONVERT(VARCHAR(10),@StatusID_Old),'')					+ '</StatusID>' +
						'<IsReviewed>'					+ ISNULL(CONVERT(VARCHAR(5),@IsReviewed_Old),'')				+ '</IsReviewed>' +
						'<Reviewer>'					+ ISNULL(CONVERT(VARCHAR(10),@ReviewerID_Old),'')				+ '</Reviewer>' +						
						'<RelatedCustID>'				+ ISNULL(@RelatedCustID_Old,'')									+ '</RelatedCustID>' +
						'<Pic1>'						+ ISNULL(dbo.f_EncodeXMLValue(@Pic1_Old),'')					+ '</Pic1>' +
						'<Pic2>'						+ ISNULL(dbo.f_EncodeXMLValue(@Pic2_Old),'')					+ '</Pic2>' +
						'<Pic3>'						+ ISNULL(dbo.f_EncodeXMLValue(@Pic3_Old),'')					+ '</Pic3>' +
						'<Pic4>'						+ ISNULL(dbo.f_EncodeXMLValue(@Pic4_Old),'')					+ '</Pic4>' +
						'<Passport>'					+ ISNULL(dbo.f_EncodeXMLValue(@Passport_Old),'')				+ '</Passport>' +
						'<Remark>'						+ ISNULL(dbo.f_EncodeXMLValue(@Description_Old),'')				+ '</Remark>' +
						'<Solution>'					+ ISNULL(dbo.f_EncodeXMLValue(@Solution_Old),'')				+ '</Solution>' +
						'<LicenseeType>'				+ ISNULL(CONVERT(VARCHAR(10),@LicenseeType_Old),'')				+ '</LicenseeType>' +
						'<WhatsApp>'					+ ISNULL(dbo.f_EncodeXMLValue(@WhatsApp_Old),'')				+ '</WhatsApp>' +
						'<Line>'						+ ISNULL(dbo.f_EncodeXMLValue(@Line_Old),'')					+ '</Line>' +
						'<WeChat>'						+ ISNULL(dbo.f_EncodeXMLValue(@WeChat_Old),'')					+ '</WeChat>' +
						'<Yahoo>'						+ ISNULL(dbo.f_EncodeXMLValue(@Yahoo_Old),'')					+ '</Yahoo>' +
						'<QQ>'							+ ISNULL(dbo.f_EncodeXMLValue(@QQ_Old),'')						+ '</QQ>' +
						'<BBM>'							+ ISNULL(dbo.f_EncodeXMLValue(@BBM_Old),'')						+ '</BBM>' +
					'</Acc_CRM_FeedbackUpd>';
	SELECT @NewValues = 				
					'<Acc_CRM_FeedbackUpd>' + --SP Name
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
						'<Creator>'						+ ISNULL(CONVERT(VARCHAR(10),@Creator_Old),'')					+ '</Creator>' +
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
						'<IsReviewed>'					+ ISNULL(CONVERT(VARCHAR(5),@IsReviewed),'')					+ '</IsReviewed>' +
						'<Reviewer>'					+ ISNULL(CONVERT(VARCHAR(10),@ReviewerID),'')					+ '</Reviewer>' +						
						'<RelatedCustID>'				+ ISNULL(@RelatedCustID,'')										+ '</RelatedCustID>' +
						'<Pic1>'						+ ISNULL(dbo.f_EncodeXMLValue(@Pic1),'')						+ '</Pic1>' +
						'<Pic2>'						+ ISNULL(dbo.f_EncodeXMLValue(@Pic2),'')						+ '</Pic2>' +
						'<Pic3>'						+ ISNULL(dbo.f_EncodeXMLValue(@Pic3),'')						+ '</Pic3>' +
						'<Pic4>'						+ ISNULL(dbo.f_EncodeXMLValue(@Pic4),'')						+ '</Pic4>' +
						'<Passport>'					+ ISNULL(dbo.f_EncodeXMLValue(@Passport),'')					+ '</Passport>' +
						'<Remark>'						+ ISNULL(dbo.f_EncodeXMLValue(@Description),'')					+ '</Remark>' +
						'<Solution>'					+ ISNULL(dbo.f_EncodeXMLValue(@Solution),'')					+ '</Solution>' +
						'<LicenseeType>'				+ ISNULL(CONVERT(VARCHAR(10),@LicenseeType),'')					+ '</LicenseeType>' +
						'<WhatsApp>'					+ ISNULL(dbo.f_EncodeXMLValue(@WhatsApp),'')					+ '</WhatsApp>' +
						'<Line>'						+ ISNULL(dbo.f_EncodeXMLValue(@Line),'')						+ '</Line>' +
						'<WeChat>'						+ ISNULL(dbo.f_EncodeXMLValue(@WeChat),'')						+ '</WeChat>' +
						'<Yahoo>'						+ ISNULL(dbo.f_EncodeXMLValue(@Yahoo),'')						+ '</Yahoo>' +
						'<QQ>'							+ ISNULL(dbo.f_EncodeXMLValue(@QQ),'')							+ '</QQ>' +
						'<BBM>'							+ ISNULL(dbo.f_EncodeXMLValue(@BBM),'')							+ '</BBM>' +
					'</Acc_CRM_FeedbackUpd>';


	EXECUTE	dbo.WriteLog_UserLog_crmLogFeedback
				@UserID = @UserID
			,	@FeedbackID = @FeedbackID
			,	@CustID = @CustID
			,	@ActionID = 201
			,	@IP = @IP
			,	@Description = @Description
			,	@Solution = @Solution
			,	@Review =  @Review
			,	@NewValues = @NewValues
			,	@OldValues = @OldValues;

END;
GO 

GRANT EXECUTE ON dbo.Acc_CRM_FeedbackUpd TO bodbAdminNet;
GO 
GRANT VIEW DEFINITION ON dbo.Acc_CRM_FeedbackUpd TO vnteam;
GO 
