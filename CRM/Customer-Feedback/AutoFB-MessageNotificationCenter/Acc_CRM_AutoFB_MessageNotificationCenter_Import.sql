/*<info serverAlias="DBCRM-bodb_CRM" executers="wsv_nap" isFunction="0" isNested="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE dbo.Acc_CRM_AutoFB_MessageNotificationCenter_Import @MsgInfo     XML,
                                                                    @Environment VARCHAR(50)    = 'LIVE',
                                                                    @ErrCode     INT            = 0  OUTPUT,
                                                                    @ErrMsg      NVARCHAR(4000) = '' OUTPUT,
                                                                    @IP          VARCHAR(45)    = ''
AS

/*
    Created: 20240502@Luke
    Task   : Collection information and create Feedback
    DB     : DBCRM/bodb_CRM

    Revisions:
        20240502@Luke: CRM - Implement Message Notifications Center for Result Amendment of Cricket [Redmine: #197621]
        20240821@Ned.Le: Include Feedback for Licensee
		20241231@Virgil: Add Remark section [Redmine: #214619]
        20251016@Helios: Updated Sporttype column datatype from TINYINT to SMALLINT [Redmine: #241501] 

    Param's Explanation:
        @MsgInfo:
            <root>
                <r MessageId="107" MsgTargetId="123" TargetId="13" BetTransId="2382,2384,2388" MatchId="12345" Content_en="" Content_cs="" Content_yn=""/>
                <r MessageId="108" MsgTargetId="145" TargetId="10" BetTransId="2265,2266,2267" MatchId="12346" Content_en="" Content_cs="" Content_yn=""/>
            </root>

    Example:
        EXEC bodb_CRM.dbo.Acc_CRM_AutoFB_MessageNotificationCenter_Import @MsgInfo     = @MsgInfo,
                                                                          @Environment = 'LIVE',
                                                                          @ErrCode     = @ErrCode OUTPUT,
                                                                          @ErrMsg      = @ErrMsg  OUTPUT,
                                                                          @IP          = '1.2.3.4'
*/

