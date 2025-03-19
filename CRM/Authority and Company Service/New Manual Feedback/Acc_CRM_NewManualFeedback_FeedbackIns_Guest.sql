/*<info serverAlias="DBCRM-bodb_CRM" executers="wsv_nap" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE dbo.Acc_CRM_NewManualFeedback_FeedbackIns_Guest --Guest Information
                                                                @UserName              NVARCHAR(50),
                                                                @TitleID               INT              = NULL,
                                                                @FirstName             NVARCHAR(50)     = NULL,
                                                                @LastName              NVARCHAR(50)     = NULL,
                                                                @Birthday              SMALLDATETIME    = NULL,
                                                                @Passport              NVARCHAR(100)    = NULL,
                                                                @IsVip                 BIT              = NULL,
                                                                @NewCommunicationTools NVARCHAR(MAX) = NULL,
                                                                --Feedback Information
                                                                @FeedbackDate          DATETIME         = NULL,
                                                                @ResolutionDate        DATETIME         = NULL,
                                                                @StationID             VARCHAR(MAX)     = NULL,
                                                                @CommunicationID       VARCHAR(MAX),
                                                                @Category              VARCHAR(MAX),
                                                                @Product               VARCHAR(MAX),
                                                                @StatusID              INT,
                                                                @LanguageID            INT,
                                                                @ResponseID            INT,
                                                                @RoleID                INT              = 7004,
                                                                @CountryID             INT,
                                                                @SiteID                INT              = 0,
                                                                @LicenseeType          INT              = 0,
                                                                @NoInquiries           SMALLINT         = NULL,
                                                                @RelatedCustID         VARCHAR(MAX)     = NULL,
                                                                @Subject               NVARCHAR(200)    = NULL,
                                                                @AutoField             NVARCHAR(MAX)    = NULL,
                                                                @Description           NVARCHAR(MAX),
                                                                @Solution              NVARCHAR(MAX)    = '',
                                                                @IsReviewed            BIT              = 0,
                                                                @Review                NVARCHAR(MAX)    = NULL,
                                                                @ReviewerID            INT              = NULL,
                                                                @CreatorID             INT,
																@Rating				   TINYINT			= 0,
                                                                --Log Information
                                                                @UserID                INT,
                                                                @IP                    VARCHAR(45),
                                                                @ErrCode               INT              = 0  OUTPUT,
                                                                @ErrMsg                NVARCHAR(4000)   = '' OUTPUT
AS

/*
    Created:  Ned.Le
    Date:     20240220
    Task :    Create new guest customer as well as add feedback for this guest
    DB:       DBCRM.bodb_CRM
    Original: Acc_CRM_GuestFeedbackIns

    Revisions:
        20240220@Ned.Le: CRM - Manage Headline/PIC/Staff authority and Company services (#193385)
        20240516@Ned.Le: CRM - Allow to add new Communication tools while Adding Feedback and allow to overwrite communication tools on Account Details page (#205068)
		20241225@Tacy: CRM - Offer Direct Member for Super and Master [Redmine: #215809]
		20250225@Virgil: CRM - Add Rating Column for Feedback [Redmine: #218235]

    Param's Explanation:
        @Category: <ROOT>
                       <Category MainCategoryID="212" SubCategoryID="2401"/>
                   </ROOT>
        @Product: <ROOT>
                      <Product ProductID="212" SubProductID="2401" BettypeID="1,2,3,4,5"/>
                  </ROOT>
        @NewCommunicationTools: <ROOT>
                                    <NewCommunicationTool CommunicationID="49001" CommunicationValue="023568974,0909862546"/>
                                    <NewCommunicationTool CommunicationID="49006" CommunicationValue="whatsapp01,whatsapp02"/>
                                </ROOT>
*/

