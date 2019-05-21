/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE	dbo.Acc_CRM_CommunicationLogIns
					@CustID				INT
				,	@RelatedCustID		VARCHAR(500)	= NULL
				,	@LanguageID			INT
				,	@CountryID			INT
				,	@ProvinceID			INT=NULL
				,	@FeedbackDate		DATETIME
				,	@ResolutionDate		DATETIME
				,	@CommunicationID	VARCHAR(MAX)	
				,	@StationID			VARCHAR(MAX)	
				,	@Category			VARCHAR(MAX)		
				,	@Product			VARCHAR(MAX)
				,	@SiteID				INT
				,	@RoleID				INT			
				,	@ResponseID			INT
				,	@StatusID			INT
				,	@AutoField			NVARCHAR(MAX)	= NULL
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
		- 20180117@Winnie:	Add Is Related Customer - [Redmine: #88774]
		- 20180405@Winnie:  Allow users to select multiple products/sub-categories - Redmine: #84714
		- 20190506@Winnie: CN88 Province RedmineID: #112637
	Param's Explanation:
*/
BEGIN
	IF	ISNULL(@CommunicationID, '') = ''
	OR	ISNULL(@Product, '') = ''
	OR	ISNULL(@Category,'') = '' 
	OR	ISNULL(@StatusID, 0) = 0 
	OR	ISNULL(@LanguageID, 0) = 0
	OR	ISNULL(@RoleID, 0) = 0
	OR	ISNULL(@ResponseID, 0) = 0
	OR	ISNULL(@StationID, '') = ''
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

	DECLARE @Remark							NVARCHAR(MAX)
		,	@MainCategoryID					VARCHAR(MAX)
		,	@SubCategoryID					VARCHAR(MAX)		
		,	@ProductID						VARCHAR(MAX)
		,	@SubProductID					VARCHAR(MAX)
		,	@BettypeID						VARCHAR(MAX)
	SELECT @Remark = @Description

	DECLARE  @tblCategory TABLE(		
			MainCategoryID		INT
		,	SubCategoryID		INT 	
		)

	DECLARE  @tblProduct TABLE(		
			ProductID		INT
		,	SubProductID	INT 
		,	BetTypeID		INT	
	)

	DECLARE  @tblStation TABLE(		
			StationID	INT		
	)

	DECLARE  @tblComm TABLE(		
			CommID	INT		
	)

	-- Read XML
	DECLARE	@iDoc			INT;
	EXECUTE sys.sp_xml_preparedocument @iDoc OUTPUT, @Category;

	INSERT INTO	@tblCategory
		( MainCategoryID,SubCategoryID)
	SELECT	ox.MainCategoryID, ox.SubCategoryID
	FROM	OPENXML(@iDoc, '/ROOT/Category', 1)
			WITH (		
				MainCategoryID				INT
			,	SubCategoryID				INT					
			) AS ox;

	EXECUTE sys.sp_xml_removedocument @iDoc;	

	EXECUTE sys.sp_xml_preparedocument @iDoc OUTPUT, @Product;

	INSERT INTO	@tblProduct
		( ProductID,SubProductID,BetTypeID)
	SELECT	ox.ProductID, ox.SubProductID,ox.BetTypeID
	FROM	OPENXML(@iDoc, '/ROOT/Product', 1)
			WITH (		
				ProductID				INT
			,	SubProductID			INT	
			,	BetTypeID				INT
			) AS ox;

	EXECUTE sys.sp_xml_removedocument @iDoc;

	INSERT INTO	@tblStation(StationID)
	SELECT SettingID
	FROM dbo.strSplit(@StationID,',')

	INSERT INTO	@tblComm(CommID)
	SELECT SettingID
	FROM dbo.strSplit(@CommunicationID,',')

	DECLARE	@FeedbackID INT;

	SELECT @MainCategoryID	 = Stuff((SELECT DISTINCT ',' + CAST(MainCategoryID AS VARCHAR(50))
                 FROM  @tblCategory fs									
                 FOR XML PATH('')), 1, 1, '')
		
	SELECT @SubCategoryID = Stuff((SELECT DISTINCT ',' + CAST(SubCategoryID AS VARCHAR(50))
                 FROM  @tblCategory fs 				
                 FOR XML PATH('')), 1, 1, '')
		
	SELECT @ProductID = Stuff((SELECT DISTINCT ',' + CAST(fs.ProductID AS VARCHAR(50))
                 FROM  @tblProduct fs							
                 FOR XML PATH('')), 1, 1, '')

	SELECT @SubProductID = Stuff((SELECT DISTINCT ',' + CAST(fs.SubProductID AS VARCHAR(50))
                 FROM  @tblProduct fs				
                 FOR XML PATH('')), 1, 1, '')

	SELECT @BettypeID = Stuff((SELECT DISTINCT ',' + CAST(fs.BetTypeID AS VARCHAR(50))
                 FROM  @tblProduct fs 								
                 FOR XML PATH('')), 1, 1, '')

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

	SELECT @Description= (SELECT @AutoField AS AutoField, @Description AS Remark  FOR XML RAW,ROOT('ROOT'))
	
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
				,	SiteID
				,	RoleID			
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
				,	ProvinceID
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
		,	@SiteID
		,	@RoleID		
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
		,	@BBM
		,	@ProvinceID

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

	INSERT INTO dbo.crmFeedbackSetting(FeedbackID,SettingID,SubSettingID,SubSettingIDLevel3)
	SELECT @FeedbackID,MainCategoryID,ISNULL(SubCategoryID,0),0
	FROM @tblCategory

	IF	@@ERROR <> 0
	BEGIN
		-- rollback
		DELETE FROM crmFeedback WHERE FeedbackID = @FeedbackID;
		DELETE FROM crmFeedbackCustomer WHERE FeedbackID = @FeedbackID;
		DELETE FROM crmFeedbackSetting WHERE FeedbackID = @FeedbackID;
		SELECT	@ErrCode = 103
			,	@ErrMsg = 'Insert feedback unsuccessfuly.';

		RETURN;
	END;

	INSERT INTO dbo.crmFeedbackSetting(FeedbackID,SettingID,SubSettingID,SubSettingIDLevel3)
	SELECT @FeedbackID,ProductID,ISNULL(SubProductID,0),ISNULL(BetTypeID,0)
	FROM @tblProduct
	IF	@@ERROR <> 0
	BEGIN
		-- rollback
		DELETE FROM crmFeedback WHERE FeedbackID = @FeedbackID;
		DELETE FROM crmFeedbackCustomer WHERE FeedbackID = @FeedbackID;
		DELETE FROM crmFeedbackSetting WHERE FeedbackID = @FeedbackID;
		SELECT	@ErrCode = 103
			,	@ErrMsg = 'Insert feedback unsuccessfuly.';

		RETURN;
	END;

	INSERT INTO dbo.crmFeedbackSetting(FeedbackID,SettingID,SubSettingID,SubSettingIDLevel3)
	SELECT @FeedbackID,StationID,0,0
	FROM @tblStation
	IF	@@ERROR <> 0
	BEGIN
		-- rollback
		DELETE FROM crmFeedback WHERE FeedbackID = @FeedbackID;
		DELETE FROM crmFeedbackCustomer WHERE FeedbackID = @FeedbackID;
		DELETE FROM crmFeedbackSetting WHERE FeedbackID = @FeedbackID;
		SELECT	@ErrCode = 103
			,	@ErrMsg = 'Insert feedback unsuccessfuly.';

		RETURN;
	END;
	INSERT INTO dbo.crmFeedbackSetting(FeedbackID,SettingID,SubSettingID,SubSettingIDLevel3)
	SELECT @FeedbackID,CommID,0,0
	FROM @tblComm
	IF	@@ERROR <> 0
	BEGIN
		-- rollback
		DELETE FROM crmFeedback WHERE FeedbackID = @FeedbackID;
		DELETE FROM crmFeedbackCustomer WHERE FeedbackID = @FeedbackID;
		DELETE FROM crmFeedbackSetting WHERE FeedbackID = @FeedbackID;
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
						'<CommunicationID>'				+ ISNULL(@CommunicationID,'')									+ '</CommunicationID>' +
						'<StationID>'					+ ISNULL(@StationID,'')											+ '</StationID>' +
						'<MainCategoryID>'				+ ISNULL(@MainCategoryID,'')									+ '</MainCategoryID>' +		
						'<SubCategoryID>'				+ ISNULL(@SubCategoryID,'')										+ '</SubCategoryID>' +		
						'<ProductID>'					+ ISNULL(@ProductID,'')											+ '</ProductID>' +		
						'<SubProductID>'				+ ISNULL(@SubProductID,'')										+ '</SubProductID>' +		
						'<BettypeID>'					+ ISNULL(@BettypeID,'')											+ '</BettypeID>' +		
						'<SiteID>'						+ ISNULL(CONVERT(VARCHAR(10),@SiteID),'')						+ '</SiteID>' +
						'<RoleID>'						+ ISNULL(CONVERT(VARCHAR(10),@RoleID),'')						+ '</RoleID>' +						
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
						'<Remark>'						+ ISNULL(dbo.f_EncodeXMLValue(@Remark),'')						+ '</Remark>' +
						'<AutoField>'					+ ISNULL(dbo.f_EncodeXMLValue(@AutoField),'')				+ '</AutoField>' +
						'<Solution>'					+ ISNULL(dbo.f_EncodeXMLValue(@Solution),'')					+ '</Solution>' +
						'<LicenseeType>'				+ ISNULL(CONVERT(VARCHAR(10),@LicenseeType),'')					+ '</LicenseeType>' +
						'<WhatsApp>'					+ ISNULL(dbo.f_EncodeXMLValue(@WhatsApp),'')					+ '</WhatsApp>' +
						'<Line>'						+ ISNULL(dbo.f_EncodeXMLValue(@Line),'')						+ '</Line>' +
						'<WeChat>'						+ ISNULL(dbo.f_EncodeXMLValue(@WeChat),'')						+ '</WeChat>' +
						'<Yahoo>'						+ ISNULL(dbo.f_EncodeXMLValue(@Yahoo),'')						+ '</Yahoo>' +
						'<QQ>'							+ ISNULL(dbo.f_EncodeXMLValue(@QQ),'')							+ '</QQ>' +
						'<BBM>'							+ ISNULL(dbo.f_EncodeXMLValue(@BBM),'')							+ '</BBM>' +
						'<ProvinceID>'					+ ISNULL(@ProvinceID,'')										+ '</ProvinceID>' +
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
