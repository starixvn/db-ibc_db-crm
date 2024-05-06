/*<info serverAlias="DBCRM-bodb_CRM" executers="wsv_nap" isFunction="0" isNested="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE dbo.Acc_CRM_ChatBot_Announcement_Upd --Key value
                                                     @AnnouncementId         INT,
                                                     --Announcement information
                                                     @NotificationTemplateId SMALLINT,
                                                     @Title                  NVARCHAR(2000) = '',
                                                     @Contents               XML,
                                                     --Input specific headline list
                                                     @HeadlineNameList       NVARCHAR(MAX)  = '',
                                                     --Get headline list based on some criteria
                                                     @SiteNameList           NVARCHAR(MAX)  = '',
                                                     @CurrencyList           VARCHAR(MAX)   = '',
                                                     @HeadlineType           TINYINT        = NULL,
                                                     --Way to send notification
                                                     @SendDate               DATETIME       = NULL,
                                                     @SendImmediately        BIT            = NULL,
                                                     @Status                 VARCHAR(20),
                                                     --Log information
                                                     @UserId                 INT,
                                                     @LoginIP                VARCHAR(45)    = '',
                                                     --Error information
                                                     @ErrCode                INT            = 0  OUTPUT,
                                                     @ErrMsg                 NVARCHAR(2000) = '' OUTPUT
AS

/*
    Created: 20221213@Malcolm
    Task: Announcement - Action (when Status = Cancelled) - Edit annoucement (Edit a announcement)
    DB: DBCRM/bodb_CRM
    Original:

    Revisions:
        - 20221213@Malcolm: Initialize SPs [Redmine: #179118]
        - 20230508@Malcolm: Offer Telegram bot service for Headlines [RedmineId : #179119]
        - 20230804@Malcolm: Add Draft Status [Redmine: #192158]
        - 20231208@Ned.Le: Fix error relate to STRING_AGG function
        - 20240327@Ned.Le: CRM - Headline Announcement - Enhancement - Allow to attach separate screenshots for a specific language AND Allow to push Notifications with empty content [Redmine: #201042]

    Param's Explanation:
        - @Contents: <Contents>
                         <Content LanguageId = "50000" Value = "Content EN" FileName = "ImageEN.png"/>
                         <Content LanguageId = "50001" Value = "Content SC" FileName = "ImageSC.png"/>
                         <Content LanguageId = "50002" Value = "Content EN SC" FileName = "ImageENSC.png"/>
                         <Content LanguageId = "50003" Value = "Content TH" FileName = "ImageTH.png"/>
                         <Content LanguageId = "50004" Value = "Content YN" FileName = "ImageYN.png"/>
                     </Contents>
        - @HeadlineType = 0 : Normal
                        = 1 : VIP
                        = 2 : All
*/

