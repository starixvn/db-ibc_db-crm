/*<info serverAlias="DBCRM-bodb_CRM" executers="wsv_nap" isFunction="0" isNested="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE dbo.Acc_CRM_Chatbot_AbnormalBets_Import @XmlData XML,
                                                        @MAXVoidingHistoryCollectionId INT,
                                                        @MAXMsgTargetId                INT,
                                                        @Environment                   VARCHAR(50)    = '',
                                                        @ErrCode                       INT            = 0  OUTPUT,
                                                        @ErrMsg                        NVARCHAR(4000) = '' OUTPUT
AS

/*
    Created: 20200811@Percy
    DB: DBCRM-bodb_CRM
    Task: CRM - ChatBot - Import Notification

    Revisions:
        - 20200811@Percy: Initialize SP [RedmineID: #130544]
        - 20201116@Malcolm: Change the MessageID column to the ReferenceId column [RedmineID: #144265]
        - 20210728@Malcolm: Get notification template for abnormal bets [RedmineID: #157303]
        - 20210729@Malcolm: Integrate Abnormal Accounts [RedmineId : #157303]
        - 20211125@Malcolm: Add Comment [RedmineId : #163833]
        - 20220112@Malcolm: Update job status = 'Completed' when job runs longer than 5 minutes [RedmineID: #167358]
        - 20230112@Malcolm: Scale out for CRM [RedmineID: #167358]
        - 20230330@Ned.Le: CRM - Enhance for Displaying Relevant MessageIDs [RedmineId : #186119]
        - 20230508@Malcolm: Offer Telegram bot service for Headlines [RedmineId : #179119]
        - 20231110@Ned.Le: CRM - Auto generate Feedback and send Headline Notification for voiding Abnormal Bets by Void By BetID [RedmineId : #196660]
        - 20231218@Ned.Le: CRM - Auto generate Feedback and Headline Notification were created and sent for non-today matches [HotFix : #198492]
        - 20240823@Ned.Le: CRM - Void by BetID - Support Auto FB and notificaitons for voiding Parlay Ticket of Sportsbook [RedmineId : #209707]

    Param's Explanation:
        - @XmlData
            + Data
                <root>
                    <r VoidingHistoryCollectionId="1" MessageId="1" UsernameList="XXX" CustId="114" Recommend="113" Mrecommend="112" Srecommend="111" IsTest="0" Content_en="" Content_cs="" Content_th="" Content_vn="" Type="1"/>
                    <r VoidingHistoryCollectionId="2" MessageId="2" UsernameList="XYZ" CustId="115" Recommend="113" Mrecommend="112" Srecommend="111" IsTest="0" Content_en="" Content_cs="" Content_th="" Content_vn="" Type="2"/>
                </root>
            + Description
                * Type = 1: get member of tickets belong to abnormal bets
                         2: Get direct account of tickets belong to abnormal accounts, IsTest : MIN(IsTest) of member have tickets voided
                         3: get member of tickets belong to abnormal bets (mix parlay)
*/

