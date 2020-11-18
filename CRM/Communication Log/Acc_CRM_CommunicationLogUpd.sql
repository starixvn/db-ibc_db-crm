/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_CommunicationLogUpd]
					@FeedbackID				INT
				,	@CustID					INT
				,	@RelatedCustID			VARCHAR(MAX)	= NULL
				,	@LanguageID				INT
				,	@CountryID				INT
				,	@FeedbackDate			DATETIME
				,	@ResolutionDate			DATETIME
				,	@CommunicationID		VARCHAR(MAX)	
				,	@StationID				VARCHAR(MAX)	
				,	@Category				VARCHAR(MAX)		
				,	@Product				VARCHAR(MAX)
				,	@SiteID					INT
				,	@RoleID					INT				
				,	@ResponseID				INT
				,	@StatusID				INT
				,	@UpdateReviewedMode		TINYINT = 0
				,	@Description			NVARCHAR(MAX)
				,	@AutoField				NVARCHAR(MAX)	= NULL
				,	@Solution				NVARCHAR(MAX)
				,	@IsReviewed				BIT
				,	@Review					NVARCHAR(MAX)	= NULL
				,	@ReviewerID				INT
				,	@Subject				NVARCHAR(200)
				,	@LicenseeType			INT				= 0
				,	@UserID					INT
				,	@IP						VARCHAR(15)
				,	@ProvinceID				INT=NULL
				,	@ErrCode				INT				= 0			OUTPUT
				,	@ErrMsg					NVARCHAR(4000)	= ''		OUTPUT
				,	@NoInquiries			SMALLINT		= NULL
