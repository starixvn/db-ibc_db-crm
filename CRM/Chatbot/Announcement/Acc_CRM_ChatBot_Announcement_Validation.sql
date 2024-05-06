/*<info serverAlias="DBCRM-bodb_CRM" executers="wsv_nap" isFunction="0" isNested="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE dbo.Acc_CRM_ChatBot_Announcement_Validation --Input specific headline list
                                                            @HeadlineNameList NVARCHAR(MAX)  = '',
                                                            --Get headline list based on some criteria
                                                            @SiteNameList     NVARCHAR(MAX)  = '',
                                                            @CurrencyList     VARCHAR(MAX)   = '',
                                                            @HeadlineType     TINYINT        = NULL,
                                                            --Content
                                                            @Contents         XML,
                                                            --Save error and return
                                                            @ErrCode          INT            = 0  OUTPUT,
                                                            @ErrMsg           NVARCHAR(2000) = '' OUTPUT
AS

/*
    Created: 20221213@Malcolm
    Task: Announcement - Annoucement list - New annoucement (Insert a new announcement)/ Edit announcement - Validation
    DB: DBCRM/bodb_CRM
    Original:

    Revisions:
        - 20221213@Malcolm: Initialize SPs [Redmine: #192158]
        - 20231208@Ned.Le: Fix error relate to STRING_AGG function
        - 20240327@Ned.Le: CRM - Headline Announcement - Enhancement - Allow to attach separate screenshots for a specific language AND Allow to push Notifications with empty content [Redmine: #201042]

    Param's Explanation:
        - @HeadlineType = 0 : Normal
                        = 1 : VIP
                        = 2 : All
*/

