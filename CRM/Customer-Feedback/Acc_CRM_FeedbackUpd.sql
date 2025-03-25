/*<info serverAlias="DBCRM-bodb_CRM" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_FeedbackUpd] (
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
				,	@FirstResponseTime			DATETIME		= NULL
				,	@ResolutionDate				DATETIME			
				,	@SiteID						INT
				,	@RoleID						INT		
				,	@CommunicationID			VARCHAR(MAX)	
				,	@StationID					VARCHAR(MAX)	
				,	@Category					VARCHAR(MAX)		
				,	@Product					VARCHAR(MAX)	
				,	@ResponseID					INT
				,	@StatusID					INT
				,	@Description				NVARCHAR(MAX)
				,	@AutoField					NVARCHAR(MAX)	=''
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
				,	@RelatedCustID				VARCHAR(MAX)	= NULL
				,	@LicenseeType				INT				= 0
				,	@ProvinceID					INT				= NULL
				,	@WhatsApp					NVARCHAR(100)	= NULL
				,	@Line						NVARCHAR(100)	= NULL
				,	@WeChat						NVARCHAR(100)	= NULL
				,	@Yahoo						NVARCHAR(100)	= NULL
				,	@QQ							NVARCHAR(100)	= NULL
				,	@BBM						NVARCHAR(100)	= NULL
				,	@IsOverWrite				BIT				= 0	
				,	@ErrCode					INT				= 0		OUTPUT
				,	@ErrMsg						NVARCHAR(4000)	= ''	OUTPUT	
				,	@NoInquiries				SMALLINT		= NULL
				,	@Rating						TINYINT			= 0
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
		- 20170614@Winnie: Write log for review - [Redmine: #77820]
		- 20180117@Winnie:	Add Is Related Customer - [Redmine: #88774]
		- 20171225@Winnie: Change for support multiple product/categories. [RedmineID: #84714]
		- 20190506@Winnie:  CN88 Permission RedmineID: #112637
		- 20190719@Winnie:  CRM - Remove limit Is Related Customer RedmineID: #113305
		- 20191104@Winnie:  [CRM] cannot search feedback of customer in manage feedback RedmineID: #123160
		- 20201021@Johnson: remove limit amount for related customers[redmine:#142194]
		- 20201119@Johnson:	check relatedCustomer <> '' to sync customer [redmine:#145661]				
		- 20210601@Johnson: Prevent CSD create new feedback mistakenly If the licensee is terminated [redmine:#154840]
		- 20230412@Winfred: NAP CRM - Some of our Headline Contact info was missing in CRM [redmine:#186726]
		- 20250224@Virgil: CRM - Add Rating Column for Feedback [Redmine: #218235]
		- 20250319@Virgil: CRM - Add 1st Reponse Time for Feedback [Redmine: #220801]

	Param's Explanation:
		- @UpdateReviewedMode: Kind of update review
			0	Do nothing
			1	Update review
			2	remove review
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @SolveDate	DATETIME;	
	DECLARE @Remark		NVARCHAR(MAX);
	SELECT @Remark = @Description
	SELECT @Description= (SELECT @AutoField AS AutoField, @Description AS Remark  FOR XML RAW,ROOT('ROOT'))
	
	SELECT	@ErrCode	= 0
		,	@ErrMsg		= '';

	IF	NOT EXISTS (SELECT 1 FROM crmFeedback WITH (NOLOCK) WHERE FeedbackID = @FeedbackID)
	BEGIN
		SELECT	@ErrCode = 100
			,	@ErrMsg = 'Feedback does not exist.';

		RETURN;
	END;

	IF	ISNULL(@CommunicationID, '') = ''
	OR	ISNULL(@Category, '') = ''
	OR	ISNULL(@Product, '') = ''
	OR	ISNULL(@StatusID, 0) = 0 
	OR	ISNULL(@LanguageID, '') = ''
	OR	ISNULL(@RoleID, 0) = 0
	OR	ISNULL(@ResponseID, 0) = 0
	OR	ISNULL(@StationID, '') = ''
	BEGIN
		SELECT	@ErrCode = 100
			,	@ErrMsg = 'Incorrect Data.';

		RETURN;
	END;

	DECLARE	@relatedCustomer TABLE(CustID INT);
	
	IF ISNULL(@RelatedCustID,'') <> ''
	BEGIN
		INSERT INTO @relatedCustomer
		SELECT	CONVERT(INT, val)
		FROM	dbo.f_CRM_strSplit(@RelatedCustID, ',');
	END 
	
	DECLARE  @tblFbSetting TABLE(		
		SettingID			INT
		,SubSettingID		INT 	
		,SubSettingIDLevel3	INT 	
	)

	
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
		,	@ProvinceID_Old					INT				= NULL
		,	@NoInquiries_Old				SMALLINT		= NULL
		,	@WhatsApp_Old					NVARCHAR(100)	= NULL
		,	@Line_Old						NVARCHAR(100)	= NULL
		,	@WeChat_Old						NVARCHAR(100)	= NULL
		,	@Yahoo_Old						NVARCHAR(100)	= NULL
		,	@QQ_Old							NVARCHAR(100)	= NULL
		,	@BBM_Old						NVARCHAR(100)	= NULL
		,	@Rating_Old						TINYINT			= 0;

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
	

	DECLARE	@RelatedCustID_Old varchar(max) = '';

	SELECT	@RelatedCustID_Old = '';

	SELECT	@RelatedCustID_Old = @RelatedCustID_Old + CAST(c.CustID AS VARCHAR(100)) + ','
	FROM	crmFeedbackCustomer(NOLOCK) c
	WHERE	c.FeedbackID = @FeedbackID
		AND	c.IsRelated = 1;

	IF	ISNULL(@RelatedCustID_Old, '') <> ''
	SELECT	@RelatedCustID_Old = LEFT(@RelatedCustID_Old, LEN(@RelatedCustID_Old) - 1);

	--check any new customers belong to terminated licensee site
	DECLARE @tmpCustInvalid TABLE(custid INT, username NVARCHAR(100))
		
	INSERT INTO @tmpCustInvalid(custid,username)
	SELECT custid,username 
	FROM crmCustomer c WITH(NOLOCK) 
		WHERE custid IN (SELECT custid FROM @relatedCustomer)
			AND custid NOT IN (SELECT custid
								FROM dbo.crmFeedbackCustomer AS fbc WITH (NOLOCK)
								WHERE	fbc.FeedbackID = @FeedbackID
									AND	fbc.IsRelated = 1)
			AND EXISTS (SELECT 1 
						FROM crmSettingRelation sr WITH(NOLOCK) 
							INNER JOIN	crmSetting s WITH(NOLOCK)
									ON	sr.SettingID = s.SettingID
									AND	s.SettingName = 'Site'
						WHERE c.SiteID = s.SettingID
							AND s.IsActive = 0
							AND sr.ParentID = 33000--licensee
					)

	
	INSERT INTO @tmpCustInvalid(custid,username)
	SELECT custid,username 
	FROM bodb02.dbo.Customer c WITH(NOLOCK) 
		WHERE custid IN (SELECT custid FROM @relatedCustomer)
			AND custid NOT IN (SELECT custid
								FROM dbo.crmFeedbackCustomer AS fbc WITH (NOLOCK)
								WHERE	fbc.FeedbackID = @FeedbackID
									AND	fbc.IsRelated = 1)
			AND custid NOT IN (SELECT custid FROM @tmpCustInvalid)						
			AND EXISTS (SELECT 1 
						FROM crmSettingRelation sr WITH(NOLOCK) 
							INNER JOIN	crmSetting s WITH(NOLOCK)
									ON	sr.SettingID = s.SettingID
									AND	s.SettingName = 'Site'
						WHERE c.site = s.settingValue
							AND s.IsActive = 0
							AND sr.ParentID = 33000--licensee
					)		
	
	IF EXISTS(SELECT 1 FROM @tmpCustInvalid)
	BEGIN		
		SELECT @ErrMsg = ''		
		SELECT @ErrMsg = ','+ @ErrMsg + username		
		FROM @tmpCustInvalid
		
		SELECT @ErrMsg = STUFF(@ErrMsg,1,1,'')
		
		SELECT @ErrCode = 106,
			@ErrMsg = 'Some Usernames belong to Inactive Site: '+ @ErrMsg
		
		RETURN
	END
		
	DELETE	crmFeedbackCustomer WITH(ROWLOCK, UPDLOCK)
	WHERE	FeedbackID = @FeedbackID
		AND	IsRelated = 1;

	UPDATE fc
	SET fc.IsRelated=1
	FROM crmFeedbackCustomer  fc WITH(ROWLOCK, UPDLOCK)
		INNER JOIN @relatedCustomer t ON fc.CustID=t.CustID
	WHERE fc.FeedbackID=@FeedbackID
		AND t.custID<>@CustID
	-- Insert feedback related
	INSERT INTO crmFeedbackCustomer
				(	FeedbackID , CustID, IsRelated)	
	SELECT DISTINCT @FeedbackID, t.CustID, 1
	FROM	@relatedCustomer t
	WHERE	NOT EXISTS(SELECT TOP 1 1 FROM crmFeedbackCustomer WITH(NOLOCK) WHERE FeedbackID=@FeedbackID AND CustID=t.CustID)
		AND t.CustID<>@CustID

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
	,	FirstResponseTime			= @FirstResponseTime
	,	ResolutionDate				= @ResolutionDate
	,	SolveDate					= @SolveDate
	,	SiteID						= @SiteID
	,	RoleID						= @RoleID
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
	,	ProvinceID					= @ProvinceID
	,	Inquiries					= @NoInquiries
	,	Rating						= @Rating
	WHERE	FeedbackID = @FeedbackID;
	
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
						'<FirstResponseTime>'			+ ISNULL(CONVERT(VARCHAR(20),@FirstResponseTime_Old),'')		+ '</FirstResponseTime>' +
						'<ResolutionDate>'				+ ISNULL(CONVERT(VARCHAR(20),@ResolutionDate_Old),'')			+ '</ResolutionDate>' +
						'<CommunicationID>'				+ ISNULL(@CommunicationID_Old,'')								+ '</CommunicationID>' +
						'<StationID>'					+ ISNULL(@StationID_Old,'')										+ '</StationID>' +
						'<MainCategoryID>'				+ ISNULL(@MainCategoryID_Old,'')								+ '</MainCategoryID>' +
						'<SubCategoryID>'				+ ISNULL(@SubCategoryID_Old,'')									+ '</SubCategoryID>' +
						'<SiteID>'						+ ISNULL(CONVERT(VARCHAR(10),@SiteID_Old),'')					+ '</SiteID>' +
						'<RoleID>'						+ ISNULL(CONVERT(VARCHAR(10),@RoleID_Old),'')					+ '</RoleID>' +
						'<ProductID>'					+ ISNULL(@ProductID_Old,'')										+ '</ProductID>' +
						'<SubProductID>'				+ ISNULL(@SubProductID_Old,'')									+ '</SubProductID>' +
						'<BettypeID>'					+ ISNULL(@BettypeID_Old,'')										+ '</BettypeID>' +
						'<ResponseID>'					+ ISNULL(CONVERT(VARCHAR(10),@ResponseID_Old),'')				+ '</ResponseID>' +
						'<StatusID>'					+ ISNULL(CONVERT(VARCHAR(10),@StatusID_Old),'')					+ '</StatusID>' +
						'<IsReviewed>'					+ ISNULL(CONVERT(VARCHAR(5),@IsReviewed_Old),'')				+ '</IsReviewed>' +
						'<Reviewer>'					+ ISNULL(CONVERT(VARCHAR(10),@ReviewerID_Old),'')				+ '</Reviewer>' +	
						'<Review>'						+ ISNULL(dbo.f_EncodeXMLValue(@Review_Old),'')					+ '</Review>' +						
						'<RelatedCustID>'				+ ISNULL(@RelatedCustID_Old,'')									+ '</RelatedCustID>' +
						'<Pic1>'						+ ISNULL(dbo.f_EncodeXMLValue(@Pic1_Old),'')					+ '</Pic1>' +
						'<Pic2>'						+ ISNULL(dbo.f_EncodeXMLValue(@Pic2_Old),'')					+ '</Pic2>' +
						'<Pic3>'						+ ISNULL(dbo.f_EncodeXMLValue(@Pic3_Old),'')					+ '</Pic3>' +
						'<Pic4>'						+ ISNULL(dbo.f_EncodeXMLValue(@Pic4_Old),'')					+ '</Pic4>' +
						'<Passport>'					+ ISNULL(dbo.f_EncodeXMLValue(@Passport_Old),'')				+ '</Passport>' +
						'<Remark>'						+ ISNULL(dbo.f_EncodeXMLValue(@Remark_Old),'')					+ '</Remark>' +
						'<AutoField>'					+ ISNULL(dbo.f_EncodeXMLValue(@AutoField_Old),'')				+ '</AutoField>' +
						'<Solution>'					+ ISNULL(dbo.f_EncodeXMLValue(@Solution_Old),'')				+ '</Solution>' +
						'<LicenseeType>'				+ ISNULL(CONVERT(VARCHAR(10),@LicenseeType_Old),'')				+ '</LicenseeType>' +
						'<WhatsApp>'					+ ISNULL(dbo.f_EncodeXMLValue(@WhatsApp_Old),'')				+ '</WhatsApp>' +
						'<Line>'						+ ISNULL(dbo.f_EncodeXMLValue(@Line_Old),'')					+ '</Line>' +
						'<WeChat>'						+ ISNULL(dbo.f_EncodeXMLValue(@WeChat_Old),'')					+ '</WeChat>' +
						'<Yahoo>'						+ ISNULL(dbo.f_EncodeXMLValue(@Yahoo_Old),'')					+ '</Yahoo>' +
						'<QQ>'							+ ISNULL(dbo.f_EncodeXMLValue(@QQ_Old),'')						+ '</QQ>' +
						'<BBM>'							+ ISNULL(dbo.f_EncodeXMLValue(@BBM_Old),'')						+ '</BBM>' +
						'<ProvinceID>'					+ ISNULL(dbo.f_EncodeXMLValue(@ProvinceID_Old),'')				+ '</ProvinceID>' +
						'<NoInquiries>'					+ ISNULL(dbo.f_EncodeXMLValue(@NoInquiries_Old),'')				+ '</NoInquiries>' +
						'<Rating>'						+ ISNULL(CONVERT(VARCHAR(5),@Rating_Old),'')					+ '</Rating>' +
						'<IsOverWrite>'					+ ISNULL(CONVERT(VARCHAR(10),0),'')								+ '</IsOverWrite>' +
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
						'<FirstResponseTime>'			+ ISNULL(CONVERT(VARCHAR(20),@FirstResponseTime),'')			+ '</FirstResponseTime>' +
						'<ResolutionDate>'				+ ISNULL(CONVERT(VARCHAR(20),@ResolutionDate),'')				+ '</ResolutionDate>' +
						'<CommunicationID>'				+ ISNULL(@CommunicationID_New,'')								+ '</CommunicationID>' +
						'<StationID>'					+ ISNULL(@StationID_New,'')										+ '</StationID>' +
						'<MainCategoryID>'				+ ISNULL(@MainCategoryID_New,'')								+ '</MainCategoryID>' +
						'<SubCategoryID>'				+ ISNULL(@SubCategoryID_New,'')									+ '</SubCategoryID>' +
						'<SiteID>'						+ ISNULL(CONVERT(VARCHAR(10),@SiteID),'')						+ '</SiteID>' +
						'<RoleID>'						+ ISNULL(CONVERT(VARCHAR(10),@RoleID),'')						+ '</RoleID>' +
						'<ProductID>'					+ ISNULL(@ProductID_New	,'')									+ '</ProductID>' +
						'<SubProductID>'				+ ISNULL(@SubProductID_New,'')									+ '</SubProductID>' +
						'<BettypeID>'					+ ISNULL(@BettypeID_New,'')										+ '</BettypeID>' +
						'<ResponseID>'					+ ISNULL(CONVERT(VARCHAR(10),@ResponseID),'')					+ '</ResponseID>' +
						'<StatusID>'					+ ISNULL(CONVERT(VARCHAR(10),@StatusID),'')						+ '</StatusID>' +
						'<IsReviewed>'					+ ISNULL(CONVERT(VARCHAR(5),@IsReviewed),'')					+ '</IsReviewed>' +
						'<Reviewer>'					+ ISNULL(CONVERT(VARCHAR(10),@ReviewerID),'')					+ '</Reviewer>' +	
						'<Review>'						+ ISNULL(dbo.f_EncodeXMLValue(@Review),'')						+ '</Review>' +											
						'<RelatedCustID>'				+ ISNULL(@RelatedCustID,'')										+ '</RelatedCustID>' +
						'<Pic1>'						+ ISNULL(dbo.f_EncodeXMLValue(@Pic1),'')						+ '</Pic1>' +
						'<Pic2>'						+ ISNULL(dbo.f_EncodeXMLValue(@Pic2),'')						+ '</Pic2>' +
						'<Pic3>'						+ ISNULL(dbo.f_EncodeXMLValue(@Pic3),'')						+ '</Pic3>' +
						'<Pic4>'						+ ISNULL(dbo.f_EncodeXMLValue(@Pic4),'')						+ '</Pic4>' +
						'<Passport>'					+ ISNULL(dbo.f_EncodeXMLValue(@Passport),'')					+ '</Passport>' +
						'<Remark>'						+ ISNULL(dbo.f_EncodeXMLValue(@Remark),'')						+ '</Remark>' +
						'<AutoField>'					+ ISNULL(dbo.f_EncodeXMLValue(@AutoField),'')					+ '</AutoField>' +
						'<Solution>'					+ ISNULL(dbo.f_EncodeXMLValue(@Solution),'')					+ '</Solution>' +
						'<LicenseeType>'				+ ISNULL(CONVERT(VARCHAR(10),@LicenseeType),'')					+ '</LicenseeType>' +
						'<WhatsApp>'					+ ISNULL(dbo.f_EncodeXMLValue(@WhatsApp),'')					+ '</WhatsApp>' +
						'<Line>'						+ ISNULL(dbo.f_EncodeXMLValue(@Line),'')						+ '</Line>' +
						'<WeChat>'						+ ISNULL(dbo.f_EncodeXMLValue(@WeChat),'')						+ '</WeChat>' +
						'<Yahoo>'						+ ISNULL(dbo.f_EncodeXMLValue(@Yahoo),'')						+ '</Yahoo>' +
						'<QQ>'							+ ISNULL(dbo.f_EncodeXMLValue(@QQ),'')							+ '</QQ>' +
						'<BBM>'							+ ISNULL(dbo.f_EncodeXMLValue(@BBM),'')							+ '</BBM>' +
						'<ProvinceID>'					+ ISNULL(dbo.f_EncodeXMLValue(@ProvinceID),'')					+ '</ProvinceID>' +
						'<NoInquiries>'					+ ISNULL(dbo.f_EncodeXMLValue(@NoInquiries),'')					+ '</NoInquiries>' +
						'<Rating>'						+ ISNULL(CONVERT(VARCHAR(5),@Rating),'')						+ '</Rating>' +
						'<IsOverWrite>'					+ ISNULL(CONVERT(VARCHAR(10),@IsOverWrite),'')					+ '</IsOverWrite>' +
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
