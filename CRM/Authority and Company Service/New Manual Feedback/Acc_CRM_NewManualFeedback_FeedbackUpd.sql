/*<info serverAlias="DBCRM-bodb_CRM" executers="wsv_nap" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE dbo.Acc_CRM_NewManualFeedback_FeedbackUpd --KEY
                                                          @FeedbackID            INT,
                                                          @CustID                INT,
                                                          --TABLE
                                                          -->crmFeedback
                                                          -->+CustomerInfo
                                                          @TitleID               INT,
                                                          @FirstName             NVARCHAR(50)   = '',
                                                          @LastName              NVARCHAR(50)   = '',
                                                          @Birthday              DATETIME       = NULL,
                                                          @Passport              NVARCHAR(100)  = NULL,
                                                          @BettingCode           NVARCHAR(100)  = NULL,
                                                          @RefCode2              NVARCHAR(100)  = NULL,
                                                          -->+FeedbackInfo
                                                          @FeedbackDate          DATETIME,
														  @FirstResponseTime	 DATETIME		= NULL,
                                                          @ResolutionDate        DATETIME,
                                                          @StatusID              INT,
                                                          @LanguageID            INT,
                                                          @ResponseID            INT,
                                                          @RoleID                INT,
                                                          @CountryID             INT,
                                                          @SiteID                INT,
                                                          @LicenseeType          INT            = 0,
                                                          @NoInquiries           SMALLINT       = NULL,
                                                          @Subject               NVARCHAR(200)  = NULL,
                                                          @AutoField             NVARCHAR(MAX)  = '',
                                                          @Description           NVARCHAR(MAX)  = '',
                                                          @Solution              NVARCHAR(MAX)  = '',
                                                          @IsReviewed            BIT            = 0,
                                                          @Review                NVARCHAR(MAX)  = NULL,
                                                          @ReviewerID            INT            = NULL,
														  @Rating				 TINYINT		= 0,
                                                          -->crmFeedbackNewCommunicationTool
                                                          @NewCommunicationTools NVARCHAR(MAX)  = NULL,
                                                          -->crmFeedbackSetting
                                                          @StationID             VARCHAR(MAX),
                                                          @CommunicationID       VARCHAR(MAX),
                                                          @Category              VARCHAR(MAX),
                                                          @Product               VARCHAR(MAX),
                                                          --crmFeedbackCustomer
                                                          @RelatedCustID         VARCHAR(MAX)   = NULL,
                                                          --IFELSE
                                                          @UpdateReviewedMode    TINYINT        = 0,
                                                          @IsOverwrite           BIT            = 0,
                                                          --LOG
                                                          @UserID                INT,
                                                          @IP                    VARCHAR(45),
                                                          @ErrCode               INT            = 0  OUTPUT,
                                                          @ErrMsg                NVARCHAR(4000) = '' OUTPUT
AS

/*
    Created:  Ned.Le
    Date:     20240220
    Task:     Get feedback info
    DB:       DBCRM.bodb_CRM
    Original: Acc_CRM_FeedbackInfoUpd, Acc_CRM_FeedbackUpd

    Revisions:
        20240220@Ned.Le: CRM - Manage Headline/PIC/Staff authority and Company services (#193385)
        20240516@Ned.Le: CRM - Allow to add new Communication tools while Adding Feedback and allow to overwrite communication tools on Account Details page (#205068)
        20240605@Ned.Le: CRM - Activity Log - Adjust text format (#206075)
		20241225@Tacy: CRM - Offer Direct Member for Super and Master [Redmine: #215809]
		20250224@Virgil: CRM - Add Rating Column for Feedback [Redmine: #218235]
		20250319@Virgil: CRM - Add 1st Reponse Time for Feedback [Redmine: #220801]

    Param's Explanation:
        @Category: <ROOT>
                       <Category MainCategoryID="212" SubCategoryID="2401"/>
                   </ROOT>
        @Product: <ROOT>
                      <Product ProductID="212" SubProductID="2401" BettypeID="1,2,3,4,5"/>
                  </ROOT>
        @NewCommunicationTools: <ROOT>
                                    <NewCommunicationTool isHeadline="0" PicInfo="" CommunicationID="49001" CommunicationValue="023568974,0909862546"/>
                                    <NewCommunicationTool isHeadline="0" PicInfo="" CommunicationID="49006" CommunicationValue="whatsapp01,whatsapp02"/>
                                </ROOT>
        @UpdateReviewedMode: Kind of update review
                             0-Do nothing
                             1-Update review
                             2-Remove review
*/