BEGIN

    SET NOCOUNT ON


    ------------------
    -- Prepare data --

    -- Variables
    DECLARE @NotificationTypeId SMALLINT
    SELECT  @NotificationTypeId = NotificationTypeId FROM bodb_CRM.dbo.crmNotificationType WITH (NOLOCK) WHERE NotificationTypeName = 'Upload Announcement'

    DECLARE @DirectAccountNameList NVARCHAR(MAX) = ''

    -- Temp tables
    CREATE TABLE #tmpHeadlineInput  (HeadlineId INT, HeadlineName VARCHAR(30))
    CREATE TABLE #tmpHeadlineOutput (HeadlineId INT, HeadlineName VARCHAR(30), ErrCode SMALLINT DEFAULT(-1))

    CREATE TABLE #tmpDirectAccountInput  (DirectAccId INT, ConversationGroupId INT, NoRecipient INT)
    CREATE TABLE #tmpDirectAccountOutput (DirectAccId INT, DirectAccName VARCHAR(30), ConversationGroupId INT)
    
    CREATE TABLE #tmpValidateContentsInput  (LanguageId INT, Content NVARCHAR(MAX), FileName NVARCHAR(MAX))
    CREATE TABLE #tmpValidateContentsOutput (HeadlineName VARCHAR(30), LanguageId INT, LanguageName NVARCHAR(100), Content NVARCHAR(MAX), FileName NVARCHAR(MAX))

    CREATE TABLE #tmpErrorList (ErrCode TINYINT, ErrMsg NVARCHAR(MAX))
    INSERT INTO  #tmpErrorList (ErrCode, ErrMsg) VALUES (1, 'Invalid Headline'),
                                                        (2, 'Not Mapped Headline'),
                                                        (3, 'Bot Removed Headline'),
                                                        (4, 'In-Active Headline'),
                                                        (5, 'Ignored Headline')

   
    ------------------
    -- Process data --

    -- Validate data for Headline from specific headline list
    IF (ISNULL(@HeadlineNameList, '') <> '')
    BEGIN 
        -- + Parse string data to table
        INSERT INTO #tmpHeadlineOutput (
            HeadlineId,
            HeadlineName,
            ErrCode
        )
        SELECT DISTINCT
               n.custid                                      HeadlineId,
               f.value                                       HeadlineName,
               CASE WHEN n.CustId IS NULL THEN 1 ELSE -1 END ErrCode
        FROM STRING_SPLIT(@HeadlineNameList, ',') f
             OUTER APPLY (SELECT c.custid
                          FROM bodb02.dbo.Customer c WITH (NOLOCK)
                          WHERE c.username = CONVERT(VARCHAR(30), f.value)) AS n
        WHERE f.value <> ''

        -- + Check input headline is headline or not
        UPDATE h
        SET h.ErrCode = 1
        FROM #tmpHeadlineOutput h 
             LEFT JOIN bodb02.dbo.CustGroupHeadline cgh WITH (NOLOCK) ON cgh.CustID = h.HeadlineId
        WHERE h.ErrCode = -1
              AND cgh.CustID IS NULL

        -- + Update value for valid headline
        UPDATE h
        SET h.ErrCode = n.ErrCode
        FROM #tmpHeadlineOutput h
             CROSS APPLY (SELECT TOP(1) 0 AS ErrCode
                          FROM bodb_CRM.dbo.crmConversationGroupHeadline             cgh WITH (NOLOCK)
                               INNER JOIN bodb_CRM.dbo.crmConversationGroup          cg  WITH (NOLOCK) ON cgh.ConversationGroupId = cg.ConversationGroupId
                               INNER JOIN bodb_CRM.dbo.crmConversationGroupRecipient cgr WITH (NOLOCK) ON cg.ConversationGroupId  = cgr.ConversationGroupId
                               INNER JOIN bodb_CRM.dbo.crmConversationGroupBot       cgb WITH (NOLOCK) ON cg.ConversationGroupId  = cgb.ConversationGroupId
                               LEFT JOIN  bodb_CRM.dbo.crmIgnoredNotificationType    ign WITH (NOLOCK) ON cg.ConversationGroupId  = ign.ConversationGroupId AND ign.NotificationTypeId = @NotificationTypeId
                          WHERE cgh.HeadlineId = h.HeadlineId
                                AND cg.IsActive = 1
                                AND ign.ConversationGroupId IS NULL) AS n
        WHERE h.ErrCode = -1

        -- + Update value for invalid headline
        UPDATE h
        SET h.ErrCode = CASE WHEN n.NotMapped           IS NULL     THEN 2 -- NotMapped
                             WHEN n.BotRemoved          IS NULL     THEN 3 -- BotRemoved
                             WHEN ISNULL(n.InActive,0)  = 0         THEN 4 -- InActive
                             WHEN n.IgnoredAnnouncement IS NOT NULL THEN 5 -- Ignored Headline
                        ELSE 0 END 
        FROM #tmpHeadlineOutput h
             OUTER APPLY (SELECT TOP(1) cg.ConversationGroupId        AS NotMapped,
                                        cgb.BotId                     AS BotRemoved,
                                        CONVERT(TINYINT, cg.IsActive) AS InActive,
                                        ign.ConversationGroupId       AS IgnoredAnnouncement
                          FROM bodb_CRM.dbo.crmConversationGroupHeadline             cgh WITH (NOLOCK)
                               INNER JOIN bodb_CRM.dbo.crmConversationGroup          cg  WITH (NOLOCK) ON cgh.ConversationGroupId = cg.ConversationGroupId
                               INNER JOIN bodb_CRM.dbo.crmConversationGroupRecipient cgr WITH (NOLOCK) ON cg.ConversationGroupId  = cgr.ConversationGroupId
                               INNER JOIN bodb_CRM.dbo.crmConversationGroupBot       cgb WITH (NOLOCK) ON cg.ConversationGroupId  = cgb.ConversationGroupId
                               LEFT JOIN  bodb_CRM.dbo.crmIgnoredNotificationType    ign WITH (NOLOCK) ON cg.ConversationGroupId  = ign.ConversationGroupId AND ign.NotificationTypeId = @NotificationTypeId
                          WHERE cgh.HeadlineId = h.HeadlineId
                                AND cg.IsDeleted = 0) AS n (NotMapped, BotRemoved, InActive, IgnoredAnnouncement)
        WHERE h.ErrCode = -1

        -- + Check exist invalid headline and return
        IF EXISTS (SELECT 1 FROM #tmpHeadlineOutput WHERE ErrCode > 0)
        BEGIN
            ;WITH CTE AS (
                SELECT h.ErrCode,
                       STRING_AGG(CONVERT(VARCHAR(MAX), h.HeadlineName), ',') HeadlineNameList
                FROM #tmpHeadlineOutput h
                WHERE h.ErrCode > 0
                GROUP BY h.ErrCode
            )
            SELECT @ErrCode = 100,
                   @ErrMsg  = ISNULL(@ErrMsg, '') + t.ErrMsg + ': ' + c.HeadlineNameList + ';'
            FROM CTE c
                 INNER JOIN #tmpErrorList t ON t.ErrCode = c.ErrCode
            ORDER BY t.ErrCode

            SELECT @ErrMsg = SUBSTRING(@ErrMsg, 1, LEN(@ErrMsg)-1)

            RETURN
        END
    END

    -- Validate data for Headline/DirectAccount from Site, Currency, Headline type
    ELSE 
    BEGIN
        -- + Get list of headline base on @SiteNameList and @CurrencyList
        INSERT INTO #tmpHeadlineInput (HeadlineId, HeadlineName)
        SELECT DISTINCT p.HeadlineID, cus.username HeadlineName
        FROM bodb_CRM.dbo.crmPicManagement p WITH (NOLOCK)
             INNER JOIN bodb02.dbo.Customer cus WITH (NOLOCK) ON p.HeadlineID = cus.custid
             CROSS APPLY (SELECT TOP 1 1 ID
                          FROM bodb02.dbo.Customer c WITH (NOLOCK)
                          WHERE c.custid = p.CustID
                                AND ',' + @SiteNameList + ',' LIKE '%,' + c.site + ',%' 
                                AND ',' + @CurrencyList + ',' LIKE '%,' + CONVERT(VARCHAR(4), c.currency) + ',%') AS c
        WHERE p.HeadlineID <> 0 --just mention to CustID have HeadlineID

        -- + Get suitable headline
        INSERT INTO #tmpHeadlineOutput (
            HeadlineId,
            HeadlineName,
            ErrCode
        )
        SELECT DISTINCT h.HeadlineId, h.HeadlineName, 0 ErrCode
        FROM #tmpHeadlineInput h
             INNER JOIN bodb_CRM.dbo.crmConversationGroupHeadline  cgh WITH(NOLOCK) ON h.HeadlineId            = cgh.HeadlineId
             INNER JOIN bodb_CRM.dbo.crmConversationGroup          cg  WITH(NOLOCK) ON cgh.ConversationGroupId = cg.ConversationGroupId
             INNER JOIN bodb_CRM.dbo.crmConversationGroupRecipient cgr WITH(NOLOCK) ON cg.ConversationGroupId  = cgr.ConversationGroupId
             INNER JOIN bodb_CRM.dbo.crmConversationGroupBot       cgb WITH(NOLOCK) ON cg.ConversationGroupId  = cgb.ConversationGroupId
             LEFT JOIN  bodb_CRM.dbo.crmIgnoredNotificationType    ign WITH(NOLOCK) ON cg.ConversationGroupId  = ign.ConversationGroupId AND ign.NotificationTypeId = @NotificationTypeId
        WHERE cg.IsActive = 1
              AND ign.NotificationTypeId IS NULL

        -- + IF @HeadlineType <> 2 | Just mention to headlince account only
        --                         | Not include direct account not assign group but have mapping to PIC
        IF (@HeadlineType <> 2)
        BEGIN
            DELETE h
            FROM #tmpHeadlineOutput h
                 LEFT JOIN bodb_CRM.dbo.crmCustomer c WITH (NOLOCK) ON c.CustID = h.HeadlineId
            WHERE ISNULL(c.IsVIP, 0) <> @HeadlineType
        END

        -- + IF @HeadlineType = 2 | Beside headline account
        --                        | Include direct account not assign group but have mapping to PIC
        ELSE 
        BEGIN
            -- + --> Insert data to table #tmpConversationGroupRecipient
            ;WITH CTE_Pic AS (
                SELECT p.CustID,
                       p.HeadlineID,
                       p.PicID
                FROM bodb_CRM.dbo.crmPicManagement p WITH (NOLOCK)
                     CROSS APPLY (SELECT TOP 1 1 AS Id
                                  FROM bodb02.dbo.Customer c WITH (NOLOCK)
                                  WHERE c.custid = p.CustID
                                        AND ',' + @SiteNameList + ',' LIKE '%,' + c.site + ',%'
                                        AND ',' + @CurrencyList + ',' LIKE '%,' + CONVERT(VARCHAR(4), c.currency) +  ',%') AS c
                WHERE p.HeadlineID = 0 --just mention to CustID not have HeadlineID
            )
            INSERT INTO #tmpDirectAccountInput (
                DirectAccId,
                ConversationGroupId,
                NoRecipient
            )
            SELECT p.CustID DirectAccId,
                   cgh.ConversationGroupId,
                   COUNT(DISTINCT cgr.RecipientId) AS NoRecipient
            FROM CTE_Pic p
                 INNER JOIN bodb_CRM.dbo.crmRecipient                  r   WITH(NOLOCK) ON p.PicID = r.SourceId AND r.DataSource = 'bodb_CRM.dbo.crmPIC'
                 INNER JOIN bodb_CRM.dbo.crmConversationGroupHeadline  cgh WITH(NOLOCK) ON p.HeadlineID = cgh.HeadlineId
                 INNER JOIN bodb_CRM.dbo.crmConversationGroup          cg  WITH(NOLOCK) ON cgh.ConversationGroupId = cg.ConversationGroupId
                 INNER JOIN bodb_CRM.dbo.crmConversationGroupRecipient cgr WITH(NOLOCK) ON cg.ConversationGroupId  = cgr.ConversationGroupId AND r.RecipientId = cgr.RecipientId
                 INNER JOIN bodb_CRM.dbo.crmConversationGroupBot       cgb WITH(NOLOCK) ON cg.ConversationGroupId  = cgb.ConversationGroupId
                 LEFT JOIN  bodb_CRM.dbo.crmIgnoredNotificationType    ign WITH(NOLOCK) ON cg.ConversationGroupId  = ign.ConversationGroupId AND ign.NotificationTypeId = @NotificationTypeId
            WHERE cg.IsActive = 1
                  AND ign.NotificationTypeId IS NULL
            GROUP BY p.CustID,
                     cgh.ConversationGroupId

            -- + --> Insert data to table #tmpDirectAccount
            ;WITH CTE_ConversationGroup AS (
                SELECT g.ConversationGroupId,
                       COUNT(RecipientId) TotalRecipient
                FROM bodb_CRM.dbo.crmConversationGroupRecipient g WITH (NOLOCK)
                WHERE EXISTS (SELECT 1 FROM #tmpDirectAccountInput r WHERE r.ConversationGroupId = g.ConversationGroupId)
                GROUP BY g.ConversationGroupId
            )
            INSERT INTO #tmpDirectAccountOutput (DirectAccId, DirectAccName, ConversationGroupId)
            SELECT gr.DirectAccId, cus.username DirectAccName, gr.ConversationGroupId
            FROM #tmpDirectAccountInput gr
                 INNER JOIN bodb02.dbo.Customer cus WITH (NOLOCK) ON gr.DirectAccId = cus.custid
                 INNER JOIN CTE_ConversationGroup g ON g.ConversationGroupId = gr.ConversationGroupId
                                                       AND g.TotalRecipient = gr.NoRecipient --pay more attention to this requirement

            -- + --> Insert one dummy row data to not return error at the next step
            IF EXISTS (SELECT 1 FROM #tmpDirectAccountOutput)
            BEGIN 
                INSERT INTO #tmpHeadlineOutput (HeadlineId, HeadlineName, ErrCode)
                VALUES (0, '', 0)
            END
        END

        -- + If not have data to create announcement will return error
        IF NOT EXISTS (SELECT 1 FROM #tmpHeadlineOutput)
        BEGIN
            SELECT @ErrCode = 102
            SELECT @ErrMsg = 'No Group Headline info'
            RETURN
        END
    END

    -- Validate data between Headline and Content
    BEGIN
        -- + Parse XML to temp table
        INSERT INTO #tmpValidateContentsInput (
            LanguageId,
            Content,
            FileName
        )
        SELECT t.c.value('@LanguageId', 'INT')         AS LanguageId,
               t.c.value('@Value', 'NVARCHAR(MAX)')    AS Content,
               t.c.value('@FileName', 'NVARCHAR(MAX)') AS FileName
        FROM @Contents.nodes('Contents/Content') AS t(c)

        -- + Process data to get result
        ;WITH
        CTE_Headline AS (
            SELECT DISTINCT
                   hl.HeadlineName,
                   cg.LanguageId,
                   s.SettingValue LanguageName
            FROM #tmpHeadlineOutput hl
                 INNER JOIN bodb_CRM.dbo.crmConversationGroupHeadline cgh WITH (NOLOCK) ON hl.HeadlineId = cgh.HeadlineId
                 INNER JOIN bodb_CRM.dbo.crmConversationGroup         cg  WITH (NOLOCK) ON cgh.ConversationGroupId = cg.ConversationGroupId
                 INNER JOIN bodb_CRM.dbo.crmSetting                   s   WITH (NOLOCK) ON s.SettingName = 'NotificationTemplateLanguage'
                                                                                           AND s.IsActive = 1
                                                                                           AND s.SiteOffer = 2
                                                                                           AND cg.LanguageId = s.SettingID
                 LEFT JOIN  bodb_CRM.dbo.crmIgnoredNotificationType   ign WITH(NOLOCK) ON cg.ConversationGroupId  = ign.ConversationGroupId AND ign.NotificationTypeId = @NotificationTypeId
            WHERE hl.HeadlineId <> 0
                  AND hl.ErrCode = 0
                  AND cg.IsActive = 1
                  AND ign.ConversationGroupId IS NULL
        ),
        CTE_DirectAccount AS (
            SELECT DISTINCT
                   da.DirectAccName HeadlineName,
                   cg.LanguageId,
                   s.SettingValue LanguageName
            FROM #tmpDirectAccountOutput da
                 INNER JOIN bodb_CRM.dbo.crmConversationGroup       cg  WITH (NOLOCK) ON da.ConversationGroupId = cg.ConversationGroupId
                 INNER JOIN bodb_CRM.dbo.crmSetting                 s   WITH (NOLOCK) ON s.SettingName = 'NotificationTemplateLanguage'
                                                                                         AND s.IsActive = 1
                                                                                         AND s.SiteOffer = 2
                                                                                         AND cg.LanguageId = s.SettingID
                 LEFT JOIN  bodb_CRM.dbo.crmIgnoredNotificationType ign WITH(NOLOCK) ON cg.ConversationGroupId  = ign.ConversationGroupId AND ign.NotificationTypeId = @NotificationTypeId
            WHERE cg.IsActive = 1
                  AND ign.ConversationGroupId IS NULL
        ),
        CTE_Union AS (
            SELECT HeadlineName, LanguageId, LanguageName FROM CTE_Headline
            UNION
            SELECT HeadlineName, LanguageId, LanguageName FROM CTE_DirectAccount
        )
        INSERT INTO #tmpValidateContentsOutput (
            HeadlineName,
            LanguageId,
            LanguageName,
            Content,
            FileName
        )
        SELECT cte.HeadlineName,
               cte.LanguageId,
               cte.LanguageName,
               tmp.Content,
               tmp.FileName
        FROM CTE_Union cte
             LEFT JOIN #tmpValidateContentsInput tmp ON cte.LanguageId = tmp.LanguageId
        WHERE ISNULL(tmp.Content, '') = '' AND ISNULL(FileName, '') = ''

        -- + Return error if exist
        IF EXISTS (SELECT TOP 1 1 FROM #tmpValidateContentsOutput)
        BEGIN
            ;WITH CTE_Data AS (
                SELECT LanguageName,
                       STRING_AGG(CAST(HeadlineName AS VARCHAR(MAX)), ',') HeadlineNameList
                FROM #tmpValidateContentsOutput
                GROUP BY LanguageName
            )
            SELECT @ErrCode = 104,
                   @ErrMsg = ISNULL(@ErrMsg, '') + 'Please input the ' + LanguageName + ' content for headline(s): ' + HeadlineNameList + ';'
            FROM CTE_Data
            ORDER BY LanguageName
        
            SELECT @ErrMsg = SUBSTRING(@ErrMsg, 1, LEN(@ErrMsg)-1)
            
            RETURN
        END
    END


    -----------------
    -- Return data --

    -- Build data for variable @HeadlineNameList
    ;WITH CTE_HeadlineName AS (
        SELECT DISTINCT HeadlineName FROM #tmpHeadlineOutput WHERE HeadlineId <> 0
    )
    SELECT @HeadlineNameList = STRING_AGG(CAST(HeadlineName AS VARCHAR(MAX)), ',')
    FROM CTE_HeadlineName

    -- Build data for variable @DirectAccountNameList
    ;WITH CTE_DirectAccName AS (
        SELECT DISTINCT DirectAccName FROM #tmpDirectAccountOutput
    )
    SELECT @DirectAccountNameList = STRING_AGG(CAST(DirectAccName AS VARCHAR(MAX)), ',')
    FROM CTE_DirectAccName

    -- Return result
    SELECT @HeadlineNameList      AS HeadlineNameList,
           @DirectAccountNameList AS DirectAccountList


    ---------------
    -- Drop data --

    DROP TABLE #tmpHeadlineInput
    DROP TABLE #tmpHeadlineOutput
    DROP TABLE #tmpDirectAccountInput
    DROP TABLE #tmpDirectAccountOutput
    DROP TABLE #tmpValidateContentsInput
    DROP TABLE #tmpValidateContentsOutput
    DROP TABLE #tmpErrorList

END
GO