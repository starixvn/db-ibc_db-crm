/*<info serverAlias="DBCRM-bodb_CRM" executers="wsv_nap" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE dbo.Acc_CRM_NewManualFeedback_FeedbackIns --KEY
                                                          @CustID                INT,
                                                          --TABLE
                                                          -->crmFeedback
                                                          -->+CustomerInfo
                                                          @TitleID               INT            = NULL,
                                                          @FirstName             NVARCHAR(50)   = NULL,
                                                          @LastName              NVARCHAR(50)   = NULL,
                                                          @Birthday              DATETIME       = NULL,
                                                          @Passport              NVARCHAR(100)  = NULL,
                                                          @BettingCode           NVARCHAR(100)  = NULL,
                                                          @RefCode2              NVARCHAR(100)  = NULL,
                                                          @IsVip                 BIT            = NULL,
                                                          -->+FeedbackInfo
                                                          @FeedbackDate          DATETIME,
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
                                                          @CreatorID             INT            = NULL,
														  @Rating				 TINYINT		= 0,
														  @SourceFeedbackID		 INT			= NULL,
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
                                                          @IsCommunicationLog    BIT            = 0,
                                                          @IsHeadline            BIT            = 0,
                                                          @IsManualMultiple      BIT            = 0,
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
    Task:     Insert feedback info
    DB:       DBCRM.bodb_CRM
    Original: Acc_CRM_CustomerFeedbackIns, Acc_CRM_FeedbackIns, Acc_CRM_CommunicationLogIns

    Revisions:
        20240220@Ned.Le: CRM - Manage Headline/PIC/Staff authority and Company services (#193385)
        20240516@Ned.Le: CRM - Allow to add new Communication tools while Adding Feedback and allow to overwrite communication tools on Account Details page (#205068)
        20240605@Ned.Le: CRM - Activity Log - Adjust text format (#206075)
		20250224@Virgil: CRM - Add Rating Column for Feedback [Redmine: #218235]
		20250311@Virgil: CRM - Add para SourceFeedbackID for store Communication Info when duplicate feedback [Redmine: #218221]

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
*/