BEGIN

    SET NOCOUNT ON


    -------------------------------------------------------
    -- CODE LAYOUT                                       --
    -------------------------------------------------------
    -- 1. Check data consistency                         --
    -- 2. Sync related customers not exist on CRM to CRM --
    -- 3. Overwrite account info                         --
    -- 4. Process data for old value                     --
    -- 5. Process data for new value                     --
    -- 6. Update main data                               --
    -- 7. Write Log                                      --
    -------------------------------------------------------


    -------------------------------
    -- 1. Check data consistency --

    -- Reset parameter value
    SELECT @ErrCode = 0
    SELECT @ErrMsg  = ''

    -- Check the existence of FeedbackID
    IF NOT EXISTS (SELECT 1 FROM bodb_CRM.dbo.crmFeedback WITH (NOLOCK) WHERE FeedbackID = @FeedbackID)
    BEGIN
        SELECT @ErrCode = 100
        SELECT @ErrMsg  = 'Feedback does not exist.'
        RETURN
    END

    -- Check input parameter value
    IF ISNULL(@CommunicationID, '') = '' OR
       ISNULL(@Category, '')        = '' OR
       ISNULL(@Product, '')         = '' OR
       ISNULL(@StatusID, 0)         = 0  OR
       ISNULL(@LanguageID, '')      = '' OR
       ISNULL(@RoleID, 0)           = 0 OR
       ISNULL(@ResponseID, 0)       = 0 OR
       ISNULL(@StationID, '')       = ''
    BEGIN
        SELECT @ErrCode = 100
        SELECT @ErrMsg  = 'Incorrect Data.'
        RETURN
    END


    -------------------------------------------------------
    -- 2. Sync related customers not exist on CRM to CRM --

    -- Create temp table
    CREATE TABLE #tmpSyncRelatedCustomer (
        CustID      INT,
        UserName    VARCHAR(50),
        FirstName   NVARCHAR(100),
        LastName    NVARCHAR(100),
        Phone       NVARCHAR(100),
        MobilePhone NVARCHAR(100),
        Fax         NVARCHAR(100),
        Email       NVARCHAR(100),
        Birthday    SMALLDATETIME,
        CountryID   INT,
        SiteID      INT,
        isExistsCRM BIT DEFAULT(0),
        isFinished  BIT DEFAULT(0)
    )

    -- Check data existence
    IF (ISNULL(@RelatedCustID,'') <> '')
    BEGIN
        INSERT INTO #tmpSyncRelatedCustomer (CustID)
        SELECT CONVERT(INT, val)
        FROM bodb_CRM.dbo.f_CRM_strSplit(@RelatedCustID, ',')
        
        UPDATE t
        SET t.isExistsCRM = 1 
        FROM #tmpSyncRelatedCustomer t
             INNER JOIN bodb_CRM.dbo.crmCustomer cm WITH (NOLOCK) ON t.custid = cm.custid
    END 

    -- Process to sync data
    IF EXISTS (SELECT 1 FROM #tmpSyncRelatedCustomer WHERE isExistsCRM = 0)
    BEGIN
        DECLARE @r_CustID      INT,
                @r_UserName    VARCHAR(50),
                @r_FirstName   NVARCHAR(100),
                @r_LastName    NVARCHAR(100),
                @r_Phone       NVARCHAR(100),
                @r_MobilePhone NVARCHAR(100),
                @r_Fax         NVARCHAR(100),
                @r_Email       NVARCHAR(100),
                @r_Birthday    SMALLDATETIME,
                @r_CountryID   INT,
                @r_SiteID      INT
            
        UPDATE t
        SET t.CustID      = c.custid,
            t.UserName    = c.username,
            t.FirstName   = c.firstname,
            t.LastName    = c.lastname,
            t.Phone       = c.phone,
            t.MobilePhone = c.mobilephone,
            t.Fax         = c.fax,
            t.Email       = c.email,
            t.Birthday    = c.birthday,
            t.CountryID   = ct.CountryID,
            t.SiteID      = (SELECT SettingID 
                             FROM bodb_CRM.dbo.crmSetting WITH (NOLOCK) 
                             WHERE SettingValue = c.site
                                   AND SettingName IN ('Site', 'SiteCategory'))
        FROM #tmpSyncRelatedCustomer t
             INNER JOIN bodb02.dbo.Customer c WITH (NOLOCK) ON t.custid = c.custid
             LEFT JOIN bodb_CRM.dbo.crmCountry ct ON c.country = ct.CountryName
        WHERE t.isExistsCRM = 0

        WHILE (1=1)
        BEGIN 
            UPDATE TOP (1) t
            SET isFinished     = 1,
                @r_CustID      = CustID,
                @r_UserName    = UserName,
                @r_FirstName   = FirstName,
                @r_LastName    = LastName, 
                @r_Phone       = Phone,
                @r_MobilePhone = MobilePhone,
                @r_Fax         = Fax,
                @r_Email       = Email,
                @r_Birthday    = Birthday,
                @r_CountryID   = CountryID,
                @r_SiteID      = SiteID
            FROM #tmpSyncRelatedCustomer t
            WHERE t.isFinished = 0
                  AND t.isExistsCRM = 0
                
            IF (@@ROWCOUNT = 0) BREAK
                
            EXECUTE bodb_CRM.dbo.Acc_CRM_CustomerIns_New @CustID      = @r_CustID,
                                                         @UserName    = @r_UserName,
                                                         @FirstName   = @r_FirstName,
                                                         @LastName    = @r_LastName,       
                                                         @Birthday    = @r_Birthday,
                                                         @Phone       = @r_Phone,
                                                         @MobilePhone = @r_MobilePhone,
                                                         @Fax         = @r_Fax,       
                                                         @Email       = @r_Email,
                                                         @CountryID   = @r_CountryID,
                                                         @SiteID      = @r_SiteID,
                                                         @CreatorID   = @UserID,
                                                         @UserID      = @UserID,
                                                         @IP          = @IP,
                                                         @ErrCode     = @ErrCode OUTPUT,
                                                         @ErrMsg      = @ErrMsg OUTPUT

            IF (@ErrCode <> 0)
            BEGIN
                SELECT @ErrCode = 100
                SELECT @ErrMsg  = 'Sync related customer'
                RETURN
            END
        END    
    END

    -- Drop temp table
    DROP TABLE #tmpSyncRelatedCustomer


    -------------------------------
    -- 3. Overwrite account info --

    IF (@IsOverwrite = 1)
    BEGIN
        DECLARE @IsVip_crmCustomer BIT
        SELECT  @IsVip_crmCustomer = IsVip		
        FROM bodb_CRM.dbo.crmCustomer WITH (NOLOCK)
        WHERE CustID = @CustID

        EXECUTE bodb_CRM.dbo.Acc_CRM_CustomerShortUpd @CustID                 = @CustID,
                                                      @TitleID                = @TitleID,
                                                      @FirstName              = @FirstName,
                                                      @LastName               = @LastName,
                                                      @Birthday               = @Birthday,
                                                      @Passport               = @Passport,
                                                      @BettingCode            = @BettingCode,
                                                      @RefCode2               = @RefCode2,
                                                      @IsVip                  = @IsVip_crmCustomer,
                                                      @SiteID                 = @SiteID,
                                                      @LicenseeType           = @LicenseeType,
                                                      @Phone                  = NULL,
                                                      @PhoneCountryCode       = NULL,
                                                      @PhoneAreaCode          = NULL,
                                                      @Phone2                 = NULL,
                                                      @Phone2CountryCode      = NULL,
                                                      @Phone2AreaCode         = NULL,
                                                      @Phone3                 = NULL,
                                                      @Phone3CountryCode      = NULL,
                                                      @Phone3AreaCode         = NULL,
                                                      @MobilePhone            = NULL,
                                                      @MobilePhoneCountryCode = NULL,
                                                      @MobilePhoneAreaCode    = NULL,
                                                      @Fax                    = NULL,
                                                      @FaxCountryCode         = NULL,
                                                      @FaxAreaCode            = NULL,
                                                      @Email                  = NULL,
                                                      @Skype                  = NULL,
                                                      @MSN                    = NULL,
                                                      @UserID                 = @UserID,
                                                      @IP                     = @IP,
                                                      @ErrCode                = @ErrCode OUTPUT,
                                                      @ErrMsg                 = @ErrMsg  OUTPUT
    END


    -----------------------------------
    -- 4. Process data for old value --

    -- crmFeedback
    DECLARE @TitleID_Old			INT,
            @FirstName_Old			NVARCHAR(50),
            @LastName_Old			NVARCHAR(50),
            @LanguageID_Old			INT,
            @CountryID_Old			INT,
            @FeedbackDate_Old		DATETIME,
            @SolveDate_old			DATETIME,
            @SiteID_Old				INT,
            @RoleID_Old				INT,
            @ResponseID_Old			INT,
            @StatusID_Old			INT,
            @Description_Old		NVARCHAR(MAX),
            @Remark_Old				NVARCHAR(MAX),
            @AutoField_Old			NVARCHAR(MAX),
            @Solution_Old			NVARCHAR(MAX),
            @IsReviewed_Old			BIT           = 0,
            @Review_Old				NVARCHAR(MAX) = NULL,
            @ReviewerID_Old			INT           = NULL,
            @Subject_Old			NVARCHAR(200) = NULL,
			@FirstResponseTime_Old	DATETIME,
            @ResolutionDate_Old		DATETIME,
            @Passport_Old			NVARCHAR(100) = NULL,
            @Birthday_Old			DATETIME,
            @BettingCode_Old		NVARCHAR(100) = NULL,
            @RefCode2_Old			NVARCHAR(100) = NULL,
            @IsVip_Old				BIT,
            @LicenseeType_Old		INT           = 0,
            @NoInquiries_Old		SMALLINT      = NULL,
			@Rating_Old				TINYINT		  = 0

    SELECT @TitleID_Old				= TitleID,
           @FirstName_Old			= FirstName,
           @LastName_Old			= LastName,
           @CountryID_Old			= CountryID,
           @LanguageID_Old			= LanguageID,
           @FeedbackDate_Old		= FeedbackDate,
           @SolveDate_Old			= SolveDate,
           @SiteID_Old				= SiteID,
           @RoleID_Old				= RoleID,       
           @ResponseID_Old			= ResponseID,
           @StatusID_Old			= StatusID,
           @Description_Old			= Description,
           @Solution_Old			= Solution,
           @IsReviewed_Old			= IsReviewed,
           @Review_Old				= Review,
           @ReviewerID_Old			= ReviewerID,
           @Subject_Old				= Subject,
		   @FirstResponseTime_Old	= FirstResponseTime,
           @ResolutionDate_Old		= ResolutionDate,
           @Passport_Old			= Passport,
           @Birthday_Old			= Birthday,
           @BettingCode_Old			= RefCode1,
           @RefCode2_Old			= RefCode2,
           @IsVip_Old				= IsVip,
           @LicenseeType_Old		= LicenseeType,
           @NoInquiries_Old			= Inquiries,
		   @Rating_Old				= Rating
    FROM bodb_CRM.dbo.crmFeedback WITH (NOLOCK)
    WHERE FeedbackID = @FeedbackID

    DECLARE @xmlDoc  XML = CAST(@Description_Old AS XML)
    DECLARE @iDoc_30 INT
    EXECUTE sp_xml_preparedocument @iDoc_30 OUTPUT, @xmlDoc
    SELECT  @AutoField_Old = ox.AutoField,
            @Remark_Old    = ox.Remark
    FROM OPENXML (@iDoc_30, '/ROOT/row', 1)
    WITH (AutoField NVARCHAR(MAX), Remark NVARCHAR(MAX)) AS ox

    -- crmFeedbackNewCommunicationTool
    DECLARE @tblOldCommunicationTools TABLE (
        isHeadline         BIT,
        PicInfo            NVARCHAR(200),
        CommunicationID    INT,
        CommunicationValue NVARCHAR(200)
    )
    INSERT INTO @tblOldCommunicationTools (
        isHeadline,
        PicInfo,
        CommunicationID,
        CommunicationValue
    )
    SELECT isHeadline,
           PicInfo,
           CommunicationID,
           CommunicationValue
    FROM bodb_CRM.dbo.crmFeedbackNewCommunicationTool WITH (NOLOCK)
    WHERE FeedbackID = @FeedbackID

    DECLARE @OldCommunicationTools NVARCHAR(MAX)
    SELECT  @OldCommunicationTools = x.xmlvalue
    FROM (SELECT *
          FROM @tblOldCommunicationTools
          FOR XML RAW('NewCommunicationTool'), ROOT('ROOT')) AS x(xmlvalue)

    -- crmFeedbackSetting
    DECLARE @StationID_Old       VARCHAR(MAX),
            @CommunicationID_Old VARCHAR(MAX),
            @MainCategoryID_Old  VARCHAR(MAX),
            @SubCategoryID_Old   VARCHAR(MAX),
            @ProductID_Old       VARCHAR(MAX),
            @SubProductID_Old    VARCHAR(MAX),
            @BettypeID_Old       VARCHAR(MAX)


    SELECT @StationID_Old = STUFF((SELECT DISTINCT ',' + CAST(fs.SettingID AS VARCHAR(50))
    FROM bodb_CRM.dbo.crmFeedbackSetting fs WITH(NOLOCK) 
         INNER JOIN bodb_CRM.dbo.crmStation p WITH(NOLOCK) ON fs.SettingID = p.StationID
    WHERE FeedbackID = @FeedbackID
    FOR XML PATH('')), 1, 1, '')

    SELECT @CommunicationID_Old = STUFF((SELECT DISTINCT ',' + CAST(fs.SettingID AS VARCHAR(50))
    FROM bodb_CRM.dbo.crmFeedbackSetting fs WITH (NOLOCK) 
         INNER JOIN bodb_CRM.dbo.crmCommunicationTool p WITH (NOLOCK) ON fs.SettingID = p.CommunicationID
    WHERE FeedbackID = @FeedbackID
    FOR XML PATH('')), 1, 1, '')

    SELECT @MainCategoryID_Old = STUFF((SELECT DISTINCT ',' + CAST(SettingID AS VARCHAR(50))
    FROM bodb_CRM.dbo.crmFeedbackSetting fs WITH (NOLOCK)
         INNER JOIN bodb_CRM.dbo.crmMainCategory m WITH (NOLOCK) ON fs.SettingID = m.MainCategoryID
    WHERE FeedbackID = @FeedbackID
    FOR XML PATH('')), 1, 1, '')
        
    SELECT @SubCategoryID_Old = STUFF((SELECT DISTINCT ',' + CAST(SubSettingID AS VARCHAR(50))
    FROM bodb_CRM.dbo.crmFeedbackSetting fs WITH (NOLOCK) 
         INNER JOIN bodb_CRM.dbo.crmSubCategory m WITH (NOLOCK) ON fs.SubSettingID = m.SubCategoryID AND fs.SettingID = m.MainCategoryID
    WHERE FeedbackID = @FeedbackID
    FOR XML PATH('')), 1, 1, '')
        
    SELECT @ProductID_Old = STUFF((SELECT DISTINCT ',' + CAST(fs.SettingID AS VARCHAR(50))
    FROM bodb_CRM.dbo.crmFeedbackSetting fs WITH (NOLOCK)
         INNER JOIN bodb_CRM.dbo.crmSetting p WITH (NOLOCK) ON fs.SettingID = p.SettingID AND p.SettingName='Product'
    WHERE FeedbackID = @FeedbackID
    FOR XML PATH('')), 1, 1, '')

    SELECT @SubProductID_Old = STUFF((SELECT DISTINCT ',' + CAST(fs.SubSettingID AS VARCHAR(50))
    FROM bodb_CRM.dbo.crmFeedbackSetting fs WITH (NOLOCK) 
         INNER JOIN bodb_CRM.dbo.crmSetting p WITH (NOLOCK) ON fs.SubSettingID = p.SettingID AND p.SettingName='SubProduct'
    WHERE FeedbackID = @FeedbackID
    FOR XML PATH('')), 1, 1, '')

    SELECT @BettypeID_Old = STUFF((SELECT DISTINCT ',' + CAST(fs.SubSettingIDLevel3 AS VARCHAR(50))
    FROM bodb_CRM.dbo.crmFeedbackSetting fs WITH (NOLOCK) 
         INNER JOIN crmBettype p WITH (NOLOCK) ON fs.SubSettingIDLevel3 = p.BettypeID
    WHERE FeedbackID = @FeedbackID
    FOR XML PATH('')), 1, 1, '')

    -- crmFeedbackCustomer
    DECLARE @RelatedCustID_Old VARCHAR(MAX)  = ''

    SELECT @RelatedCustID_Old = @RelatedCustID_Old + CAST(CustID AS VARCHAR(100)) + ','
    FROM bodb_CRM.dbo.crmFeedbackCustomer WITH (NOLOCK)
    WHERE FeedbackID = @FeedbackID AND IsRelated = 1

    IF (ISNULL(@RelatedCustID_Old, '') <> '') SELECT @RelatedCustID_Old = LEFT(@RelatedCustID_Old, LEN(@RelatedCustID_Old) - 1)


    -----------------------------------
    -- 5. Process data for new value --

    --------------
    -- crmFeedback

    -- @IsVip_crmFeedback
    DECLARE @IsVip_crmFeedback BIT
    SELECT  @IsVip_crmFeedback = IsVip FROM bodb_CRM.dbo.crmFeedback WITH (NOLOCK) WHERE FeedbackID = @FeedbackID AND CustID = @CustID

    -- @SolveDate|@Review|@IsReviewed|@ReviewerID
    DECLARE @SolveDate DATETIME
    SELECT  @SolveDate  = CASE WHEN @UpdateReviewedMode = 0 THEN SolveDate
                               WHEN @UpdateReviewedMode = 1 THEN GETDATE()
                               WHEN @UpdateReviewedMode = 2 THEN NULL
                               ELSE SolveDate END,
            @Review     = CASE WHEN @UpdateReviewedMode = 0 THEN Review
                               WHEN @UpdateReviewedMode = 1 THEN @Review
                               WHEN @UpdateReviewedMode = 2 THEN NULL
                               ELSE Review END,
            @IsReviewed = CASE WHEN @UpdateReviewedMode = 0 THEN IsReviewed
                               WHEN @UpdateReviewedMode = 1 THEN 1
                               WHEN @UpdateReviewedMode = 2 THEN 0
                               ELSE IsReviewed END,
            @ReviewerID = CASE WHEN @UpdateReviewedMode = 0 THEN ReviewerID
                               WHEN @UpdateReviewedMode = 1 THEN @ReviewerID
                               WHEN @UpdateReviewedMode = 2 THEN NULL
                               ELSE ReviewerID END
    FROM bodb_CRM.dbo.crmFeedback WITH (NOLOCK)
    WHERE FeedbackID = @FeedbackID

    -- @Remark|@AutoField|@Description
    DECLARE @Remark NVARCHAR(MAX)
    SELECT  @Remark = @Description
    SELECT  @Description = (SELECT @AutoField AS AutoField, @Description AS Remark  FOR XML RAW, ROOT('ROOT'))

    ----------------------------------
    -- crmFeedbackNewCommunicationTool

    IF (ISNULL(@NewCommunicationTools, '') <> '')
    BEGIN
        DECLARE @iDoc_41 INT
        EXECUTE sys.sp_xml_preparedocument @iDoc_41 OUTPUT, @NewCommunicationTools

        DECLARE @tblNewCommunicationTools TABLE (
            isHeadline         BIT,
            PicInfo            NVARCHAR(200),
            CommunicationID    INT,
            CommunicationValue NVARCHAR(200)
        )

        INSERT INTO @tblNewCommunicationTools (
            isHeadline,
            PicInfo,
            CommunicationID,
            CommunicationValue
        )
        SELECT ox.isHeadline,
               ox.PicInfo,
               ox.CommunicationID,
               ox.CommunicationValue
        FROM OPENXML(@iDoc_41, '/ROOT/NewCommunicationTool', 1)
        WITH (isHeadline         BIT,
              PicInfo            NVARCHAR(200),
              CommunicationID    INT,
              CommunicationValue NVARCHAR(200)) AS ox
    END

    ---------------------
    -- crmFeedbackSetting
    
    -- Parse value from parameter to table
    DECLARE @iDoc_42 INT

    DECLARE @tblFeedbackSetting TABLE (
        SettingID          INT,
        SubSettingID       INT,
        SubSettingIDLevel3 INT     
    )

    EXECUTE sys.sp_xml_preparedocument @iDoc_42 OUTPUT, @Category
    INSERT INTO @tblFeedbackSetting (SettingID, SubSettingID, SubSettingIDLevel3)
    SELECT ox.MainCategoryID, ox.SubCategoryID, 0
    FROM OPENXML(@iDoc_42, '/ROOT/Category', 1)
    WITH (MainCategoryID INT, SubCategoryID INT) AS ox
    EXECUTE sys.sp_xml_removedocument @iDoc_42

    EXECUTE sys.sp_xml_preparedocument @iDoc_42 OUTPUT, @Product
    INSERT INTO @tblFeedbackSetting (SettingID, SubSettingID, SubSettingIDLevel3)
    SELECT ox.ProductID, ox.SubProductID, ox.BetTypeID
    FROM OPENXML(@iDoc_42, '/ROOT/Product', 1)
    WITH (ProductID INT,SubProductID INT, BetTypeID INT) AS ox
    EXECUTE sys.sp_xml_removedocument @iDoc_42

    INSERT INTO @tblFeedbackSetting (SettingID, SubSettingID, SubSettingIDLevel3)
    SELECT SettingID, 0, 0
    FROM bodb_CRM.dbo.strSplit(@CommunicationID, ',')

    INSERT INTO @tblFeedbackSetting (SettingID, SubSettingID, SubSettingIDLevel3)
    SELECT SettingID, 0, 0
    FROM bodb_CRM.dbo.strSplit(@StationID, ',')
    
    -- Parse value from table to parameter
    DECLARE @StationID_New       VARCHAR(MAX),
            @CommunicationID_New VARCHAR(MAX),
            @MainCategoryID_New  VARCHAR(MAX),
            @SubCategoryID_New   VARCHAR(MAX),
            @ProductID_New       VARCHAR(MAX),
            @SubProductID_New    VARCHAR(MAX),
            @BettypeID_New       VARCHAR(MAX)

    SELECT @StationID_New = Stuff((SELECT DISTINCT ',' + CAST(fs.SettingID AS VARCHAR(50))
    FROM @tblFeedbackSetting fs
         INNER JOIN bodb_CRM.dbo.crmStation p WITH (NOLOCK) ON fs.SettingID = p.StationID
    FOR XML PATH('')), 1, 1, '')

    SELECT @CommunicationID_New = Stuff((SELECT DISTINCT ',' + CAST(fs.SettingID AS VARCHAR(50))
    FROM @tblFeedbackSetting fs
         INNER JOIN bodb_CRM.dbo.crmCommunicationTool p WITH (NOLOCK) ON fs.SettingID = p.CommunicationID
    FOR XML PATH('')), 1, 1, '')

    SELECT @MainCategoryID_New = STUFF((SELECT DISTINCT ',' + CAST(SettingID AS VARCHAR(50))
    FROM @tblFeedbackSetting fs
         INNER JOIN bodb_CRM.dbo.crmMainCategory m WITH (NOLOCK) ON fs.SettingID = m.MainCategoryID              
    FOR XML PATH('')), 1, 1, '')

    SELECT @SubCategoryID_New = STUFF((SELECT DISTINCT ',' + CAST(SubSettingID AS VARCHAR(50))
    FROM @tblFeedbackSetting fs
         INNER JOIN bodb_CRM.dbo.crmSubCategory m WITH (NOLOCK) ON fs.SubSettingID = m.SubCategoryID AND fs.SettingID = m.MainCategoryID
    FOR XML PATH('')), 1, 1, '')

    SELECT @ProductID_New = STUFF((SELECT DISTINCT ',' + CAST(fs.SettingID AS VARCHAR(50))
    FROM @tblFeedbackSetting fs
         INNER JOIN bodb_CRM.dbo.crmSetting p WITH (NOLOCK) ON fs.SettingID = p.SettingID AND p.SettingName = 'Product'
    FOR XML PATH('')), 1, 1, '')

    SELECT @SubProductID_New = STUFF((SELECT DISTINCT ',' + CAST(fs.SubSettingID AS VARCHAR(50))
    FROM @tblFeedbackSetting fs
         INNER JOIN bodb_CRM.dbo.crmSetting p WITH (NOLOCK) ON fs.SubSettingID = p.SettingID AND p.SettingName = 'SubProduct'
    FOR XML PATH('')), 1, 1, '')

    SELECT @BettypeID_New = STUFF((SELECT DISTINCT ',' + CAST(fs.SubSettingIDLevel3 AS VARCHAR(50))
    FROM @tblFeedbackSetting fs
         INNER JOIN bodb_CRM.dbo.crmBettype p WITH (NOLOCK) ON fs.SubSettingIDLevel3 = p.BettypeID
    FOR XML PATH('')), 1, 1, '')

    ----------------------
    -- crmFeedbackCustomer
    
    -- Parse data to table
    DECLARE @tblRelatedCustID TABLE (CustID INT)

    IF (ISNULL(@RelatedCustID,'') <> '')
    BEGIN
        INSERT INTO @tblRelatedCustID
        SELECT CONVERT(INT, val) FROM bodb_CRM.dbo.f_CRM_strSplit(@RelatedCustID, ',')
    END

    -- Check the total related customer reach to limitation
    IF ((SELECT COUNT(1) FROM @tblRelatedCustID) > 2000)
    BEGIN
        SELECT @ErrCode = 106
        SELECT @ErrMsg  = 'Exceed limitation. We only support around 2000 related accounts in maximum.'
        RETURN
    END

    -- Check any new customers belong to terminated licensee site
    DECLARE @tblInvalidCustomer TABLE(CustID INT, UserName NVARCHAR(100))
        
    INSERT INTO @tblInvalidCustomer (CustID, UserName)
    SELECT c.CustID, c.UserName
    FROM bodb_CRM.dbo.crmCustomer c WITH (NOLOCK)
    WHERE c.CustID IN (SELECT CustID FROM @tblRelatedCustID)
          AND c.CustID NOT IN (SELECT custid
                               FROM bodb_CRM.dbo.crmFeedbackCustomer fbc WITH (NOLOCK)
                               WHERE fbc.FeedbackID = @FeedbackID AND fbc.IsRelated = 1)
          AND EXISTS (SELECT TOP 1 1
                      FROM bodb_CRM.dbo.crmSettingRelation sr WITH (NOLOCK) 
                           INNER JOIN bodb_CRM.dbo.crmSetting s WITH (NOLOCK) ON sr.SettingID = s.SettingID AND s.SettingName = 'Site'
                      WHERE s.SettingID = c.SiteID
                            AND s.IsActive = 0
                            AND sr.ParentID = 33000)

    INSERT INTO @tblInvalidCustomer (CustID, UserName)
    SELECT c.custid, c.username
    FROM bodb02.dbo.Customer c WITH (NOLOCK) 
    WHERE c.custid IN (SELECT custid FROM @tblRelatedCustID)
          AND c.custid NOT IN (SELECT custid
                               FROM bodb_CRM.dbo.crmFeedbackCustomer fbc WITH (NOLOCK)
                               WHERE fbc.FeedbackID = @FeedbackID AND fbc.IsRelated = 1)
          AND c.custid NOT IN (SELECT CustID FROM @tblInvalidCustomer)                        
          AND EXISTS (SELECT TOP 1 1 
                      FROM bodb_CRM.dbo.crmSettingRelation sr WITH (NOLOCK) 
                           INNER JOIN bodb_CRM.dbo.crmSetting s WITH (NOLOCK) ON sr.SettingID = s.SettingID AND s.SettingName = 'Site'
                      WHERE s.SettingValue = c.site
                            AND s.IsActive = 0
                            AND sr.ParentID = 33000)

    IF EXISTS(SELECT 1 FROM @tblInvalidCustomer)
    BEGIN
        SELECT @ErrMsg  = ''
        SELECT @ErrMsg  = ',' + @ErrMsg + UserName FROM @tblInvalidCustomer
        SELECT @ErrMsg  = STUFF(@ErrMsg, 1, 1, '')
        SELECT @ErrMsg  = 'Some Usernames belong to Inactive Site: '+ @ErrMsg
        SELECT @ErrCode = 106
        RETURN
    END


    -------------------------
    -- 6. Update main data --

    -- crmFeedback
    UPDATE bodb_CRM.dbo.crmFeedback WITH (ROWLOCK, UPDLOCK)
    SET TitleID				= @TitleID,
        FirstName			= @FirstName,
        LastName			= @LastName,
        LanguageID			= @LanguageID,
        CountryID			= @CountryID,
        FeedbackDate		= @FeedbackDate,
        SolveDate			= @SolveDate,
        SiteID				= @SiteID,
        RoleID				= @RoleID,
        ResponseID			= @ResponseID,
        StatusID			= @StatusID,
        Description			= @Description,
        Solution			= @Solution,
        IsReviewed			= @IsReviewed,
        Review				= @Review,
        ReviewerID			= @ReviewerID,
        Subject				= @Subject,
		FirstResponseTime	= @FirstResponseTime,
        ResolutionDate		= @ResolutionDate,
        Passport			= @Passport,
        Birthday			= @Birthday,
        RefCode1			= @BettingCode,
        RefCode2			= @RefCode2,
        IsVip				= @IsVip_crmFeedback,
        LicenseeType		= @LicenseeType,
        Inquiries			= @NoInquiries,
		Rating				= @Rating
    WHERE FeedbackID = @FeedbackID
          AND CustID = @CustID

    -- crmFeedbackNewCommunicationTool
    DELETE fc
    FROM bodb_CRM.dbo.crmFeedbackNewCommunicationTool fc WITH (ROWLOCK, UPDLOCK)
    WHERE fc.FeedbackID = @FeedbackID

    INSERT INTO bodb_CRM.dbo.crmFeedbackNewCommunicationTool (FeedbackID, CustID, isHeadline, PicInfo, CommunicationID, CommunicationValue)
    SELECT @FeedbackID, @CustID, isHeadline, PicInfo, CommunicationID, CommunicationValue
    FROM @tblNewCommunicationTools

    -- crmFeedbackSetting
    DELETE fs
    FROM bodb_CRM.dbo.crmFeedbackSetting fs WITH (ROWLOCK, UPDLOCK)
    WHERE fs.FeedbackID = @FeedbackID
    
    INSERT INTO bodb_CRM.dbo.crmFeedbackSetting (FeedbackID, SettingID, SubSettingID, SubSettingIDLevel3)
    SELECT @FeedbackID, SettingID, SubSettingID, SubSettingIDLevel3
    FROM @tblFeedbackSetting

    -- crmFeedbackCustomer
    DELETE fc
    FROM bodb_CRM.dbo.crmFeedbackCustomer fc WITH (ROWLOCK, UPDLOCK)
    WHERE fc.FeedbackID = @FeedbackID
          AND fc.IsRelated = 1

    UPDATE fc
    SET fc.IsRelated = 1
    FROM bodb_CRM.dbo.crmFeedbackCustomer fc WITH (ROWLOCK, UPDLOCK)
         INNER JOIN @tblRelatedCustID t ON fc.CustID = t.CustID
    WHERE fc.FeedbackID = @FeedbackID
          AND t.custID <> @CustID

    INSERT INTO bodb_CRM.dbo.crmFeedbackCustomer (FeedbackID, CustID, IsRelated)
    SELECT DISTINCT @FeedbackID, t.CustID, 1
    FROM @tblRelatedCustID t
    WHERE NOT EXISTS(SELECT TOP 1 1 FROM bodb_CRM.dbo.crmFeedbackCustomer WITH (NOLOCK) WHERE FeedbackID = @FeedbackID AND CustID = t.CustID)
          AND t.CustID <> @CustID

    IF (@@ERROR <> 0)
    BEGIN
        SELECT @ErrCode = 101
        SELECT @ErrMsg  = 'Updated feedback unsuccessfuly.'
        RETURN
    END


    ------------------
    -- 7. Write Log --

    -- Build XML for old value
    -- + Deal with field NewCommunicationTools
    -- + Create variable
    DECLARE @OldCommunicationTools_LogValue NVARCHAR(MAX)
    -- + Non Headline
    IF EXISTS (SELECT 1 FROM @tblOldCommunicationTools WHERE isHeadline = 0)
    BEGIN
        SELECT @OldCommunicationTools_LogValue = STRING_AGG(CAST(ISNULL(bodb_CRM.dbo.f_EncodeXMLValue(sc.SettingValue + ': ' + cnc.CommunicationValue), '') AS NVARCHAR(MAX)), '<br/>') WITHIN GROUP (ORDER BY sc.SettingValue)
        FROM @tblOldCommunicationTools cnc
             LEFT JOIN bodb_CRM.dbo.crmSetting sc WITH (NOLOCK) ON sc.SettingName = 'PICCommunicationTool' AND cnc.CommunicationID = sc.SettingID
    END
    -- + Headline
    IF EXISTS (SELECT 1 FROM @tblOldCommunicationTools WHERE isHeadline = 1)
    BEGIN
        ;WITH CTE_Data AS (
            SELECT bodb_CRM.dbo.f_EncodeXMLValue(cnc.PicInfo) PicInfo,
                   STRING_AGG(CAST(ISNULL(bodb_CRM.dbo.f_EncodeXMLValue(sc.SettingValue + ': ' + cnc.CommunicationValue), '') AS NVARCHAR(MAX)), '<br/>') WITHIN GROUP (ORDER BY sc.SettingValue) CommunicationInfo
            FROM @tblOldCommunicationTools cnc
                 LEFT JOIN bodb_CRM.dbo.crmSetting sc WITH (NOLOCK) ON sc.SettingName = 'PICCommunicationTool' AND cnc.CommunicationID = sc.SettingID
            GROUP BY bodb_CRM.dbo.f_EncodeXMLValue(cnc.PicInfo)
        )
        SELECT @OldCommunicationTools_LogValue = STRING_AGG(CAST(ISNULL((PicInfo + '<br/>' + CommunicationInfo), '') AS NVARCHAR(MAX)), '<br/>') WITHIN GROUP (ORDER BY PicInfo)
        FROM CTE_Data
    END
    -- + Build log content
    DECLARE @OldValues XML 
    SELECT  @OldValues = '<Acc_CRM_NewManualFeedback_FeedbackUpd>' +
                         '<TitleID>'               + ISNULL(CONVERT(VARCHAR(5),@TitleID_Old),'')           + '</TitleID>'               +
                         '<FirstName>'             + ISNULL(dbo.f_EncodeXMLValue(@FirstName_Old),'')       + '</FirstName>'             +
                         '<LastName>'              + ISNULL(dbo.f_EncodeXMLValue(@LastName_Old),'')        + '</LastName>'              +
                         '<LanguageID>'            + ISNULL(CONVERT(VARCHAR(10),@LanguageID_Old),'')       + '</LanguageID>'            +
                         '<CountryID>'             + ISNULL(CONVERT(VARCHAR(10),@CountryID_Old),'')        + '</CountryID>'             +
                         '<FeedbackDate>'          + ISNULL(CONVERT(VARCHAR(20),@FeedbackDate_Old),'')     + '</FeedbackDate>'          +
                         '<SolveDate>'             + ISNULL(CONVERT(VARCHAR(20),@SolveDate_Old),'')        + '</SolveDate>'             +
                         '<CommunicationID>'       + ISNULL(dbo.f_EncodeXMLValue(@CommunicationID_Old),'') + '</CommunicationID>'       +
                         '<StationID>'             + ISNULL(dbo.f_EncodeXMLValue(@StationID_Old),'')       + '</StationID>'             +
                         '<MainCategoryID>'        + ISNULL(dbo.f_EncodeXMLValue(@MainCategoryID_Old),'')  + '</MainCategoryID>'        +
                         '<SubCategoryID>'         + ISNULL(dbo.f_EncodeXMLValue(@SubCategoryID_Old),'')   + '</SubCategoryID>'         +
                         '<SiteID>'                + ISNULL(CONVERT(VARCHAR(10),@SiteID_Old),'')           + '</SiteID>'                +
                         '<RoleID>'                + ISNULL(CONVERT(VARCHAR(10),@RoleID_Old),'')           + '</RoleID>'                +
                         '<ProductID>'             + ISNULL(dbo.f_EncodeXMLValue(@ProductID_Old),'')       + '</ProductID>'             +
                         '<SubProductID>'          + ISNULL(dbo.f_EncodeXMLValue(@SubProductID_Old),'')    + '</SubProductID>'          +
                         '<BettypeID>'             + ISNULL(dbo.f_EncodeXMLValue(@BettypeID_Old),'')       + '</BettypeID>'             +
                         '<ResponseID>'            + ISNULL(CONVERT(VARCHAR(10),@ResponseID_Old),'')       + '</ResponseID>'            +
                         '<StatusID>'              + ISNULL(CONVERT(VARCHAR(10),@StatusID_Old),'')         + '</StatusID>'              +
                         '<Remark>'                + ISNULL(dbo.f_EncodeXMLValue(@Remark_Old),'')          + '</Remark>'                +
                         '<AutoField>'             + ISNULL(dbo.f_EncodeXMLValue(@AutoField_Old),'')       + '</AutoField>'             +
                         '<Solution>'              + ISNULL(dbo.f_EncodeXMLValue(@Solution_Old),'')        + '</Solution>'              +
                         '<IsReviewed>'            + ISNULL(CONVERT(VARCHAR(5),@IsReviewed_Old),'')        + '</IsReviewed>'            +
                         '<Review>'                + ISNULL(dbo.f_EncodeXMLValue(@Review_Old),'')          + '</Review>'                +
                         '<Reviewer>'              + ISNULL(CONVERT(VARCHAR(10),@ReviewerID_Old),'')       + '</Reviewer>'              +
                         '<Subject>'               + ISNULL(dbo.f_EncodeXMLValue(@Subject_Old),'')         + '</Subject>'               +
						 '<FirstResponseTime>'     + ISNULL(CONVERT(VARCHAR(20),@FirstResponseTime_Old),'')+ '</FirstResponseTime>'     +
                         '<ResolutionDate>'        + ISNULL(CONVERT(VARCHAR(20),@ResolutionDate_Old),'')   + '</ResolutionDate>'        +
                         '<Passport>'              + ISNULL(dbo.f_EncodeXMLValue(@Passport_Old),'')        + '</Passport>'              +
                         '<Birthday>'              + ISNULL(CONVERT(VARCHAR(20),@Birthday_Old,107),'')     + '</Birthday>'              +
                         '<BettingCode>'           + ISNULL(dbo.f_EncodeXMLValue(@BettingCode_Old),'')     + '</BettingCode>'           +
                         '<RefCode2>'              + ISNULL(dbo.f_EncodeXMLValue(@RefCode2_Old),'')        + '</RefCode2>'              +
                         '<IsVip>'                 + ISNULL(CONVERT(VARCHAR(10),@IsVip_Old),'')            + '</IsVip>'                 +
                         '<LicenseeType>'          + ISNULL(CONVERT(VARCHAR(10),@LicenseeType_Old),'')     + '</LicenseeType>'          +
                         '<NoInquiries>'           + ISNULL(dbo.f_EncodeXMLValue(@NoInquiries_Old),'')     + '</NoInquiries>'           +
                         '<RelatedCustID>'         + ISNULL(dbo.f_EncodeXMLValue(@RelatedCustID_Old),'')   + '</RelatedCustID>'         +
                         '<NewCommunicationTools>' + ISNULL(@OldCommunicationTools_LogValue,'')            + '</NewCommunicationTools>' +
						 '<Rating>'				   + ISNULL(CONVERT(VARCHAR(5),@Rating_Old),'')			   + '</Rating>'                +
                         '<IsOverWrite>'           + ISNULL(CONVERT(VARCHAR(10),0),'')                     + '</IsOverWrite>'           +
                         '</Acc_CRM_NewManualFeedback_FeedbackUpd>'

    -- Build XML for new value
    -- + Deal with field NewCommunicationTools
    -- + Create variable
    DECLARE @NewCommunicationTools_LogValue NVARCHAR(MAX)
    -- + Non Headline
    IF EXISTS (SELECT 1 FROM @tblNewCommunicationTools WHERE isHeadline = 0)
    BEGIN
        SELECT @NewCommunicationTools_LogValue = STRING_AGG(CAST(ISNULL(bodb_CRM.dbo.f_EncodeXMLValue(sc.SettingValue + ': ' + cnc.CommunicationValue), '') AS NVARCHAR(MAX)), '<br/>') WITHIN GROUP (ORDER BY sc.SettingValue)
        FROM @tblNewCommunicationTools cnc
             LEFT JOIN bodb_CRM.dbo.crmSetting sc WITH (NOLOCK) ON sc.SettingName = 'PICCommunicationTool' AND cnc.CommunicationID = sc.SettingID
    END
    -- + Headline
    IF EXISTS (SELECT 1 FROM @tblNewCommunicationTools WHERE isHeadline = 1)
    BEGIN
        ;WITH CTE_Data AS (
            SELECT bodb_CRM.dbo.f_EncodeXMLValue(cnc.PicInfo) PicInfo,
                   STRING_AGG(CAST(ISNULL(bodb_CRM.dbo.f_EncodeXMLValue(sc.SettingValue + ': ' + cnc.CommunicationValue), '') AS NVARCHAR(MAX)), '<br/>') WITHIN GROUP (ORDER BY sc.SettingValue) CommunicationInfo
            FROM @tblNewCommunicationTools cnc
                 LEFT JOIN bodb_CRM.dbo.crmSetting sc WITH (NOLOCK) ON sc.SettingName = 'PICCommunicationTool' AND cnc.CommunicationID = sc.SettingID
            GROUP BY bodb_CRM.dbo.f_EncodeXMLValue(cnc.PicInfo)
        )
        SELECT @NewCommunicationTools_LogValue = STRING_AGG(CAST(ISNULL((PicInfo + '<br/>' + CommunicationInfo), '') AS NVARCHAR(MAX)), '<br/>') WITHIN GROUP (ORDER BY PicInfo)
        FROM CTE_Data
    END
    -- + Build log content
    DECLARE @NewValues XML
    SELECT  @NewValues = '<Acc_CRM_NewManualFeedback_FeedbackUpd>' +
                         '<TitleID>'               + ISNULL(CONVERT(VARCHAR(5),@TitleID),'')               + '</TitleID>'               +
                         '<FirstName>'             + ISNULL(dbo.f_EncodeXMLValue(@FirstName),'')           + '</FirstName>'             +
                         '<LastName>'              + ISNULL(dbo.f_EncodeXMLValue(@LastName),'')            + '</LastName>'              +
                         '<LanguageID>'            + ISNULL(CONVERT(VARCHAR(10),@LanguageID),'')           + '</LanguageID>'            +
                         '<CountryID>'             + ISNULL(CONVERT(VARCHAR(10),@CountryID),'')            + '</CountryID>'             +
                         '<FeedbackDate>'          + ISNULL(CONVERT(VARCHAR(20),@FeedbackDate),'')         + '</FeedbackDate>'          +
                         '<SolveDate>'             + ISNULL(CONVERT(VARCHAR(20),@SolveDate),'')            + '</SolveDate>'             +
                         '<CommunicationID>'       + ISNULL(dbo.f_EncodeXMLValue(@CommunicationID_New),'') + '</CommunicationID>'       +
                         '<StationID>'             + ISNULL(dbo.f_EncodeXMLValue(@StationID_New),'')       + '</StationID>'             +
                         '<MainCategoryID>'        + ISNULL(dbo.f_EncodeXMLValue(@MainCategoryID_New),'')  + '</MainCategoryID>'        +
                         '<SubCategoryID>'         + ISNULL(dbo.f_EncodeXMLValue(@SubCategoryID_New),'')   + '</SubCategoryID>'         +
                         '<SiteID>'                + ISNULL(CONVERT(VARCHAR(10),@SiteID),'')               + '</SiteID>'                +
                         '<RoleID>'                + ISNULL(CONVERT(VARCHAR(10),@RoleID),'')               + '</RoleID>'                +
                         '<ProductID>'             + ISNULL(dbo.f_EncodeXMLValue(@ProductID_New),'')       + '</ProductID>'             +
                         '<SubProductID>'          + ISNULL(dbo.f_EncodeXMLValue(@SubProductID_New),'')    + '</SubProductID>'          +
                         '<BettypeID>'             + ISNULL(dbo.f_EncodeXMLValue(@BettypeID_New),'')       + '</BettypeID>'             +
                         '<ResponseID>'            + ISNULL(CONVERT(VARCHAR(10),@ResponseID),'')           + '</ResponseID>'            +
                         '<StatusID>'              + ISNULL(CONVERT(VARCHAR(10),@StatusID),'')             + '</StatusID>'              +
                         '<Remark>'                + ISNULL(dbo.f_EncodeXMLValue(@Remark),'')              + '</Remark>'                +
                         '<AutoField>'             + ISNULL(dbo.f_EncodeXMLValue(@AutoField),'')           + '</AutoField>'             +
                         '<Solution>'              + ISNULL(dbo.f_EncodeXMLValue(@Solution),'')            + '</Solution>'              +
                         '<IsReviewed>'            + ISNULL(CONVERT(VARCHAR(5),@IsReviewed),'')            + '</IsReviewed>'            +
                         '<Review>'                + ISNULL(dbo.f_EncodeXMLValue(@Review),'')              + '</Review>'                +
                         '<Reviewer>'              + ISNULL(CONVERT(VARCHAR(10),@ReviewerID),'')           + '</Reviewer>'              +
                         '<Subject>'               + ISNULL(dbo.f_EncodeXMLValue(@Subject),'')             + '</Subject>'               +
						 '<FirstResponseTime>'     + ISNULL(CONVERT(VARCHAR(20),@FirstResponseTime),'')	   + '</FirstResponseTime>'     +
                         '<ResolutionDate>'        + ISNULL(CONVERT(VARCHAR(20),@ResolutionDate),'')       + '</ResolutionDate>'        +
                         '<Passport>'              + ISNULL(dbo.f_EncodeXMLValue(@Passport),'')            + '</Passport>'              +
                         '<Birthday>'              + ISNULL(CONVERT(VARCHAR(20),@Birthday,107),'')         + '</Birthday>'              +
                         '<BettingCode>'           + ISNULL(dbo.f_EncodeXMLValue(@BettingCode),'')         + '</BettingCode>'           +
                         '<RefCode2>'              + ISNULL(dbo.f_EncodeXMLValue(@RefCode2),'')            + '</RefCode2>'              +
                         '<IsVip>'                 + ISNULL(CONVERT(VARCHAR(10),@IsVip_crmFeedback),'')    + '</IsVip>'                 +
                         '<LicenseeType>'          + ISNULL(CONVERT(VARCHAR(10),@LicenseeType),'')         + '</LicenseeType>'          +
                         '<NoInquiries>'           + ISNULL(dbo.f_EncodeXMLValue(@NoInquiries),'')         + '</NoInquiries>'           +
                         '<RelatedCustID>'         + ISNULL(dbo.f_EncodeXMLValue(@RelatedCustID),'')       + '</RelatedCustID>'         +
                         '<NewCommunicationTools>' + ISNULL(@NewCommunicationTools_LogValue,'')            + '</NewCommunicationTools>' +
						 '<Rating>'				   + ISNULL(CONVERT(VARCHAR(5),@Rating),'')				   + '</Rating>'				+
                         '<IsOverWrite>'           + ISNULL(CONVERT(VARCHAR(10),@IsOverWrite),'')          + '</IsOverWrite>'           +
                         '</Acc_CRM_NewManualFeedback_FeedbackUpd>'

    -- Execute sp to write log
    EXECUTE bodb_CRM.dbo.WriteLog_UserLog_crmLogFeedback @FeedbackID  = @FeedbackID,
                                                         @CustID      = @CustID,
                                                         @Description = @Description,
                                                         @Solution    = @Solution,
                                                         @Review      = @Review,
                                                         @NewValues   = @NewValues,
                                                         @OldValues   = @OldValues,
                                                         @Duration    = NULL,
                                                         @ActionID    = 208,
                                                         @UserID      = @UserID,
                                                         @IP          = @IP

END
GO