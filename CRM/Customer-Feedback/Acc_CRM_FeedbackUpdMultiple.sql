/*<info serverAlias="DBCRM-bodb_CRM" executers="wsv_nap" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE [dbo].[Acc_CRM_FeedbackUpdMultiple] (
					@UserID						INT		
				  , @FeedbackID					INT	
				  , @CustID						INT
				  ,	@LanguageID					INT
				  ,	@IsUpdateLanguageID			BIT		
				  ,	@CountryID					INT
				  ,	@IsUpdateCountryID			BIT	
				  ,	@Subject					NVARCHAR(200)	= NULL
				  ,	@IsUpdateSubject			BIT
				  ,	@FeedbackDate				DATETIME
				  ,	@IsUpdateFeedbackDate		BIT
				  ,	@FirstResponseTime			DATETIME
				  ,	@IsUpdateFirstResponseTime	BIT
				  ,	@ResolutionDate				DATETIME	
				  ,	@IsUpdateResolutionDate		BIT		
				  ,	@SiteID						INT
				  ,	@IsUpdateSiteID				BIT	
				  ,	@RoleID						INT		
				  ,	@IsUpdateRoleID				BIT		
				  ,	@CommunicationID			VARCHAR(MAX)	
				  ,	@IsUpdateCommunicationID	BIT
				  ,	@StationID					VARCHAR(MAX)	
				  ,	@IsUpdateStationID			BIT
				  ,	@Category					VARCHAR(MAX)	
				  ,	@IsUpdateCategory			BIT	
				  ,	@Product					VARCHAR(MAX)	
				  ,	@IsUpdateProduct			BIT
				  ,	@ResponseID					INT
				  ,	@IsUpdateResponseID			BIT
				  ,	@StatusID					INT
				  ,	@IsUpdateStatusID			BIT	
				  ,	@Description				NVARCHAR(MAX)
				  ,	@IsUpdateDescription		BIT
				  ,	@AutoField					NVARCHAR(MAX)	=''
				  ,	@IsUpdateAutoField			BIT
				  ,	@Solution					NVARCHAR(MAX)
				  ,	@IsUpdateSolution			BIT
				  ,	@UpdateReviewedMode			TINYINT			= 0
				  ,	@IsReviewed					BIT				= 0				 
				  ,	@Review						NVARCHAR(MAX)	= NULL
				  ,	@IsUpdateReview				BIT
				  ,	@ReviewerID					INT				= NULL			
				  ,	@IP							VARCHAR(15)					
				  ,	@LicenseeType				INT				= 0
				  ,	@IsUpdateLicenseeType		BIT
				  ,	@ProvinceID					INT	
				  ,	@NoInquiries				SMALLINT		= NULL
				  , @IsUpdateNoInquiries		BIT
				  ,	@IsUpdateProvinceID			BIT				= NULL
				  , @Rating						TINYINT			= 0
				  , @IsUpdateRating				BIT
				  ,	@ErrCode					INT				= 0		OUTPUT
				  ,	@ErrMsg						NVARCHAR(4000)	= ''	OUTPUT	
)
AS
/*
	Created:	Winnie
	Date:		20190814
	Task:		update feedback
	DB:			DB052.bodb_CRM
	Original:

	Revisions:
		- 20190814@Winnie: Multiple Edit RedmineID:#99434
		- 20190923@Winnie: CRM - Include no. of Inquiries in Feedbacks RedmineID: #120596
        - 20240516@Ned.Le: CRM - Allow to add new Communication tools while Adding Feedback and allow to overwrite communication tools on Account Details page (#205068)
		- 20250226@Virgil: CRM - Add Rating Column for Feedback [Redmine: #218235]
		- 20250320@Virgil: CRM - Add 1st Reponse Time for Feedback [Redmine: #220801]

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
		
	DECLARE  @tblFbSetting TABLE(		
		SettingID			INT
		,SubSettingID		INT 	
		,SubSettingIDLevel3	INT 	
	)
	
	-- Read XML
	DECLARE	@iDoc			INT;

	IF @IsUpdateCategory=1
	BEGIN
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
	END

	IF @IsUpdateProduct=1
	BEGIN
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
	END

	IF @IsUpdateStationID=1
		INSERT INTO	@tblFbSetting
		( SettingID,SubSettingID,SubSettingIDLevel3)	
		SELECT SettingID,0,0
		FROM dbo.strSplit(@StationID,',')

	IF @IsUpdateCommunicationID=1
		INSERT INTO	@tblFbSetting
		( SettingID,SubSettingID,SubSettingIDLevel3)	
		SELECT SettingID,0,0
		FROM dbo.strSplit(@CommunicationID,',')


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

	DECLARE	@LanguageID_Old					INT
		,	@CountryID_Old					INT
		,	@Subject_Old					NVARCHAR(200)	= NULL
		,	@FeedbackDate_Old				DATETIME
		,	@FirstResponseTime_Old			DATETIME
		,	@ResolutionDate_Old				DATETIME
		,	@CommunicationID_Old			VARCHAR(MAX)
		,	@StationID_Old					VARCHAR(MAX)
		,	@MainCategoryID_Old				VARCHAR(MAX)
		,	@SubCategoryID_Old				VARCHAR(MAX)
		,	@CommunicationID_New			VARCHAR(MAX)
		,	@StationID_New					VARCHAR(MAX)
		,	@MainCategoryID_New				VARCHAR(MAX)
		,	@SubCategoryID_New				VARCHAR(MAX)
		,	@SiteID_Old						INT
		,	@RoleID_Old						INT
		,	@ProductID_Old					VARCHAR(MAX)
		,	@SubProductID_Old				VARCHAR(MAX)
		,	@BettypeID_Old					VARCHAR(MAX)
		,	@ProductID_New					VARCHAR(MAX)
		,	@SubProductID_New				VARCHAR(MAX)
		,	@BettypeID_New					VARCHAR(MAX)
		,	@ResponseID_Old					INT
		,	@StatusID_Old					INT
		,	@Remark_Old						NVARCHAR(MAX)
		,	@AutoField_Old					NVARCHAR(MAX)
		,	@Description_Old				NVARCHAR(MAX)
		,	@Solution_Old					NVARCHAR(MAX)
		,	@UpdateReviewedMode_Old			TINYINT			= 0
		,	@IsReviewed_Old					BIT				= 0
		,	@Review_Old						NVARCHAR(MAX)	= NULL
		,	@ReviewerID_Old					INT				= NULL		
		,	@IP_Old							VARCHAR(15)			
		,	@SolveDate_old					DATETIME
		,	@Creator_Old					INT		
		,	@LicenseeType_Old				INT				= 0
		,	@ProvinceID_Old					INT				= NULL	
		,	@NoInquiries_Old				SMALLINT		= NULL
		,	@Rating_Old						TINYINT			= 0

	SELECT	@CountryID_Old					= CountryID
		,	@LanguageID_Old					= LanguageID
		,	@Subject_Old					= Subject
		,	@FeedbackDate_Old				= FeedbackDate
		,	@FirstResponseTime_Old			= FirstResponseTime
		,	@ResolutionDate_Old				= ResolutionDate
		,	@SolveDate_Old					= SolveDate	
		,	@SiteID_Old						= SiteID
		,	@RoleID_Old						= RoleID		
		,	@ResponseID_Old					= ResponseID
		,	@StatusID_Old					= StatusID
		,	@Description_Old				= Description
		,	@Solution_Old					= Solution
		,	@IsReviewed_Old					= IsReviewed
		,	@Review_Old						= Review
		,	@ReviewerID_Old					= ReviewerID	
		,	@SolveDate_old					= @SolveDate
		,	@Creator_Old					= CreatorID		
		,	@LicenseeType_Old				= LicenseeType		
		,	@ProvinceID_Old					= ProvinceID
		,	@NoInquiries_Old				= Inquiries
		,	@Rating_Old						= Rating
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
	
	DECLARE @Remark		NVARCHAR(MAX);

	IF(@IsUpdateDescription=1)
		SELECT @Remark = @Description
	ELSE
		SELECT @Remark = @Remark_Old

	IF @IsUpdateAutoField<>1
		SELECT @AutoField=@AutoField_Old

	IF @IsUpdateDescription=1 OR @IsUpdateAutoField=1
		SELECT @Description= (SELECT @AutoField AS AutoField, @Description AS Remark  FOR XML RAW,ROOT('ROOT'))

	SELECT @MainCategoryID_Old = Stuff((SELECT DISTINCT ',' + CAST(SettingID AS VARCHAR(50))
                 FROM  crmFeedbackSetting fs WITH(NOLOCK) 
					INNER JOIN crmMainCategory m WITH(NOLOCK) ON fs.SettingID=m.MainCategoryID
					WHERE FeedbackID=@FeedbackID
                 FOR XML PATH('')), 1, 1, '')
		
	SELECT @SubCategoryID_Old = Stuff((SELECT DISTINCT ',' + CAST(SubSettingID AS VARCHAR(50))
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
		
	SELECT @SubCategoryID_New = Stuff((SELECT DISTINCT ',' + CAST(SubSettingID AS VARCHAR(50))
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

	SELECT @BettypeID_New = Stuff((SELECT DISTINCT ',' + CAST(fs.SubSettingIDLevel3 AS VARCHAR(50))
                 FROM  @tblFbSetting fs 
					INNER JOIN crmBettype p WITH(NOLOCK) ON fs.SubSettingIDLevel3=p.BettypeID				
                 FOR XML PATH('')), 1, 1, '')
	
	SELECT @CommunicationID_New = Stuff((SELECT DISTINCT ',' + CAST(fs.SettingID AS VARCHAR(50))
                 FROM  @tblFbSetting fs 
					INNER JOIN crmCommunicationTool p WITH(NOLOCK) ON fs.SettingID=p.CommunicationID				
                 FOR XML PATH('')), 1, 1, '')

	SELECT @StationID_New = Stuff((SELECT DISTINCT ',' + CAST(fs.SettingID AS VARCHAR(50))
                FROM  @tblFbSetting fs 
				INNER JOIN crmStation p WITH(NOLOCK) ON fs.SettingID=p.StationID		
                FOR XML PATH('')), 1, 1, '')

	--- update feedback
	UPDATE crmFeedback WITH (ROWLOCK, UPDLOCK)
	SET	CustID						= @CustID
	,	CountryID					= CASE WHEN @IsUpdateCountryID=1 THEN @CountryID ELSE CountryID END
	,	LanguageID					= CASE WHEN @IsUpdateLanguageID=1 THEN @LanguageID ELSE LanguageID END
	,	Subject						= CASE WHEN @IsUpdateSubject=1 THEN @Subject ELSE Subject END
	,	FeedbackDate				= CASE WHEN @IsUpdateFeedbackDate=1 THEN @FeedbackDate ELSE FeedbackDate END
	,	FirstResponseTime			= CASE WHEN @IsUpdateFirstResponseTime=1 THEN @FirstResponseTime ELSE FirstResponseTime END
	,	ResolutionDate				= CASE WHEN @IsUpdateResolutionDate=1 THEN @ResolutionDate ELSE ResolutionDate END
	,	SolveDate					= CASE WHEN @IsUpdateReview=1 THEN @SolveDate ELSE SolveDate END
	,	SiteID						= CASE WHEN @IsUpdateSiteID=1 THEN @SiteID ELSE SiteID END
	,	RoleID						= CASE WHEN @IsUpdateRoleID=1 THEN @RoleID ELSE RoleID END
	,	ResponseID					= CASE WHEN @IsUpdateResponseID=1 THEN @ResponseID ELSE ResponseID END
	,	StatusID					= CASE WHEN @IsUpdateStatusID=1 THEN @StatusID ELSE StatusID END
	,	Description					= CASE WHEN @IsUpdateDescription=1 OR @IsUpdateAutoField=1 THEN @Description ELSE Description END
	,	Solution					= CASE WHEN @IsUpdateSolution=1 THEN @Solution ELSE Solution END
	,	IsReviewed					= CASE WHEN @IsUpdateReview=1 THEN @IsReviewed ELSE IsReviewed END
	,	Review						= CASE WHEN @IsUpdateReview=1 THEN @Review ELSE Review END
	,	ReviewerID					= CASE WHEN @IsUpdateReview=1 THEN @ReviewerID ELSE ReviewerID END
	,	LicenseeType				= CASE WHEN @IsUpdateLicenseeType=1 THEN @LicenseeType ELSE LicenseeType END
	,	ProvinceID					= CASE WHEN @IsUpdateProvinceID=1 THEN @ProvinceID ELSE ProvinceID END
	,	Inquiries					= CASE WHEN @IsUpdateNoInquiries=1 THEN @NoInquiries ELSE Inquiries END
	,	Rating						= CASE WHEN @IsUpdateRating=1 THEN @Rating ELSE Rating END
	WHERE	FeedbackID = @FeedbackID;
	
	IF(@IsUpdateCategory=1)
	BEGIN
		DELETE s
		FROM crmfeedbackSetting s WITH(ROWLOCK)
			INNER JOIN crmMainCategory m WITH(NOLOCK) ON s.SettingID=m.MainCategoryID
			 WHERE FeedbackID=@FeedbackID
	END
	IF(@IsUpdateProduct=1)
	BEGIN
		DELETE s
		FROM crmfeedbackSetting s WITH(ROWLOCK)
			INNER JOIN crmSetting m WITH(NOLOCK) ON s.SettingID=m.SettingID AND SettingName='Product' AND SiteOffer=2
			 WHERE FeedbackID=@FeedbackID
	END
	IF(@IsUpdateCommunicationID=1)
	BEGIN
		DELETE s
		FROM crmfeedbackSetting s WITH(ROWLOCK)
			INNER JOIN crmCommunicationTool m WITH(NOLOCK) ON s.SettingID=m.CommunicationID
			 WHERE FeedbackID=@FeedbackID
	END
	IF(@IsUpdateStationID=1)
	BEGIN
		DELETE s
		FROM crmfeedbackSetting s WITH(ROWLOCK)
			INNER JOIN crmStation m WITH(NOLOCK) ON s.SettingID=m.StationID
			 WHERE FeedbackID=@FeedbackID
	END
	
	INSERT INTO crmfeedbackSetting(FeedbackID,SettingID,SubSettingID,SubSettingIDLevel3)
	SELECT @FeedbackID,t.SettingID,t.SubSettingID,t.SubSettingIDLevel3
	FROM @tblFbSetting t	

	IF	@@ERROR <> 0
	BEGIN
		SELECT	@ErrCode = 101
			,	@ErrMsg = 'updated feedback unsuccessfuly.';

		RETURN;
	END;

	-- write log
	DECLARE	@OldValues NVARCHAR(MAX)
		,	@NewValues NVARCHAR(MAX)
		,	@OldValuesXML	XML
		,	@NewValuesXML	XML
	SELECT	@OldValues = 				
					'<Acc_CRM_FeedbackUpdMultiple>' 
	SELECT @NewValues = 				
					'<Acc_CRM_FeedbackUpdMultiple>'

	IF @IsUpdateLanguageID=1
	BEGIN
		SELECT	@OldValues = 	@OldValues+
			'<LanguageID>'					+ ISNULL(CONVERT(VARCHAR(10),@LanguageID_Old),'')				+ '</LanguageID>' +
			'<IsUpdateLanguageID>'			+ ISNULL(CONVERT(VARCHAR(1),@IsUpdateLanguageID),'')			+ '</IsUpdateLanguageID>' 

		SELECT	@NewValues = 	@NewValues+
			'<LanguageID>'					+ ISNULL(CONVERT(VARCHAR(10),@LanguageID),'')					+ '</LanguageID>' +
			'<IsUpdateLanguageID>'			+ ISNULL(CONVERT(VARCHAR(1),@IsUpdateLanguageID),'')			+ '</IsUpdateLanguageID>' 
	END
	IF @IsUpdateCountryID=1
	BEGIN
		SELECT	@OldValues = 	@OldValues+
			'<CountryID>'					+ ISNULL(CONVERT(VARCHAR(10),@CountryID_Old),'')				+ '</CountryID>' +
			'<IsUpdateCountryID>'			+ ISNULL(CONVERT(VARCHAR(1),@IsUpdateCountryID),'')				+ '</IsUpdateCountryID>' 

		SELECT	@NewValues = 	@NewValues+
			'<CountryID>'					+ ISNULL(CONVERT(VARCHAR(10),@CountryID),'')					+ '</CountryID>' +
			'<IsUpdateCountryID>'			+ ISNULL(CONVERT(VARCHAR(1),@IsUpdateCountryID),'')				+ '</IsUpdateCountryID>' 
	END
	IF @IsUpdateSubject=1
	BEGIN
		SELECT	@OldValues = 	@OldValues+
			'<Subject>'						+ ISNULL(dbo.f_EncodeXMLValue(@Subject_Old),'')					+ '</Subject>' +
			'<IsUpdateSubject>'				+ ISNULL(CONVERT(VARCHAR(1),@IsUpdateSubject),'')				+ '</IsUpdateSubject>' 

		SELECT	@NewValues = 	@NewValues+
			'<Subject>'						+ ISNULL(dbo.f_EncodeXMLValue(@Subject),'')						+ '</Subject>' +
			'<IsUpdateSubject>'				+ ISNULL(CONVERT(VARCHAR(1),@IsUpdateSubject),'')				+ '</IsUpdateSubject>' 
	END
	IF @IsUpdateFeedbackDate=1
	BEGIN
		SELECT	@OldValues = 	@OldValues+
			'<FeedbackDate>'				+ ISNULL(CONVERT(VARCHAR(20),@FeedbackDate_Old),'')				+ '</FeedbackDate>' +
			'<IsUpdateFeedbackDate>'		+ ISNULL(CONVERT(VARCHAR(1),@IsUpdateFeedbackDate),'')			+ '</IsUpdateFeedbackDate>' 

		SELECT	@NewValues = 	@NewValues+
			'<FeedbackDate>'				+ ISNULL(CONVERT(VARCHAR(20),@FeedbackDate),'')					+ '</FeedbackDate>' +
			'<IsUpdateFeedbackDate>'		+ ISNULL(CONVERT(VARCHAR(1),@IsUpdateFeedbackDate),'')			+ '</IsUpdateFeedbackDate>' 
	END
	IF @IsUpdateFirstResponseTime=1
	BEGIN
		SELECT	@OldValues = 	@OldValues+
			'<FirstResponseTime>'				+ ISNULL(CONVERT(VARCHAR(20),@FirstResponseTime_Old),'')	+ '</FirstResponseTime>' +
			'<IsUpdateFirstResponseTime>'		+ ISNULL(CONVERT(VARCHAR(1),@IsUpdateFirstResponseTime),'')	+ '</IsUpdateFirstResponseTime>' 

		SELECT	@NewValues = 	@NewValues+
			'<FirstResponseTime>'				+ ISNULL(CONVERT(VARCHAR(20),@FirstResponseTime),'')		+ '</FirstResponseTime>' +
			'<IsUpdateFirstResponseTime>'		+ ISNULL(CONVERT(VARCHAR(1),@IsUpdateFirstResponseTime),'') + '</IsUpdateFirstResponseTime>' 
	END
	IF @IsUpdateResolutionDate=1
	BEGIN
		SELECT	@OldValues = 	@OldValues+
			'<ResolutionDate>'				+ ISNULL(CONVERT(VARCHAR(20),@ResolutionDate_Old),'')			+ '</ResolutionDate>' +
			'<IsUpdateResolutionDate>'		+ ISNULL(CONVERT(VARCHAR(1),@IsUpdateResolutionDate),'')		+ '</IsUpdateResolutionDate>' 

		SELECT	@NewValues = 	@NewValues+
			'<ResolutionDate>'				+ ISNULL(CONVERT(VARCHAR(20),@ResolutionDate),'')				+ '</ResolutionDate>' +
			'<IsUpdateResolutionDate>'		+ ISNULL(CONVERT(VARCHAR(1),@IsUpdateResolutionDate),'')		+ '</IsUpdateResolutionDate>' 
	END
	IF @IsUpdateCommunicationID=1
	BEGIN
		SELECT	@OldValues = 	@OldValues+
			'<CommunicationID>'				+ ISNULL(@CommunicationID_Old,'')								+ '</CommunicationID>' +
			'<IsUpdateCommunicationID>'		+ ISNULL(CONVERT(VARCHAR(1),@IsUpdateCommunicationID),'')		+ '</IsUpdateCommunicationID>' 

		SELECT	@NewValues = 	@NewValues+
			'<CommunicationID>'				+ ISNULL(@CommunicationID_New,'')								+ '</CommunicationID>' +
			'<IsUpdateCommunicationID>'		+ ISNULL(CONVERT(VARCHAR(1),@IsUpdateCommunicationID),'')		+ '</IsUpdateCommunicationID>' 
	END
	IF @IsUpdateStationID=1
	BEGIN
		SELECT	@OldValues = 	@OldValues+
			'<StationID>'					+ ISNULL(@StationID_Old,'')										+ '</StationID>' +
			'<IsUpdateStationID>'			+ ISNULL(CONVERT(VARCHAR(1),@IsUpdateStationID),'')				+ '</IsUpdateStationID>' 

		SELECT	@NewValues = 	@NewValues+
			'<StationID>'					+ ISNULL(@StationID_New,'')										+ '</StationID>' +
			'<IsUpdateStationID>'			+ ISNULL(CONVERT(VARCHAR(1),@IsUpdateStationID),'')				+ '</IsUpdateStationID>' 
	END
	IF @IsUpdateCategory=1
	BEGIN
		SELECT	@OldValues = 	@OldValues+
			'<MainCategoryID>'				+ ISNULL(@MainCategoryID_Old,'')								+ '</MainCategoryID>' +
			'<IsUpdateCategory>'			+ ISNULL(CONVERT(VARCHAR(1),@IsUpdateCategory),'')				+ '</IsUpdateCategory>' +
			'<SubCategoryID>'				+ ISNULL(@SubCategoryID_Old,'')									+ '</SubCategoryID>' 

		SELECT	@NewValues = 	@NewValues+
			'<MainCategoryID>'				+ ISNULL(@MainCategoryID_New,'')								+ '</MainCategoryID>' +
			'<IsUpdateCategory>'			+ ISNULL(CONVERT(VARCHAR(1),@IsUpdateCategory),'')				+ '</IsUpdateCategory>' +
			'<SubCategoryID>'				+ ISNULL(@SubCategoryID_New,'')									+ '</SubCategoryID>' 
	END
	IF @IsUpdateSiteID=1
	BEGIN
		SELECT	@OldValues = 	@OldValues+
			'<SiteID>'						+ ISNULL(CONVERT(VARCHAR(10),@SiteID_Old),'')					+ '</SiteID>' +
			'<IsUpdateSiteID>'				+ ISNULL(CONVERT(VARCHAR(1),@IsUpdateSiteID),'')				+ '</IsUpdateSiteID>' 

		SELECT	@NewValues = 	@NewValues+
			'<SiteID>'						+ ISNULL(CONVERT(VARCHAR(10),@SiteID),'')						+ '</SiteID>' +
			'<IsUpdateSiteID>'				+ ISNULL(CONVERT(VARCHAR(1),@IsUpdateSiteID),'')				+ '</IsUpdateSiteID>' 
	END
	IF @IsUpdateRoleID=1
	BEGIN
		SELECT	@OldValues = 	@OldValues+
			'<RoleID>'						+ ISNULL(CONVERT(VARCHAR(10),@RoleID_Old),'')					+ '</RoleID>' +
			'<IsUpdateRoleID>'				+ ISNULL(CONVERT(VARCHAR(1),@IsUpdateRoleID),'')				+ '</IsUpdateRoleID>' 

		SELECT	@NewValues = 	@NewValues+
			'<RoleID>'						+ ISNULL(CONVERT(VARCHAR(10),@RoleID),'')						+ '</RoleID>' +
			'<IsUpdateRoleID>'				+ ISNULL(CONVERT(VARCHAR(1),@IsUpdateRoleID),'')				+ '</IsUpdateRoleID>' 
	END
	IF @IsUpdateProduct=1
	BEGIN
		SELECT	@OldValues = 	@OldValues+
			'<ProductID>'					+ ISNULL(@ProductID_Old,'')										+ '</ProductID>' +
			'<IsUpdateProduct>'				+ ISNULL(CONVERT(VARCHAR(1),@IsUpdateProduct),'')				+ '</IsUpdateProduct>' +
			'<SubProductID>'				+ ISNULL(@SubProductID_Old,'')									+ '</SubProductID>' +
			'<BettypeID>'					+ ISNULL(@BettypeID_Old,'')										+ '</BettypeID>' 

		SELECT	@NewValues = 	@NewValues+
			'<ProductID>'					+ ISNULL(@ProductID_New	,'')									+ '</ProductID>' +
			'<IsUpdateProduct>'				+ ISNULL(CONVERT(VARCHAR(1),@IsUpdateProduct),'')				+ '</IsUpdateProduct>' +
			'<SubProductID>'				+ ISNULL(@SubProductID_New,'')									+ '</SubProductID>' +
			'<BettypeID>'					+ ISNULL(@BettypeID_New,'')										+ '</BettypeID>' 
	END
	IF @IsUpdateResponseID=1
	BEGIN
		SELECT	@OldValues = 	@OldValues+
			'<ResponseID>'					+ ISNULL(CONVERT(VARCHAR(10),@ResponseID_Old),'')				+ '</ResponseID>' +
			'<IsUpdateResponseID>'			+ ISNULL(CONVERT(VARCHAR(1),@IsUpdateResponseID),'')			+ '</IsUpdateResponseID>' 

		SELECT	@NewValues = 	@NewValues+
			'<ResponseID>'					+ ISNULL(CONVERT(VARCHAR(10),@ResponseID),'')					+ '</ResponseID>' +
			'<IsUpdateResponseID>'			+ ISNULL(CONVERT(VARCHAR(1),@IsUpdateResponseID),'')			+ '</IsUpdateResponseID>' 
	END
	IF @IsUpdateStatusID=1
	BEGIN
		SELECT	@OldValues = 	@OldValues+
			'<StatusID>'					+ ISNULL(CONVERT(VARCHAR(10),@StatusID_Old),'')					+ '</StatusID>' +
			'<IsUpdateStatusID>'			+ ISNULL(CONVERT(VARCHAR(1),@IsUpdateStatusID),'')				+ '</IsUpdateStatusID>' 

		SELECT	@NewValues = 	@NewValues+
			'<StatusID>'					+ ISNULL(CONVERT(VARCHAR(10),@StatusID),'')						+ '</StatusID>' +
			'<IsUpdateStatusID>'			+ ISNULL(CONVERT(VARCHAR(1),@IsUpdateStatusID),'')				+ '</IsUpdateStatusID>' 
	END
	IF @IsUpdateReview=1
	BEGIN
		SELECT	@OldValues = 	@OldValues+
			'<IsReviewed>'					+ ISNULL(CONVERT(VARCHAR(5),@IsReviewed_Old),'')				+ '</IsReviewed>' +					
			'<Reviewer>'					+ ISNULL(CONVERT(VARCHAR(10),@ReviewerID_Old),'')				+ '</Reviewer>' +						
			'<Review>'						+ ISNULL(dbo.f_EncodeXMLValue(@Review_Old),'')					+ '</Review>' +		
			'<IsUpdateReview>'				+ ISNULL(CONVERT(VARCHAR(1),@IsUpdateReview),'')				+ '</IsUpdateReview>' 

		SELECT	@NewValues = 	@NewValues+
			'<IsReviewed>'					+ ISNULL(CONVERT(VARCHAR(5),@IsReviewed),'')					+ '</IsReviewed>' +					
			'<Reviewer>'					+ ISNULL(CONVERT(VARCHAR(10),@ReviewerID),'')					+ '</Reviewer>' +	
			'<Review>'						+ ISNULL(dbo.f_EncodeXMLValue(@Review),'')						+ '</Review>' +	
			'<IsUpdateReview>'				+ ISNULL(CONVERT(VARCHAR(1),@IsUpdateReview),'')				+ '</IsUpdateReview>' 
	END
	IF @IsUpdateDescription=1
	BEGIN
		SELECT	@OldValues = 	@OldValues+
			'<Remark>'						+ ISNULL(dbo.f_EncodeXMLValue(@Remark_Old),'')					+ '</Remark>' +
			'<IsUpdateDescription>'			+ ISNULL(CONVERT(VARCHAR(1),@IsUpdateDescription),'')			+ '</IsUpdateDescription>' 

		SELECT	@NewValues = 	@NewValues+
			'<Remark>'						+ ISNULL(dbo.f_EncodeXMLValue(@Remark),'')						+ '</Remark>' +
			'<IsUpdateDescription>'			+ ISNULL(CONVERT(VARCHAR(1),@IsUpdateDescription),'')			+ '</IsUpdateDescription>' 
	END
	IF @IsUpdateAutoField=1
	BEGIN
		SELECT	@OldValues = 	@OldValues+
			'<AutoField>'					+ ISNULL(dbo.f_EncodeXMLValue(@AutoField_Old),'')				+ '</AutoField>' +
			'<IsUpdateAutoField>'			+ ISNULL(CONVERT(VARCHAR(1),@IsUpdateAutoField),'')				+ '</IsUpdateAutoField>' 

		SELECT	@NewValues = 	@NewValues+
			'<AutoField>'					+ ISNULL(dbo.f_EncodeXMLValue(@AutoField),'')					+ '</AutoField>' +
			'<IsUpdateAutoField>'			+ ISNULL(CONVERT(VARCHAR(1),@IsUpdateAutoField),'')				+ '</IsUpdateAutoField>' 
	END
	IF @IsUpdateSolution=1
	BEGIN
		SELECT	@OldValues = 	@OldValues+
			'<Solution>'					+ ISNULL(dbo.f_EncodeXMLValue(@Solution_Old),'')				+ '</Solution>' +
			'<IsUpdateSolution>'			+ ISNULL(CONVERT(VARCHAR(1),@IsUpdateSolution),'')				+ '</IsUpdateSolution>' 

		SELECT	@NewValues = 	@NewValues+
			'<Solution>'					+ ISNULL(dbo.f_EncodeXMLValue(@Solution),'')					+ '</Solution>' +
			'<IsUpdateSolution>'			+ ISNULL(CONVERT(VARCHAR(1),@IsUpdateSolution),'')				+ '</IsUpdateSolution>' 
	END
	IF @IsUpdateLicenseeType=1
	BEGIN
		SELECT	@OldValues = 	@OldValues+
			'<LicenseeType>'				+ ISNULL(CONVERT(VARCHAR(10),@LicenseeType_Old),'')				+ '</LicenseeType>' +	
			'<IsUpdateLicenseeType>'		+ ISNULL(CONVERT(VARCHAR(1),@IsUpdateLicenseeType),'')			+ '</IsUpdateLicenseeType>' 

		SELECT	@NewValues = 	@NewValues+
			'<LicenseeType>'				+ ISNULL(CONVERT(VARCHAR(10),@LicenseeType),'')					+ '</LicenseeType>' +
			'<IsUpdateLicenseeType>'		+ ISNULL(CONVERT(VARCHAR(1),@IsUpdateLicenseeType),'')			+ '</IsUpdateLicenseeType>' 
	END
	IF @IsUpdateNoInquiries=1
	BEGIN
		SELECT	@OldValues = 	@OldValues+
			'<NoInquiries>'					+ ISNULL(CONVERT(VARCHAR(10),@NoInquiries_Old),'')						+ '</NoInquiries>' +	
			'<IsUpdateNoInquiries>'			+ ISNULL(CONVERT(VARCHAR(1),@IsUpdateNoInquiries),'')					+ '</IsUpdateNoInquiries>' 

		SELECT	@NewValues = 	@NewValues+
			'<NoInquiries>'					+ ISNULL(CONVERT(VARCHAR(10),@NoInquiries),'')							+ '</NoInquiries>' +
			'<IsUpdateNoInquiries>'			+ ISNULL(CONVERT(VARCHAR(1),@IsUpdateNoInquiries),'')					+ '</IsUpdateNoInquiries>' 
	END
	IF @IsUpdateRating=1
	BEGIN
		SELECT	@OldValues = 	@OldValues+
			'<Rating>'					+ ISNULL(CONVERT(VARCHAR(10),@Rating_Old),'')						+ '</Rating>' +	
			'<IsUpdateRating>'			+ ISNULL(CONVERT(VARCHAR(1),@IsUpdateRating),'')					+ '</IsUpdateRating>' 

		SELECT	@NewValues = 	@NewValues+
			'<Rating>'					+ ISNULL(CONVERT(VARCHAR(10),@Rating),'')							+ '</Rating>' +
			'<IsUpdateRating>'			+ ISNULL(CONVERT(VARCHAR(1),@IsUpdateRating),'')					+ '</IsUpdateRating>' 
	END

	SELECT	@OldValues = 	@OldValues+
			'<Creator>'						+ ISNULL(CONVERT(VARCHAR(10),@Creator_Old),'')					+ '</Creator>' +
			'</Acc_CRM_FeedbackUpdMultiple>'

	SELECT	@NewValues = 	@NewValues+
			'<Creator>'						+ ISNULL(CONVERT(VARCHAR(10),@Creator_Old),'')					+ '</Creator>' +
			'</Acc_CRM_FeedbackUpdMultiple>'
	
	SELECT @OldValuesXML=CONVERT(XML,@OldValues)
	SELECT @NewValuesXML=CONVERT(XML,@NewValues)
	EXECUTE	dbo.WriteLog_UserLog_crmLogFeedback
				@UserID = @UserID
			,	@FeedbackID = @FeedbackID
			,	@CustID = @CustID
			,	@ActionID = 205
			,	@IP = @IP
			,	@Description = @Description
			,	@Solution = @Solution
			,	@Review =  @Review
			,	@NewValues = @NewValuesXML
			,	@OldValues = @OldValuesXML;

END
GO