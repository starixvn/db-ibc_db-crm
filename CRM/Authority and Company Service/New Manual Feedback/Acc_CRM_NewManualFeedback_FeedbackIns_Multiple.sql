/*<info serverAlias="DBCRM-bodb_CRM" executers="wsv_nap" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE dbo.Acc_CRM_NewManualFeedback_FeedbackIns_Multiple @ListCustID           VARCHAR(MAX)    = NULL,
                                                                   @RelatedCustomers     NVARCHAR(MAX)   = NULL,
                                                                   @FeedbackDate         DATETIME        = NULL,
																   @FirstResponseTime	 DATETIME        = NULL,
                                                                   @ResolutionDate       DATETIME        = NULL,
                                                                   @StationID            VARCHAR(MAX),
                                                                   @IsCheckedDefaultComm BIT             = 0,
                                                                   @CommunicationID      VARCHAR(MAX)    = '',
                                                                   @Category             VARCHAR(MAX),
                                                                   @Categorystr          VARCHAR(MAX),
                                                                   @SubCategorystr       VARCHAR(MAX),
                                                                   @Product              VARCHAR(MAX),
                                                                   @StatusID             INT,
                                                                   @LanguageID           INT             = 0,
                                                                   @ResponseID           INT,
                                                                   @CountryName          NVARCHAR(300)   = '',
                                                                   @NoInquiries          SMALLINT        = NULL,
                                                                   @Subject              NVARCHAR(200)   = NULL,
                                                                   @AutoField            NVARCHAR(MAX)   = NULL,
                                                                   @AutoField1           NVARCHAR(MAX)   = '',
                                                                   @AutoField2           NVARCHAR(MAX)   = '',
                                                                   @AutoField3           NVARCHAR(MAX)   = '',
                                                                   @Description          NVARCHAR(MAX),
                                                                   @Solution             NVARCHAR(MAX)   = '',
                                                                   @IsReviewed           BIT             = 0,
                                                                   @Review               NVARCHAR(MAX)   = NULL,
                                                                   @ReviewerID           INT             = NULL,
                                                                   @CreatorID            INT,
                                                                   @UserID               INT,
																   @Rating				 TINYINT		 = 0,
                                                                   @IP                   VARCHAR(45),
                                                                   @ErrCode              INT            = 0  OUTPUT,
                                                                   @ErrMsg               NVARCHAR(4000) = '' OUTPUT
AS

/*
    Created:  Ned.Le
    Date:     20240220
    Task:     Insert multiple feedback info
    DB:       DBCRM.bodb_CRM
    Original: Acc_CRM_GuestFeedbackIns_Multiple

    Revisions:
        20240220@Ned.Le: CRM - Manage Headline/PIC/Staff authority and Company services (#193385)
        20240516@Ned.Le: CRM - Allow to add new Communication tools while Adding Feedback and allow to overwrite communication tools on Account Details page (#205068)
		20250225@Virgil: CRM - Add Rating Column for Feedback [Redmine: #218235]
		20250320@Virgil: CRM - Add 1st Reponse Time for Feedback [Redmine: #220801]
        
    Param's Explanation:
        @ListCustID       = '<ROOT>
                                 <Cust CustId="7818" Username="RM09" />
                                 <Cust CustId="89523498" Username="RM103" />
                             </ROOT>'
        @RelatedCustomers = '<ROOT>
                                 <Row CustId="1" RelatedCustId="2" Username="test" />
                             </ROOT>'
        @Product          = '<ROOT>
                                 <Product ProductID="46004" SubProductID="8063" BetTypeID="9144" />
                             </ROOT>'
        @Category         = '<ROOT>
                                 <Category MainCategoryID="3040" SubCategoryID="4183" />
                                 <Category MainCategoryID="3040" SubCategoryID="4187" />
                                 <Category MainCategoryID="3028" SubCategoryID="4005" />
                             </ROOT>'
*/