AS
/*
	Created:	20140127@Dom
	Task:		Insert new customer log
	DB:			DBCRM.bodb_CRM
	Original:

	Revisions:
		- 20141118@Dom:		add more fields of communication tool
		- 20160308@Billy:	Integrate Sub-Product field - [Redmine: #52998]
		- 20180117@Winnie:	Add Is Related Customer - [Redmine: #88774]
		- 20180405@Winnie:  Allow users to select multiple products/sub-categories - Redmine: #84714
		- 20190506@Winnie: CN88 Province RedmineID: #112637
		- 20190719@Winnie: Limit Related Customer RedmineID:#113305
		- 20190923@Winnie: CRM - Include no. of Inquiries in Feedbacks RedmineID: #120596
		- 20201102@Johnson: - remove limit amount for related customers
							- sync customer profile to CRM for related customers [redmine:#142194]
	Param's Explanation:
*/
BEGIN
	IF	ISNULL(@CommunicationID, '') = '' 
	OR	ISNULL(@Product, '') = '' 
	OR	ISNULL(@Category, '') = ''
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

	
	DECLARE  @tblFbSetting TABLE(		
		SettingID			INT
		,SubSettingID		INT 	
		,SubSettingIDLevel3	INT 	
	)

	DECLARE @Remark		NVARCHAR(MAX);
	SELECT @Remark = @Description
	-- Read XML
	DECLARE	@iDoc			INT;
	EXECUTE sys.sp_xml_preparedocument @iDoc OUTPUT, @Category;

	INSERT INTO	@tblFbSetting
		( SettingID,SubSettingID,SubSettingIDLevel3)
	SELECT	ox.MainCategoryID, ox.SubCategoryID,0
	FROM	OPENXML(@iDoc, '/ROOT/Category', 1)
			WITH (		
				MainCategoryID				INT
			,	SubCategoryID				INT					
			) AS ox;

	EXECUTE sys.sp_xml_removedocument @iDoc;	

	EXECUTE sys.sp_xml_preparedocument @iDoc OUTPUT, @Product;

	INSERT INTO	@tblFbSetting
		( SettingID,SubSettingID,SubSettingIDLevel3)		
	SELECT	ox.ProductID, ox.SubProductID,ox.BetTypeID
	FROM	OPENXML(@iDoc, '/ROOT/Product', 1)
			WITH (		
				ProductID				INT
			,	SubProductID			INT	
			,	BetTypeID				INT
			) AS ox;

	EXECUTE sys.sp_xml_removedocument @iDoc;

	INSERT INTO	@tblFbSetting
	( SettingID,SubSettingID,SubSettingIDLevel3)	
	SELECT SettingID,0,0
	FROM dbo.strSplit(@StationID,',')

	INSERT INTO	@tblFbSetting
	( SettingID,SubSettingID,SubSettingIDLevel3)	
	SELECT SettingID,0,0
	FROM dbo.strSplit(@CommunicationID,',')

	SELECT @Description= (SELECT @AutoField AS AutoField, @Description AS Remark  FOR XML RAW,ROOT('ROOT'))

	DECLARE	@relatedCustomer TABLE(CustID INT, 								
									username VARCHAR(50),
									FirstName NVARCHAR(100),
									LastName NVARCHAR(100),
									phone NVARCHAR(100),
									MobilePhone NVARCHAR(100),
									Fax NVARCHAR(100),
									Email NVARCHAR(100),
									Birthday SMALLDATETIME,
									CountryID INT,
									SiteID INT,
									isExistsCRM BIT DEFAULT(0), 
									isFinished BIT DEFAULT(0));

	INSERT INTO @relatedCustomer(CustID)
	SELECT	CONVERT(INT, val)
	FROM	dbo.f_CRM_strSplit(@RelatedCustID, ',');

	DECLARE	@CustID_Old					INT
		,	@RelatedCustID_Old			VARCHAR(MAX)
		,	@LanguageID_Old				INT
		,	@CountryID_Old				INT
		,	@ResolutionDate_Old			DATETIME
		,	@FeedbackDate_Old			DATETIME
		,	@CommunicationID_Old		VARCHAR(MAX)
		,	@StationID_Old				VARCHAR(MAX)
		,	@MainCategoryID_Old			VARCHAR(MAX)
		,	@SubCategoryID_Old			VARCHAR(MAX)
		,	@MainCategoryID_New			VARCHAR(MAX)
		,	@SubCategoryID_New			VARCHAR(MAX)
		,	@SiteID_Old					INT
		,	@RoleID_Old					INT
		,	@ProductID_Old				VARCHAR(MAX)
		,	@SubProductID_Old			VARCHAR(MAX)
		,	@BetTypeID_Old				VARCHAR(MAX)
		,	@ProductID_New				VARCHAR(MAX)
		,	@SubProductID_New			VARCHAR(MAX)
		,	@BetTypeID_New				VARCHAR(MAX)
		,	@ResponseID_Old				INT
		,	@StatusID_Old				INT
		,	@Description_Old			NVARCHAR(MAX)
		,	@AutoField_Old				NVARCHAR(MAX)
		,	@Remark_Old					NVARCHAR(MAX)
		,	@Solution_Old				NVARCHAR(MAX)
		,	@IsReviewed_Old				BIT
		,	@Review_Old					NVARCHAR(4000)
		,	@ReviewerID_Old				INT
		,	@Subject_Old				NVARCHAR(200)
		,	@SolveDate_Old				DATETIME
		,	@LicenseeType_Old			INT
		,	@NoInquiries_Old			SMALLINT
		,	@ProvinceID_Old				INT;

	SELECT	@CustID_Old				= CustID		
		,	@CountryID_Old			= CountryID
		,	@LanguageID_Old			= LanguageID
		,	@ResolutionDate_Old		= ResolutionDate
		,	@FeedbackDate_Old		= FeedbackDate
		,	@SiteID_Old				= SiteID
		,	@RoleID_Old				= RoleID
		,	@ResponseID_Old			= ResponseID
		,	@StatusID_Old			= StatusID
		,	@Description_Old		= Description
		,	@Solution_Old			= Solution
		,	@IsReviewed_Old			= IsReviewed
		,	@Review_Old				= Review
		,	@ReviewerID_Old			= ReviewerID
		,	@Subject_Old			= Subject
		,	@SolveDate_Old			= SolveDate
		,	@LicenseeType_Old		= LicenseeType
		,	@ProvinceID_Old			= ProvinceID
		,	@NoInquiries_Old		= Inquiries
	FROM	crmFeedback WITH (NOLOCK)
	WHERE	FeedbackID = @FeedbackID;

	SELECT	@RelatedCustID_Old = '';

	SELECT	@RelatedCustID_Old = @RelatedCustID_Old + CAST(fbc.CustID AS VARCHAR(1000)) + ','
	FROM	dbo.crmFeedbackCustomer AS fbc WITH (NOLOCK)
	WHERE	fbc.FeedbackID = @FeedbackID
		AND	fbc.IsRelated = 1;

	IF	ISNULL(@RelatedCustID_Old, '') <> ''
		SELECT	@RelatedCustID_Old = LEFT(@RelatedCustID_Old, LEN(@RelatedCustID_Old) - 1);

	DECLARE	@SolveDate	DATETIME;

	IF	@IsReviewed_Old = 0 
	AND	@IsReviewed = 1
		SET	@ReviewerID = @UserID;

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

	DECLARE	@xmlDoc		XML
	DECLARE @iDoc2		INT
	SELECT @xmlDoc=CAST(@Description_Old AS XML)

	EXECUTE	sp_xml_preparedocument @iDoc2 OUTPUT, @xmlDoc;

	SELECT	@AutoField_Old=ox.AutoField,@Remark_Old=ox.Remark
	FROM OPENXML (@iDoc2, '/ROOT/row', 1) 
	WITH (
		AutoField		NVARCHAR(MAX)
	,	Remark			NVARCHAR(MAX)	
	) AS ox;
	

	SELECT @MainCategoryID_Old = Stuff((SELECT DISTINCT ',' + CAST(SettingID AS VARCHAR(50))
                 FROM  crmFeedbackSetting fs WITH(NOLOCK) 
					INNER JOIN crmMainCategory m WITH(NOLOCK) ON fs.SettingID=m.MainCategoryID
					WHERE FeedbackID=@FeedbackID
                 FOR XML PATH('')), 1, 1, '')
		
	SELECT SubCategoryID_Old = Stuff((SELECT DISTINCT ',' + CAST(SubSettingID AS VARCHAR(50))
                 FROM  crmFeedbackSetting fs WITH(NOLOCK) 
					INNER JOIN crmSubCategory m WITH(NOLOCK) ON fs.SubSettingID=m.SubCategoryID AND fs.SettingID=m.MainCategoryID
					WHERE FeedbackID=@FeedbackID
                 FOR XML PATH('')), 1, 1, '')
		
	SELECT @ProductID_Old = Stuff((SELECT DISTINCT ',' + CAST(fs.SettingID AS VARCHAR(50))
                 FROM  crmFeedbackSetting fs WITH(NOLOCK) 
					INNER JOIN crmSetting p WITH(NOLOCK) ON fs.SettingID=p.SettingID AND p.SettingName='Product'
					WHERE FeedbackID=@FeedbackID
                 FOR XML PATH('')), 1, 1, '')

	SELECT @SubProductID_Old = Stuff((SELECT DISTINCT ',' + CAST(fs.SubSettingID AS VARCHAR(50))
                 FROM  crmFeedbackSetting fs WITH(NOLOCK) 
					INNER JOIN crmSetting p WITH(NOLOCK) ON fs.SubSettingID=p.SettingID AND p.SettingName='SubProduct'
					WHERE FeedbackID=@FeedbackID
                 FOR XML PATH('')), 1, 1, '')

	SELECT @BettypeID_Old = Stuff((SELECT DISTINCT ',' + CAST(fs.SubSettingIDLevel3 AS VARCHAR(50))
                 FROM  crmFeedbackSetting fs WITH(NOLOCK) 
					INNER JOIN crmBettype p WITH(NOLOCK) ON fs.SubSettingIDLevel3=p.BettypeID
					WHERE FeedbackID=@FeedbackID
                 FOR XML PATH('')), 1, 1, '')
	
	SELECT @CommunicationID_Old = Stuff((SELECT DISTINCT ',' + CAST(fs.SettingID AS VARCHAR(50))
                 FROM  crmFeedbackSetting fs WITH(NOLOCK) 
					INNER JOIN crmCommunicationTool p WITH(NOLOCK) ON fs.SettingID=p.CommunicationID
					WHERE FeedbackID=@FeedbackID
                 FOR XML PATH('')), 1, 1, '')

	SELECT @StationID_Old = Stuff((SELECT DISTINCT ',' + CAST(fs.SettingID AS VARCHAR(50))
                FROM  crmFeedbackSetting fs WITH(NOLOCK) 
				INNER JOIN crmStation p WITH(NOLOCK) ON fs.SettingID=p.StationID
				WHERE FeedbackID=@FeedbackID
                FOR XML PATH('')), 1, 1, '')
	
	SELECT @MainCategoryID_New = Stuff((SELECT DISTINCT ',' + CAST(SettingID AS VARCHAR(50))
                 FROM  @tblFbSetting fs
					INNER JOIN crmMainCategory m WITH(NOLOCK) ON fs.SettingID=m.MainCategoryID					
                 FOR XML PATH('')), 1, 1, '')
		
	SELECT SubCategoryID_New = Stuff((SELECT DISTINCT ',' + CAST(SubSettingID AS VARCHAR(50))
                 FROM  @tblFbSetting fs  
					INNER JOIN crmSubCategory m WITH(NOLOCK) ON fs.SubSettingID=m.SubCategoryID AND fs.SettingID=m.MainCategoryID					
                 FOR XML PATH('')), 1, 1, '')
		
	SELECT @ProductID_New = Stuff((SELECT DISTINCT ',' + CAST(fs.SettingID AS VARCHAR(50))
                 FROM  @tblFbSetting fs
					INNER JOIN crmSetting p WITH(NOLOCK) ON fs.SettingID=p.SettingID AND p.SettingName='Product'				
                 FOR XML PATH('')), 1, 1, '')

	SELECT @SubProductID_New = Stuff((SELECT DISTINCT ',' + CAST(fs.SubSettingID AS VARCHAR(50))
                 FROM  @tblFbSetting fs
					INNER JOIN crmSetting p WITH(NOLOCK) ON fs.SubSettingID=p.SettingID AND p.SettingName='SubProduct'					
                 FOR XML PATH('')), 1, 1, '')

	SELECT @BetTypeID_New = Stuff((SELECT DISTINCT ',' + CAST(fs.SubSettingIDLevel3 AS VARCHAR(50))
                 FROM  @tblFbSetting fs 
					INNER JOIN crmBettype p WITH(NOLOCK) ON fs.SubSettingIDLevel3=p.BettypeID				
                 FOR XML PATH('')), 1, 1, '')

	UPDATE	crmFeedback WITH (ROWLOCK, UPDLOCK)
	SET	LanguageID			= @LanguageID
	,	CountryID			= @CountryID
	,	ResolutionDate		= @ResolutionDate
	,	FeedbackDate		= @FeedbackDate
	,	SiteID				= @SiteID
	,	RoleID				= @RoleID
	,	ResponseID			= @ResponseID
	,	StatusID			= @StatusID
	,	Description			= @Description
	,	Solution			= @Solution
	,	IsReviewed			= @IsReviewed
	,	Review				= @Review
	,	ReviewerID			= @ReviewerID
	,	Subject				= @Subject
	,	SolveDate			= @SolveDate
	,	LicenseeType		= @LicenseeType
	,	ProvinceID			= @ProvinceID
	,	Inquiries			= @NoInquiries
	WHERE	FeedbackID = @FeedbackID;
	IF	@@ERROR <> 0
	BEGIN
		-- Rollback
		SELECT	@ErrCode = 103
			,	@ErrMsg = 'Update feedback unsuccessfuly.';

		RETURN;
	END;
	
	DELETE FROM crmfeedbackSetting WHERE FeedbackID=@FeedbackID
	
	INSERT INTO crmfeedbackSetting(FeedbackID,SettingID,SubSettingID,SubSettingIDLevel3)
	SELECT @FeedbackID,t.SettingID,t.SubSettingID,t.SubSettingIDLevel3
	FROM @tblFbSetting t	

	IF	@@ERROR <> 0
	BEGIN
		SELECT	@ErrCode = 101
			,	@ErrMsg = 'updated feedback unsuccessfuly.';

		RETURN;
	END;	
		
	DELETE	crmFeedbackCustomer WITH(ROWLOCK, UPDLOCK)
	WHERE	FeedbackID = @FeedbackID
		AND	IsRelated = 1;

	-- Insert feedback related
	INSERT INTO crmFeedbackCustomer
				(	FeedbackID , CustID, IsRelated)	
	SELECT DISTINCT @FeedbackID, CustID, 1
	FROM	@relatedCustomer
	WHERE	CustID <> @CustID;

	IF	@@ERROR <> 0
	BEGIN	
		SELECT	@ErrCode = 105
			,	@ErrMsg = 'Update feedback unsuccessfuly.';

		RETURN;
	END;
	
	--Sync profile for related customers to CRM
	UPDATE t
	SET isExistsCRM = 1 
	FROM @relatedCustomer t
		INNER JOIN crmCustomer cm WITH(NOLOCK) ON t.custid = cm.custid
		
	IF EXISTS (SELECT 1 FROM @relatedCustomer WHERE isExistsCRM = 0)
	BEGIN
		DECLARE @r_CustID INT,
				@r_username VARCHAR(50),
				@r_FirstName NVARCHAR(100),
				@r_LastName NVARCHAR(100),
				@r_phone NVARCHAR(100),
				@r_MobilePhone NVARCHAR(100),
				@r_Fax NVARCHAR(100),
				@r_Email NVARCHAR(100),
				@r_Birthday SMALLDATETIME,
				@r_CountryID INT,
				@r_SiteID INT
			
		UPDATE t
		SET t.custid = c.custid,
			t.username = c.username,
			t.FirstName = c.FirstName,
			t.LastName = c.LastName, 
			t.phone = c.phone,
			t.MobilePhone = c.MobilePhone,
			t.Fax = c.Fax,
			t.Email = c.Email,
			t.Birthday = c.Birthday,
			t.CountryID = ct.CountryID,
			t.SiteID = (SELECT SettingID 
						FROM crmSetting WITH(NOLOCK) 
						WHERE SettingValue = ISNULL(c.site,ag.site)
							AND SettingName IN( 'Site','SiteCategory')
						)
		FROM @relatedCustomer t
			INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON t.custid = c.custid
			LEFT JOIN bodb02.dbo.Customer ag WITH(NOLOCK) ON c.recommend = ag.custid
			LEFT JOIN crmCountry ct ON c.country = ct.CountryName
		WHERE isExistsCRM = 0	
		
		WHILE (1=1)
		BEGIN 
			UPDATE TOP (1) t
			SET isFinished = 1,
				@r_Custid = custid,
				@r_username = username,
				@r_FirstName = FirstName,
				@r_LastName = LastName, 
				@r_phone = phone,
				@r_MobilePhone = MobilePhone,
				@r_Fax = Fax,
				@r_Email = Email,
				@r_Birthday = Birthday,
				@r_CountryID = CountryID,
				@r_SiteID = siteID
			FROM @relatedCustomer t
			WHERE isFinished = 0
				AND isExistsCRM = 0
				
			IF @@ROWCOUNT = 0
				BREAK;
				
			EXECUTE	dbo.Acc_CRM_CustomerIns_New
					@UserID					= @UserID
				,	@CustID					= @r_CustID
				,	@UserName				= @r_UserName
				,	@FirstName				= @r_FirstName
				,	@LastName				= @r_LastName			
				,	@Birthday				= @r_Birthday				
				,	@Phone					= @r_Phone	
				,	@MobilePhone			= @r_MobilePhone				
				,	@Fax					= @r_Fax				
				,	@Email					= @r_Email				
				,	@CountryID				= @r_CountryID				
				,	@SiteID					= @r_SiteID
				,	@CreatorID				= @UserID
				
				,	@IP						= @IP
				,	@ErrCode				= @ErrCode OUTPUT
				,	@ErrMsg					= @ErrMsg OUTPUT;
			IF @ErrCode <> 0
			BEGIN
				--SELECT @ErrCode = 100
				RETURN;
			END;	
		END
	END
	
	-- Write Log
	DECLARE	@NewValues	XML
		,	@OldValues	XML;
	
	SELECT	@OldValues = 				
					'<Acc_CRM_CommunicationLogUpd>' + 
							'<LanguageID>'					+ ISNULL(CONVERT(VARCHAR(10),@LanguageID_Old),'')					+ '</LanguageID>' +
							'<CountryID>'					+ ISNULL(CONVERT(VARCHAR(10),@CountryID_Old),'')					+ '</CountryID>' +
							'<Subject>'						+ ISNULL(dbo.f_EncodeXMLValue(@Subject_Old),'')						+ '</Subject>' +
							'<Remark>'						+ ISNULL(dbo.f_EncodeXMLValue(@Remark_Old),'')						+ '</Remark>' +
							'<AutoField>'					+ ISNULL(dbo.f_EncodeXMLValue(@AutoField_Old),'')					+ '</AutoField>' +
							'<Solution>'					+ ISNULL(dbo.f_EncodeXMLValue(@Solution_Old),'')					+ '</Solution>' +
							'<Review>'						+ ISNULL(dbo.f_EncodeXMLValue(@Review_Old),'')						+ '</Review>' +
							'<ResolutionDate>'				+ ISNULL(CONVERT(VARCHAR(20),@ResolutionDate_Old),'')				+ '</ResolutionDate>' +
							'<FeedbackDate>'				+ ISNULL(CONVERT(VARCHAR(20),@FeedbackDate_Old),'')					+ '</FeedbackDate>' +
							'<CommunicationID>'				+ ISNULL(@CommunicationID_Old,'')									+ '</CommunicationID>' +
							'<StationID>'					+ ISNULL(@StationID_Old,'')											+ '</StationID>' +
							'<MainCategoryID>'				+ ISNULL(@MainCategoryID_Old,'')									+ '</MainCategoryID>' +
							'<SubCategoryID>'				+ ISNULL(@SubCategoryID_Old,'')										+ '</SubCategoryID>' +
							'<SiteID>'						+ ISNULL(CONVERT(VARCHAR(10),@SiteID_Old),'')						+ '</SiteID>' +
							'<RoleID>'						+ ISNULL(CONVERT(VARCHAR(10),@RoleID_Old),'')						+ '</RoleID>' +
							'<ProductID>'					+ ISNULL(@ProductID_Old,'')											+ '</ProductID>' +
							'<SubProductID>'				+ ISNULL(@SubProductID_Old,'')										+ '</SubProductID>' +
							'<BettypeID>'					+ ISNULL(@BettypeID_Old,'')											+ '</BettypeID>' +
							'<ResponseID>'					+ ISNULL(CONVERT(VARCHAR(10),@ResponseID_Old),'')					+ '</ResponseID>' +
							'<StatusID>'					+ ISNULL(CONVERT(VARCHAR(10),@StatusID_Old),'')						+ '</StatusID>' +
							'<RelatedCustID>'				+ ISNULL(@RelatedCustID_Old,'')										+ '</RelatedCustID>' +
							'<IsReviewed>'					+ ISNULL(CONVERT(VARCHAR(5),@IsReviewed_Old),'')					+ '</IsReviewed>' +
							'<Reviewer>'					+ ISNULL(CONVERT(VARCHAR(10),@ReviewerID_Old),'')					+ '</Reviewer>' +	
							'<SolveDate>'					+ ISNULL(CONVERT(VARCHAR(20),@SolveDate_Old),'')					+ '</SolveDate>' +	
							'<LicenseeType>'				+ ISNULL(CONVERT(VARCHAR(10),@LicenseeType_Old),'')					+ '</LicenseeType>' +		
							'<ProvinceID>'					+ ISNULL(CONVERT(VARCHAR(20),@ProvinceID_Old),'')					+ '</ProvinceID>' +			
							'<NoInquiries>'					+ ISNULL(CONVERT(VARCHAR(20),@NoInquiries_Old),'')					+ '</NoInquiries>' +			
					'</Acc_CRM_CommunicationLogUpd>';
	 
	SELECT	@NewValues =
					'<Acc_CRM_CommunicationLogUpd>' + 
							'<LanguageID>'					+ ISNULL(CONVERT(VARCHAR(10),@LanguageID),'')					+ '</LanguageID>' +
							'<CountryID>'					+ ISNULL(CONVERT(VARCHAR(10),@CountryID),'')					+ '</CountryID>' +
							'<Subject>'						+ ISNULL(dbo.f_EncodeXMLValue(@Subject),'')						+ '</Subject>' +
							'<Remark>'						+ ISNULL(dbo.f_EncodeXMLValue(@Remark),'')						+ '</Remark>' +
							'<AutoField>'					+ ISNULL(dbo.f_EncodeXMLValue(@AutoField),'')					+ '</AutoField>' +
							'<Solution>'					+ ISNULL(dbo.f_EncodeXMLValue(@Solution),'')					+ '</Solution>' +
							'<Review>'						+ ISNULL(dbo.f_EncodeXMLValue(@Review),'')						+ '</Review>' +
							'<ResolutionDate>'				+ ISNULL(CONVERT(VARCHAR(20),@ResolutionDate),'')				+ '</ResolutionDate>' +
							'<FeedbackDate>'				+ ISNULL(CONVERT(VARCHAR(20),@FeedbackDate),'')					+ '</FeedbackDate>' +
							'<CommunicationID>'				+ ISNULL(@CommunicationID,'')									+ '</CommunicationID>' +
							'<StationID>'					+ ISNULL(@StationID,'')											+ '</StationID>' +
							'<MainCategoryID>'				+ ISNULL(@MainCategoryID_New,'')								+ '</MainCategoryID>' +
							'<SubCategoryID>'				+ ISNULL(@SubCategoryID_New,'')									+ '</SubCategoryID>' +
							'<SiteID>'						+ ISNULL(CONVERT(VARCHAR(10),@SiteID),'')						+ '</SiteID>' +
							'<RoleID>'						+ ISNULL(CONVERT(VARCHAR(10),@RoleID),'')						+ '</RoleID>' +
							'<ProductID>'					+ ISNULL(@ProductID_New,'')										+ '</ProductID>' +
							'<SubProductID>'				+ ISNULL(@SubProductID_New,'')									+ '</SubProductID>' +
							'<BettypeID>'					+ ISNULL(@BetTypeID_New,'')										+ '</BettypeID>' +
							'<ResponseID>'					+ ISNULL(CONVERT(VARCHAR(10),@ResponseID),'')					+ '</ResponseID>' +
							'<StatusID>'					+ ISNULL(CONVERT(VARCHAR(10),@StatusID),'')						+ '</StatusID>' +
							'<RelatedCustID>'				+ ISNULL(@RelatedCustID,'')										+ '</RelatedCustID>' +
							'<IsReviewed>'					+ ISNULL(CONVERT(VARCHAR(5), @IsReviewed),'')					+ '</IsReviewed>' +
							'<Reviewer>'					+ ISNULL(CONVERT(VARCHAR(10),@ReviewerID),'')					+ '</Reviewer>' +			
							'<SolveDate>'					+ ISNULL(CONVERT(VARCHAR(20),@SolveDate),'')					+ '</SolveDate>' +			
							'<LicenseeType>'				+ ISNULL(CONVERT(VARCHAR(10),@LicenseeType),'')					+ '</LicenseeType>' +
							'<ProvinceID>'					+ ISNULL(CONVERT(VARCHAR(20),@ProvinceID),'')					+ '</ProvinceID>' +		
							'<NoInquiries>'					+ ISNULL(CONVERT(VARCHAR(20),@NoInquiries),'')					+ '</NoInquiries>' +			
					'</Acc_CRM_CommunicationLogUpd>';
			
	EXECUTE	dbo.WriteLog_UserLog_crmLogFeedback
				@UserID = @UserID
			,	@FeedbackID = @FeedbackID
			,	@CustID = @CustID
			,	@ActionID = 203
			,	@IP = @IP
			,	@Description = @Description
			,	@Solution = @Solution
			,	@Review =  @Review
			,	@NewValues = @NewValues
			,	@OldValues = @OldValues;
END;
GO 

GRANT EXECUTE ON dbo.Acc_CRM_CommunicationLogUpd TO bodbAdminNet;
GO 
