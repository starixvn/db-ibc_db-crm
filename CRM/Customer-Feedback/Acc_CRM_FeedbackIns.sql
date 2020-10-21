/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_FeedbackIns] (
					@UserID						INT
				,	@CustID						INT				
				,	@UserName					NVARCHAR(50)
				,	@TitleID					INT				= NULL
				,	@Birthday					DATETIME		= NULL
				,	@FirstName					NVARCHAR(50)	= NULL
				,	@LastName					NVARCHAR(50)	= NULL
				,	@Phone						NVARCHAR(100)	= NULL
				,	@PhoneCountryCode			NVARCHAR(40)	= NULL
				,	@PhoneAreaCode				NVARCHAR(40)	= NULL
				,	@Phone2						NVARCHAR(100)	= NULL
				,	@Phone2CountryCode			NVARCHAR(40)	= NULL
				,	@Phone2AreaCode				NVARCHAR(40)	= NULL
				,	@Phone3						NVARCHAR(100)	= NULL
				,	@Phone3CountryCode			NVARCHAR(40)	= NULL
				,	@Phone3AreaCode				NVARCHAR(40)	= NULL
				,	@MobilePhone				NVARCHAR(100)	= NULL
				,	@MobilePhoneCountryCode		NVARCHAR(40)	= NULL
				,	@MobilePhoneAreaCode		NVARCHAR(40)	= NULL
				,	@Fax						NVARCHAR(50)	= NULL
				,	@FaxCountryCode				NVARCHAR(40)	= NULL
				,	@FaxAreaCode				NVARCHAR(40)	= NULL
				,	@Email						NVARCHAR(254)	= NULL
				,	@Skype						NVARCHAR(100)	= NULL
				,	@MSN						NVARCHAR(100)	= NULL
				,	@LanguageID					INT				= NULL
				,	@CountryID					INT				= NULL	
				,	@Pic1						NVARCHAR(100)	= NULL
				,	@Pic2						NVARCHAR(100)	= NULL
				,	@Pic3						NVARCHAR(100)	= NULL
				,	@Pic4						NVARCHAR(100)	= NULL
				,	@Pic1Name					NVARCHAR(100)	= NULL
				,	@Pic2Name					NVARCHAR(100)	= NULL
				,	@Pic3Name					NVARCHAR(100)	= NULL
				,	@Pic4Name					NVARCHAR(100)	= NULL
				,	@Passport					NVARCHAR(100)	= NULL
				,	@BettingCode				NVARCHAR(100)	= NULL			
				,	@RefCode2					NVARCHAR(100)	= NULL
				,	@IsVip						BIT				= 0
				,	@SiteID						INT				= NULL
				,	@CreatorID					INT
				,	@Subject					NVARCHAR(200)	= NULL
				,	@FeedbackDate				DATETIME
				,	@ResolutionDate				DATETIME
				,	@CommunicationID			VARCHAR(MAX)	
				,	@StationID					VARCHAR(MAX)	
				,	@Category					VARCHAR(MAX)		
				,	@Product					VARCHAR(MAX)						
				,	@RoleID						INT											
				,	@ResponseID					INT
				,	@StatusID					INT
				,	@RelatedCustID				VARCHAR(MAX)	= NULL
				,	@Description				NVARCHAR(MAX)	= NULL
				,	@AutoField					NVARCHAR(MAX)	= NULL
				,	@Solution					NVARCHAR(MAX)	= NULL
				,	@IsReviewed					BIT				= 0
				,	@Review						NVARCHAR(MAX)	= NULL
				,	@ReviewerID					INT				= NULL
				,	@ProvinceID					INT				= NULL
				,	@LicenseeType				INT				= 0
				,	@WhatsApp					NVARCHAR(100)	= NULL
				,	@Line						NVARCHAR(100)	= NULL
				,	@WeChat						NVARCHAR(100)	= NULL
				,	@Yahoo						NVARCHAR(100)	= NULL
				,	@QQ							NVARCHAR(100)	= NULL
				,	@BBM						NVARCHAR(100)	= NULL
				,	@IP							VARCHAR(15)
				,	@ErrCode					INT				= 0		OUTPUT
				,	@ErrMsg						NVARCHAR(4000)	= ''	OUTPUT	
				,	@NoInquiries				SMALLINT		= NULL
				, 	@MessageID 					INT 			= 0
				,	@WinLimitLogID				BIGINT			= 0	
				, 	@RequestIDs					VARCHAR(1000)	= ''
				,	@ListOrigCustIDs			VARCHAR(MAX)	= ''
				)