BEGIN

    SET NOCOUNT ON


    -------------------------------------------------
    -- CODE LAYOUT                                 --
    -------------------------------------------------
    -- 1. Check data consistency                   --
    -- 2. Parse data from input parameter to table --
    -- 3. Check terminated licensee site           --
    -- 4. Sync customers not exist on CRM to CRM   --
    -- 5. Process to create feedback               --
    -- 6. Drop temp tables                         --
    -------------------------------------------------


    -------------------------------
    -- 1. Check data consistency --

    -- Reset parameter value
    SELECT @ErrCode = 0
    SELECT @ErrMsg  = ''

    -- Check input parameter value
    IF ISNULL(@Categorystr, '')    = '' OR
       ISNULL(@Category, '')       = '' OR
       ISNULL(@Product, '')        = '' OR
       ISNULL(@StatusID, 0)        = 0  OR
       ISNULL(@SubCategorystr, '') = '' OR
       ISNULL(@ResponseID, 0)      = 0  OR
       ISNULL(@StationID, '')      = ''
    BEGIN
        SELECT @ErrCode = 100
        SELECT @ErrMsg  = 'Incorrect Data.'
        RETURN
    END


    -------------------------------------------------
    -- 2. Parse data from input parameter to table --

    -- Declare variables
    DECLARE @iDoc INT

    -- #tmpListCustID
    CREATE TABLE #tmpListCustID (
        CustId   INT PRIMARY KEY,
        Username NVARCHAR(200)
    )

    EXEC sp_xml_preparedocument @iDoc OUTPUT, @ListCustID

    INSERT INTO #tmpListCustID (CustId, Username)
    SELECT CustId, Username
    FROM OPENXML(@iDoc, '/ROOT/Cust', 1) WITH (CustId INT, Username NVARCHAR(200))
    
    EXEC sp_xml_removedocument @iDoc

    -- #tmpRelatedCustomers
    CREATE TABLE #tmpRelatedCustomers (
        CustId        INT,
        RelatedCustId INT,
        Username      NVARCHAR(200)
    )

    IF (ISNULL(@RelatedCustomers, '') <> '')
    BEGIN
        EXEC sp_xml_preparedocument @iDoc OUTPUT, @RelatedCustomers

        INSERT INTO #tmpRelatedCustomers (CustId, RelatedCustId, Username)
        SELECT CustId, RelatedCustId, Username
        FROM OPENXML(@iDoc, '/ROOT/Row', 1) WITH (CustId INT, RelatedCustId INT, Username NVARCHAR(200))

        EXEC sp_xml_removedocument @iDoc
    END


    ---------------------------------------
    -- 3. Check terminated licensee site --

    CREATE TABLE #tmpInvalidCustomer (CustID INT, UserName NVARCHAR(200))
        
    INSERT INTO #tmpInvalidCustomer(CustID, UserName)
    SELECT c.CustID, c.UserName
    FROM bodb_CRM.dbo.crmCustomer c WITH (NOLOCK)
    WHERE (c.CustID IN (SELECT CustId FROM #tmpListCustID) OR c.CustID IN (SELECT RelatedCustId FROM #tmpRelatedCustomers))
          AND EXISTS (SELECT TOP 1 1
                      FROM bodb_CRM.dbo.crmSettingRelation sr WITH (NOLOCK)
                           INNER JOIN bodb_CRM.dbo.crmSetting s WITH (NOLOCK) ON sr.SettingID = s.SettingID AND s.SettingName = 'Site'
                      WHERE s.SettingID = c.SiteID
                            AND s.IsActive = 0
                            AND sr.ParentID = 33000)

    INSERT INTO #tmpInvalidCustomer(CustID, UserName)
    SELECT c.custid, c.username
    FROM bodb02.dbo.Customer c WITH (NOLOCK)
    WHERE (c.CustID IN (SELECT CustId FROM #tmpListCustID) OR c.CustID IN (SELECT RelatedCustId FROM #tmpRelatedCustomers))
          AND c.custid NOT IN (SELECT CustID FROM #tmpInvalidCustomer)
          AND EXISTS (SELECT TOP 1 1
                      FROM bodb_CRM.dbo.crmSettingRelation sr WITH (NOLOCK)
                           INNER JOIN bodb_CRM.dbo.crmSetting s WITH (NOLOCK) ON sr.SettingID = s.SettingID AND s.SettingName = 'Site'
                      WHERE s.SettingValue = c.site
                            AND s.IsActive = 0
                            AND sr.ParentID = 33000)

    IF EXISTS(SELECT 1 FROM #tmpInvalidCustomer)
    BEGIN
        SELECT @ErrMsg  = ''
        SELECT @ErrMsg  = ',' + @ErrMsg + UserName FROM #tmpInvalidCustomer
        SELECT @ErrMsg  = STUFF(@ErrMsg, 1, 1, '')
        SELECT @ErrMsg  = 'Some Usernames belong to Inactive Site: '+ @ErrMsg
        SELECT @ErrCode = 106
        RETURN
    END


    -----------------------------------------------
    -- 4. Sync customers not exist on CRM to CRM --

    -- Create temp table
    CREATE TABLE #tmpSyncCustomers (
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
    INSERT INTO #tmpSyncCustomers (CustID)
    SELECT CustId
    FROM #tmpListCustID

    INSERT INTO #tmpSyncCustomers (CustID)
    SELECT RelatedCustId
    FROM #tmpRelatedCustomers
    WHERE RelatedCustId NOT IN (SELECT CustID FROM #tmpSyncCustomers)
        
    UPDATE t
    SET t.isExistsCRM = 1
    FROM #tmpSyncCustomers t
         INNER JOIN bodb_CRM.dbo.crmCustomer cm WITH (NOLOCK) ON t.custid = cm.custid

    -- Process to sync data
    IF EXISTS (SELECT 1 FROM #tmpSyncCustomers WHERE isExistsCRM = 0)
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
        FROM #tmpSyncCustomers t
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
            FROM #tmpSyncCustomers t
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


    -----------------------------------
    -- 5. Process to create feedback --

    -- Declare variables and temp tables
    DECLARE @input_CustID         INT,
            @input_TitleID        INT,
            @input_FirstName      NVARCHAR(50),
            @input_LastName       NVARCHAR(50),
            @input_Birthday       DATETIME,
            @input_Passport       NVARCHAR(100),
            @input_BettingCode    NVARCHAR(50),
            @input_RefCode2       NVARCHAR(50),
            @input_IsVip          BIT,
            @input_CountryID      INT,
            @input_SiteID         INT,
            @input_LicenseeType   INT,
            @input_RoleID         INT,
            @input_IsHeadline     BIT,
            @input_RelatedCustIds VARCHAR(MAX)

    DECLARE @support_CommName         NVARCHAR(MAX),
            @support_RelatedCustomers NVARCHAR(MAX),
            @support_DefaultLanguage  BiT = 0

    IF (ISNULL(@CountryName, '') <> '')
    BEGIN
        SELECT @input_CountryID = CountryID
        FROM bodb_CRM.dbo.crmCountry WITH (NOLOCK)
        WHERE CountryName = @CountryName
    END

    IF (@LanguageID = 0)
    BEGIN
        SET @support_DefaultLanguage = 1
    END

    CREATE TABLE #tmpSupportComm (CommID INT)

    -- Run the loop to process data
    WHILE EXISTS (SELECT 1 FROM #tmpListCustID)
    BEGIN
        -- + Get key value
        SELECT TOP 1 @input_CustID = CustId FROM #tmpListCustID

        -- + Reset value for some parameter
        SELECT @ErrCode                  = 0,
               @ErrMsg                   = '',
               @input_RelatedCustIds     = '',
               @support_RelatedCustomers = ''

        IF (@support_DefaultLanguage = 1)
        BEGIN
            SET @LanguageID = 0
        END
        
        IF (@IsCheckedDefaultComm = 1)
        BEGIN
            TRUNCATE TABLE #tmpSupportComm
            SELECT @CommunicationID = ''
        END

        -- + Deal with @IsCheckedDefaultComm
        -- + --> Check #1
        IF (@IsCheckedDefaultComm = 1)
        BEGIN
            SELECT @CommunicationID = STUFF((SELECT ',' + CONVERT(VARCHAR(50), c.settingID)
                                             FROM bodb_CRM.dbo.crmDefaultCommTool c WITH (NOLOCK)
                                             WHERE c.DefaultCommID = a.DefaultCommID
                                                   AND c.SettingType = 3
                                             FOR XML PATH('')), 1, 1, '')
            FROM bodb_CRM.dbo.crmDefaultCommTool a WITH (NOLOCK)
            WHERE a.DefaultCommID <> 0
                  AND a.CustID = @input_CustID
                  AND STUFF((SELECT ',' + CONVERT(VARCHAR(50), c.settingID)
                             FROM bodb_CRM.dbo.crmDefaultCommTool c WITH (NOLOCK)
                             WHERE c.DefaultCommID = a.DefaultCommID
                                   AND c.SettingType = 1
                             ORDER BY c.SettingID ASC
                             FOR XML PATH('')), 1, 1, '') = @Categorystr
                  AND STUFF((SELECT ',' + CONVERT(VARCHAR(50), c.settingID)
                             FROM bodb_CRM.dbo.crmDefaultCommTool c WITH (NOLOCK)
                             WHERE c.DefaultCommID = a.DefaultCommID
                                   AND c.SettingType = 2
                             ORDER BY c.SettingID ASC
                             FOR XML PATH('')), 1, 1, '') = @SubCategorystr
        END
        -- + --> Check #2
        IF ((ISNULL(@CommunicationID, '') = '') AND (@IsCheckedDefaultComm = 1))
        BEGIN
            SELECT @CommunicationID = STUFF((SELECT ',' + CONVERT(VARCHAR(50), c.settingID)
                                             FROM bodb_CRM.dbo.crmDefaultCommTool c WITH (NOLOCK)
                                             WHERE c.DefaultCommID = a.DefaultCommID
                                                   AND c.SettingType = 3
                                             FOR XML PATH('')), 1, 1, '')
            FROM bodb_CRM.dbo.crmDefaultCommTool a WITH (NOLOCK)
            WHERE a.DefaultCommID <> 0
                  AND a.CustID = @input_CustID
                  AND STUFF((SELECT ',' + CONVERT(VARCHAR(50), c.settingID)
                             FROM bodb_CRM.dbo.crmDefaultCommTool c WITH (NOLOCK)
                             WHERE c.DefaultCommID = a.DefaultCommID
                                   AND c.SettingType = 1
                             ORDER BY c.SettingID ASC
                             FOR XML PATH('')), 1, 1, '') = @Categorystr
                  AND EXISTS (SELECT TOP 1 1
                              FROM bodb_CRM.dbo.crmDefaultCommTool c WITH (NOLOCK)
                              WHERE c.DefaultCommID = a.DefaultCommID
                                    AND c.SettingID = 0
                                    AND c.SettingType = 2)
        END
        -- + --> Check #3
        IF ((ISNULL(@CommunicationID, '') = '') AND (@IsCheckedDefaultComm = 1))
        BEGIN
            SELECT @CommunicationID = STUFF((SELECT ',' + CONVERT(VARCHAR(50), c.settingID)
                                             FROM bodb_CRM.dbo.crmDefaultCommTool c WITH (NOLOCK)
                                             WHERE c.DefaultCommID = a.DefaultCommID
                                                   AND c.SettingType = 3
                                             FOR XML path('')), 1, 1, '')
            FROM bodb_CRM.dbo.crmDefaultCommTool a WITH (NOLOCK)
            WHERE a.DefaultCommID <> 0
                  AND a.CustID = @input_CustID
                  AND EXISTS (SELECT TOP 1 1
                              FROM bodb_CRM.dbo.crmDefaultCommTool c WITH (NOLOCK)
                              WHERE c.DefaultCommID = a.DefaultCommID
                                    AND c.SettingID = 0
                                    AND c.SettingType = 1)
                  AND STUFF((SELECT ',' + CONVERT(VARCHAR(50), c.settingID)
                             FROM bodb_CRM.dbo.crmDefaultCommTool c WITH (NOLOCK)
                             WHERE c.DefaultCommID = a.DefaultCommID
                                   AND c.SettingType = 2
                             ORDER BY c.SettingID ASC
                             FOR XML path('')), 1, 1, '') = @SubCategorystr
        END
        -- + --> Check #4
        IF ((ISNULL(@CommunicationID, '') = '') AND (@IsCheckedDefaultComm = 1))
        BEGIN
            SELECT @CommunicationID = STUFF((SELECT ',' + CONVERT(VARCHAR(50), c.settingID)
                                             FROM bodb_CRM.dbo.crmDefaultCommTool c WITH (NOLOCK)
                                             WHERE c.DefaultCommID = a.DefaultCommID
                                                   AND c.SettingType = 3
                                             FOR XML path('')), 1, 1, '')
            FROM bodb_CRM.dbo.crmDefaultCommTool a WITH (NOLOCK)
            WHERE a.DefaultCommID <> 0
                  AND a.CustID = @input_CustID
                  AND EXISTS (SELECT TOP 1 1
                              FROM bodb_CRM.dbo.crmDefaultCommTool c WITH (NOLOCK)
                              WHERE c.DefaultCommID = a.DefaultCommID
                                    AND c.SettingID = 0
                                    AND c.SettingType = 1)
                  AND EXISTS (SELECT TOP 1 1
                              FROM bodb_CRM.dbo.crmDefaultCommTool c WITH (NOLOCK)
                              WHERE c.DefaultCommID = a.DefaultCommID
                                    AND c.SettingID = 0
                                    AND c.SettingType = 2)
        END
        -- + --> Check #5
        IF ((ISNULL(@CommunicationID, '') = '') AND (@IsCheckedDefaultComm = 1))
        BEGIN
            SELECT @CommunicationID = 1005
        END

        -- + Main process
        IF (ISNULL(@CommunicationID, '') <> '')
        BEGIN
            -- + --> Set value for some parameters
            IF (@IsCheckedDefaultComm = 1)
            BEGIN
                INSERT INTO #tmpSupportComm (CommID)
                SELECT SettingID
                FROM bodb_CRM.dbo.strSplit(@CommunicationID, ',')

                SELECT @support_CommName = STUFF((SELECT '/' + s.SettingValue
                                           FROM #tmpSupportComm t
                                                INNER JOIN bodb_CRM.dbo.crmSetting s WITH (NOLOCK) ON t.CommID = s.SettingID
                                          FOR XML path('')), 1, 1, '')

                SELECT @AutoField = @AutoField1 + @AutoField2 + @support_CommName + @AutoField3
            END

            SELECT @support_RelatedCustomers = STUFF((SELECT ', ' + Username
                                                      FROM #tmpRelatedCustomers
                                                      WHERE CustId = @input_CustID
                                                      ORDER BY Username
                                                      FOR XML path('')), 1, 1, '')

            SELECT @input_RelatedCustIds = STUFF((SELECT ',' + CAST(RelatedCustId AS VARCHAR(20))
                                                  FROM #tmpRelatedCustomers
                                                  WHERE CustId = @input_CustID
                                                  FOR XML path('')), 1, 1, '')

            IF (@support_RelatedCustomers <> '')
            BEGIN
                IF CHARINDEX('System ID:', @AutoField) = 0
                BEGIN
                    SET @AutoField = @AutoField + CHAR(13) + 'System ID:'
                END

                SET @AutoField = STUFF(@AutoField, CHARINDEX('System ID:', @AutoField), LEN('System ID:'), 'System ID: ' + @support_RelatedCustomers)
            END

            SELECT @input_TitleID      = c.TitleID,
                   @input_FirstName    = c.FirstName,
                   @input_LastName     = c.LastName,
                   @input_Birthday     = c.Birthday,
                   @input_Passport     = c.Passport,
                   @input_BettingCode  = c.RefCode1,
                   @input_RefCode2     = c.RefCode2,
                   @input_IsVip        = c.IsVip,
                   @input_CountryID    = CASE WHEN ISNULL(@CountryName,'') <> '' THEN @input_CountryID ELSE CountryID END,
                   @input_SiteID       = SiteID,
                   @input_LicenseeType = LicenseeType
            FROM bodb_CRM.dbo.crmCustomer c WITH (NOLOCK)
            WHERE c.CustID = @input_CustID

            IF EXISTS (SELECT TOP 1 1 FROM bodb02.dbo.Customer c WITH (NOLOCK) WHERE c.CustID = @input_CustID)
            BEGIN
                SELECT @input_RoleID = CASE WHEN c.roleid = 1 THEN 7000
                                            WHEN c.roleid = 2 THEN 7001
                                            WHEN c.roleid = 3 THEN 7002
                                            WHEN c.roleid = 4 THEN 7003
                                            ELSE 7004 END
                FROM bodb02.dbo.Customer c WITH (NOLOCK)
                WHERE c.CustID = @input_CustID
            END
            ELSE
            BEGIN
                SELECT @input_RoleID = 7004
            END
            
            IF (@support_DefaultLanguage = 1)
            BEGIN
                SELECT @LanguageID = LanguageID
                FROM dbo.crmCustomerLanguage WITH (NOLOCK)
                WHERE Custid = @input_CustID
            END

            IF EXISTS (SELECT TOP 1 1 FROM bodb02.dbo.custAccount WITH (NOLOCK) WHERE custid = @input_CustID AND IsGroupHeadLine = 1)
            BEGIN
                SET @input_IsHeadline = 1
            END
            ELSE
            BEGIN
                SET @input_IsHeadline = 0
            END

            -- + --> Run sp to create feedback
            EXEC bodb_CRM.dbo.Acc_CRM_NewManualFeedback_FeedbackIns --KEY
                                                                    @CustID                = @input_CustID,
                                                                    --TABLE
                                                                    -->crmFeedback
                                                                    -->+CustomerInfo
                                                                    @TitleID               = @input_TitleID,
                                                                    @FirstName             = @input_FirstName,
                                                                    @LastName              = @input_LastName,
                                                                    @Birthday              = @input_Birthday,
                                                                    @Passport              = @input_Passport,
                                                                    @BettingCode           = @input_BettingCode,
                                                                    @RefCode2              = @input_RefCode2,
                                                                    @IsVip                 = @input_IsVip,
                                                                    -->+FeedbackInfo
                                                                    @FeedbackDate          = @FeedbackDate,
																	@FirstResponseTime	   = @FirstResponseTime,
                                                                    @ResolutionDate        = @ResolutionDate,
                                                                    @StatusID              = @StatusID,
                                                                    @LanguageID            = @LanguageID,
                                                                    @ResponseID            = @ResponseID,
                                                                    @RoleID                = @input_RoleID,
                                                                    @CountryID             = @input_CountryID,
                                                                    @SiteID                = @input_SiteID,
                                                                    @LicenseeType          = @input_LicenseeType,
                                                                    @NoInquiries           = @NoInquiries,
                                                                    @Subject               = @Subject,
                                                                    @AutoField             = @AutoField,
                                                                    @Description           = @Description,
                                                                    @Solution              = @Solution,
                                                                    @IsReviewed            = @IsReviewed,
                                                                    @Review                = @Review,
                                                                    @ReviewerID            = @ReviewerID,
                                                                    @CreatorID             = @CreatorID,
																	@Rating				   = @Rating,
                                                                    -->crmFeedbackNewCommunicationTool
                                                                    @NewCommunicationTools = NULL,
                                                                    -->crmFeedbackSetting
                                                                    @StationID             = @StationID,
                                                                    @CommunicationID       = @CommunicationID,
                                                                    @Category              = @Category,
                                                                    @Product               = @Product,
                                                                    --crmFeedbackCustomer
                                                                    @RelatedCustID         = @input_RelatedCustIds,
                                                                    --IFELSE
                                                                    @IsCommunicationLog    = 1,
                                                                    @IsHeadline            = @input_IsHeadline,
                                                                    @IsManualMultiple      = 1,
                                                                    @IsOverwrite           = 0,
                                                                    --LOG
                                                                    @UserID                = @UserID,
                                                                    @IP                    = @IP,
                                                                    @ErrCode               = @ErrCode OUTPUT,
                                                                    @ErrMsg                = @ErrMsg  OUTPUT

            IF (@ErrCode <> 0)
            BEGIN
                SELECT @ErrMsg  = CASE WHEN @ErrCode = 110 THEN @ErrMsg ELSE 'Insert failed 2' END
                SELECT @ErrCode = 102
                RETURN
            END
        END

        -- Reset data for the loop
        DELETE tmp
        FROM #tmpListCustID tmp
        WHERE CustId = @input_CustID
    END


    -------------------------
    -- 6. Drop temp tables --

    DROP TABLE #tmpListCustID
    DROP TABLE #tmpRelatedCustomers
    DROP TABLE #tmpInvalidCustomer
    DROP TABLE #tmpSyncCustomers
    DROP TABLE #tmpSupportComm

END
GO