BEGIN

    SET NOCOUNT ON


    ------------------
    -- Prepare data --

    -- Variables
    DECLARE @return_HeadlineNameList      NVARCHAR(MAX)
    DECLARE @return_DirectAccountNameList NVARCHAR(MAX)
    DECLARE @CurrentDate                  DATETIME = GETDATE()

    -- Temp tables
    CREATE TABLE #tmpReturnValidationData (
        HeadlineNameList      NVARCHAR(MAX),
        DirectAccountNameList NVARCHAR(MAX)
    )

    CREATE TABLE #tmpAnnouncementOldValue (
        NotificationTemplateId  SMALLINT,
        Title                   NVARCHAR(2000),
        SendDate                DATETIME,
        CreatedBy               INT,
        CreatedDate             DATETIME,
        Status                  VARCHAR(20),
        SendImmediately         BIT,
        HeadlineNameList        NVARCHAR(MAX),
        SiteNameList            NVARCHAR(MAX),
        CurrencyIdList          VARCHAR(MAX),
        HeadlineType            TINYINT,
        UpdatedBy               INT,
        UpdatedDate             DATETIME,
        LanguageId              INT,
        Content                 NVARCHAR(MAX),
        FileName                NVARCHAR(2000),
        CustId                  INT,
        Type                    TINYINT --1:crmAnnouncement|2:crmAnnouncementContent|3:crmAnnouncementHeadline|4:crmAnnouncementDirectAccount
    )


    -------------------
    -- Validate data --

    -- Check status of AnnouncementId
    IF EXISTS (SELECT 1
               FROM bodb_CRM.dbo.crmAnnouncement WITH (NOLOCK)
               WHERE AnnouncementId = @AnnouncementId
                     AND Status NOT IN ('Cancelled', 'Draft'))
    BEGIN
        SELECT @ErrCode = 105
        SELECT @ErrMsg  = 'Can not edit this announcement, please check again.'
        RETURN
    END

    -- Check data correct of announcement information
    IF (@Status = 'Planned')
    BEGIN
        INSERT INTO #tmpReturnValidationData (HeadlineNameList, DirectAccountNameList)
        EXEC bodb_CRM.dbo.Acc_CRM_ChatBot_Announcement_Validation @HeadlineNameList = @HeadlineNameList,
                                                                  @SiteNameList     = @SiteNameList,
                                                                  @CurrencyList     = @CurrencyList,
                                                                  @HeadlineType     = @HeadlineType,
                                                                  @Contents         = @Contents,
                                                                  @ErrCode          = @ErrCode OUTPUT,
                                                                  @ErrMsg           = @ErrMsg  OUTPUT
        
        IF (ISNULL(@ErrCode, 0) <> 0)
        BEGIN
            RETURN
        END
        ELSE
        BEGIN
            SELECT @return_HeadlineNameList      = HeadlineNameList,
                   @return_DirectAccountNameList = DirectAccountNameList
            FROM #tmpReturnValidationData
        END
    END

    -- Set value for parameter @return_HeadlineNameList when @Status='Draft'
    IF (@Status = 'Draft')
    BEGIN
        SET @return_HeadlineNameList = @HeadlineNameList
    END


    ------------------
    -- Process data --

    -- Set data for @SendDate
    IF (@SendImmediately = 1)
    BEGIN
        SELECT @SendDate = @CurrentDate
    END

    -- Update data on table
    BEGIN TRY
        -- + crmAnnouncement
        UPDATE bodb_CRM.dbo.crmAnnouncement WITH (ROWLOCK, UPDLOCK)
        SET NotificationTemplateId = @NotificationTemplateId,
            Title                  = @Title,
            SendDate               = @SendDate,
            Status                 = @Status,
            SendImmediately        = @SendImmediately,
            HeadlineNameList       = @return_HeadlineNameList,
            SiteNameList           = @SiteNameList,
            CurrencyIdList         = @CurrencyList,
            HeadlineType           = @HeadlineType,
            UpdatedBy              = @UserId,
            UpdatedDate            = @CurrentDate
        OUTPUT deleted.NotificationTemplateId,
               deleted.Title,
               deleted.SendDate,
               deleted.CreatedBy,
               deleted.CreatedDate,
               deleted.Status,
               deleted.SendImmediately,
               deleted.HeadlineNameList,
               deleted.SiteNameList,
               deleted.CurrencyIdList,
               deleted.HeadlineType,
               deleted.UpdatedBy,
               deleted.UpdatedDate,
               1 Type
        INTO #tmpAnnouncementOldValue (
            NotificationTemplateId,
            Title,
            SendDate,
            CreatedBy,
            CreatedDate,
            Status,
            SendImmediately,
            HeadlineNameList,
            SiteNameList,
            CurrencyIdList,
            HeadlineType,
            UpdatedBy,
            UpdatedDate,
            Type
        )
        WHERE AnnouncementId = @AnnouncementId

        -- + crmAnnouncementContent
        DELETE bodb_CRM.dbo.crmAnnouncementContent WITH (ROWLOCK, UPDLOCK)
        OUTPUT deleted.LanguageId, deleted.Content, deleted.FileName, 2 Type
        INTO #tmpAnnouncementOldValue (LanguageId, Content, FileName, Type)
        WHERE AnnouncementId = @AnnouncementId

        INSERT INTO bodb_CRM.dbo.crmAnnouncementContent (
            AnnouncementId,
            LanguageId,
            Content,
            FileName
        )
        SELECT @AnnouncementId                         AS AnnouncementId,
               t.c.value('@LanguageId', 'INT')         AS LanguageId,
               t.c.value('@Value', 'NVARCHAR(MAX)')    AS Content,
               t.c.value('@FileName', 'NVARCHAR(MAX)') AS FileName
        FROM @Contents.nodes('Contents/Content') AS t(c)

        -- + Deal with @Status = 'Planned'
        IF (@Status = 'Planned')
        BEGIN
            -- + --> crmAnnouncementHeadline
            DELETE bodb_CRM.dbo.crmAnnouncementHeadline WITH (ROWLOCK, UPDLOCK)
            OUTPUT deleted.CustId, 3 Type
            INTO #tmpAnnouncementOldValue (CustId, Type)
            WHERE AnnouncementId = @AnnouncementId

            ;WITH CTE_HeadlineAccount AS (
                SELECT DISTINCT
                       f.value  HeadlineName,
                       n.custid HeadlineID
                FROM STRING_SPLIT(@return_HeadlineNameList, ',') f
                     OUTER APPLY (SELECT c.custid
                                  FROM bodb02.dbo.Customer c WITH (NOLOCK)
                                  WHERE c.username = CONVERT(VARCHAR(30), f.value)) AS n
                WHERE f.value <> ''
            )
            INSERT INTO bodb_CRM.dbo.crmAnnouncementHeadline (
                AnnouncementId,
                CustId
            )
            SELECT @AnnouncementId AnnouncementId,
                   HeadlineID      CustId
            FROM CTE_HeadlineAccount

            -- + --> crmAnnouncementDirectAccount
            DELETE dbo.crmAnnouncementDirectAccount WITH(ROWLOCK, UPDLOCK)
            OUTPUT deleted.CustId, 4 Type
            INTO #tmpAnnouncementOldValue (CustId, Type)
            WHERE AnnouncementId = @AnnouncementId

            ;WITH CTE_DirectAccount AS (
                SELECT DISTINCT
                       f.value  DirectAccountName,
                       n.custid DirectAccountID
                FROM STRING_SPLIT(@return_DirectAccountNameList, ',') f
                     OUTER APPLY (SELECT c.custid
                                  FROM bodb02.dbo.Customer c WITH (NOLOCK)
                                  WHERE c.username = CONVERT(VARCHAR(30), f.value)) AS n
                WHERE f.value <> ''
            )
            INSERT INTO bodb_CRM.dbo.crmAnnouncementDirectAccount (
                AnnouncementId,
                CustId
            )
            SELECT @AnnouncementId AnnouncementId,
                   DirectAccountID CustId
            FROM CTE_DirectAccount
        END
    END TRY
    BEGIN CATCH
        -- + crmAnnouncement
        IF EXISTS (SELECT 1 FROM #tmpAnnouncementOldValue WHERE Type = 1)
        BEGIN
            UPDATE a WITH (ROWLOCK, UPDLOCK)
            SET a.NotificationTemplateId = t.NotificationTemplateId,
                a.Title                  = t.Title,
                a.SendDate               = t.SendDate,
                a.CreatedBy              = t.CreatedBy,
                a.CreatedDate            = t.CreatedDate,
                a.Status                 = t.Status,
                a.SendImmediately        = t.SendImmediately,
                a.HeadlineNameList       = t.HeadlineNameList,
                a.SiteNameList           = t.SiteNameList,
                a.CurrencyIdList         = t.CurrencyIdList,
                a.HeadlineType           = t.HeadlineType,
                a.UpdatedBy              = t.UpdatedBy,
                a.UpdatedDate            = t.UpdatedDate
            FROM bodb_CRM.dbo.crmAnnouncement a 
                 CROSS JOIN #tmpAnnouncementOldValue t
            WHERE a.AnnouncementId = @AnnouncementId
                  AND t.Type = 1
        END

        -- + crmAnnouncementContent
        IF EXISTS (SELECT 1 FROM #tmpAnnouncementOldValue WHERE Type = 2)
        BEGIN    
            DELETE bodb_CRM.dbo.crmAnnouncementContent WITH (ROWLOCK, UPDLOCK)
            WHERE AnnouncementId = @AnnouncementId

            INSERT INTO bodb_CRM.dbo.crmAnnouncementContent (
                AnnouncementId,
                LanguageId,
                Content,
                FileName
            )
            SELECT @AnnouncementId AnnouncementId,
                   LanguageId      LanguageId,
                   Content         Content,
                   FileName        FileName
            FROM #tmpAnnouncementOldValue 
            WHERE Type = 2
        END

        -- + crmAnnouncementHeadline
        IF EXISTS (SELECT 1 FROM #tmpAnnouncementOldValue WHERE Type = 3)
        BEGIN
            DELETE bodb_CRM.dbo.crmAnnouncementHeadline WITH (ROWLOCK, UPDLOCK)
            WHERE AnnouncementId = @AnnouncementId

            INSERT INTO bodb_CRM.dbo.crmAnnouncementHeadline (
                AnnouncementId,
                CustId
            )
            SELECT @AnnouncementId AnnouncementId,
                   CustId          CustId
            FROM #tmpAnnouncementOldValue
            WHERE Type = 3
        END

        -- + crmAnnouncementDirectAccount
        IF EXISTS (SELECT 1 FROM #tmpAnnouncementOldValue WHERE Type = 4)
        BEGIN
            DELETE bodb_CRM.dbo.crmAnnouncementDirectAccount WITH (ROWLOCK, UPDLOCK)
            WHERE AnnouncementId = @AnnouncementId

            INSERT INTO bodb_CRM.dbo.crmAnnouncementDirectAccount (
                AnnouncementId,
                CustId
            )
            SELECT @AnnouncementId AnnouncementId,
                   CustId          CustId
            FROM #tmpAnnouncementOldValue
            WHERE Type = 4
        END

        -- + Return
        RETURN
    END CATCH

    -- Create notification if @SendImmediately = 1 AND @Status = 'Planned'
    IF (@SendImmediately = 1 AND @Status = 'Planned')
    BEGIN
        EXEC bodb_CRM.dbo.Acc_CRM_ChatBot_Notification_Import @AnnouncementId = @AnnouncementId
    END


    --------------
    -- Log data --

    -- Get old value
    DECLARE @OldValues NVARCHAR(MAX)
    SELECT  @OldValues = CONVERT(NVARCHAR(MAX), (SELECT @AnnouncementId        AS '@AnnouncementId',
                                                        NotificationTemplateId AS '@NotificationTemplateId',
                                                        Title                  AS '@Title',
                                                        SendDate               AS '@SendDate',
                                                        Status                 AS '@Status',
                                                        SendImmediately        AS '@SendImmediately',
                                                        HeadlineNameList       AS '@HeadlineNameList',
                                                        SiteNameList           AS '@SiteNameList',
                                                        CurrencyIdList         AS '@CurrencyIdList',
                                                        HeadlineType           AS '@HeadlineType',
                                                        (SELECT LanguageId AS '@LanguageId',
                                                                Content    AS '@Value',
                                                                FileName   AS '@FileName'
                                                         FROM #tmpAnnouncementOldValue
                                                         WHERE Type = 2
                                                         FOR XML PATH('Content'), ROOT('Contents'), TYPE)
                                                 FROM #tmpAnnouncementOldValue
                                                 WHERE Type = 1
                                                 FOR XML PATH('Acc_CRM_ChatBot_Announcement_Upd')))

    -- Get new value
    DECLARE @NewValues NVARCHAR(MAX)
    SELECT  @NewValues = CONVERT(VARCHAR(MAX), (SELECT @AnnouncementId          AS '@AnnouncementId',
                                                       @NotificationTemplateId  AS '@NotificationTemplateId',
                                                       @Title                   AS '@Title',
                                                       @SendDate                AS '@SendDate',
                                                       @Status                  AS '@Status',
                                                       @SendImmediately         AS '@SendImmediately',
                                                       @return_HeadlineNameList AS '@HeadlineNameList',
                                                       @SiteNameList            AS '@SiteNameList',
                                                       @CurrencyList            AS '@CurrencyList',
                                                       @HeadlineType            AS '@HeadlineType',
                                                       @Contents                
                                                FOR XML PATH('Acc_CRM_ChatBot_Announcement_Upd')))

    -- Write log
    EXEC bodb_CRM.dbo.WriteLog_UserLog_crmUserLog_RunSP @UserID       = @UserID,
                                                        @CustID       = NULL,
                                                        @ActionID     = 1014,
                                                        @IP           = @LoginIP,
                                                        @NewValues    = @NewValues,
                                                        @OldValues    = @OldValues,
                                                        @CustIds      = NULL,
                                                        @ReferenceIds = NULL


    ---------------
    -- Drop data --

    DROP TABLE #tmpReturnValidationData
    DROP TABLE #tmpAnnouncementOldValue

END
GO