BEGIN

    SET NOCOUNT ON


    -----------------------------------------------------------------------------------
    -- CODE LAYOUT                                                                   --
    --                                                                               --
    -- [01] Global variables                                                         --
    --      _ Declare all variables that be used through all stored procedure        --
    --                                                                               --
    -- [02] Check and update some job settings                                       --
    --      _ We need to check the job status to know that the job is running or not --
    --      _ And depend on each case we will have suitable action                   --
    --                                                                               --
    -- [03] Parse XML data                                                           --
    --      _ Just parse XML data to temp table in order to use later                --
    --                                                                               --
    -- [04] Collect fundamental data                                                 --
    --      _ Collect fundamental data for futher processes later                    --
    --                                                                               --
    -- [05] Sync data from maindb to crmCustomer                                     --
    --      _ Sync data for new customer from maindb system to CRM system            --
    --                                                                               --
    -- [06] Collect buffer data to prepare for creating Feedback                     --
    --      _ Based on the requirement to create Feedback                            --
    --      _ We need to collect many kind of data to prepare                        --
    --                                                                               --
    -- [07] Create Feedback                                                          --
    --      _ Now, that is the time to create Feedback                               --
    --                                                                               --
    -- [08] Update job setting                                                       --
    --      _ Need to update some settings relate to the job                         --
    --                                                                               --
    -- [09] Drop temp tables                                                         --
    --      _ Need to clean all temp tables                                          --
    -----------------------------------------------------------------------------------


    ---------------------------
    -- [01] Global variables --

    DECLARE @CreatorId                    INT         = 10278938
    DECLARE @ServiceName                  VARCHAR(50) = 'AutoFB - MessageNotificationCenter'
    DECLARE @LastMsgTargetId              INT

    DECLARE @IncludeUUSCurrency           BIT
    SELECT  @IncludeUUSCurrency           = CONVERT(BIT, Value) FROM bodb_CRM.dbo.SystemSetting WITH (NOLOCK) WHERE ServiceName = @ServiceName AND SettingName = 'IncludeUUSCurrency'

    DECLARE @SettingNameOfLastRuntime     VARCHAR(50)
    SELECT  @SettingNameOfLastRuntime     = CASE WHEN @Environment = 'UAT' THEN 'LastRuntimeUAT' ELSE 'LastRuntime' END
    DECLARE @LastRuntime                  DATETIME
    SELECT  @LastRuntime                  = CONVERT(DATETIME, Value) FROM bodb_CRM.dbo.SystemSetting WITH (NOLOCK) WHERE SettingName = @SettingNameOfLastRuntime AND ServiceName = @ServiceName

    DECLARE @SettingNameOfJobStatus       VARCHAR(50)
    SELECT  @SettingNameOfJobStatus       = CASE WHEN @Environment = 'UAT' THEN 'JobStatusUAT' ELSE 'JobStatus' END
    
    DECLARE @SettingNameOfLastMsgTargetId VARCHAR(50)
    SELECT  @SettingNameOfLastMsgTargetId = CASE WHEN @Environment = 'UAT' THEN 'LastMsgTargetIdUAT' ELSE 'LastMsgTargetId' END


    ---------------------------------------------
    -- [02] Check and update some job settings --

    -- Declare variables
    DECLARE @ServerName NVARCHAR(100) = @@SERVERNAME
    DECLARE @DBName     NVARCHAR(100) = DB_NAME()
    DECLARE @SPName     NVARCHAR(300) = OBJECT_NAME(@@PROCID)

    -- Update status to running
    UPDATE s
    SET s.Value = 'Running'
    FROM bodb_CRM.dbo.SystemSetting s WITH (ROWLOCK)
    WHERE s.ServiceName = @ServiceName
          AND s.SettingName = @SettingNameOfJobStatus
          AND s.Value = 'Completed'

    -- If nothing happened, it means job is already running and we need to do something else
    IF (@@ROWCOUNT = 0)
    BEGIN
        -- + Check if the job run for more than 5mi
        IF (DATEDIFF(SECOND, @LastRuntime, GETDATE()) >= 5 * 60)
        BEGIN
            UPDATE s
            SET s.Value = 'Completed'
            FROM bodb_CRM.dbo.SystemSetting s WITH (ROWLOCK)
            WHERE s.ServiceName = @ServiceName
                  AND s.SettingName = @SettingNameOfJobStatus
                  AND s.Value = 'Running'

            UPDATE s
            SET s.Value = CONVERT(VARCHAR(20), GETDATE(), 120)
            FROM bodb_CRM.dbo.SystemSetting s WITH (ROWLOCK)
            WHERE s.ServiceName = @ServiceName
                  AND s.SettingName = @SettingNameOfLastRuntime
        END
        -- + If not, it means the job still running and still not over 5mi
        ELSE
        BEGIN
            SELECT @ErrCode = 100
            SELECT @ErrMsg = 'Server Name: ' + @ServerName + ' - Database Name: ' + @DBName + ' - SP Name: ' + @SPName + ' - Error Message: ' + @ServiceName + ' - Job is running.'
        END
        -- + Return
        RETURN
    END

    -- Update LastRuntime
    UPDATE s
    SET s.Value = CONVERT(VARCHAR(20), GETDATE(), 120)
    FROM bodb_CRM.dbo.SystemSetting s WITH (ROWLOCK)
    WHERE s.ServiceName = @ServiceName
          AND s.SettingName = @SettingNameOfLastRuntime


    -------------------------
    -- [03] Parse XML data --

    -- Create temp table and parse XML data to temp table
    CREATE TABLE #tmpXMLData (
        MessageId   INT,
        MsgTargetId INT,
        TargetId    INT,
        BetTransIds VARCHAR(MAX),
        MatchId     INT,
        Content_EN  NVARCHAR(MAX),
        Content_CS  NVARCHAR(MAX),
        Content_YN  NVARCHAR(MAX)
    )

    INSERT INTO #tmpXMLData (
        MessageId,
        MsgTargetId,
        TargetId,
        BetTransIds,
        MatchId,
        Content_EN,
        Content_CS,
        Content_YN
    )
    SELECT t.c.value('@MessageId',   'INT')           AS MessageId,
           t.c.value('@MsgTargetId', 'INT')           AS MsgTargetId,
           t.c.value('@TargetId',    'INT')           AS TargetId,
           t.c.value('@BetTransId',  'VARCHAR(MAX)')  AS BetTransIds,
           t.c.value('@MatchId',     'INT')           AS MatchId,
           t.c.value('@Content_en',  'NVARCHAR(MAX)') AS Content_EN,
           t.c.value('@Content_cs',  'NVARCHAR(MAX)') AS Content_CS,
           t.c.value('@Content_yn',  'NVARCHAR(MAX)') AS Content_YN
    FROM @MsgInfo.nodes('root/r') AS t(c)
    OPTION (OPTIMIZE FOR (@MsgInfo = NULL))

    -- Clean data | Just keep data of member
    ;WITH CTE_SMATarget AS (
        SELECT m.MsgTargetId 
        FROM #tmpXMLData m
             INNER JOIN bodb02.dbo.Customer c WITH (NOLOCK) ON c.custid = m.TargetId
        WHERE c.roleid IN (2, 3, 4)
    )
    DELETE m
    FROM #tmpXMLData m
         INNER JOIN CTE_SMATarget c ON c.MsgTargetId = m.MsgTargetId

    -- If no have data, need to update setting and return
    IF NOT EXISTS (SELECT 1 FROM #tmpXMLData)
    BEGIN
        UPDATE s
        SET s.Value = 'Completed'
        FROM bodb_CRM.dbo.SystemSetting s WITH (ROWLOCK)
        WHERE s.ServiceName = @ServiceName
              AND s.SettingName = @SettingNameOfJobStatus
              AND s.Value = 'Running'

        RETURN
    END

    -- Set value for @LastMsgTargetId
    SELECT @LastMsgTargetId = MAX(MsgTargetId) FROM #tmpXMLData

    -- Create index
    CREATE CLUSTERED INDEX CIX_MessageId ON #tmpXMLData(MessageId)


    --------------------------------------------------------------------------------------------------------
    -- [04] Collect fundamental data                                                                      --
    --      _ First, we collect data relate to message, include SMA and member, match, sporttype, bettype --
    --      _ Second, base on SMA and member information, we collect headline information                 --
    --------------------------------------------------------------------------------------------------------

    -- Collect message data
    -- + Create temp table
    CREATE TABLE #tmpMessageData (
        MessageId  INT,
        TransId    BIGINT,
        IsTest     BIT DEFAULT 0,
        CustId     INT,
        Username   VARCHAR(30),
        Recommend  INT,
        Mrecommend INT,
        Srecommend INT,
        MatchId    INT,
        Sporttype  SMALLINT, -- Updated from TINYINT to SMALLINT
        Bettype    INT
    )

    -- + Get data from XML
    INSERT INTO #tmpMessageData (
        MessageId,
        MatchId,
        TransId
    )
    SELECT m.MessageId,
           m.MatchId,
           bt.TransId
    FROM #tmpXMLData m
         CROSS APPLY (SELECT CAST(value AS BIGINT) TransId
                      FROM STRING_SPLIT(m.BetTransIds, ',')) bt
    -- + Get data from bettrans
    UPDATE d
    SET d.IsTest     = CASE WHEN b.currency = 20 THEN 1 ELSE 0 END,
        d.CustId     = b.custId,
        d.Recommend  = b.recommend,
        d.Mrecommend = b.mrecommend,
        d.Srecommend = b.srecommend,
        d.Username   = b.Username,
        d.Sporttype  = m.sporttype,
        d.Bettype    = b.bettype
    FROM #tmpMessageData d
         LEFT JOIN bodb02.dbo.match m WITH (NOLOCK) ON d.MatchId = m.matchid
         CROSS APPLY (SELECT TOP(1) b.currency, b.custId, b.recommend, b.mrecommend, b.srecommend, b.Username, b.bettype
                      FROM bodb02.dbo.bettrans b WITH (NOLOCK)
                      WHERE b.transid = d.TransId) b
    -- + Get data from bettrans14
    UPDATE d
    SET d.IsTest     = CASE WHEN b.currency = 20 THEN 1 ELSE 0 END,
        d.CustId     = b.custId,
        d.Recommend  = b.recommend,
        d.Mrecommend = b.mrecommend,
        d.Srecommend = b.srecommend,
        d.Username   = b.Username,
        d.Sporttype  = m.sporttype,
        d.Bettype    = b.bettype
    FROM #tmpMessageData d
         LEFT JOIN bodb02.dbo.match14 m WITH (NOLOCK) ON d.MatchId = m.matchid
         CROSS APPLY (SELECT TOP(1) b.currency, b.custId, b.recommend, b.mrecommend, b.srecommend, b.Username, b.bettype
                      FROM bodb02.dbo.bettrans14 b WITH (NOLOCK)
                      WHERE b.transid = d.TransId) b
    -- + Clean data, only import testing data with UAT environment
    IF (@Environment = 'UAT')
    BEGIN
        DELETE m
        FROM #tmpMessageData m
        WHERE m.IsTest = 0
    END
    -- + Clean data, exclude UUS currency with LIVE environment
    IF (@Environment = 'LIVE' AND @IncludeUUSCurrency = 0)
    BEGIN
        DELETE m
        FROM #tmpMessageData m
        WHERE m.IsTest = 1
    END
    -- + Clean data, remove records that no longer existed in bettrans & bettrans14
    BEGIN
        DELETE m
        FROM #tmpMessageData m
        WHERE m.CustId IS NULL
    END
    -- + Check data existence
    IF NOT EXISTS (SELECT 1 FROM #tmpMessageData)
    BEGIN
        UPDATE s
        SET s.Value = CONVERT(VARCHAR(20), @LastMsgTargetId)
        FROM bodb_CRM.dbo.SystemSetting s WITH (ROWLOCK)
        WHERE s.ServiceName = @ServiceName
              AND s.SettingName = @SettingNameOfLastMsgTargetId

        UPDATE s
        SET s.Value = 'Completed'
        FROM bodb_CRM.dbo.SystemSetting s WITH (ROWLOCK)
        WHERE s.ServiceName = @ServiceName
              AND s.SettingName = @SettingNameOfJobStatus
              AND s.Value = 'Running'

        RETURN
    END
    -- + Create index
    CREATE CLUSTERED INDEX CIX_MessageId ON #tmpMessageData(MessageId)
    CREATE NONCLUSTERED INDEX IX_CustId ON #tmpMessageData(CustId)

    -- Collect headline data
    -- + Create temp table
    CREATE TABLE #tmpHeadlineData (
        CustId            INT,
        HeadlineId        INT,
        HeadlineName      NVARCHAR(50),
        HeadlineSite      NVARCHAR(50),
        HeadlineSiteLabel NVARCHAR(50),
        isLicensee        BIT,
        IsVip             BIT
    )
    -- + Get list of custid
    DECLARE @ListCustId NVARCHAR(MAX)
    ;WITH CTE_CustId AS (
        SELECT DISTINCT CustId FROM #tmpMessageData
    )
    SELECT @ListCustId = ISNULL(STRING_AGG(CONVERT(VARCHAR(MAX), CustId), ','), '') FROM CTE_CustId
    -- + Gen data to temp table
    INSERT INTO #tmpHeadlineData (CustId, HeadlineId, HeadlineName)
    EXEC bodb02.dbo.Acc_CRM_GroupHeadlineSel @custIds = @ListCustId
    -- + Update value for temp table
    UPDATE h
    SET h.HeadlineSite      = c.site,
        h.HeadlineSiteLabel = s.SiteLabel,
        h.isLicensee        = CASE WHEN d.custid IS NOT NULL THEN 1 ELSE 0 END,
        h.IsVip             = ISNULL(cr.IsVIP, 0)
    FROM #tmpHeadlineData h
         LEFT JOIN bodb02.dbo.Dep_CustSuper d WITH (NOLOCK) ON h.HeadlineId = d.custid
         LEFT JOIN bodb02.dbo.Customer c WITH (NOLOCK) ON h.CustId = c.custid
         LEFT JOIN bodb02.dbo.Site s WITH (NOLOCK) ON c.site = s.site
         LEFT JOIN bodb_CRM.dbo.crmCustomer cr WITH (NOLOCK) ON h.HeadlineId = cr.CustID
    -- + Delete ignored data
    -- + --> for #tmpMessageData
    DELETE d
    FROM #tmpMessageData d
         INNER JOIN #tmpHeadlineData h ON d.CustId = h.CustId
         INNER JOIN bodb_CRM.dbo.crmCustomer c WITH (NOLOCK) ON c.CustID = h.HeadlineId
    WHERE c.Ignored = 1
    -- + --> for #tmpHeadlineData
    DELETE h
    FROM #tmpHeadlineData h
         INNER JOIN bodb_CRM.dbo.crmCustomer c WITH (NOLOCK) ON c.CustID = h.HeadlineId
    WHERE c.Ignored = 1
    -- + Create index
    CREATE CLUSTERED INDEX CIX_CustId ON #tmpHeadlineData(CustId)


    -----------------------------------------------
    -- [05] Sync data from maindb to crmCustomer --

    -- Sync Headline
    -- + Declare variables
    DECLARE @SyncHeadline_Id       INT = 1
    DECLARE @SyncHeadline_CustId   INT
    DECLARE @SyncHeadline_Username NVARCHAR(50)
    -- + Create temp table and gen data
    CREATE TABLE #tmpSyncHeadline (Id INT IDENTITY(1, 1), HeadlineId INT, HeadlineName NVARCHAR(50))
    INSERT INTO  #tmpSyncHeadline (HeadlineId, HeadlineName) SELECT DISTINCT HeadlineId, HeadlineName FROM #tmpHeadlineData
    -- + Run the loop to sync data
    WHILE EXISTS (SELECT 1 FROM #tmpSyncHeadline WHERE Id = @SyncHeadline_Id)
    BEGIN
        -- + --> Set value for some variables
        SELECT @SyncHeadline_CustId   = HeadlineId,
               @SyncHeadline_Username = HeadlineName
        FROM #tmpSyncHeadline
        WHERE Id = @SyncHeadline_Id

        -- + --> Run sp to sync data
        IF NOT EXISTS (SELECT 1 FROM bodb_CRM.dbo.crmCustomer WITH (NOLOCK) WHERE CustId = @SyncHeadline_CustID)
        BEGIN
            EXECUTE bodb_CRM.dbo.Acc_CRM_CustomerIns_New @UserId                 = @CreatorId,
                                                         @CustId                 = @SyncHeadline_CustId,
                                                         @UserName               = @SyncHeadline_Username,
                                                         @FirstName              = NULL,
                                                         @LastName               = NULL,
                                                         @TitleId                = NULL,
                                                         @Birthday               = NULL,
                                                         @LanguageId             = 0,
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
                                                         @Passport               = NULL,
                                                         @BettingCode            = NULL,
                                                         @RefCode2               = NULL,
                                                         @Skype                  = NULL,
                                                         @MSN                    = NULL,
                                                         @CountryId              = NULL,
                                                         @IsVIP                  = 0,
                                                         @SiteId                 = NULL,
                                                         @CreatorId              = @CreatorId,
                                                         @LicenseeType           = NULL,
                                                         @WhatsApp               = NULL,
                                                         @Line                   = NULL,
                                                         @WeChat                 = NULL,
                                                         @Yahoo                  = NULL,
                                                         @QQ                     = NULL,
                                                         @BBM                    = NULL,
                                                         @IP                     = @IP,
                                                         @Pic1                   = NULL,
                                                         @Pic2                   = NULL,
                                                         @Pic3                   = NULL,
                                                         @Pic4                   = NULL,
                                                         @ProvinceId             = NULL,                    
                                                         @ErrCode                = @ErrCode OUTPUT,
                                                         @ErrMsg                 = @ErrMsg  OUTPUT

            IF (@ErrCode <> 0)
            BEGIN
                SET @ErrMsg  = ISNULL(@ErrMsg, '') + ' - ' +
                               'Insert failed: Acc_CRM_CustomerIns_New [CustId='    + ISNULL(CONVERT(VARCHAR(20), @SyncHeadline_CustId), '') + ',' +
                                                                       'Username='  + ISNULL(@SyncHeadline_Username, '')                     + ',' +
                                                                       'CreatorId=' + ISNULL(CONVERT(VARCHAR(20), @CreatorId), '')           + ',' +
                                                                       'IP='        + ISNULL(CONVERT(VARCHAR(20), @IP), '')                  + ']'

                UPDATE s
                SET s.Value = 'Completed'
                FROM bodb_CRM.dbo.SystemSetting s WITH (ROWLOCK)
                WHERE s.ServiceName = @ServiceName
                      AND s.SettingName = @SettingNameOfJobStatus
                      AND s.Value = 'Running'

                RETURN
            END
        END

        -- + --> Continue the loop
        SET @SyncHeadline_Id += 1
    END

    -- Sync Member
    -- + Declare variables
    DECLARE @RelatedCustomers NVARCHAR(MAX)
    ;WITH
    CTE_Data AS (
        SELECT DISTINCT
               h.HeadlineId CustId,
               h.CustId     RelatedCustId,
               b.Username   Username
        FROM #tmpHeadlineData h
             LEFT JOIN #tmpMessageData b ON h.CustId = b.CustId
    )
    SELECT @RelatedCustomers = (
        SELECT CustId        AS '@CustId',
               RelatedCustId AS '@RelatedCustId',
               Username      AS '@Username'
        FROM CTE_Data
        FOR XML PATH ('Row'), ROOT('ROOT')
    )
    -- + Run sp to sync data
    EXECUTE bodb_CRM.dbo.Acc_CRM_AmendmentNoti_MultiCustIns @RelatedCustomers = @RelatedCustomers,
                                                            @UserId           = @CreatorId,
                                                            @CreatorId        = @CreatorId,
                                                            @IP               = @IP,
                                                            @ErrCode          = @ErrCode OUTPUT,
                                                            @ErrMsg           = @ErrMsg  OUTPUT

    IF (@ErrCode <> 0)
    BEGIN
        SET @ErrCode = 101
        SET @ErrMsg  = ISNULL(@ErrMsg, '') + ' - ' +
                       'Insert failed: Acc_CRM_AmendmentNoti_MultiCustIns [RelatedCustomers=' + ISNULL(@RelatedCustomers, '')                + ',' +
                                                                          'CreatorId='        + ISNULL(CONVERT(VARCHAR(20), @CreatorId), '') + ',' +
                                                                          'IP='               + ISNULL(@IP, '')                              + ']'

        UPDATE s
        SET s.Value = 'Completed'
        FROM bodb_CRM.dbo.SystemSetting s WITH (ROWLOCK)
        WHERE s.ServiceName = @ServiceName
              AND s.SettingName = @SettingNameOfJobStatus
              AND s.Value = 'Running'

        RETURN
    END


    -----------------------------------------------------------------------------------------------------------------
    -- [06] Collect buffer data to prepare for creating Feedback                                                   --
    --      _ Base on the requirement to create Feedback we divide them into group and collect data for each group --
    --      _ Group 01, fixed information                                                                          --
    --      _ Group 02, base information                                                                           --
    --      _ Group 03, event information                                                                          --
    -----------------------------------------------------------------------------------------------------------------

    -- Group 01, Feedback fixed information > From spec
    --                                      > We can know Feedback's field that info is fixed
    --                                      > And we just collect data for them first
    DECLARE @Feedback_Date           DATETIME     = GETDATE()
    DECLARE @Feedback_ResolutionDate DATETIME     = DATEADD(MINUTE, 1, @Feedback_Date)
    DECLARE @Feedback_Subject        VARCHAR(200) = 'Result Amended/Recalculation Notification'
    DECLARE @Feedback_StationId      INT
    DECLARE @Feedback_CategoryId     INT
    DECLARE @Feedback_SubCategoryId  INT
    DECLARE @Feedback_ProductId      INT
    DECLARE @Feedback_StatusId       INT
    DECLARE @Feedback_ResponseId     INT

    SELECT @Feedback_StationId     = MAX(CASE WHEN SettingName = 'Station'      AND SettingValue = 'N/A'                                       THEN SettingId ELSE NULL END),
           @Feedback_CategoryId    = MAX(CASE WHEN SettingName = 'MainCategory' AND SettingValue = 'Result Amended/Recalculation Notification' THEN SettingId ELSE NULL END),
           @Feedback_SubCategoryId = MAX(CASE WHEN SettingName = 'SubCategory'  AND SettingValue = 'N/A'                                       THEN SettingId ELSE NULL END),
           @Feedback_ProductId     = MAX(CASE WHEN SettingName = 'Product'      AND SettingValue = 'Sportsbook'                                THEN SettingId ELSE NULL END),
           @Feedback_StatusId      = MAX(CASE WHEN SettingName = 'Status'       AND SettingValue = 'Closed'                                    THEN SettingId ELSE NULL END),
           @Feedback_ResponseId    = MAX(CASE WHEN SettingName = 'Response'     AND SettingValue = 'Neutral'                                   THEN SettingId ELSE NULL END)
    FROM bodb_CRM.dbo.crmSetting WITH (NOLOCK)
    WHERE SiteOffer = 2

    -- Group 02, Feedback base information > For each MessageId|HeadlineId we will create one Feedback
    --                                     > We need to know that the way to create Feedback for Credit Model is difference to Licensee Model
    --                                     > We collect list_relatecust|list_subproduct|list_bettype belong to each Feedback
    --                                     > We also collect info about communicationtool|role|language|country belong to each Feedback
    -- + Get Cust data
    -- + --> Create temp table
    CREATE TABLE #tmpFeedback_base_cust (
        MessageId       INT,
        HeadlineId      INT,
        isLicensee      BIT,
        RelatedCustId   VARCHAR(MAX),
        RelatedUsername NVARCHAR(MAX),
        MappingCustId   INT
    )
    -- + --> Gen credit data to temp table
    INSERT INTO #tmpFeedback_base_cust (
        MessageId,
        HeadlineId,
        isLicensee,
        RelatedCustId,
        RelatedUsername,
        MappingCustId
    )
    SELECT b.MessageId  MessageId,
           h.HeadlineId HeadlineId,
           0            isLicensee,
           b.CustId     RelatedCustId,
           b.Username   RelatedUsername,
           b.CustId     MappingCustId
    FROM #tmpMessageData b
         LEFT JOIN #tmpHeadlineData h ON b.CustId = h.CustId
    WHERE h.isLicensee = 0
    GROUP BY b.MessageId,
             h.HeadlineId,
             b.CustId,
             b.Username
    -- + --> Gen licensee data to temp table
    INSERT INTO #tmpFeedback_base_cust (
        MessageId,
        HeadlineId,
        isLicensee,
        RelatedCustId,
        RelatedUsername,
        MappingCustId
    )
    SELECT b.MessageId MessageId,
           a.CustID    HeadlineId,
           1           isLicensee,
           lm.custid   RelatedCustId,
           c.UserName  RelatedUsername,
           b.CustId    MappingCustId
    FROM #tmpMessageData b
         LEFT JOIN #tmpHeadlineData h ON b.CustId = h.CustId
         LEFT JOIN bodb_CRM.dbo.crmLicenseeMapping lm WITH (NOLOCK) ON h.HeadlineSite = lm.Site
         LEFT JOIN bodb_CRM.dbo.crmCustomer c WITH (NOLOCK) ON lm.custid = c.CustID
         CROSS JOIN (SELECT CustID FROM bodb_CRM.dbo.crmCustomer WITH (NOLOCK) WHERE UserName = 'All-licensees') a
    WHERE h.isLicensee = 1
    GROUP BY b.MessageId,
             a.CustID,
             lm.custid,
             c.UserName,
             b.CustId
    -- + Get SubProduct data
    -- + --> Create temp table
    CREATE TABLE #tmpFeedback_base_subproduct (
        MessageId    INT,
        HeadlineId   INT,
        SubProductId INT
    )
    -- + --> Gen data to temp table
    INSERT INTO #tmpFeedback_base_subproduct (
        MessageId,
        HeadlineId,
        SubProductId
    )
    SELECT b.MessageId,
           h.HeadlineId,
           mp.SettingID SubProductId
    FROM #tmpMessageData b
         INNER JOIN #tmpFeedback_base_cust h ON b.MessageId = h.MessageId AND b.CustId = h.MappingCustId
         INNER JOIN bodb02.dbo.Sports s WITH (NOLOCK) ON b.Sporttype = s.SportType
         INNER JOIN bodb_CRM.dbo.crmSettingMapping mp WITH (NOLOCK) ON s.SportName = mp.SettingSource
         INNER JOIN bodb_CRM.dbo.crmSetting st WITH (NOLOCK) ON st.SettingName = 'SubProduct' AND mp.SettingID = st.SettingID
    GROUP BY b.MessageId,
             h.HeadlineId,
             mp.SettingID
    -- + Get Bettype data
    -- + --> Create temp table
    CREATE TABLE #tmpFeedback_base_bettype (
        MessageId  INT,
        HeadlineId INT,
        BettypeId  INT
    )
    -- + --> Gen data to temp table
    INSERT INTO #tmpFeedback_base_bettype (
        MessageId,
        HeadlineId,
        BettypeId
    )
    SELECT b.MessageId,
           h.HeadlineId,
           mp.SettingID BettypeId
    FROM #tmpMessageData b
         LEFT JOIN #tmpFeedback_base_cust h ON b.MessageId = h.MessageId AND b.CustId = h.MappingCustId
         INNER JOIN bodb02.dbo.bettype bt WITH (NOLOCK) ON b.Bettype = bt.typeid
         INNER JOIN bodb_CRM.dbo.crmSettingMapping mp WITH (NOLOCK) ON bt.typenamee = mp.SettingSource
         INNER JOIN bodb_CRM.dbo.crmSetting st WITH (NOLOCK) ON st.SettingName = 'BetType' AND mp.SettingID = st.SettingID
         INNER JOIN bodb_CRM.dbo.crmSettingRelation sr WITH (NOLOCK) ON sr.ParentID IN (SELECT SubProductId FROM #tmpFeedback_base_subproduct) AND st.SettingID = sr.SettingID
    GROUP BY b.MessageId,
             h.HeadlineId,
             mp.SettingID
    -- + Get final data
    -- + --> Create temp table
    CREATE TABLE #tmpFeedback_base (
        Id                 INT IDENTITY(1, 1),
        MessageId          INT,
        HeadlineId         INT,
        isLicensee         BIT,
        RelatedCustIds     VARCHAR(MAX),
        RelatedUsernames   NVARCHAR(MAX),
        SubProductIds      VARCHAR(MAX),
        BettypeIds         VARCHAR(MAX),
        CommunicationIds   VARCHAR(MAX),
        CommunicationNames NVARCHAR(MAX),
        RoleId             INT,
        LanguageId         INT,
        CountryId          INT
    )
    -- + --> Gen data to temp table
    ;WITH
    CTE_cust AS (
        SELECT c.MessageId,
               c.HeadlineId,
               c.isLicensee,
               STRING_AGG(CAST(c.RelatedCustId AS VARCHAR(MAX)), ',')    RelatedCustIds,
               STRING_AGG(CAST(c.RelatedUsername AS VARCHAR(MAX)), ', ') RelatedUsernames
        FROM (SELECT MessageId, HeadlineId, isLicensee, RelatedCustId, RelatedUsername
              FROM #tmpFeedback_base_cust
              GROUP BY MessageId, HeadlineId, isLicensee, RelatedCustId, RelatedUsername) c
        GROUP BY c.MessageId,
                 c.HeadlineId,
                 c.isLicensee
    ),
    CTE_subproduct AS (
        SELECT MessageId,
               HeadlineId,
               STRING_AGG(CAST(SubProductId AS VARCHAR(MAX)), ',') SubProductIds
        FROM #tmpFeedback_base_subproduct
        GROUP BY MessageId,
                 HeadlineId
    ),
    CTE_bettype AS (
        SELECT MessageId,
               HeadlineId,
               STRING_AGG(CAST(BettypeId AS VARCHAR(MAX)), ',') BettypeIds
        FROM #tmpFeedback_base_bettype
        GROUP BY MessageId,
                 HeadlineId
    )
    INSERT INTO #tmpFeedback_base (
        MessageId,
        HeadlineId,
        isLicensee,
        RelatedCustIds,
        RelatedUsernames,
        SubProductIds,
        BettypeIds
    )
    SELECT c.MessageId,
           c.HeadlineId,
           c.isLicensee,
           c.RelatedCustIds,
           c.RelatedUsernames,
           sp.SubProductIds,
           b.BettypeIds
    FROM CTE_cust c
         LEFT JOIN CTE_subproduct sp ON c.MessageId = sp.MessageId AND c.HeadlineId = sp.HeadlineId
         LEFT JOIN CTE_bettype b ON c.MessageId = b.MessageId AND c.HeadlineId = b.HeadlineId
    -- + Update CommunicationIds
    -- + --> For Credit Model (base on setting)
    ;WITH
    CTE_Headline AS (
        SELECT HeadlineId
        FROM #tmpHeadlineData
        WHERE isLicensee = 0
        GROUP BY HeadlineId
    ),
    CTE_Setting AS (
        SELECT c.DefaultCommID,
               c.CustID,
               STRING_AGG(IIF(c.SettingType = 1, CONVERT(VARCHAR(MAX), c.SettingId), NULL), ',') WITHIN GROUP (ORDER BY c.SettingId ASC) AS Categorystr,
               STRING_AGG(IIF(c.SettingType = 2, CONVERT(VARCHAR(MAX), c.SettingId), NULL), ',') WITHIN GROUP (ORDER BY c.SettingId ASC) AS SubCategorystr,
               STRING_AGG(IIF(c.SettingType = 3, CONVERT(VARCHAR(MAX), c.SettingId), NULL), ',') WITHIN GROUP (ORDER BY c.SettingId ASC) AS CommunicationIds
        FROM bodb_CRM.dbo.crmDefaultCommTool c WITH (NOLOCK)
             LEFT JOIN bodb_CRM.dbo.crmSetting s WITH (NOLOCK) ON c.SettingID = s.SettingID
        WHERE c.CustID IN (SELECT HeadlineId FROM CTE_Headline)
              AND c.DefaultCommID <> 0
        GROUP BY c.DefaultCommId,
                 c.CustID
    ),
    CTE_CommTool AS (
        SELECT CustID,
               CommunicationIds,
               CASE WHEN Categorystr = CONVERT(VARCHAR(20), @Feedback_CategoryId) THEN 1
                    WHEN ',' + Categorystr + ',' LIKE '%,0,%' THEN 2 
                    ELSE 3 END AS Category_MappedLevel,
               CASE WHEN SubCategorystr = CONVERT(VARCHAR(20), @Feedback_SubCategoryId) THEN 1
                    WHEN ',' + SubCategorystr + ',' LIKE '%,0,%' THEN 2
                    ELSE 3 END AS SubCategory_MappedLevel
        FROM CTE_Setting
    )
    UPDATE h
    SET h.CommunicationIds = ISNULL(df.CommunicationIds, '1005') --CommunicationIds=1005 : N/A
    FROM #tmpFeedback_base h
         OUTER APPLY (SELECT TOP (1)
                             CASE WHEN c.Category_MappedLevel = 3 OR c.SubCategory_MappedLevel = 3 THEN '1005' ELSE c.CommunicationIds END AS CommunicationIds
                             FROM CTE_CommTool c
                             WHERE c.CustID = h.HeadlineId
                      ORDER BY c.Category_MappedLevel ASC ,
                               c. SubCategory_MappedLevel ASC) df
    WHERE isLicensee = 0
    -- + --> For Licensee Model (hardcode Email)
    ;WITH
    CTE_Data AS (
        SELECT TOP 1 SettingID
        FROM bodb_CRM.dbo.crmSetting WITH (NOLOCK)
        WHERE SettingName = 'Communication'
              AND SettingValue = 'Email'
              AND SiteOffer = 2
    )
    UPDATE h
    SET h.CommunicationIds = CAST(cte.SettingID AS VARCHAR(100))
    FROM #tmpFeedback_base h
         CROSS JOIN CTE_Data cte
    WHERE h.isLicensee = 1
    -- + Update CommunicationNames
    UPDATE h
    SET h.CommunicationNames = n.CommunicationNames
    FROM #tmpFeedback_base h
         CROSS APPLY (SELECT STRING_AGG(CONVERT(VARCHAR(MAX), s.SettingValue), '/') WITHIN GROUP (ORDER BY s.SettingValue ASC) AS CommunicationNames
                      FROM STRING_SPLIT(h.CommunicationIds, ',') AS h
                           INNER JOIN bodb_CRM.dbo.crmSetting s WITH (NOLOCK) ON s.SettingID = CONVERT(INT, h.value)) AS n
    -- + Update RoleId|LanguageId|CountryId
    UPDATE h
    SET h.RoleId = CASE c.roleid WHEN 1 THEN 7000
                                 WHEN 2 THEN 7001
                                 WHEN 3 THEN 7002
                                 WHEN 4 THEN 7003
                                 ELSE 7004 END,
        h.LanguageId = l.LanguageId,
        h.CountryId = cr.CountryID
    FROM #tmpFeedback_base h
         LEFT JOIN bodb_CRM.dbo.crmCustomer cr WITH (NOLOCK) ON h.HeadlineId = cr.CustID
         OUTER APPLY (SELECT TOP (1) l.LanguageId FROM bodb_CRM.dbo.crmCustomerLanguage l WITH (NOLOCK) WHERE l.CustID = h.HeadlineId ORDER BY l.LanguageID DESC) l
         LEFT JOIN bodb02.dbo.Customer c WITH (NOLOCK) ON h.HeadlineId = c.custid
         LEFT JOIN bodb02.dbo.Site s WITH (NOLOCK) ON c.site = s.site
    -- + Create index
    CREATE CLUSTERED INDEX CIX_Feedback_base ON #tmpFeedback_base(MessageId, HeadlineId)
    CREATE NONCLUSTERED INDEX IX_Id ON #tmpFeedback_base(Id)

    -- Group 03, Feedback event information > Base on spec
    --                                      > When create Feedback for Credit model
    --                                      > Field Description need info about event
    -- + Get data about SABA LeagueGroupID
    CREATE TABLE #tmpFeedback_event_SABALeagueGroupID (LeagueGroupID INT)
    INSERT INTO  #tmpFeedback_event_SABALeagueGroupID (LeagueGroupID)
    SELECT LeagueGroupID
    FROM bodb02.dbo.f_LeagueGroupConfig()
    -- + Frist, we need to collect detail data
    -- + --> Create temp table
    CREATE TABLE #tmpFeedback_event_detaildata (
        MessageId      INT,
        HeadlineId     INT,
        MatchId        INT,
        EventDate      DATE,
        SportType      INT,
        SportName      VARCHAR(200),
        GlobalShowTime DATETIME,
        LeagueName     VARCHAR(200),
        HomeTeamName   VARCHAR(200),
        AwayTeamName   VARCHAR(200)
    )
    -- + --> Gen data
    ;WITH
    CTE_Data AS (
        SELECT b.MessageId,
               h.HeadlineId,
               h.HeadlineSite,
               b.MatchId
        FROM #tmpMessageData b
             LEFT JOIN #tmpHeadlineData h ON b.CustId = h.CustId
        WHERE h.isLicensee = 0
        GROUP BY b.MessageId,
                 h.HeadlineId,
                 h.HeadlineSite,
                 b.MatchId
    )
    INSERT INTO #tmpFeedback_event_detaildata (
        MessageId,
        HeadlineId,
        MatchId,
        EventDate,
        SportType,
        SportName,
        GlobalShowTime,
        LeagueName,
        HomeTeamName,
        AwayTeamName
    )
    SELECT cte.MessageId,
           cte.HeadlineId,
           cte.MatchId,
           m.eventdate EventDate,
           s.SportType,
           s.SportName,
           m.GlobalShowTime,
           CASE WHEN (cte.HeadlineSite = '777777' AND lg.LeagueGroupID IS NOT NULL) THEN REPLACE(l.leaguename, 'SABA', '') ELSE l.leaguename END LeagueName,
           h.teamname HomeTeamName,
           a.teamname AwayTeamName
    FROM CTE_Data cte
         LEFT JOIN (SELECT matchid, eventdate, sporttype, GlobalShowTime, leagueid, homeid, awayid FROM bodb02.dbo.match WITH (NOLOCK)
                    UNION
                    SELECT matchid, eventdate, sporttype, GlobalShowTime, leagueid, homeid, awayid FROM bodb02.dbo.match14 WITH (NOLOCK)) m ON cte.MatchId = m.matchid
         LEFT JOIN bodb02.dbo.Sports s WITH (NOLOCK) ON m.sporttype = s.SportType
         LEFT JOIN bodb02.dbo.League l WITH (NOLOCK) ON m.leagueid = l.leagueid
         LEFT JOIN #tmpFeedback_event_SABALeagueGroupID lg ON l.LeagueGroupID = lg.LeagueGroupID
         LEFT JOIN bodb02.dbo.Team h WITH (NOLOCK) ON m.homeid = h.teamid
         LEFT JOIN bodb02.dbo.Team a WITH (NOLOCK) ON m.awayid = a.teamid
    -- + --> Create index
    CREATE CLUSTERED INDEX CIX_Feedback_event_detaildata ON #tmpFeedback_event_detaildata(MessageId, HeadlineId)
    -- + Second, we need to transform data to the way that suitable to create description, remember that we need to order event information as the spec request
    -- + --> Create temp table
    CREATE TABLE #tmpFeedback_event_finaldata (
        OrderID     INT IDENTITY(1,1),
        MessageId   INT,
        HeadlineId  INT,
        event_date  VARCHAR(1000),
        sport_name  VARCHAR(1000),
        ko_time     VARCHAR(1000),
        league_name VARCHAR(1000),
        match_name  VARCHAR(1000),
    )
    -- + --> Gen data to temp table
    INSERT INTO #tmpFeedback_event_finaldata (
        MessageId,
        HeadlineId,
        event_date,
        sport_name,
        ko_time,
        league_name,
        match_name
    )
    SELECT MessageId,
           HeadlineId,
           ISNULL(FORMAT(EventDate, 'dd-MMM-yyyy'), '') event_date,
           ISNULL(SportName, '') sport_name,
           ISNULL(FORMAT(DATEADD(HOUR, 12, GlobalShowTime), 'hh:mm tt'), '') ko_time,
           ISNULL(LeagueName, '') league_name,
           ISNULL((HomeTeamName + ' -vs- '+ AwayTeamName), '') match_name
    FROM #tmpFeedback_event_detaildata
    ORDER BY MessageId ASC,
             HeadlineId ASC,
             EventDate DESC,
             CAST(GlobalShowTime AS TIME) DESC,
             SportType ASC
    -- + --> Create index
    CREATE CLUSTERED INDEX CIX_Feedback_event_finaldata ON #tmpFeedback_event_finaldata(MessageId, HeadlineId)


    ----------------------------------------------------------------------------------------------------------
    -- [07] Create Feedback                                                                                 --
    --      _ Description and Solution are two most complicated fields and we need spend more time for them --
    --      _ When everything is ready, we run the loop to create Feedback                                  --
    ----------------------------------------------------------------------------------------------------------

    -- Declare variables
    DECLARE @Id         INT = 1
    DECLARE @FeedbackId INT

    DECLARE @CustId          INT
    DECLARE @IsGroupHeadLine BIT = 0

    -- Build Feedback Description
    -- + Create temp table
    CREATE TABLE #tmpFeedback_description (
        MessageId   INT,
        HeadlineId  INT,
        Description NVARCHAR(MAX),
        isLicensee  BIT,
        isProcessed BIT DEFAULT 0
    )
    -- + Gen data for credit model
    ;WITH
    CTE_eventinfo AS (
        SELECT MessageId,
               HeadlineId,
               STRING_AGG(CONVERT(NVARCHAR(MAX), 'Date: ' + event_date + '<br/>' + 'Sport: '+ sport_name + '<br/>' + 'Event Start Time: ' + ko_time + '<br/>' + 'League: ' + league_name + '<br/>' + 'Match: ' + match_name), '<br/>--------------------------------------------------<br/>') EventInfo
        FROM #tmpFeedback_event_finaldata
        GROUP BY MessageId,
                 HeadlineId
    )
    INSERT INTO #tmpFeedback_description (
        MessageId,
        HeadlineId,
        Description,
        isLicensee
    )
    SELECT b.MessageId,
           b.HeadlineId,
           d.Description,
           b.isLicensee
    FROM #tmpFeedback_base b
         LEFT JOIN CTE_eventinfo e ON b.MessageId = e.MessageId AND b.HeadlineId = e.HeadlineId
         OUTER APPLY (
            SELECT (
                       'Date Time & Tool: ' + FORMAT(DATEADD(HOUR, 12, @Feedback_Date), 'yyyyMMdd/hh:mmtt') + '/' + ISNULL(b.CommunicationNames, '') + CHAR(13) + CHAR(10)
                       + 'System ID: ' + ISNULL(b.RelatedUsernames, '')
                   ) AS '@AutoField'
                   ,
                   (
                       '<span style="color: rgb(255, 0, 0);">This is an auto-generated entry.</span><br/><span style="color: rgb(255, 0, 0);">'
                       + 'Msg ID: ' + ISNULL(CONVERT(VARCHAR(20), b.MessageId), '') + '</span><br/><br/>'
                       + ISNULL(e.EventInfo, '')
                   ) AS '@Remark'
            FOR XML PATH('row'), ROOT('ROOT')
        ) AS d(Description)
    WHERE b.isLicensee = 0
    -- + Gen data for licensee model
    -- + --> Just get base data first
    INSERT INTO #tmpFeedback_description (
        MessageId,
        HeadlineId,
        Description,
        isLicensee
    )
    SELECT b.MessageId,
           b.HeadlineId,
           d.Description,
           b.isLicensee
    FROM #tmpFeedback_base b
         OUTER APPLY (
            SELECT (
                       'Date Time & Tool: ' + FORMAT(DATEADD(HOUR, 12, @Feedback_Date), 'yyyyMMdd/hh:mmtt') + '/' + ISNULL(b.CommunicationNames, '') + CHAR(13) + CHAR(10)
                       + 'System ID: ' + ISNULL(b.RelatedUsernames, '')
                   ) AS '@AutoField'
                   ,
                   (
                       '<span style="color: rgb(255, 0, 0);">This is an auto-generated entry.</span><br/><span style="color: rgb(255, 0, 0);">'
                       + 'Msg ID: ' + ISNULL(CONVERT(VARCHAR(20), b.MessageId), '') + '</span><br/><br/>'
                       + '@RemarkContent@'
                   ) AS '@Remark'
            FOR XML PATH('row'), ROOT('ROOT')
        ) AS d(Description)
    WHERE b.isLicensee = 1
    -- + --> Get more infomation from sp NAP_Chatbot_ResultAmendment_InternalCSD_MessageBuilder
    BEGIN
        DECLARE @Loop_Lic_Des_CountTable     INT
        DECLARE @Loop_Lic_Des_MessageId      INT
        DECLARE @Loop_Lic_Des_HeadlineId     INT
        DECLARE @Loop_Lic_Des_NotificationID INT
        DECLARE @Loop_Lic_Des_ContentOutput  NVARCHAR(MAX)

        WHILE (1=1)
        BEGIN
            SELECT @Loop_Lic_Des_CountTable = COUNT(1) FROM #tmpFeedback_description tmp WHERE tmp.isLicensee = 1 AND tmp.isProcessed = 0
            IF (@Loop_Lic_Des_CountTable = 0) BREAK

            SELECT TOP(1)
                   @Loop_Lic_Des_MessageId  = tmp.MessageId,
                   @Loop_Lic_Des_HeadlineId = tmp.HeadlineId
            FROM #tmpFeedback_description tmp
            WHERE tmp.isLicensee = 1
                  AND tmp.isProcessed = 0

            SELECT @Loop_Lic_Des_NotificationID = NotificationID
            FROM MessageNotification.dbo.Notification WITH (NOLOCK)
            WHERE RefID = @Loop_Lic_Des_MessageId
                  AND NotificationType = 1

            EXEC MessageNotification.dbo.NAP_Chatbot_ResultAmendment_InternalCSD_MessageBuilder @NotificationID = @Loop_Lic_Des_NotificationID,
                                                                                                @OutputContent  = @Loop_Lic_Des_ContentOutput OUTPUT
            
            ;WITH
            CTE_raw AS (
                SELECT value LineText,
                       ROW_NUMBER() OVER (ORDER BY (SELECT 0) ASC) LineNumber
                FROM STRING_SPLIT(@Loop_Lic_Des_ContentOutput, CHAR(10))
            ),
            CTE_up AS (
                SELECT LineNumber UpNumber
                FROM CTE_raw
                WHERE LineText LIKE 'MatchID:%'
            ),
			CTE_upRemark AS (
                SELECT LineNumber UpNumber2
                FROM CTE_raw
                WHERE LineText LIKE '**Remark:**%'
            ),
            CTE_down AS (
                SELECT LineNumber DownNumber
                FROM CTE_raw
                WHERE LineText LIKE 'Attn:%'
            ),
            CTE_clean AS (
                SELECT r.LineText
                FROM CTE_raw r
                     CROSS JOIN CTE_up u
                     CROSS JOIN CTE_down d
					 OUTER APPLY CTE_upRemark ur
                WHERE ( r.LineNumber >= u.UpNumber
						AND r.LineNumber <= (d.DownNumber - 2)
						AND r.LineText NOT LIKE '%Affected Credit sites%'
						AND r.LineText NOT LIKE '%Credit Total Bets%'
						)
						OR r.LineNumber >= ur.UpNumber2
            )
            SELECT @Loop_Lic_Des_ContentOutput = STRING_AGG(CAST(REPLACE(REPLACE(LineText, '\', ''), '**', '') AS NVARCHAR(MAX)), '<br />')
            FROM CTE_clean

            SELECT @Loop_Lic_Des_ContentOutput = bodb_CRM.dbo.f_EncodeXMLValue(@Loop_Lic_Des_ContentOutput)

            UPDATE tmp
            SET tmp.isProcessed = 1,
                tmp.Description = REPLACE(tmp.Description, '@RemarkContent@', ISNULL(@Loop_Lic_Des_ContentOutput, ''))
            FROM #tmpFeedback_description tmp
            WHERE tmp.isLicensee = 1
                  AND tmp.isProcessed = 0
                  AND tmp.MessageId = @Loop_Lic_Des_MessageId
                  AND tmp.HeadlineId = @Loop_Lic_Des_HeadlineId
        END
    END
    -- + Create index
    CREATE CLUSTERED INDEX CIX_Feedback_description ON #tmpFeedback_description(MessageId, HeadlineId)

    -- Build Feedback solution
    -- + Create temp table
    CREATE TABLE #tmpFeedback_solution (
        MessageId  INT,
        HeadlineId INT,
        Solution   NVARCHAR(MAX)
    )
    -- + Gen data for credit model
    ;WITH
    CTE_Headline AS (
        SELECT HeadlineId, HeadlineSiteLabel, IsVip
        FROM #tmpHeadlineData
        WHERE isLicensee = 0
        GROUP BY HeadlineId, HeadlineSiteLabel, IsVip
    ),
    CTE_Message AS (
        SELECT MessageId, Content_EN, Content_CS, Content_YN
        FROM #tmpXMLData
        GROUP BY MessageId, Content_EN, Content_CS, Content_YN
    ),
    CTE_Template AS (
        SELECT CONVERT(NVARCHAR(MAX), N'Dear Sir, Customer Support would like to inform the below announcement:<br/>'
                                      + N'您好，客服部在此通知以下的通告：<br/><br/>' 
                                      + N'{message_content_en}<br/><br/>'                    
                                      + N'{message_content_sc}<br/><br/>'
                                      + N'Affected user/受影响会员: {affected_list}') AS SolutionENCS,
               CONVERT(NVARCHAR(MAX), N'Dear Sir, Customer Support would like to inform the below announcement:<br/>'
                                      + N'Xin chào quý khách, Bộ phận chăm sóc khách hàng xin thông báo thông báo dưới đây:<br/><br>'
                                      + N'{message_content_en}<br/><br/>'
                                      + N'Affected user / Tài khoản bị ảnh hưởng: {affected_list}') AS SolutionENYN
    )
    INSERT INTO #tmpFeedback_solution (
        MessageId,
        HeadlineId,
        Solution
    )
    SELECT b.MessageId,
           b.HeadlineId,
           CASE WHEN h.HeadlineSiteLabel = '789y' AND h.IsVip = 1 THEN REPLACE(REPLACE(REPLACE(t.SolutionENYN, '{message_content_en}', m.Content_EN), '@@', ''), '{affected_list}', b.RelatedUsernames)
                ELSE REPLACE(REPLACE(REPLACE(REPLACE(t.SolutionENCS, '{message_content_en}', m.Content_EN), '{message_content_sc}', m.Content_CS), '@@', ''), '{affected_list}', b.RelatedUsernames) END Solution
    FROM #tmpFeedback_base b
         LEFT JOIN CTE_Headline h ON b.HeadlineId = h.HeadlineId
         LEFT JOIN CTE_Message m ON b.MessageId = m.MessageId
         CROSS JOIN CTE_Template t
    WHERE b.isLicensee = 0
    -- + Gen data for licensee model
    ;WITH
    CTE_Message AS (
        SELECT MessageId, Content_EN, Content_CS, Content_YN
        FROM #tmpXMLData
        GROUP BY MessageId, Content_EN, Content_CS, Content_YN
    )
    INSERT INTO #tmpFeedback_solution (
        MessageId,
        HeadlineId,
        Solution
    )
    SELECT b.MessageId,
           b.HeadlineId,
           (
               REPLACE(m.Content_en, '@@', '') + '<br/><br/>' +
               REPLACE(m.Content_cs, '@@', '')
           ) Solution
    FROM #tmpFeedback_base b
         LEFT JOIN CTE_Message m ON b.MessageId = m.MessageId
    WHERE b.isLicensee = 1
    -- + Create index
    CREATE CLUSTERED INDEX CIX_Feedback_solution ON #tmpFeedback_solution(MessageId, HeadlineId)

    -- Run the loop to process data
    WHILE EXISTS (SELECT 1 FROM #tmpFeedback_base WHERE Id = @Id)
    BEGIN
        -- + Insert data to table crmFeedback
        INSERT INTO bodb_CRM.dbo.crmFeedback (
            CustID,
            TitleID,
            FirstName,
            LastName,
            Phone,
            MobilePhone,
            Fax,
            Email,
            LanguageID,
            CountryID,
            CreateDate,
            CreatorID,
            FeedbackDate,
            SolveDate,
            CommunicationID,
            StationID,
            MainCategoryID,
            SubCategoryID,
            SiteID,
            RoleID,
            ProductID,
            BetTypeID,
            ResponseID,
            StatusID,
            Description,
            Solution,
            IsReviewed,
            Review,
            ReviewerID,
            Subject,
            Skype,
            MSN,
            ResolutionDate,
            Pic1,
            Pic2,
            Pic3,
            PhoneCountryCode,
            PhoneAreaCode,
            Phone2,
            Phone2CountryCode,
            Phone2AreaCode,
            Phone3,
            Phone3CountryCode,
            Phone3AreaCode,
            MobilePhoneCountryCode,
            MobilePhoneAreaCode,
            FaxCountryCode,
            FaxAreaCode,
            Pic4,
            Passport,
            Line1,
            Line2,
            Line3,
            City,
            Postcode,
            State,
            BankLine1,
            BankLine2,
            BankLine3,
            BankCity,
            BankCode,
            BankState,
            Birthday,
            RefCode1,
            RefCode2,
            IsVip,
            Pic1Name,
            Pic2Name,
            Pic3Name,
            Pic4Name,
            WhatsApp,
            Line,
            WeChat,
            Yahoo,
            QQ,
            BBM,
            LicenseeType,
            SubProductID,
            ProvinceID,
            Inquiries
        )
        SELECT b.HeadlineId             CustID,
               c.TitleID                TitleID,
               c.FirstName              FirstName,
               c.LastName               LastName,
               c.Phone                  Phone,
               c.MobilePhone            MobilePhone,
               c.Fax                    Fax,
               c.Email                  Email,
               b.LanguageId             LanguageID,
               b.CountryId              CountryID,
               GETDATE()                CreateDate,
               @CreatorId               CreatorID,
               @Feedback_Date           FeedbackDate,
               NULL                     SolveDate,
               NULL                     CommunicationID,
               NULL                     StationID,
               NULL                     MainCategoryID,
               NULL                     SubCategoryID,
               c.SiteID                 SiteID,
               b.RoleId                 RoleID,
               NULL                     ProductID,
               NULL                     BetTypeID,
               @Feedback_ResponseId     ResponseID,
               @Feedback_StatusId       StatusID,
               d.Description            Description,
               s.Solution               Solution,
               0                        IsReviewed,
               ''                       Review,
               NULL                     ReviewerID,
               @Feedback_Subject        Subject,
               c.Skype                  Skype,
               c.MSN                    MSN,
               @Feedback_ResolutionDate ResolutionDate,
               c.Pic1                   Pic1,
               c.Pic2                   Pic2,
               c.Pic3                   Pic3,
               c.PhoneCountryCode       PhoneCountryCode,
               c.PhoneAreaCode          PhoneAreaCode,
               c.Phone2                 Phone2,
               c.Phone2CountryCode      Phone2CountryCode,
               c.Phone2AreaCode         Phone2AreaCode,
               c.Phone3                 Phone3,
               c.Phone3CountryCode      Phone3CountryCode,
               c.Phone3AreaCode         Phone3AreaCode,
               c.MobilePhoneCountryCode MobilePhoneCountryCode,
               c.MobilePhoneAreaCode    MobilePhoneAreaCode,
               c.FaxCountryCode         FaxCountryCode,
               c.FaxAreaCode            FaxAreaCode,
               c.Pic4                   Pic4,
               c.Passport               Passport,
               c.Line1                  Line1,
               c.Line2                  Line2,
               c.Line3                  Line3,
               c.City                   City,
               c.Postcode               Postcode,
               c.State                  State,
               c.BankLine1              BankLine1,
               c.BankLine2              BankLine2,
               c.BankLine3              BankLine3,
               c.BankCity               BankCity,
               c.BankCode               BankCode,
               c.BankState              BankState,
               c.Birthday               Birthday,
               c.RefCode1               RefCode1,
               c.RefCode2               RefCode2,
               c.IsVip                  IsVip,
               c.Pic1Name               Pic1Name,
               c.Pic2Name               Pic2Name,
               c.Pic3Name               Pic3Name,
               c.Pic4Name               Pic4Name,
               c.WhatsApp               WhatsApp,
               c.Line                   Line,
               c.WeChat                 WeChat,
               c.Yahoo                  Yahoo,
               c.QQ                     QQ,
               c.BBM                    BBM,
               c.LicenseeType           LicenseeType,
               NULL                     SubProductID,
               c.ProvinceID             ProvinceID,
               0                        Inquiries
        FROM #tmpFeedback_base b
             LEFT JOIN bodb_CRM.dbo.crmCustomer c WITH (NOLOCK) ON b.HeadlineId = c.CustID
             LEFT JOIN #tmpFeedback_solution s ON b.MessageId = s.MessageId AND b.HeadlineId = s.HeadlineId
             LEFT JOIN #tmpFeedback_description d ON b.MessageId = d.MessageId AND b.HeadlineId = d.HeadlineId
        WHERE b.Id = @Id

        -- + Get data for @FeedbackId|@CustId|@IsGroupHeadLine
        SELECT @FeedbackId      = SCOPE_IDENTITY()
        SELECT @CustId          = HeadlineId FROM #tmpFeedback_base WHERE Id = @Id
        SELECT @IsGroupHeadLine = ISNULL(IsGroupHeadLine, 0) FROM bodb02.dbo.custAccount WITH (NOLOCK) WHERE custid = @CustId AND IsGroupHeadLine = 1

        -- + Insert data to table crmFeedbackCustomer
        INSERT INTO bodb_CRM.dbo.crmFeedbackCustomer (
            FeedbackId,
            CustId,
            IsRelated
        )
        SELECT @FeedbackId FeedbackId,
               n.CustId    CustId,
               n.IsRelated IsRelated
        FROM #tmpFeedback_base b
             CROSS APPLY (SELECT CAST(c.value AS INT) CustId, 1 IsRelated
                          FROM STRING_SPLIT(b.RelatedCustIds, ',') c
                          WHERE c.value <> b.HeadlineId
                          UNION ALL
                          SELECT b.HeadlineId CustId, 0 IsRelated) n
        WHERE b.Id = @Id

        -- + Insert data to table crmFeedbackSetting
        INSERT INTO bodb_CRM.dbo.crmFeedbackSetting (
            FeedbackId,
            SettingId,
            SubSettingId,
            SubSettingIdLevel3
        )
        -- + --> CS Ex./Station
        SELECT @FeedbackId         FeedbackId,
               @Feedback_StationId SettingId,
               0                   SubSettingId,
               0                   SubSettingIdLevel3
        UNION ALL
        -- + --> Category|SubCategory
        SELECT @FeedbackId             FeedbackId,
               @Feedback_CategoryId    SettingId,
               @Feedback_SubCategoryId SubSettingId,
               0                       SubSettingIdLevel3
        UNION ALL
        -- + --> Communication Tool
        SELECT @FeedbackId                  FeedbackId,
               ISNULL(c.CommunicationId, 0) SettingId,
               0                            SubSettingId,
               0                            SubSettingIdLevel3
        FROM #tmpFeedback_base b
             OUTER APPLY(SELECT CAST(c.value AS INT) CommunicationId FROM STRING_SPLIT(b.CommunicationIds, ',') c) c
        WHERE b.Id = @Id
        UNION ALL
        -- + --> Product|Sub-product|Bet Type
        SELECT DISTINCT
               @FeedbackId               FeedbackId,
               @Feedback_ProductId       SettingId,
               ISNULL(s.SubProductId, 0) SubSettingId,
               ISNULL(t.BettypeId, 0)    SubSettingIdLevel3
        FROM #tmpFeedback_base b
             OUTER APPLY(SELECT CAST(s.value AS INT) SubProductId FROM STRING_SPLIT(b.SubProductIds, ',') s) s
             OUTER APPLY(SELECT CAST(t.value AS INT) BettypeId FROM STRING_SPLIT(b.BettypeIds, ',') t) t
        WHERE b.Id = @Id

        -- + Insert data to table crmFeedbackNewCommunicationTool
        IF (@IsGroupHeadLine = 1)
        BEGIN
            ;WITH CTE_HeadlineInfo AS (
                SELECT DISTINCT
                       p.PicID         PicID,
                       p.Username      PicName,
                       sr.SettingValue PicRoleName
                FROM bodb_CRM.dbo.crmPicManagement pm WITH (NOLOCK)
                     LEFT JOIN bodb_CRM.dbo.crmPIC p WITH (NOLOCK) ON pm.PicID = p.PicID
                     LEFT JOIN bodb_CRM.dbo.crmSetting sr WITH (NOLOCK) ON sr.SettingName = 'PICRole' AND p.Role = sr.SettingID
                WHERE pm.HeadlineID = @CustId
            )
            INSERT INTO bodb_CRM.dbo.crmFeedbackNewCommunicationTool (
                FeedbackID,
                CustID,
                isHeadline,
                PicInfo,
                CommunicationID,
                CommunicationValue
            )
            SELECT @FeedbackId                                              FeedbackID,
                   @CustId                                                  CustID,
                   ISNULL(@IsGroupHeadLine, 0)                              isHeadline,
                   ISNULL((cte.PicName + ' (' + cte.PicRoleName + ')'), '') PicInfo,
                   pc.CommunicationID                                       CommunicationID,
                   pc.CommunicationValue                                    PicCommunicationValue
            FROM CTE_HeadlineInfo cte
                 LEFT JOIN bodb_CRM.dbo.crmPICCommunication pc WITH (NOLOCK) ON cte.PicID = pc.PicID
        END
        ELSE
        BEGIN
            INSERT INTO bodb_CRM.dbo.crmFeedbackNewCommunicationTool (
                FeedbackID,
                CustID,
                isHeadline,
                PicInfo,
                CommunicationID,
                CommunicationValue
            )
            SELECT @FeedbackId                 FeedbackID,
                   @CustId                     CustID,
                   ISNULL(@IsGroupHeadLine, 0) isHeadline,
                   ''                          PicInfo,
                   ccc.CommunicationID         CommunicationID,
                   ccc.CommunicationValue      CommunicationValue
            FROM bodb_CRM.dbo.crmCustomerNewCommunicationTool ccc WITH (NOLOCK)
            WHERE ccc.CustID = @CustId
        END

        -- + Insert data to table crmFeedbackReference
        INSERT INTO bodb_CRM.dbo.crmFeedbackReference (
            FeedbackId,
            ReferenceId,
            DataSource,
            CreatedDate
        )
        SELECT @FeedbackId                  FeedbackId,
               MessageId                    ReferenceId,
               'DBMSG.bodb_Message.dbo.Msg' DataSource,
               GETDATE()                    CreatedDate
        FROM #tmpFeedback_base
        WHERE Id = @Id

        -- + Continue the loop
        SET @Id += 1
    END


    -----------------------------
    -- [08] Update job setting --

    UPDATE s
    SET s.Value = CONVERT(VARCHAR(20), @LastMsgTargetId)
    FROM bodb_CRM.dbo.SystemSetting s WITH (ROWLOCK)
    WHERE s.ServiceName = @ServiceName
          AND s.SettingName = @SettingNameOfLastMsgTargetId

    UPDATE s
    SET s.Value = 'Completed'
    FROM bodb_CRM.dbo.SystemSetting s WITH (ROWLOCK)
    WHERE s.ServiceName = @ServiceName
          AND s.SettingName = @SettingNameOfJobStatus
          AND s.Value = 'Running'


    ---------------------------
    -- [09] Drop temp tables --

    DROP TABLE #tmpXMLData

    DROP TABLE #tmpMessageData
    DROP TABLE #tmpHeadlineData

    DROP TABLE #tmpSyncHeadline

    DROP TABLE #tmpFeedback_base_cust
    DROP TABLE #tmpFeedback_base_subproduct
    DROP TABLE #tmpFeedback_base_bettype
    DROP TABLE #tmpFeedback_base
    DROP TABLE #tmpFeedback_event_SABALeagueGroupID
    DROP TABLE #tmpFeedback_event_detaildata
    DROP TABLE #tmpFeedback_event_finaldata

    DROP TABLE #tmpFeedback_description
    DROP TABLE #tmpFeedback_solution

END
GO