BEGIN

    SET NOCOUNT ON


    ---------------------------
    -- [01] Global variables --

    DECLARE @ServiceName                             VARCHAR(50) = 'ChatBot - AbnormalBets'

    DECLARE @SettingNameOfLastRuntime                VARCHAR(50)
    SELECT  @SettingNameOfLastRuntime                = CASE WHEN @Environment = 'UAT' THEN 'LastRuntimeUAT' ELSE 'LastRuntime' END
    DECLARE @LastRuntime                             DATETIME
    SELECT  @LastRuntime                             = CONVERT(DATETIME, Value) FROM bodb_CRM.dbo.SystemSetting WITH (NOLOCK) WHERE SettingName = @SettingNameOfLastRuntime AND ServiceName = @ServiceName

    DECLARE @SettingNameOfJobStatus                  VARCHAR(50)
    SELECT  @SettingNameOfJobStatus                  = CASE WHEN @Environment = 'UAT' THEN 'JobStatusUAT' ELSE 'JobStatus' END

    DECLARE @SettingNameOfMsgTargetId                VARCHAR(50)
    SELECT  @SettingNameOfMsgTargetId                = CASE WHEN @Environment = 'UAT' THEN 'LastMsgTargetIdUAT' ELSE 'LastMsgTargetId' END

    DECLARE @SettingNameOfVoidingHistoryCollectionId VARCHAR(50)
    SELECT  @SettingNameOfVoidingHistoryCollectionId = CASE WHEN @Environment = 'UAT' THEN 'LastVoidingHistoryCollectionIdUAT' ELSE 'LastVoidingHistoryCollectionId' END


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
        VoidingHistoryCollectionId INT,
        MessageId                  INT,
        Username                   VARCHAR(50),
        CustId                     INT,
        Recommend                  INT,
        Mrecommend                 INT,
        Srecommend                 INT,
        IsTest                     BIT,
        Content_en                 NVARCHAR(4000),
        Content_cs                 NVARCHAR(4000),
        Content_th                 NVARCHAR(4000),
        Content_vn                 NVARCHAR(4000),
        [Type]                     TINYINT
    )
    INSERT INTO #tmpXMLData (
        VoidingHistoryCollectionId,
        MessageId,
        Username,
        CustId,
        Recommend,
        Mrecommend,
        Srecommend,
        IsTest,
        Content_en,
        Content_cs,
        Content_th,
        Content_vn,
        [Type]
    )
    SELECT
        t.c.value('@VoidingHistoryCollectionId', 'INT')            AS VoidingHistoryCollectionId,
        t.c.value('@MessageId',                  'INT')            AS MessageId,
        ISNULL(l.Username, '')                                     AS Username,
        t.c.value('@CustId',                     'INT')            AS CustId,
        t.c.value('@Recommend',                  'INT')            AS Recommend,
        t.c.value('@Mrecommend',                 'INT')            AS Mrecommend,
        t.c.value('@Srecommend',                 'INT')            AS Srecommend,
        t.c.value('@IsTest',                     'BIT')            AS IsTest,
        t.c.value('@Content_en',                 'NVARCHAR(4000)') AS Content_en,
        t.c.value('@Content_cs',                 'NVARCHAR(4000)') AS Content_cs,
        t.c.value('@Content_th',                 'NVARCHAR(4000)') AS Content_th,
        t.c.value('@Content_vn',                 'NVARCHAR(4000)') AS Content_vn,
        t.c.value('@Type',                       'TINYINT')        AS [Type]
    FROM @XmlData.nodes('root/r') t(c)
         OUTER APPLY (SELECT f.value AS Username
                      FROM STRING_SPLIT(t.c.value('@UsernameList', 'NVARCHAR(MAX)'), ',') f WHERE f.value <> '') l(Username)
    OPTION (OPTIMIZE FOR (@XmlData = NULL))

    -- If nothing happened, need to update setting and return
    IF (@@ROWCOUNT = 0)
    BEGIN

        IF (ISNULL(@MAXVoidingHistoryCollectionId, 0) > 0)
        BEGIN
            UPDATE s
            SET s.Value = CONVERT(VARCHAR(50), @MAXVoidingHistoryCollectionId)
            FROM bodb_CRM.dbo.SystemSetting s WITH(ROWLOCK, UPDLOCK)
            WHERE s.ServiceName = @ServiceName
                  AND s.SettingName = @SettingNameOfVoidingHistoryCollectionId
        END

        IF (ISNULL(@MAXMsgTargetId, 0) > 0)
        BEGIN
            UPDATE s
            SET s.Value = CONVERT(VARCHAR(50), @MAXMsgTargetId)
            FROM bodb_CRM.dbo.SystemSetting s WITH(ROWLOCK, UPDLOCK)
            WHERE s.ServiceName = @ServiceName
                  AND s.SettingName = @SettingNameOfMsgTargetId
        END

        BEGIN
            UPDATE s
            SET s.Value = 'Completed'
            FROM bodb_CRM.dbo.SystemSetting s WITH(ROWLOCK, UPDLOCK)
            WHERE s.ServiceName = @ServiceName
                  AND s.SettingName = @SettingNameOfJobStatus
                  AND s.Value = 'Running'
        END

        RETURN
    END


    ------------------------------------------------------------------------------------------------------------------------------
    -- [03] Get Notification Template Data                                                                                      --
    --      _ Each Notification has its own Template                                                                            --
    --      _ Notification Template exists on tables crmNotificationType|crmNotificationTemplate|crmNotificationTemplateContent --
    --      _ Notification Service will have setting that indicates which Template belong to                                    --
    ------------------------------------------------------------------------------------------------------------------------------

    -- Get template setting | Get setting that indicate Notification Service will use which Notification Template
    --                      | Columns explanation
    --                      | + IsTest: Mot template ma IsTest=1 thi co nghia la nhung notification duoc tao ra se mark Status='Draft'
    --                      |           Tuc la template nay dang o giai doan test va muc dich la chi muon xem no tao ra dung hay khong
    --                      |           Sau khi test thay ok thi moi bat lai co IsTest=0 de dung tren thuc te
    --                      | + LanguageId: Gia tri nay duoc su dung de check nguoc lai voi data o bang vat ly
    --                      |               Nham dam bao viec tao setting la chinh xac va khong gay ra loi
    --                      | + TemplateRequiredParam: Tuong tu nhu tren gia tri nay cung dung voi muc dich kiem tra cheo chong loi
    --                      | + [Type]: Gia tri nay duoc su dung de mapping voi du loi parse ra tu XML de tao notification
    -- + Create and get data for variable
    DECLARE @NotificationTemplateSetting XML
    SELECT  @NotificationTemplateSetting = CONVERT(XML, Value) FROM bodb_CRM.dbo.SystemSetting WITH (NOLOCK) WHERE ServiceName = @ServiceName AND SettingName = 'NotificationTemplate'
    -- + Create temp table
    CREATE TABLE #tmpNotificationTemplateSetting (
        NotificationTemplateId SMALLINT,
        NotificationTypeId     SMALLINT,
        IsTest                 BIT,
        LanguageId             INT,
        TemplateRequiredParam  NVARCHAR(MAX),
        [Type]                 TINYINT
    )
    -- + Gen data to temp table
    INSERT INTO #tmpNotificationTemplateSetting (
        NotificationTemplateId,
        NotificationTypeId,
        IsTest,
        LanguageId,
        TemplateRequiredParam,
        [Type]
    )
    SELECT p.n.value('@NotificationTemplateID', 'SMALLINT')      AS NotificationTemplateId,
           p.n.value('@NotificationTypeID',     'SMALLINT')      AS NotificationTypeId,
           c.n.value('@IsTest',                 'BIT')           AS IsTest,
           c.n.value('@LanguageId',             'INT')           AS LanguageId,
           c.n.value('@Value',                  'NVARCHAR(MAX)') AS TemplateRequiredParam,
           p.n.value('@Type',                   'TINYINT')       AS [Type]
    FROM @NotificationTemplateSetting.nodes('root/r') p(n)
         CROSS APPLY p.n.nodes('TemplateRequiredParam') c(n)
    -- + If no have data means error
    IF (@@ROWCOUNT = 0)
    BEGIN
        SELECT @ErrCode = 101
        SELECT @ErrMsg = 'Server Name : ' + @ServerName + ' - Database Name : ' + @DBName + ' - SP Name : '+ @SPName + ' - Error Message : ' + @ServiceName + ' - Invalid SystemSetting!'
        
        UPDATE s
        SET s.Value = 'Completed'
        FROM bodb_CRM.dbo.SystemSetting s WITH (ROWLOCK)
        WHERE s.ServiceName = @ServiceName
              AND s.SettingName = @SettingNameOfJobStatus
              AND s.Value = 'Running'

        RETURN
    END

    -- Get template data
    -- + Create temp table
    CREATE TABLE #tmpNotificationTemplateData (
        NotificationTypeId     SMALLINT,
        NotificationTemplateId SMALLINT,
        Title                  NVARCHAR(2000),
        IsTest                 BIT,
        LanguageId             INT,
        Content                NVARCHAR(MAX),
        [Type]                 TINYINT
    )
    -- + Gen data to temp table | Du tren gia tri setting ta mapping voi cac bang vat ly de lay len data can dung
    ;WITH CTE_Setting AS (
        SELECT DISTINCT
               NotificationTemplateId,
               NotificationTypeId,
               IsTest,
               [Type]
        FROM #tmpNotificationTemplateSetting
    )
    INSERT INTO #tmpNotificationTemplateData (
        NotificationTypeId,
        NotificationTemplateId,
        Title,
        IsTest,
        LanguageId,
        Content,
        [Type]
    )
    SELECT s.NotificationTypeId      NotificationTypeId,
           nt.NotificationTemplateId NotificationTemplateId,
           nt.Title                  Title,
           s.IsTest                  IsTest,
           ntc.LanguageId            LanguageId,
           ntc.Content               Content,
           s.[Type]                  [Type]
    FROM CTE_Setting s
         INNER JOIN bodb_CRM.dbo.crmNotificationTemplate nt WITH (NOLOCK) ON s.NotificationTemplateId = nt.NotificationTemplateId
         INNER JOIN bodb_CRM.dbo.crmNotificationTemplateContent ntc WITH (NOLOCK) ON nt.NotificationTemplateId = ntc.NotificationTemplateId

    -- Check require param | Day la buoc check cheo data quan trong nham dam bao tinh chinh xac cua du lieu
    IF EXISTS (
        SELECT 1
        FROM #tmpNotificationTemplateSetting st
             INNER JOIN #tmpNotificationTemplateData nt ON st.NotificationTemplateId = nt.NotificationTemplateId
                                                           AND st.NotificationTypeId = nt.NotificationTypeId
                                                           AND st.LanguageId         = nt.LanguageId
        WHERE nt.Content NOT LIKE N'%' + st.TemplateRequiredParam + N'%'
    )
    BEGIN
        SELECT @ErrCode = 102
        SELECT @ErrMsg  = 'Server Name : ' + @ServerName + ' - Database Name : ' + @DBName + ' - SP Name : '+ @SPName + ' - Error Message : ' + @ServiceName + ' - Notification Template Content(s) are not include Required Param(s)'
        
        UPDATE s
        SET s.Value = 'Completed'
        FROM bodb_CRM.dbo.SystemSetting s WITH (ROWLOCK)
        WHERE s.ServiceName = @ServiceName
              AND s.SettingName = @SettingNameOfJobStatus
              AND s.Value = 'Running'

        RETURN
    END

    -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    -- [04] Get Notification Recipient Data                                                                                                                                            --
    --      _ Base on source data we will known exactly affected SMA and Member and from that we know Direct Account and from that we know Recipient (PIC)                             --
    --        + Mot Direct Account chi thuoc mot Headline duy nhat                                                                                                                     --
    --        + Mot Recipient (PIC) co the thuoc nhieu Direct Account khac nhau va tat nhien se thuoc nhieu Headline khac nhau                                                         --
    --        + Mot Headline se co rat nhieu Direct Account khac nhau nhung thuong chi co mot vai PIC (kieu nhu mot dang thu ky cua Headline) hay cung co the PIC la chinh Headline    --
    --      _ We need to do one more thing here, for group chat, to sure that number of recipient in group at database is the same with number of recipient in group when process data --
    --        + Thong tin giai thich cu the cho phan nay o ben duoi                                                                                                                    --
    -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

    -- Get detail message info | Notes
    --                         | + From source data we have SMA and Member
    --                         | + From SMA and Member we know Direct Account (from table CustDirectAccount)
    --                         | + From Direct Account we know Headline and PIC (from table crmPicManagement)
    --                         | Columns explanation
    --                         | + RecipientId: Ve co ban cac cot con lai deu lay tu XML data hoac tu cac bang vat ly nhung khong gay ra duplicate data
    --                         |                Rieng cot nay se co the lam data tang len nhieu dong
    --                         |                Vi nhu ta da biet la mot Direct Account co the co nhieu Recipient (PIC)
    --                         |                Nhom table lien quan den ConverstionGroup chi su dung gia tri RecipientId chu ko dung PicID
    -- + Create temp table
    CREATE TABLE #tmpNotificationMessageInfo (
        VoidingHistoryCollectionId INT,
        MessageId                  INT,
        Supername                  VARCHAR(50),
        Username                   VARCHAR(50),
        DirectAccount              INT,
        HeadlineId                 INT,
        IsTest                     BIT,
        Content_en                 NVARCHAR(4000),
        Content_cs                 NVARCHAR(4000),
        Content_th                 NVARCHAR(4000),
        Content_vn                 NVARCHAR(4000),
        RecipientId                INT
    )
    -- + Gen data to temp table
    INSERT INTO #tmpNotificationMessageInfo (
        VoidingHistoryCollectionId,
        MessageId,
        Supername,
        Username,
        DirectAccount,
        HeadlineId,
        IsTest,
        Content_en,
        Content_cs,
        Content_th,
        Content_vn,
        RecipientId
    )
    SELECT m.VoidingHistoryCollectionId VoidingHistoryCollectionId,
           m.MessageId                  MessageId,
           sup.username                 Supername,
           m.Username                   Username,
           pm.CustId                    DirectAccount,
           pm.HeadlineId                HeadlineId,
           m.IsTest                     IsTest,
           m.Content_en                 Content_en,
           m.Content_cs                 Content_cs,
           m.Content_th                 Content_th,
           m.Content_vn                 Content_vn,
           r.RecipientId                RecipientId
    FROM #tmpXMLData m
         INNER JOIN bodb02.dbo.Customer mem WITH (NOLOCK) ON m.Username = mem.username
         INNER JOIN bodb02.dbo.Customer sup WITH (NOLOCK) ON mem.srecommend = sup.custid AND sup.roleid = 4
         INNER JOIN bodb02.dbo.CustDirectAccount cda WITH (NOLOCK) ON cda.CustId IN (m.CustId, m.Recommend, m.Mrecommend, m.Srecommend)
         INNER JOIN bodb_CRM.dbo.crmPicManagement pm WITH (NOLOCK) ON cda.CustId = pm.CustId
         INNER JOIN bodb_CRM.dbo.crmRecipient r WITH (NOLOCK) ON pm.PicId = r.SourceId AND r.DataSource = 'bodb_CRM.dbo.crmPIC'
    
    -- Get detail group chat info | Notes
    --                            | + From RecipientId we know ConversationGroupId belong to (from table crmConversationGroupRecipient)
    --                            | + We also need to consistent data when INNER JOIN with two table crmConversationGroupHeadline|crmConversationGroup
    --                            | Columns explanation
    --                            | + ConversationGroupId: Mot ConversationGroupID hay cung chinh la mot tai khoan (Personal) hay mot group Letstalk/Telegram (Group)
    --                            | + DirectAccount: Mot ConversationGroupId neu la Personal co the map voi nhieu Direct Account
    --                            |                  Vi ly do nay ma ta can gom nhom theo ConversationGroupID|DirectAccount khi tinh toan NoRecipient
    --                            | + NoRecipient: Mot ConversationGroupId neu la Personal (ChatTypeId=2) se chi map voi mot RecipientId (PicID)
    --                            |                Mot ConversationGroupID neu la Group (ChatTypeId=1) co the map voi nhieu RecipientId (PicID)
    -- + Create temp table
    CREATE TABLE #tmpNotificationGroupChatInfo (
        VoidingHistoryCollectionId INT,
        ConversationGroupId        SMALLINT,
        ChannelId                  TINYINT,
        ChatTypeId                 TINYINT,
        LanguageId                 INT,
        DirectAccount              INT,
        NoRecipient                INT
    )
    -- + Gen data to temp table
    INSERT INTO #tmpNotificationGroupChatInfo (
        VoidingHistoryCollectionId,
        ConversationGroupId,
        DirectAccount,
        NoRecipient
    )
    SELECT m.VoidingHistoryCollectionId  VoidingHistoryCollectionId,
           cgr.ConversationGroupId       ConversationGroupId,
           m.DirectAccount               DirectAccount,
           COUNT(DISTINCT m.RecipientId) NoRecipient
    FROM #tmpNotificationMessageInfo m
         INNER JOIN bodb_CRM.dbo.crmConversationGroupRecipient cgr WITH (NOLOCK) ON m.RecipientId = cgr.RecipientId
         INNER JOIN bodb_CRM.dbo.crmConversationGroupHeadline cgh WITH (NOLOCK) ON m.HeadlineId = cgh.HeadlineId AND cgr.ConversationGroupId = cgh.ConversationGroupId
         INNER JOIN bodb_CRM.dbo.crmConversationGroup cg WITH (NOLOCK) ON cgr.ConversationGroupId = cg.ConversationGroupId
    WHERE cg.IsActive = 1
    GROUP BY m.VoidingHistoryCollectionId,
             cgr.ConversationGroupId,
             m.DirectAccount

    -- Cross Check data | Notes
    --                  | + Viec cross check data o day chi co y nghia cho ConversationGroup dang Group (ChatType=1)
    --                  | + Muc dich chinh la nham dam bao data cho Chattype Mapping giua DirectAccount voi PIC
    --                  |   La khop voi data cho ConversationGroup giua ConversationGroupID voi RecipientId (PIC)
    --                  | How to check
    --                  | + Tu bang crmConversationGroupRecipient ta se biet chinh xac la mot ConversationGroupId dang Group duoc mapping voi bao nhieu RecipientId
    --                  |   Tuc la mot group Letstalk/Telegram se bao gom bao nhieu account (Recipient hay cung la PIC) trong do
    --                  |   Ta goi la Dataset01
    --                  | + Con qua trinh xao nau data de do vao bang tam #tmpNotificationGroupChatInfo
    --                  |   Ta biet chinh xac la mot DirectAccount dang di voi bao nhieu RecipientId (PIC)
    --                  |   Ta goi la Dataset02
    --                  | + Ve nguyen tac hai gia tri nay phai bang nhau
    --                  |   Nhung trong mot so truong hop tap Dataset01 nho hon Dataset02
    --                  |   Tuc la mot RecipientId khong con di voi DirectAccount nua nhung van con nam trong group ConversationGroupId
    --                  |   Va ta can stop ko gui thong tin vao group ConversationGroupId nay de ko bi lo thong tin
    ;WITH
    CTE_Group AS (
        SELECT DISTINCT
               ConversationGroupId
        FROM #tmpNotificationGroupChatInfo
    ),
    CTE_GroupPIC AS(
        SELECT ConversationGroupId,
               COUNT(1) NoRecipient
        FROM bodb_CRM.dbo.crmConversationGroupRecipient cgr WITH (NOLOCK)
        WHERE EXISTS (SELECT 1 FROM CTE_Group g WHERE g.ConversationGroupId = cgr.ConversationGroupId)
        GROUP BY ConversationGroupId
    )
    DELETE t
    FROM #tmpNotificationGroupChatInfo t
         INNER JOIN CTE_GroupPIC g ON t.ConversationGroupId = g.ConversationGroupId
    WHERE t.NoRecipient < g.NoRecipient

    -- Update columns that still be NULL
    UPDATE t
    SET t.ChatTypeId = cg.ChatTypeId,
        t.LanguageId = cg.LanguageId,
        t.ChannelId  = cg.ChannelId
    FROM #tmpNotificationGroupChatInfo t
         INNER JOIN bodb_CRM.dbo.crmConversationGroup cg WITH (NOLOCK) ON t.ConversationGroupId = cg.ConversationGroupId


    -----------------------------------------------------------------------------------------------------------------------
    -- [05] Get Notification Final Data                                                                                  -- 
    --      _ We have data of Group (ChatTypeId=1) and data of Personal (ChatTypeId=2)                                   --
    --      _ So if one Headline belong to Group we ko need send notification to Personal to prevent duplicate send data --
    --      _ The way to group data here quite complicated and need to understand clearly                                --
    -----------------------------------------------------------------------------------------------------------------------

    -- Declare variables
    -- + Because of the maximum character in message of Letstalk/Telegram
    --   So we need to limit info about affected list will appear on message
    DECLARE @MaxBatchOfLetstalkGroup INT = 250
    DECLARE @MaxBatchOfTelegramGroup INT = 100
    -- + For test Template status of Notification must be Draft
    DECLARE @Status VARCHAR(20) = 'Planned'
    IF EXISTS (SELECT 1 FROM #tmpNotificationTemplateData WHERE IsTest = 1) SET @Status = 'Draft'

    -- Get prepare data | O day ta lam hai viec
    --                  | + Dau tien la lay len nhung thong tin can thiet de tao notification
    --                  | + Thu hai la chia data thanh tung batch theo so luong username de dam bao ko bi qua tai so luong ky tu khi tao notification
    -- + Create temp table
    CREATE TABLE #tmpNotificationPrepareData (
        VoidingHistoryCollectionId INT,
        ConversationGroupId        SMALLINT,
        ChannelId                  TINYINT,
        ChatTypeId                 TINYINT,
        LanguageId                 INT,
        Supername                  VARCHAR(50),
        Username                   VARCHAR(50),
        HeadlineId                 INT,
        IsTest                     BIT,
        MessageId                  INT,
        BatchOfGroup               INT
    )
    -- + Gen data to temp table
    INSERT INTO #tmpNotificationPrepareData (
        VoidingHistoryCollectionId,
        ConversationGroupId,
        ChannelId,
        ChatTypeId,
        LanguageId,
        Supername,
        Username,
        HeadlineId,
        IsTest,
        MessageId,
        BatchOfGroup
    )
    SELECT m.VoidingHistoryCollectionId,
           g.ConversationGroupId,
           g.ChannelId,
           g.ChatTypeId,
           g.LanguageId,
           m.Supername,
           m.Username,
           m.HeadlineId,
           m.IsTest,
           m.MessageId,
           (
               (DENSE_RANK() OVER(PARTITION BY m.VoidingHistoryCollectionId,
                                               g.ConversationGroupId
                                  ORDER BY m.Username ASC) - 1)
                /
                (CASE WHEN g.ChannelId = 1 THEN @MaxBatchOfLetstalkGroup
                      WHEN g.ChannelId = 2 THEN @MaxBatchOfTelegramGroup
                      ELSE 1 END)
            ) BatchOfGroup
    FROM #tmpNotificationMessageInfo m
         INNER JOIN #tmpNotificationGroupChatInfo g ON m.VoidingHistoryCollectionId = g.VoidingHistoryCollectionId AND m.DirectAccount = g.DirectAccount
         INNER JOIN bodb_CRM.dbo.crmConversationGroupRecipient cgr WITH (NOLOCK) ON m.RecipientId = cgr.RecipientId AND g.ConversationGroupId = cgr.ConversationGroupId
         INNER JOIN bodb_CRM.dbo.crmConversationGroupHeadline cgh WITH (NOLOCK) ON m.HeadlineId = cgh.HeadlineId AND g.ConversationGroupId = cgh.ConversationGroupId

    -- Get final data | Ta tach
    -- + Create temp table
    CREATE TABLE #tmpNotificationFinalData (
        Id                         INT IDENTITY(1, 1),
        VoidingHistoryCollectionId INT,
        Content_en                 NVARCHAR(4000),
        Content_cs                 NVARCHAR(4000),
        Content_th                 NVARCHAR(4000),
        Content_vn                 NVARCHAR(4000),
        ConversationGroupId        SMALLINT,
        ChannelId                  TINYINT,
        ChatTypeId                 TINYINT,
        LanguageId                 INT,
        AffectedList               VARCHAR(MAX),
        HeadlineList               VARCHAR(MAX),
        IsTest                     BIT,
        Status                     VARCHAR(20),
        RelatedIds                 VARCHAR(1000),
        [Type]                     TINYINT,
        MessageIdList              VARCHAR(MAX)
    )
    -- + Gen data to temp table for Group (ChatTypeId=1) | Ta can gom data thanh tung level
    --                                                   | + Khi viet code theo kieu nay thi code se dai hon
    --                                                   | + Nhung bu lai thi code se tuong minh va de hieu hon
    --                                                   | Rat kho de mo ta tai sao phai code gom data nhu ben duoi
    --                                                   | + Cach tot nhat de hieu la hieu ro ban chat cua data
    --                                                   | + Cung nhu loi data ra debug de co cai nhin thuc te
    ;WITH
    CTE_AggregateData_Level1_Username AS (
        SELECT VoidingHistoryCollectionId,
               ConversationGroupId,
               ChannelId,
               ChatTypeId,
               LanguageId,
               HeadlineId,
               IsTest,
               MessageId,
               BatchOfGroup,
               Supername,
               STRING_AGG(CAST(Username AS VARCHAR(MAX)), ', ') UsernameList
        FROM #tmpNotificationPrepareData
        WHERE ChatTypeId = 1
        GROUP BY VoidingHistoryCollectionId,
                 ConversationGroupId,
                 ChannelId,
                 ChatTypeId,
                 LanguageId,
                 HeadlineId,
                 IsTest,
                 MessageId,
                 BatchOfGroup,
                 Supername
    ),
    CTE_AggregateData_Level2_Supername AS (
        SELECT VoidingHistoryCollectionId,
               ConversationGroupId,
               ChannelId,
               ChatTypeId,
               LanguageId,
               HeadlineId,
               IsTest,
               MessageId,
               BatchOfGroup,
               STRING_AGG(CAST(('- ' + Supername + ': ' + UsernameList) AS VARCHAR(MAX)), '<br/>') AffectedList
        FROM CTE_AggregateData_Level1_Username
        GROUP BY VoidingHistoryCollectionId,
                 ConversationGroupId,
                 ChannelId,
                 ChatTypeId,
                 LanguageId,
                 HeadlineId,
                 IsTest,
                 MessageId,
                 BatchOfGroup
    ),
    CTE_AggregateData_Level3_HeadlineIdAffectedList AS (
        SELECT VoidingHistoryCollectionId                              VoidingHistoryCollectionId,
               ConversationGroupId                                     ConversationGroupId,
               ChannelId                                               ChannelId,
               ChatTypeId                                              ChatTypeId,
               LanguageId                                              LanguageId,
               STRING_AGG(CAST(HeadlineId   AS VARCHAR(MAX)), ',')     HeadlineList,
               IsTest                                                  IsTest,
               MessageId                                               MessageId,
               BatchOfGroup                                            BatchOfGroup,
               STRING_AGG(CAST(AffectedList AS VARCHAR(MAX)), '<br/>') AffectedList
        FROM CTE_AggregateData_Level2_Supername
        GROUP BY VoidingHistoryCollectionId,
                 ConversationGroupId,
                 ChannelId,
                 ChatTypeId,
                 LanguageId,
                 IsTest,
                 MessageId,
                 BatchOfGroup
    )
    INSERT INTO #tmpNotificationFinalData (
        VoidingHistoryCollectionId,
        ConversationGroupId,
        ChannelId,
        ChatTypeId,
        LanguageId,
        AffectedList,
        HeadlineList,
        IsTest,
        Status,
        MessageIdList
    )
    SELECT VoidingHistoryCollectionId                              VoidingHistoryCollectionId,
           ConversationGroupId                                     ConversationGroupId,
           ChannelId                                               ChannelId,
           ChatTypeId                                              ChatTypeId,
           LanguageId                                              LanguageId,
           STRING_AGG(CAST(AffectedList AS VARCHAR(MAX)), '<br/>') AffectedList,
           STRING_AGG(CAST(HeadlineList   AS VARCHAR(MAX)), ',')   HeadlineList,
           MIN(CONVERT(TINYINT, IsTest))                           IsTest,
           @Status                                                 Status,
           STRING_AGG(CAST(MessageId    AS VARCHAR(MAX)), ',')     MessageIdList
    FROM CTE_AggregateData_Level3_HeadlineIdAffectedList
    GROUP BY VoidingHistoryCollectionId,
             ConversationGroupId,
             ChannelId,
             ChatTypeId,
             LanguageId,
             BatchOfGroup
    -- + Gen data to temp table for Personal (ChatTypeId=2) | Doan code nay se chi can 2 level gom data vi la Personal se don gian hon Group
    --                                                      | Nhung bug lai doan code giup detect ra data Personal da co trong Group hay chua lai lam kha phuc tap
    ;WITH
    CTE_tmpDetail AS (
        SELECT p.VoidingHistoryCollectionId,
               p.ConversationGroupId,
               p.ChannelId,
               p.ChatTypeId,
               p.LanguageId,
               p.Supername,
               p.Username,
               p.HeadlineId,
               p.IsTest,
               t.Id AS RelatedId,
               p.MessageId,
               (DENSE_RANK() OVER(PARTITION BY p.VoidingHistoryCollectionId,
                                               p.ConversationGroupId,
                                               CASE WHEN t.Id IS NULL THEN 0 ELSE 1 END
                                  ORDER BY CASE WHEN t.Id IS NULL THEN p.Username ELSE '' END ASC) - 1)
               /
               (CASE WHEN p.ChannelId = 1 THEN @MaxBatchOfLetstalkGroup
                     WHEN p.ChannelId = 2 THEN @MaxBatchOfTelegramGroup
                     ELSE 1 END) AS BatchOfGroup
        FROM #tmpNotificationPrepareData p
             OUTER APPLY (SELECT DISTINCT r.Id
                          FROM bodb_CRM.dbo.crmConversationGroupRecipient cgr1 WITH (NOLOCK)
                               INNER JOIN bodb_CRM.dbo.crmConversationGroupRecipient cgr2 WITH (NOLOCK) ON cgr2.RecipientId = cgr1.RecipientId
                               INNER JOIN #tmpNotificationPrepareData g ON g.ConversationGroupId = cgr2.ConversationGroupId
                               INNER JOIN #tmpNotificationFinalData r ON g.VoidingHistoryCollectionId = r.VoidingHistoryCollectionId AND g.ConversationGroupId = r.ConversationGroupId
                          WHERE p.ConversationGroupId = cgr1.ConversationGroupId
                                AND p.VoidingHistoryCollectionId = g.VoidingHistoryCollectionId
                                AND p.Username = g.Username
                                AND p.ChannelId = g.ChannelId
                                AND g.ChatTypeId = 1) t
        WHERE p.ChatTypeId = 2
    ),
    CTE_tmpAggregate_01 AS (
        SELECT VoidingHistoryCollectionId,
               ConversationGroupId,
               ChannelId,
               ChatTypeId,
               LanguageId,
               Supername,
               STRING_AGG(CAST(Username AS VARCHAR(MAX)), ', ') UsernameList,
               HeadlineId,
               IsTest,
               MessageId,
               CASE WHEN t1.RelatedId IS NULL THEN 0 ELSE 1 END AS IsDuplicated,
               STUFF((SELECT DISTINCT ',' + CONVERT(VARCHAR(20), t2.RelatedId)
                      FROM CTE_tmpDetail t2
                      WHERE t1.VoidingHistoryCollectionId = t2.VoidingHistoryCollectionId AND
                            t1.ConversationGroupId        = t2.ConversationGroupId
                      FOR XML PATH ('')), 1, 1, '') AS RelatedIds,
               BatchOfGroup
        FROM CTE_tmpDetail t1
        GROUP BY VoidingHistoryCollectionId,
                 ConversationGroupId,
                 ChannelId,
                 ChatTypeId,
                 LanguageId,
                 Supername,
                 HeadlineId,
                 IsTest,
                 MessageId,
                 CASE WHEN t1.RelatedId IS NULL THEN 0 ELSE 1 END,
                 BatchOfGroup
    ),
    CTE_tmpAggregate_02 AS (
        SELECT VoidingHistoryCollectionId,
               ConversationGroupId,
               ChannelId,
               ChatTypeId,
               LanguageId,
               STRING_AGG(CAST(('- ' + Supername + ': ' + UsernameList) AS VARCHAR(MAX)), '<br/>') AffectedList,
               HeadlineId,
               IsTest,
               MessageId,
               IsDuplicated,
               RelatedIds,
               BatchOfGroup
        FROM CTE_tmpAggregate_01 t1
        GROUP BY VoidingHistoryCollectionId,
                 ConversationGroupId,
                 ChannelId,
                 ChatTypeId,
                 LanguageId,
                 HeadlineId,
                 IsTest,
                 MessageId,
                 IsDuplicated,
                 RelatedIds,
                 BatchOfGroup
    )
    INSERT INTO #tmpNotificationFinalData (
        VoidingHistoryCollectionId,
        ConversationGroupId,
        ChannelId,
        ChatTypeId,
        LanguageId,
        AffectedList,
        HeadlineList,
        IsTest,
        Status,
        RelatedIds,
        MessageIdList
    )
    SELECT VoidingHistoryCollectionId,
           ConversationGroupId,
           ChannelId,
           ChatTypeId,
           LanguageId,
           STRING_AGG(CAST(AffectedList AS VARCHAR(MAX)), '<br/>')                               AffectedList,
           STRING_AGG(CAST(HeadlineId   AS VARCHAR(MAX)), ',')                                   HeadlineList,
           MIN(CONVERT(TINYINT, IsTest))                                                         IsTest,
           CASE WHEN IsDuplicated = 1 THEN 'Duplicated' ELSE @Status END                         Status,
           CASE WHEN IsDuplicated = 1 THEN STRING_AGG(CAST(RelatedIds AS VARCHAR(MAX)), ',') END RelatedIds,
           STRING_AGG(CAST(MessageId  AS VARCHAR(20)), ',')                                      MessageIdList
    FROM CTE_tmpAggregate_02
    GROUP BY VoidingHistoryCollectionId,
             ConversationGroupId,
             ChannelId,
             ChatTypeId,
             LanguageId,
             IsDuplicated,
             BatchOfGroup

    -- + Update to correct data or to get data for NULL value
    -- + --> AffectedList | Ta thay the ky tu '<br/>' bang ky tu xuong dong
    UPDATE tmp
    SET tmp.AffectedList = REPLACE(tmp.AffectedList, '<br/>', CHAR(13) + CHAR(10))
    FROM #tmpNotificationFinalData tmp
    -- + --> Status | Chi gui di nhung tin nhan ma Template dang thu nhiem (Status='Draft') va no la ticket test (IsTest=1)
    --              | Con nhung notification khac deu mark Status='Draf' tuc la se khong duoc gui di
    --              | Thuong thi dang data nay chi duoc su dung khi test moi truong UAT
    UPDATE tmp
    SET tmp.Status = 'Planned'
    FROM #tmpNotificationFinalData tmp
    WHERE tmp.IsTest = 1
          AND tmp.Status = 'Draft'
    -- + --> Content and Type | Update cac columns dang mang gia tri NULL
    UPDATE r
    SET r.Content_en = m.Content_en,
        r.Content_cs = m.Content_cs,
        r.Content_th = m.Content_th,
        r.Content_vn = m.Content_vn,
        r.[Type]     = m.[Type]
    FROM #tmpNotificationFinalData r
         CROSS APPLY (SELECT TOP 1
                             m.Content_en,
                             m.Content_cs,
                             m.Content_th,
                             m.Content_vn,
                             m.[Type]
                      FROM #tmpXMLData m
                      WHERE r.VoidingHistoryCollectionId = m.VoidingHistoryCollectionId) m


    --------------------------------------------------------
    -- [07] Create Notification                           --
    --      _ Run the while loop to create notification   --
    --      _ Remember to insert data to secondary tables -- 
    --------------------------------------------------------

    -- Declare variables
    DECLARE @Sender         INT      = 10278938
    DECLARE @SendDate       DATETIME = GETDATE()
    DECLARE @NotificationId INT
    DECLARE @Id             INT = 1

    -- Run the loop to process data
    WHILE (1 = 1)
    BEGIN
        -- + Check to break the loop
        IF NOT EXISTS (SELECT 1 FROM #tmpNotificationFinalData WHERE Id = @Id) BREAK

        -- + Insert data to table crmNotification
        INSERT INTO bodb_CRM.dbo.crmNotification (
            NotificationTypeId,
            Sender,
            SendDate,
            Title,
            Status,
            Content,
            RelatedNotificationIds,
            ChannelId
        )
        SELECT nt.NotificationTypeId NotificationTypeId,
               @Sender                                      Sender,
               @SendDate                                    SendDate,
               nt.Title                                     Title,
               r.Status                                     Status,
               REPLACE(
                   REPLACE(
                       REPLACE(
                           REPLACE(
                               REPLACE(nt.Content,
                                       '{EN Announcement}',
                                       r.Content_en),
                               '{SC Announcement}',
                               r.Content_cs),
                           '{TH Announcement}',
                           r.Content_th),
                       '{YN Announcement}',
                       r.Content_vn),
                   '{Affected List}',
                   r.AffectedList)                          Content,
               r.RelatedIds                                 RelatedNotificationIds,
               r.ChannelId                                  ChannelId
        FROM #tmpNotificationFinalData r
             INNER JOIN #tmpNotificationTemplateData nt ON r.LanguageId = nt.LanguageId
                                                           AND r.[Type] = nt.[Type]
        WHERE r.Id = @Id

        -- + Get data for @NotificationId
        SELECT @NotificationId = SCOPE_IDENTITY()

        -- + Insert data to table crmNotificationGroup
        INSERT INTO bodb_CRM.dbo.crmNotificationGroup (
            NotificationId,
            ConversationGroupId,
            Status
        )
        SELECT @NotificationId     NotificationId,
               ConversationGroupId ConversationGroupId,
               Status              Status
        FROM #tmpNotificationFinalData
        WHERE Id = @Id

        -- + Insert data to table crmNotificationRecipient
        INSERT INTO bodb_CRM.dbo.crmNotificationRecipient (
            NotificationId,
            RecipientId,
            ConversationGroupId
        )
        SELECT @NotificationId       NotificationId,
               cgr.RecipientId       RecipientId,
               r.ConversationGroupId ConversationGroupId
        FROM bodb_CRM.dbo.crmConversationGroupRecipient cgr WITH (NOLOCK)
             INNER JOIN #tmpNotificationFinalData r ON r.ConversationGroupId = cgr.ConversationGroupId
        WHERE r.Id = @Id

        -- + Insert data to table crmNotificationHeadline
        INSERT INTO bodb_CRM.dbo.crmNotificationHeadline (
            NotificationId,
            HeadlineId
        )
        SELECT DISTINCT
               @NotificationId NotificationId,
               f.value         HeadlineId
        FROM #tmpNotificationFinalData r
             CROSS APPLY STRING_SPLIT(r.HeadlineList, ',') f
        WHERE r.Id = @Id

        -- + Insert data to table crmNotificationRefDetail
        INSERT INTO dbo.crmNotificationRefDetail (
            NotificationId,
            ReferenceId,
            DataSource,
            CreatedDate
        )
        SELECT @NotificationId              NotificationId,
               f.value                      ReferenceId,
               'DBMSG.bodb_Message.dbo.Msg' DataSource,
               GETDATE()                    CreatedDate
        FROM #tmpNotificationFinalData r
             CROSS APPLY STRING_SPLIT(r.MessageIdList, ',') f
        WHERE r.Id = @Id

        -- + Update value column RelatedIds for Notification of Personal that be duplicate data with Group
        --   --> Ta can luu y la gia tri column RelatedNotificationIds cua bang crmNotification phai la gia tri NotificationID
        --   --> Va doan code nay giup giai quyet van de nay
        UPDATE r
        SET r.RelatedIds = RIGHT(LEFT(t.tmpRelatedIds, LEN(t.tmpRelatedIds) - 1), LEN(t.tmpRelatedIds) - 2)
        FROM #tmpNotificationFinalData r
             CROSS APPLY (SELECT tmpRelatedIds = REPLACE(',' + r.RelatedIds + ',', ',' + CONVERT(VARCHAR(20), @Id) + ',', ',' + CONVERT(VARCHAR(20), @NotificationId) + ',')) t
        WHERE r.Id > @Id
              AND r.ChatTypeId = 2
              AND ',' + r.RelatedIds + ',' LIKE '%,' + CONVERT(VARCHAR(20), @Id) + ',%'

        -- + Set value to continue the loop
        SELECT @Id = @Id + 1
    END


    -----------------------------
    -- [08] Update job setting --

    BEGIN
        UPDATE s
        SET s.Value = 'Completed'
        FROM bodb_CRM.dbo.SystemSetting s WITH (ROWLOCK, UPDLOCK)
        WHERE s.ServiceName = @ServiceName
              AND s.SettingName = @SettingNameOfJobStatus
              AND s.Value = 'Running'
    END

    IF (ISNULL(@MAXVoidingHistoryCollectionId, 0) > 0)
    BEGIN
        UPDATE s
        SET s.Value = CONVERT(VARCHAR(50), @MAXVoidingHistoryCollectionId)
        FROM bodb_CRM.dbo.SystemSetting s WITH (ROWLOCK, UPDLOCK)
        WHERE s.ServiceName = @ServiceName
              AND s.SettingName = @SettingNameOfVoidingHistoryCollectionId
    END

    IF (ISNULL(@MAXMsgTargetId, 0) > 0)
    BEGIN
        UPDATE s
        SET s.Value = CONVERT(VARCHAR(50), @MAXMsgTargetId)
        FROM bodb_CRM.dbo.SystemSetting s WITH (ROWLOCK, UPDLOCK)
        WHERE s.ServiceName = @ServiceName
              AND s.SettingName = @SettingNameOfMsgTargetId
    END


    ---------------------------
    -- [09] Drop temp tables --

    DROP TABLE #tmpXMLData

    DROP TABLE #tmpNotificationTemplateSetting
    DROP TABLE #tmpNotificationTemplateData

    DROP TABLE #tmpNotificationMessageInfo
    DROP TABLE #tmpNotificationGroupChatInfo
    
    DROP TABLE #tmpNotificationPrepareData
    DROP TABLE #tmpNotificationFinalData

END
GO