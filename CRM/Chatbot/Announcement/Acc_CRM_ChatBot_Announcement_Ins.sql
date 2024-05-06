/*<info serverAlias="DBCRM-bodb_CRM" executers="wsv_nap" isFunction="0" isNested="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE dbo.Acc_CRM_ChatBot_Announcement_Ins --Announcement information
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
                                                     --Return AnnouncementId
                                                     @AnnouncementId         INT            = 0  OUTPUT,
                                                     --Log information
                                                     @UserId                 INT,
                                                     @LoginIP                VARCHAR(45)    = '',
                                                     --Error information
                                                     @ErrCode                INT            = 0  OUTPUT,
                                                     @ErrMsg                 NVARCHAR(2000) = '' OUTPUT
AS

/*
    Created: 20221213@Malcolm
    Task: Announcement - Annoucement list - New annoucement (Insert a new announcement)
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


    -------------------
    -- Validate data --

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

    -- Insert data to table
    BEGIN TRY
        -- + crmAnnouncement
        INSERT INTO bodb_CRM.dbo.crmAnnouncement (
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
            HeadlineType
        )
        VALUES (
            @NotificationTemplateId,
            @Title,
            @SendDate,
            @UserId,
            @CurrentDate,
            @Status,
            @SendImmediately,
            @return_HeadlineNameList,
            @SiteNameList,
            @CurrencyList,
            @HeadlineType
        )

        -- + Get AnnouncementId
        SET @AnnouncementId = SCOPE_IDENTITY()

        -- + crmAnnouncementContent
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
        DELETE bodb_CRM.dbo.crmAnnouncement         WITH(ROWLOCK, UPDLOCK) WHERE AnnouncementId = @AnnouncementId
        DELETE bodb_CRM.dbo.crmAnnouncementContent  WITH(ROWLOCK, UPDLOCK) WHERE AnnouncementId = @AnnouncementId
        DELETE bodb_CRM.dbo.crmAnnouncementHeadline WITH(ROWLOCK, UPDLOCK) WHERE AnnouncementId = @AnnouncementId

        SELECT @ErrCode = @@ERROR
        SELECT @ErrMsg  = ERROR_MESSAGE()

        RETURN
    END CATCH

    -- Create notification if @SendImmediately = 1 AND @Status = 'Planned'
    IF (@SendImmediately = 1 AND @Status = 'Planned')
    BEGIN
        EXEC bodb_CRM.dbo.Acc_CRM_ChatBot_Notification_Import @AnnouncementId = @AnnouncementId
    END


    --------------
    -- Log data --

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
                                                FOR XML PATH('Acc_CRM_ChatBot_Announcement_Ins')))

    -- Write log
    EXEC bodb_CRM.dbo.WriteLog_UserLog_crmUserLog_RunSP @UserID       = @UserID,
                                                        @CustID       = NULL,
                                                        @ActionID     = 1013,
                                                        @IP           = @LoginIP,
                                                        @NewValues    = @NewValues,
                                                        @CustIds      = NULL,
                                                        @ReferenceIds = NULL


    ---------------
    -- Drop data --

    DROP TABLE #tmpReturnValidationData

END
GO