BEGIN

    SET NOCOUNT ON


    -------------------------------------------------------
    -- CODE LAYOUT                                       --
    -------------------------------------------------------
    -- 1. Check data consistency                         --
    -- 2. Sync related customers not exist on CRM to CRM --
    -- 3. Overwrite account info                         --
    -- 4. Process data                                   --
    -- 5. Insert data to table                           --
    -- 6. Write Log                                      --
    -------------------------------------------------------


    -------------------------------
    -- 1. Check data consistency --

    -- Reset parameter value
    SELECT @ErrCode = 0
    SELECT @ErrMsg  = ''

    -- Check terminated licensee site
    IF EXISTS (SELECT 1 FROM bodb_CRM.dbo.crmCustomer c WITH (NOLOCK) 
               WHERE c.CustID = @CustID
                     AND EXISTS (SELECT 1 
                                 FROM bodb_CRM.dbo.crmSettingRelation sr WITH (NOLOCK)
                                      INNER JOIN bodb_CRM.dbo.crmSetting s WITH (NOLOCK) ON sr.SettingID = s.SettingID AND s.SettingName = 'Site'
                                 WHERE c.SiteID = s.SettingID
                                       AND s.IsActive = 0
                                       AND sr.ParentID = 33000))
    BEGIN
        SELECT @ErrCode = 107
        SELECT @ErrMsg  = 'Cannot create Feedback for Inactive Site. Please recheck information.'
        RETURN
    END

    -- Check input parameter value
    IF (@IsCommunicationLog = 0)
    BEGIN
        IF ISNULL(@CommunicationID, '') = '' OR
           ISNULL(@Category, '')        = '' OR
           ISNULL(@Product, '')         = '' OR
           ISNULL(@StatusID, 0)         = 0  OR
           ISNULL(@LanguageID, '')      = '' OR
           ISNULL(@RoleID, 0)           = 0  OR
           ISNULL(@ResponseID, 0)       = 0  OR
           ISNULL(@StationID, '')       = ''
        BEGIN
            SELECT @ErrCode = 100
            SELECT @ErrMsg  = 'Incorrect Data.'
            RETURN
        END
    END

    IF (@IsCommunicationLog = 1)
    BEGIN
        IF ISNULL(@Category, '')        = '' OR
           ISNULL(@Product, '')         = '' OR
           ISNULL(@StatusID, 0)         = 0  OR
           ISNULL(@ResponseID, 0)       = 0  OR
           ISNULL(@StationID, '')       = ''
        BEGIN
            SELECT @ErrCode = 100
            SELECT @ErrMsg  = 'Incorrect Data.'
            RETURN
        END
    END

    IF (@IsHeadline IS NULL)
    BEGIN
        SET @IsHeadline = 0
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
                             WHERE SettingValue = ISNULL(c.site, ag.site)
                                   AND SettingName IN ('Site', 'SiteCategory'))
        FROM #tmpSyncRelatedCustomer t
             INNER JOIN bodb02.dbo.Customer c WITH (NOLOCK) ON t.custid = c.custid
             LEFT JOIN bodb02.dbo.Customer ag WITH (NOLOCK) ON c.recommend = ag.custid
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
                                                         @CreatorID   = @CreatorID,
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
        EXECUTE bodb_CRM.dbo.Acc_CRM_CustomerShortUpd @CustID                 = @CustID,
                                                      @TitleID                = @TitleID,
                                                      @FirstName              = @FirstName,
                                                      @LastName               = @LastName,
                                                      @Birthday               = @Birthday,
                                                      @Passport               = @Passport,
                                                      @BettingCode            = @BettingCode,
                                                      @RefCode2               = @RefCode2,
                                                      @IsVip                  = @IsVip,
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


    ---------------------
    -- 4. Process data --

    --------------
    -- crmFeedback

    -- @SolveDate
    DECLARE @SolveDate DATETIME
    SELECT	@SolveDate = CASE WHEN @IsReviewed = 0 THEN NULL ELSE GETDATE() END

    -- @Remark|@AutoField|@Description
    DECLARE @Remark NVARCHAR(MAX)
    SELECT  @Remark = @Description
    SELECT  @Description = (SELECT @AutoField AS AutoField, @Description AS Remark  FOR XML RAW, ROOT('ROOT'))

    -- @TitleID|@FirstName|@LastName|@Birthday|@Passport|@BettingCode|@RefCode2|@IsVip
    IF (@IsCommunicationLog = 1)
    BEGIN
        SELECT @TitleID     = TitleID,
               @FirstName   = FirstName,
               @LastName    = LastName,
               @Birthday    = Birthday,
               @Passport    = Passport,
               @BettingCode = RefCode1,
               @RefCode2    = RefCode2,
               @IsVip       = IsVip
        FROM bodb_CRM.dbo.crmCustomer WITH (NOLOCK)
        WHERE CustID = @CustID
    END

    ----------------------------------
    -- crmFeedbackNewCommunicationTool

    -- Create table variable
    DECLARE @tblNewCommunicationTools TABLE (
        isHeadline         BIT,
        PicInfo            NVARCHAR(200),
        CommunicationID    INT,
        CommunicationValue NVARCHAR(200)
    )

    -- If new feedback is communication log
    IF (@IsCommunicationLog = 1)
    BEGIN
        -- + Headline
        IF (@IsHeadline = 1 AND @SourceFeedbackID IS NULL)
        BEGIN
            ;WITH CTE_HeadlineInfo AS (
                SELECT DISTINCT
                       p.PicID         PicID,
                       p.Username      PicName,
                       sr.SettingValue PicRoleName
                FROM bodb_CRM.dbo.crmPicManagement pm WITH (NOLOCK)
                     LEFT JOIN bodb_CRM.dbo.crmPIC p WITH (NOLOCK) ON pm.PicID = p.PicID
                     LEFT JOIN bodb_CRM.dbo.crmSetting sr WITH (NOLOCK) ON sr.SettingName = 'PICRole' AND p.Role = sr.SettingID
                WHERE pm.HeadlineID = @CustID
            )
            INSERT INTO @tblNewCommunicationTools (
                isHeadline,
                PicInfo,
                CommunicationID,
                CommunicationValue
            )
            SELECT @IsHeadline                                              isHeadline,
                   ISNULL((cte.PicName + ' (' + cte.PicRoleName + ')'), '') PicInfo,
                   pc.CommunicationID                                       CommunicationID,
                   pc.CommunicationValue                                    PicCommunicationValue
            FROM CTE_HeadlineInfo cte
                 LEFT JOIN bodb_CRM.dbo.crmPICCommunication pc WITH (NOLOCK) ON cte.PicID = pc.PicID
        END		
        -- + Other Account
        ELSE IF (@IsHeadline = 0 AND @SourceFeedbackID IS NULL) 
        BEGIN
            INSERT INTO @tblNewCommunicationTools (
                isHeadline,
                PicInfo,
                CommunicationID,
                CommunicationValue
            )
            SELECT @IsHeadline            isHeadline,
                   ''                     PicInfo,
                   ccc.CommunicationID    CommunicationID,
                   ccc.CommunicationValue CommunicationValue
            FROM bodb_CRM.dbo.crmCustomerNewCommunicationTool ccc WITH (NOLOCK)
            WHERE ccc.CustID = @CustID
        END
		ELSE IF (@SourceFeedbackID IS NOT NULL)
		BEGIN
			INSERT INTO @tblNewCommunicationTools (
                isHeadline,
                PicInfo,
                CommunicationID,
                CommunicationValue
            )
			SELECT isHeadline,
					PicInfo,
					CommunicationID,
					CommunicationValue
			FROM bodb_CRM.dbo.crmFeedbackNewCommunicationTool fnc WITH (NOLOCK)
			WHERE FeedbackID = @SourceFeedbackID
		END

        -- + Parse data to variable
        SELECT @NewCommunicationTools = x.xmlvalue
        FROM (SELECT *
              FROM @tblNewCommunicationTools
              FOR XML RAW('NewCommunicationTool'), ROOT('ROOT')) AS x(xmlvalue)
    END

    -- If new feedback is normal feedback
    IF ((@IsCommunicationLog = 0) AND (ISNULL(@NewCommunicationTools, '') <> ''))
    BEGIN
        DECLARE @iDoc_31 INT
        EXECUTE sys.sp_xml_preparedocument @iDoc_31 OUTPUT, @NewCommunicationTools

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
        FROM OPENXML(@iDoc_31, '/ROOT/NewCommunicationTool', 1)
        WITH (isHeadline         BIT,
              PicInfo            NVARCHAR(200),
              CommunicationID    INT,
              CommunicationValue NVARCHAR(200)) AS ox
    END

    ---------------------
    -- crmFeedbackSetting

    -- Parse value from parameter to table
    DECLARE @iDoc_32 INT

    DECLARE @tblFeedbackSetting TABLE (
        SettingID          INT,
        SubSettingID       INT,
        SubSettingIDLevel3 INT     
    )

    EXECUTE sys.sp_xml_preparedocument @iDoc_32 OUTPUT, @Category
    INSERT INTO @tblFeedbackSetting (SettingID, SubSettingID, SubSettingIDLevel3)
    SELECT ox.MainCategoryID, ox.SubCategoryID, 0
    FROM OPENXML(@iDoc_32, '/ROOT/Category', 1)
    WITH (MainCategoryID INT, SubCategoryID INT) AS ox
    EXECUTE sys.sp_xml_removedocument @iDoc_32

    EXECUTE sys.sp_xml_preparedocument @iDoc_32 OUTPUT, @Product
    INSERT INTO @tblFeedbackSetting (SettingID, SubSettingID, SubSettingIDLevel3)
    SELECT ox.ProductID, ox.SubProductID, ox.BetTypeID
    FROM OPENXML(@iDoc_32, '/ROOT/Product', 1)
    WITH (ProductID INT,SubProductID INT, BetTypeID INT) AS ox
    EXECUTE sys.sp_xml_removedocument @iDoc_32

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
        INSERT INTO @tblRelatedCustID (CustID)
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
          AND c.custid NOT IN (SELECT CustID FROM @tblInvalidCustomer)                        
          AND EXISTS (SELECT TOP 1 1 
                      FROM bodb_CRM.dbo.crmSettingRelation sr WITH (NOLOCK) 
                           INNER JOIN bodb_CRM.dbo.crmSetting s WITH (NOLOCK) ON sr.SettingID = s.SettingID AND s.SettingName = 'Site'
                      WHERE s.SettingValue = c.site
                            AND s.IsActive = 0
                            AND sr.ParentID = 33000)

    IF EXISTS (SELECT 1 FROM @tblInvalidCustomer)
    BEGIN
        SELECT @ErrMsg  = ''
        SELECT @ErrMsg  = ',' + @ErrMsg + UserName FROM @tblInvalidCustomer
        SELECT @ErrMsg  = STUFF(@ErrMsg, 1, 1, '')
        SELECT @ErrMsg  = 'Some Usernames belong to Inactive Site: '+ @ErrMsg
        SELECT @ErrCode = 106
        RETURN
    END


    -----------------------------
    -- 5. Insert data to table --

    -- Create variables
    DECLARE @FeedbackID INT

    -- Check duplicate data
    -- + For manual multiple
    IF (@IsManualMultiple = 1)
    BEGIN
        SELECT fs.FeedbackID, fs.SettingID, fs.SubSettingID
        INTO #tmpDupFBMultiple
        FROM bodb_CRM.dbo.crmFeedback fb WITH (NOLOCK) 
             INNER JOIN crmFeedbackSetting fs WITH (NOLOCK) ON fb.FeedbackID = fs.FeedbackID
        WHERE fb.CreateDate >= DATEADD(MINUTE, -1, GETDATE())
              AND fb.CustID = @CustID
              AND fb.CreatorID = @UserID
              AND fb.Description = @Description

        IF EXISTS (SELECT TOP (1) 1
                   FROM #tmpDupFBMultiple fs
                        INNER JOIN @tblFeedbackSetting t ON fs.SettingID = t.SettingID AND fs.SubSettingID=t.SubSettingID)
        BEGIN
            SELECT @ErrCode = 110,
                   @ErrMsg = 'Please try creating new feedback after ONE minute.'

            DROP TABLE #tmpDupFBMultiple

            RETURN
        END
    END
    -- + For manual single
    ELSE
    BEGIN
        SELECT fs.FeedbackID, fs.SettingID, fs.SubSettingID
        INTO #tmpDupFBSingle
        FROM bodb_CRM.dbo.crmFeedback fb WITH (NOLOCK)
             INNER JOIN bodb_CRM.dbo.crmFeedbackSetting fs WITH (NOLOCK) ON fb.FeedbackID = fs.FeedbackID
        WHERE fb.CreateDate >= DATEADD(SECOND, -30, GETDATE())
              AND fb.CustID = @CustID
              AND fb.CreatorID = @UserID
              AND fb.Description = @Description
            
        IF EXISTS (SELECT TOP 1 1
                   FROM #tmpDupFBSingle fs
                        INNER JOIN @tblFeedbackSetting t ON fs.SettingID = t.SettingID AND fs.SubSettingID = t.SubSettingID)
        BEGIN
            SELECT @ErrCode = 112,
                   @ErrMsg = 'Please try creating new feedback after 30 seconds.'

            DROP TABLE #tmpDupFBSingle

            RETURN
        END
    END

    -- crmFeedback
    INSERT INTO bodb_CRM.dbo.crmFeedback (
        CustID,
        TitleID,
        FirstName,
        LastName,
        LanguageID,
        CountryID,
        CreateDate,
        CreatorID,
        FeedbackDate,
        SolveDate,
        SiteID,
        RoleID,
        ResponseID,
        StatusID,
        Description,
        Solution,
        IsReviewed,
        Review,
        ReviewerID,
        Subject,
        ResolutionDate,
        Passport,
        Birthday,
        RefCode1,
        RefCode2,
        IsVip,
        LicenseeType,
        Inquiries,
		Rating
    )            
    SELECT @CustID,
           @TitleID,
           @FirstName,
           @LastName,
           @LanguageID,
           @CountryID,
           GETDATE(),
           @CreatorID,
           @FeedbackDate,
           @SolveDate,
           @SiteID,
           @RoleID,
           @ResponseID,
           @StatusID,
           @Description,
           @Solution,
           @IsReviewed,
           @Review,
           @ReviewerID,
           @Subject,
           @ResolutionDate,
           @Passport,
           @Birthday,
           @BettingCode,
           @RefCode2,
           @IsVip,
           @LicenseeType,
           @NoInquiries,
		   @Rating

    IF (@@ERROR <> 0)
    BEGIN
        SELECT @ErrCode = 102
        SELECT @ErrMsg  = 'Insert feedback unsuccessfuly.'
        RETURN
    END
    
    -- @FeedbackID
    SELECT @FeedbackID = @@identity

    -- crmFeedbackNewCommunicationTool
    INSERT INTO bodb_CRM.dbo.crmFeedbackNewCommunicationTool (FeedbackID, CustID, isHeadline, PicInfo, CommunicationID, CommunicationValue)
    SELECT @FeedbackID, @CustID, isHeadline, PicInfo, CommunicationID, CommunicationValue
    FROM @tblNewCommunicationTools

    IF (@@ERROR <> 0)
    BEGIN
        DELETE FROM bodb_CRM.dbo.crmFeedback WHERE FeedbackID = @FeedbackID
        DELETE FROM bodb_CRM.dbo.crmFeedbackNewCommunicationTool WHERE FeedbackID = @FeedbackID

        SELECT @ErrCode = 103
        SELECT @ErrMsg  = 'Insert feedback unsuccessfuly.'
        RETURN
    END

    -- crmFeedbackSetting
    INSERT INTO bodb_CRM.dbo.crmFeedbackSetting (FeedbackID, SettingID, SubSettingID, SubSettingIDLevel3)
    SELECT @FeedbackID, SettingID, SubSettingID, SubSettingIDLevel3
    FROM @tblFeedbackSetting
    
    IF (@@ERROR <> 0)
    BEGIN
        DELETE FROM bodb_CRM.dbo.crmFeedback WHERE FeedbackID = @FeedbackID
        DELETE FROM bodb_CRM.dbo.crmFeedbackNewCommunicationTool WHERE FeedbackID = @FeedbackID
        DELETE FROM bodb_CRM.dbo.crmFeedbackSetting WHERE FeedbackID = @FeedbackID

        SELECT @ErrCode = 103
        SELECT @ErrMsg  = 'Insert feedback unsuccessfuly.'
        RETURN
    END

    -- crmFeedbackCustomer
    INSERT INTO bodb_CRM.dbo.crmFeedbackCustomer (FeedbackID, CustID, IsRelated)
    SELECT @FeedbackID, @CustID, 0

    IF (@@ERROR <> 0)
    BEGIN
        DELETE FROM bodb_CRM.dbo.crmFeedback WHERE FeedbackID = @FeedbackID
        DELETE FROM bodb_CRM.dbo.crmFeedbackNewCommunicationTool WHERE FeedbackID = @FeedbackID
        DELETE FROM bodb_CRM.dbo.crmFeedbackSetting WHERE FeedbackID = @FeedbackID
        DELETE FROM bodb_CRM.dbo.crmFeedbackCustomer WHERE FeedbackID = @FeedbackID

        SELECT @ErrCode = 103
        SELECT @ErrMsg  = 'Insert feedback unsuccessfuly.'
        RETURN
    END

    IF (ISNULL(@RelatedCustID, '') <> '')
    BEGIN
        -- Insert feedback related
        INSERT INTO bodb_CRM.dbo.crmFeedbackCustomer (FeedbackID, CustID, IsRelated)
        SELECT @FeedbackID, CustID, 1
        FROM @tblRelatedCustID
        WHERE CustID <> @CustID

        IF (@@ERROR <> 0)
        BEGIN
            DELETE FROM bodb_CRM.dbo.crmFeedback WHERE FeedbackID = @FeedbackID
            DELETE FROM bodb_CRM.dbo.crmFeedbackNewCommunicationTool WHERE FeedbackID = @FeedbackID
            DELETE FROM bodb_CRM.dbo.crmFeedbackSetting WHERE FeedbackID = @FeedbackID
            DELETE FROM bodb_CRM.dbo.crmFeedbackCustomer WHERE FeedbackID = @FeedbackID

            SELECT @ErrCode = 103
            SELECT @ErrMsg  = 'Insert feedback unsuccessfuly.'
            RETURN
        END
    END


    ------------------
    -- 6. Write Log --

    -- Deal with field NewCommunicationTools
    -- + Create variable
    DECLARE @NewCommunicationTools_LogValue NVARCHAR(MAX)
    -- + Non Headline
    IF (@IsHeadline = 0)
    BEGIN
        SELECT @NewCommunicationTools_LogValue = STRING_AGG(CAST(ISNULL(bodb_CRM.dbo.f_EncodeXMLValue(sc.SettingValue + ': ' + cnc.CommunicationValue), '') AS NVARCHAR(MAX)), '<br/>') WITHIN GROUP (ORDER BY sc.SettingValue)
        FROM @tblNewCommunicationTools cnc
             LEFT JOIN bodb_CRM.dbo.crmSetting sc WITH (NOLOCK) ON sc.SettingName = 'PICCommunicationTool' AND cnc.CommunicationID = sc.SettingID
    END
    -- + Headline
    IF (@IsHeadline = 1)
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

    -- Build log content
    DECLARE @LogElement XML
    SELECT  @LogElement = '<Acc_CRM_NewManualFeedback_FeedbackIns>' +
                          '<TitleID>'               + ISNULL(CONVERT(VARCHAR(5),@TitleID),'')               + '</TitleID>'               +
                          '<FirstName>'             + ISNULL(dbo.f_EncodeXMLValue(@FirstName),'')           + '</FirstName>'             +
                          '<LastName>'              + ISNULL(dbo.f_EncodeXMLValue(@LastName),'')            + '</LastName>'              +
                          '<LanguageID>'            + ISNULL(CONVERT(VARCHAR(10),@LanguageID),'')           + '</LanguageID>'            +
                          '<CountryID>'             + ISNULL(CONVERT(VARCHAR(10),@CountryID),'')            + '</CountryID>'             +
                          '<CreateDate>'            + ISNULL(CONVERT(VARCHAR(20),GETDATE()),'')             + '</CreateDate>'            +
                          '<Creator>'               + ISNULL(CONVERT(VARCHAR(10),@CreatorID),'')            + '</Creator>'               +
                          '<FeedbackDate>'          + ISNULL(CONVERT(VARCHAR(20),@FeedbackDate),'')         + '</FeedbackDate>'          +
                          '<SolveDate>'             + ISNULL(CONVERT(VARCHAR(20),@SolveDate),'')            + '</SolveDate>'             +
                          '<CommunicationID>'       + ISNULL(dbo.f_EncodeXMLValue(@CommunicationID_New),'') + '</CommunicationID>'       +
                          '<StationID>'             + ISNULL(dbo.f_EncodeXMLValue(@StationID_New),'')       + '</StationID>'             +
                          '<MainCategoryID>'        + ISNULL(dbo.f_EncodeXMLValue(@MainCategoryID_New),'')  + '</MainCategoryID>'        +
                          '<SubCategoryID>'         + ISNULL(dbo.f_EncodeXMLValue(@SubCategoryID_New),'')   + '</SubCategoryID>'         +
                          '<SiteID>'                + ISNULL(CONVERT(VARCHAR(10),@SiteID),'')               + '</SiteID>'                +
                          '<RoleID>'                + ISNULL(CONVERT(VARCHAR(10),@RoleID),'')               + '</RoleID>'                +
                          '<ProductID>'             + ISNULL(@ProductID_New    ,'')                         + '</ProductID>'             +
                          '<SubProductID>'          + ISNULL(@SubProductID_New,'')                          + '</SubProductID>'          +
                          '<BettypeID>'             + ISNULL(@BettypeID_New,'')                             + '</BettypeID>'             +
                          '<ResponseID>'            + ISNULL(CONVERT(VARCHAR(10),@ResponseID),'')           + '</ResponseID>'            +
                          '<StatusID>'              + ISNULL(CONVERT(VARCHAR(10),@StatusID),'')             + '</StatusID>'              +
                          '<Remark>'                + ISNULL(dbo.f_EncodeXMLValue(@Remark),'')              + '</Remark>'                +
                          '<AutoField>'             + ISNULL(dbo.f_EncodeXMLValue(@AutoField),'')           + '</AutoField>'             +
                          '<Solution>'              + ISNULL(dbo.f_EncodeXMLValue(@Solution),'')            + '</Solution>'              +
                          '<IsReviewed>'            + ISNULL(CONVERT(VARCHAR(5),@IsReviewed),'')            + '</IsReviewed>'            +
                          '<Review>'                + ISNULL(dbo.f_EncodeXMLValue(@Review),'')              + '</Review>'                +
                          '<Reviewer>'              + ISNULL(CONVERT(VARCHAR(10),@ReviewerID),'')           + '</Reviewer>'              +
                          '<Subject>'               + ISNULL(dbo.f_EncodeXMLValue(@Subject),'')             + '</Subject>'               +
                          '<ResolutionDate>'        + ISNULL(CONVERT(VARCHAR(20),@ResolutionDate),'')       + '</ResolutionDate>'        +
                          '<Passport>'              + ISNULL(dbo.f_EncodeXMLValue(@Passport),'')            + '</Passport>'              +
                          '<Birthday>'              + ISNULL(CONVERT(VARCHAR(20),@Birthday,107),'')         + '</Birthday>'              +
                          '<BettingCode>'           + ISNULL(dbo.f_EncodeXMLValue(@BettingCode),'')         + '</BettingCode>'           +
                          '<RefCode2>'              + ISNULL(dbo.f_EncodeXMLValue(@RefCode2),'')            + '</RefCode2>'              +
                          '<IsVip>'                 + ISNULL(CONVERT(VARCHAR(10),@IsVip),'')                + '</IsVip>'                 +
                          '<LicenseeType>'          + ISNULL(CONVERT(VARCHAR(10),@LicenseeType),'')         + '</LicenseeType>'          +
                          '<NoInquiries>'           + ISNULL(dbo.f_EncodeXMLValue(@NoInquiries),'')         + '</NoInquiries>'           +
                          '<RelatedCustID>'         + ISNULL(dbo.f_EncodeXMLValue(@RelatedCustID),'')       + '</RelatedCustID>'         +
                          '<NewCommunicationTools>' + ISNULL(@NewCommunicationTools_LogValue,'')            + '</NewCommunicationTools>' +
						  '<Rating>'				+ ISNULL(CONVERT(VARCHAR(5),@Rating),'')				+ '</Rating>'				 +
						  '<SourceFeedbackID>'		+ ISNULL(CONVERT(VARCHAR(10),@SourceFeedbackID),'')		+ '</SourceFeedbackID>'		 +
                          '<IsOverWrite>'           + ISNULL(CONVERT(VARCHAR(10),@IsOverWrite),'')          + '</IsOverWrite>'           +
                          '</Acc_CRM_NewManualFeedback_FeedbackIns>'

    -- Run sp to write log
    EXECUTE bodb_CRM.dbo.WriteLog_UserLog_crmLogFeedback @FeedbackID  = @FeedbackID,
                                                         @CustID      = @CustID,
                                                         @Description = @Description,
                                                         @Solution    = @Solution,
                                                         @Review      = @Review,
                                                         @NewValues   = @LogElement,
                                                         @OldValues   = NULL,
                                                         @Duration    = NULL,
                                                         @ActionID    = 207,
                                                         @UserID      = @UserID,
                                                         @IP          = @IP

END
GO