BEGIN

    SET NOCOUNT ON


    -------------------------------------------------------
    -- CODE LAYOUT                                       --
    -------------------------------------------------------
    -- 1. Create key variables                           --
    -- 2. Create new guest customer                      --
    -- 3. Create communication tool for guest customer   --
    -- 4. Sync related customers not exist on CRM to CRM --
    -- 5. Create feedback for guest customer             --
    -------------------------------------------------------



    -----------------------------
    -- 1. Create key variables --

    DECLARE @CustID INT


    ----------------------------------
    -- 2. Create new guest customer --

    EXECUTE bodb_CRM.dbo.Acc_CRM_CustomerGuestIns @CustID       = @CustID OUTPUT,
                                                  @UserName     = @UserName,
                                                  @FirstName    = @FirstName,
                                                  @LastName     = @LastName,
                                                  @TitleID      = @TitleID,
                                                  @Birthday     = @Birthday,
                                                  @Passport     = @Passport,
                                                  @LanguageID   = @LanguageID,
                                                  @CountryID    = @CountryID,
                                                  @IsVIP        = @IsVIP,
                                                  @SiteID       = @SiteID,
                                                  @CreatorID    = @CreatorID,
                                                  @LicenseeType = @LicenseeType,
                                                  @UserID       = @UserID,
                                                  @IP           = @IP,
                                                  @ErrCode      = @ErrCode OUTPUT,
                                                  @ErrMsg       = @ErrMsg OUTPUT

    IF (@ErrCode <> 0)
    BEGIN
        SELECT @ErrCode = 100
        SELECT @ErrMsg  = 'Error when create new guest customer'
        RETURN
    END


    -----------------------------------------------------
    -- 3. Create communication tool for guest customer --

    IF (ISNULL(@NewCommunicationTools, '') <> '')
    BEGIN
        EXEC bodb_CRM.dbo.Acc_CRM_NewAccDetail_UpdOtherAccCommunicationInfo @CustID                = @CustID,
                                                                            @NewCommunicationTools = @NewCommunicationTools,
                                                                            @UserID                = @UserID,
                                                                            @IP                    = @IP,
                                                                            @ErrCode               = @ErrCode OUTPUT,
                                                                            @ErrMsg                = @ErrMsg  OUTPUT

        IF (@ErrCode <> 0)
        BEGIN
            SELECT @ErrCode = 100
            SELECT @ErrMsg  = 'Error when create communication tool for guest customer guest customer'
            RETURN
        END
    END
    

    -------------------------------------------------------
    -- 4. Sync related customers not exist on CRM to CRM --

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
                SELECT @ErrMsg  = 'Sync related customer failed'
                RETURN
            END
        END    
    END

    -- Drop temp table
    DROP TABLE #tmpSyncRelatedCustomer


    -------------------------------------------
    -- 5. Create feedback for guest customer --

    EXEC bodb_CRM.dbo.Acc_CRM_NewManualFeedback_FeedbackIns --KEY
                                                            @CustID                = @CustID,
                                                            --TABLE
                                                            -->crmFeedback
                                                            -->+CustomerInfo
                                                            @TitleID               = @TitleID,
                                                            @FirstName             = @FirstName,
                                                            @LastName              = @LastName,
                                                            @Birthday              = @Birthday,
                                                            @Passport              = @Passport,
                                                            @BettingCode           = NULL,
                                                            @RefCode2              = NULL,
                                                            @IsVip                 = @IsVip,
                                                            -->+FeedbackInfo
                                                            @FeedbackDate          = @FeedbackDate,
                                                            @ResolutionDate        = @ResolutionDate,
                                                            @StatusID              = @StatusID,
                                                            @LanguageID            = @LanguageID,
                                                            @ResponseID            = @ResponseID,
                                                            @RoleID                = @RoleID,
                                                            @CountryID             = @CountryID,
                                                            @SiteID                = @SiteID,
                                                            @LicenseeType          = @LicenseeType,
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
                                                            @RelatedCustID         = @RelatedCustID,
                                                            --IFELSE
                                                            @IsCommunicationLog    = 1,
                                                            @IsHeadline            = 0,
                                                            @IsManualMultiple      = 0,
                                                            @IsOverwrite           = 0,
                                                            --LOG
                                                            @UserID                = @UserID,
                                                            @IP                    = @IP,
                                                            @ErrCode               = @ErrCode OUTPUT,
                                                            @ErrMsg                = @ErrMsg  OUTPUT

    IF (@ErrCode <> 0)
    BEGIN
        SELECT @ErrCode = 102
        SELECT @ErrMsg  = 'Create feedback failed'
        RETURN
    END

END
GO