AS
/*
	Created:	Lukas
	Date:		20101023
	Task :		insert feedback
	DB:			DB052.bodb_CRM
	Original:

	Revisions:
		- 20110629@Lukas:	support multiple feedback related customer
		- 20120307@Elodie:	add 3 params @Pic1, @Pic3, @Pic3
		- 20120314@Elodie:	check condition that feedback related customer must be different to customer of feedback
		- 20120319@Elodie:	change DB06 to DB052
		- 20120327@Elodie:	change data type of @Pic1, @Pic2, @Pic3 params to NVARCHAR(100)
		- 20120418@Elodie:	change default value of @RelatedCustID param to NULL value
		- 20120529@Elodie:	encode some parameters to write log in XML format, such as Pic1, Pic2, Pic3
		- 20131108@Kathy:	check required fields update to zero Redmine:#7206
		- 20140303@Dom:		Modify for new structure
		- 20141118@Dom:		get more fields of communication tool
		- 20160308@Billy:	Integrate Sub-Product field - Redmine: #52998
		- 20180117@Winnie:	Add Is Related Customer - [Redmine: #88774]
		- 20171222@Winnie:  Allow users to select multiple products/sub-categories - Redmine: #84714
		- 20190506@Winnie:  CN88 Permission RedmineID: #112637
		- 20190719@Winnie:  CRM - Remove limit Is Related Customer RedmineID: #113305
		- 20190923@Winnie: CRM - Include no. of Inquiries in Feedbacks RedmineID: #120596
		- 20200603@Johnson: check duplicate feedback from auto service [redmine: #135337]
		- 20200615@Johnson: check missing feedback from auto service [redmine: #135719]
		- 20200901@Johnson: add requestid to check missing auto void request [redmine:#139158]	
		- 20201020@Johnson: add WinlimitLogid for auto feedback company win limit
							and remove limit amount for related customers[redmine:#142194]
	Param's Explanation:
	@Product:
		<ROOT>
		<Product       
			ProductID="212" 
			SubProductID="2401" 
			BettypeID="1,2,3,4,5"
		/>
		</ROOT>
	@Category:
		<ROOT>
			<Category       
			  MainCategoryID="212" 
			  SubCategoryID="2401"      
			/>
		</ROOT>
	@MessageID : MsgID from Auto fb service
	@WinLimitLogID: LogID from winlimit auto fb service, process 1 logid with 1 headline
	@ListOrigCustIDs: list custid have void tickets from auto fb service	
*/
BEGIN	
	SET NOCOUNT ON;

	DECLARE	@FeedbackID						INT
		,	@SolveDate						DATETIME			
		,	@Remark							NVARCHAR(MAX)
		,	@MainCategoryID					VARCHAR(MAX)
		,	@SubCategoryID					VARCHAR(MAX)		
		,	@ProductID						VARCHAR(MAX)
		,	@SubProductID					VARCHAR(MAX)
		,	@BettypeID						VARCHAR(MAX)
		, 	@StartRun						DATETIME
		,	@Duration						INT
	
	SELECT @StartRun = GETDATE()	
	SELECT @Remark = @Description		
	SELECT @Description= (SELECT @AutoField AS AutoField, @Description AS Remark  FOR XML RAW,ROOT('ROOT'))

	SELECT	@ErrCode	= 0
		,	@ErrMsg		= '';
	
	IF	NOT EXISTS (SELECT 1 FROM crmCustomer WITH (NOLOCK) WHERE CustID = @CustID)
	BEGIN
		SELECT	@ErrCode = 101
			,	@ErrMsg = 'Customer does not exist.';

		RETURN;
	END;	

	IF	ISNULL(@CommunicationID, '') = ''
	OR	ISNULL(@Category, '') = '' 	
	OR	ISNULL(@StatusID, 0) = 0 
	OR	ISNULL(@RoleID, 0) = 0
	OR	ISNULL(@ResponseID, 0) = 0
	OR	ISNULL(@StationID, '') = ''
	BEGIN
		SELECT	@ErrCode = 100
			,	@ErrMsg = 'Incorrect Data.';
		RETURN;
	END;

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

	-- get solve date
	SELECT	@SolveDate = CASE WHEN @IsReviewed = 0 THEN NULL ELSE GETDATE() END;

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
	
	--check msg from auto void service
	DECLARE @tmpOrigCustID TABLE (custid INT)
	DECLARE @tmpRequest TABLE (RequestID INT)
		
	IF @MessageID > 0
	BEGIN
		INSERT INTO @tmpRequest(requestID)
		SELECT val 
		FROM dbo.f_CRM_strSplit(@RequestIDs,',')
		
		INSERT INTO @tmpOrigCustID(custid)
		SELECT	CONVERT(INT, val)
		FROM	dbo.f_CRM_strSplit(@ListOrigCustIDs, ',');
		
		--check fb for these custids base on voiding tickets create yet
		IF EXISTS (SELECT 1 FROM crmAutoFeedbackInfo WITH(NOLOCK)
					WHERE MessageID = @MessageID
						AND RequestID IN (SELECT RequestID FROM @tmpRequest)
						AND	HeadlineID = @custid
						AND CustID IN (SELECT custid FROM @tmpOrigCustID)
						AND status = 'completed'
				)
		RETURN;		
	END
	
	IF @WinLimitLogID > 0
	BEGIN
		--check fb for LogId create yet
		IF EXISTS (SELECT 1 FROM crmWinLimitFeedbackInfo WITH(NOLOCK)
					WHERE LogID = @WinLimitLogID
						AND status = 'completed'
				)
		RETURN;		
	END
	
	-- insert feedback
	INSERT INTO	crmFeedback (
					CustID
				,	TitleID
				,	Birthday
				,	FirstName
				,	LastName
				,	Phone
				,	PhoneCountryCode
				,	PhoneAreaCode
				,	Phone2
				,	Phone2CountryCode
				,	Phone2AreaCode
				,	Phone3
				,	Phone3CountryCode
				,	Phone3AreaCode
				,	MobilePhone
				,	MobilePhoneCountryCode
				,	MobilePhoneAreaCode
				,	Fax
				,	FaxCountryCode
				,	FaxAreaCode
				,	Email
				,	Skype
				,	MSN
				,	LanguageID
				,	CountryID
				,	Pic1
				,	Pic2
				,	Pic3
				,	Pic4
				,	Pic1Name
				,	Pic2Name
				,	Pic3Name
				,	Pic4Name
				,	Passport
				,	RefCode1
				,	RefCode2
				,	IsVip
				,	CreatorID
				,	CreateDate
				,	Subject
				,	FeedbackDate
				,	ResolutionDate		
				,	RoleID			
				,	ResponseID
				,	StatusID
				,	Description
				,	Solution
				,	IsReviewed
				,	Review
				,	ReviewerID
				,	SiteID
				,	LicenseeType
				,	WhatsApp
				,	Line
				,	WeChat
				,	Yahoo
				,	QQ
				,	BBM
				,	ProvinceID
				,	Inquiries
				)
	VALUES	(	@CustID
			,	@TitleID
			,	@Birthday
			,	@FirstName
			,	@LastName
			,	@Phone
			,	@PhoneCountryCode
			,	@PhoneAreaCode
			,	@Phone2
			,	@Phone2CountryCode
			,	@Phone2AreaCode
			,	@Phone3
			,	@Phone3CountryCode
			,	@Phone3AreaCode
			,	@MobilePhone
			,	@MobilePhoneCountryCode
			,	@MobilePhoneAreaCode
			,	@Fax
			,	@FaxCountryCode
			,	@FaxAreaCode
			,	@Email
			,	@Skype
			,	@MSN
			,	@LanguageID
			,	@CountryID
			,	@Pic1
			,	@Pic2
			,	@Pic3
			,	@Pic4
			,	@Pic1Name
			,	@Pic2Name
			,	@Pic3Name
			,	@Pic4Name
			,	@Passport
			,	@BettingCode
			,	@RefCode2
			,	@IsVip
			,	@CreatorID
			,	GETDATE()
			,	@Subject
			,	@FeedbackDate
			,	@ResolutionDate			
			,	@RoleID
			,	@ResponseID
			,	@StatusID
			,	@Description
			,	@Solution
			,	@IsReviewed
			,	@Review
			,	@ReviewerID
			,	@SiteID
			,	@LicenseeType
			,	@WhatsApp
			,	@Line
			,	@WeChat
			,	@Yahoo
			,	@QQ
			,	@BBM
			,   @ProvinceID
			,	@NoInquiries
			);
	IF @@ERROR <> 0
	BEGIN
		SELECT	@ErrCode = 102
			,	@ErrMsg = 'Insert feedback unsuccessfuly.';
		RETURN;
	END;

	-- insert to crmFeedback customer
	SELECT	@FeedbackID = @@identity;	
	INSERT INTO crmFeedbackCustomer	(
					FeedbackID
				,	CustID
				,	IsRelated
				)
	VALUES	(	@FeedbackID
			,	@CustID
			,	0
			);
	IF	@@ERROR <> 0
	BEGIN
		-- rollback
		DELETE FROM crmFeedback WHERE FeedbackID = @FeedbackID;

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

		INSERT INTO	@relatedCustomer
		SELECT	CONVERT(INT, val)
		FROM	dbo.f_CRM_strSplit(@RelatedCustID, ',');

		-- insert feedback related
		INSERT INTO	crmFeedbackCustomer
					(	FeedbackID, CustID, IsRelated)	
		SELECT DISTINCT @FeedbackID, CustID, 1
		FROM	@relatedCustomer
		WHERE	CustID <> @CustID;

		IF	@@ERROR <> 0
		BEGIN
			-- rollback
			DELETE FROM crmFeedback WHERE FeedbackID = @FeedbackID;
			DELETE FROM crmFeedbackCustomer WHERE FeedbackID = @FeedbackID;
			DELETE FROM crmFeedbackSetting WHERE FeedbackID = @FeedbackID;
			SELECT	@ErrCode = 105
				,	@ErrMsg = 'Insert feedback unsuccessfuly.';

			RETURN;
		END;
	END;	
	
	--update status for crmAutoFeedbackInfo 
	IF  @MessageID > 0
	BEGIN
		UPDATE fb
		SET status = 'completed',
			UpdatedTime = GETDATE()
		FROM crmAutoFeedbackInfo fb WITH(UPDLOCK,ROWLOCK)
		WHERE MessageID = @MessageID
			AND RequestID IN (SELECT requestID FROM @tmpRequest)
			AND	HeadlineID = @custid
			AND CustID IN (SELECT custid FROM @tmpOrigCustID)			
		
		IF	@@ERROR <> 0
		BEGIN
			-- rollback
			DELETE FROM crmFeedback WHERE FeedbackID = @FeedbackID;
			DELETE FROM crmFeedbackCustomer WHERE FeedbackID = @FeedbackID;
			DELETE FROM crmFeedbackSetting WHERE FeedbackID = @FeedbackID;
			SELECT	@ErrCode = 105
				,	@ErrMsg = 'Insert feedback unsuccessfuly.';

			RETURN;
		END;
		
		UPDATE crmMessageImport WITH(UPDLOCK,ROWLOCK)
		SET isProcessed = 1		
		WHERE MessageID = @MessageID
			AND RequestID IN (SELECT requestID FROM @tmpRequest)
			AND isProcessed = 0

		IF	@@ERROR <> 0
		BEGIN
			-- rollback
			DELETE FROM crmFeedback WHERE FeedbackID = @FeedbackID;
			DELETE FROM crmFeedbackCustomer WHERE FeedbackID = @FeedbackID;
			DELETE FROM crmFeedbackSetting WHERE FeedbackID = @FeedbackID;
			SELECT	@ErrCode = 105
				,	@ErrMsg = 'Insert feedback unsuccessfuly.';

			RETURN;
		END;	
	END
	
	IF @WinLimitLogID > 0
	BEGIN
		UPDATE crmWinLimitFeedbackInfo WITH(UPDLOCK,ROWLOCK)
		SET Status = 'completed',
			UpdatedTime = GETDATE()
		WHERE LogID = @WinLimitLogID
		
		IF	@@ERROR <> 0
		BEGIN
			-- rollback
			DELETE FROM crmFeedback WHERE FeedbackID = @FeedbackID;
			DELETE FROM crmFeedbackCustomer WHERE FeedbackID = @FeedbackID;
			DELETE FROM crmFeedbackSetting WHERE FeedbackID = @FeedbackID;
			SELECT	@ErrCode = 105
				,	@ErrMsg = 'Insert feedback unsuccessfuly.';

			RETURN;
		END;
	END
	
	-- write log
	DECLARE @LogElement XML;

	SELECT @LogElement = 				
					'<Acc_CRM_FeedbackIns>' + --SP Name
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
						'<IsReviewed>'					+ ISNULL(CONVERT(VARCHAR(5),@IsReviewed),'')					+ '</IsReviewed>' +
						'<Reviewer>'					+ ISNULL(CONVERT(VARCHAR(10),@ReviewerID),'')					+ '</Reviewer>' +						
						'<Pic1>'						+ ISNULL(dbo.f_EncodeXMLValue(@Pic1),'')						+ '</Pic1>' +
						'<Pic2>'						+ ISNULL(dbo.f_EncodeXMLValue(@Pic2),'')						+ '</Pic2>' +
						'<Pic3>'						+ ISNULL(dbo.f_EncodeXMLValue(@Pic3),'')						+ '</Pic3>' +
						'<Pic4>'						+ ISNULL(dbo.f_EncodeXMLValue(@Pic4),'')						+ '</Pic4>' +
						'<Pic1Name>'					+ ISNULL(dbo.f_EncodeXMLValue(@Pic1Name),'')					+ '</Pic1Name>' +
						'<Pic2Name>'					+ ISNULL(dbo.f_EncodeXMLValue(@Pic2Name),'')					+ '</Pic2Name>' +
						'<Pic3Name>'					+ ISNULL(dbo.f_EncodeXMLValue(@Pic3Name),'')					+ '</Pic3Name>' +
						'<Pic4Name>'					+ ISNULL(dbo.f_EncodeXMLValue(@Pic4Name),'')					+ '</Pic4Name>' +
						'<Passport>'					+ ISNULL(dbo.f_EncodeXMLValue(@Passport),'')					+ '</Passport>' +
						'<Remark>'						+ ISNULL(dbo.f_EncodeXMLValue(@Remark),'')						+ '</Remark>' +
						'<AutoField>'					+ ISNULL(dbo.f_EncodeXMLValue(@AutoField),'')					+ '</AutoField>' +
						'<LicenseeType>'				+ ISNULL(CONVERT(VARCHAR(10),@LicenseeType),'')					+ '</LicenseeType>' +
						'<WhatsApp>'					+ ISNULL(dbo.f_EncodeXMLValue(@WhatsApp),'')					+ '</WhatsApp>' +
						'<Line>'						+ ISNULL(dbo.f_EncodeXMLValue(@Line),'')						+ '</Line>' +
						'<WeChat>'						+ ISNULL(dbo.f_EncodeXMLValue(@WeChat),'')						+ '</WeChat>' +
						'<Yahoo>'						+ ISNULL(dbo.f_EncodeXMLValue(@Yahoo),'')						+ '</Yahoo>' +
						'<QQ>'							+ ISNULL(dbo.f_EncodeXMLValue(@QQ),'')							+ '</QQ>' +
						'<BBM>'							+ ISNULL(dbo.f_EncodeXMLValue(@BBM),'')							+ '</BBM>' +
						'<ProvinceID>'					+ ISNULL(CONVERT(VARCHAR(20),@ProvinceID),'')					+ '</ProvinceID>' +	
						'<NoInquiries>'					+ ISNULL(CONVERT(VARCHAR(20),@NoInquiries),'')					+ '</NoInquiries>' +	
					'</Acc_CRM_FeedbackIns>';

	SELECT @Duration = DATEDIFF (millisecond,@startRun,GETDATE())
	
	EXECUTE	dbo.WriteLog_UserLog_crmLogFeedback
				@UserID = @UserID
			,	@FeedbackID = @FeedbackID
			,	@CustID = @CustID
			,	@ActionID = 200
			,	@IP = @IP
			,	@Description = @Description
			,	@Solution = @Solution
			,	@Review =  @Review
			,	@NewValues = @LogElement
			, 	@Duration = @Duration
END;
GO
