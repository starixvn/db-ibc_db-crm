/*<info serverAlias="DBCRM-bodb_CRM" executers="wsv_nap" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Acc_CRM_Chatbot_RebateRetention_Import]  
	@XmlData		XML,
    @NewLogSID		XML,
    @Environment	VARCHAR(50)    = '',
    @ErrCode		INT            = 0  OUTPUT,
    @ErrMsg			NVARCHAR(4000) = '' OUTPUT
AS

/*
    Created: 20241030@Virgil
    DB: DBCRM-bodb_CRM
    Task: CRM - ChatBot - Import RebateAndRetention Notification

    Revisions:
        - 20241018@Virgil: Initialize SP [RedmineID: #210688]

    Param's Explanation:
		- @XmlData: <root>
					  <r CustId="1284" Recommend="1262" Mrecommend="117835270" Srecommend="117835268" AffectedMember="305RM: {100 RM}" IsTest="0"/>
					  <r CustId="1290" Recommend="1262" Mrecommend="117835270" Srecommend="117835268" AffectedMember="192RM: {100 RM}" IsTest="0"/>
					  <r CustId="96324235" Recommend="93558369" Mrecommend="117835270" Srecommend="117835268" AffectedMember="WINRM008: {100 RM}" />
					</root>
        - @NewLogSID: <root>
					  <r LastLogSID="74" SiteDBGroupId="3" ListPendingSIDs="84,85,86,72,73" />
					  <r LastLogSID="1" SiteDBGroupId="4" ListPendingSIDs="" />
					</root>
*/
BEGIN

    SET NOCOUNT ON


    ---------------------------
    -- [01] Global variables --

    DECLARE @ServiceName			  VARCHAR(50) = 'ChatBot - RebateRetention'

    DECLARE @SettingNameOfLastRuntime VARCHAR(50)
    SELECT  @SettingNameOfLastRuntime = CASE WHEN @Environment = 'UAT' THEN 'LastRuntimeUAT' ELSE 'LastRuntime' END

    DECLARE @LastRuntime			  DATETIME
    SELECT  @LastRuntime			  = CONVERT(DATETIME, Value) FROM bodb_CRM.dbo.SystemSetting WITH (NOLOCK) WHERE SettingName = @SettingNameOfLastRuntime AND ServiceName = @ServiceName

    DECLARE @SettingNameOfJobStatus   VARCHAR(50)
    SELECT  @SettingNameOfJobStatus   = CASE WHEN @Environment = 'UAT' THEN 'JobStatusUAT' ELSE 'JobStatus' END

    DECLARE @SettingNameOfLastLogSID  VARCHAR(50)
    SELECT  @SettingNameOfLastLogSID  = CASE WHEN @Environment = 'UAT' THEN 'LastLogSIdUAT' ELSE 'LastLogSId' END

	DECLARE @IncludeUUSCurrency		  BIT
	SELECT @IncludeUUSCurrency		  = CONVERT(BIT, Value) FROM dbo.SystemSetting WITH(NOLOCK) WHERE ServiceName = @ServiceName and SettingName = 'IncludeUUSCurrency'
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

    -- Create temp table and parse XML data
    CREATE TABLE #tmpXMLData (
		SiteDBGroupID	SMALLINT,
		CustId			INT,
		Recommend		INT,
		Mrecommend		INT,
		Srecommend		INT,
		AffectedMember	VARCHAR(100),
		IsTest			BIT
    )
    INSERT INTO #tmpXMLData 
    SELECT
		t.c.value('@SiteDBGroupID', 'SMALLINT')		AS SiteDBGroupID,
        t.c.value('@CustId',		'INT')			AS CustId,
        t.c.value('@Recommend',		'INT')			AS Recommend,
        t.c.value('@Mrecommend',	'INT')			AS Mrecommend,
        t.c.value('@Srecommend',	'INT')			AS Srecommend,
        t.c.value('@AffectedMember','VARCHAR(100)') AS AffectedMember,
        t.c.value('@IsTest',		'BIT')			AS IsTest
    FROM @XmlData.nodes('root/r') t(c)
    OPTION (OPTIMIZE FOR (@XmlData = NULL))


    -- If nothing happened, need to update setting and return
    IF (@@ROWCOUNT = 0)
    BEGIN

		UPDATE s
        SET s.Value = CAST(@NewLogSID AS VARCHAR(300))
        FROM bodb_CRM.dbo.SystemSetting s WITH(ROWLOCK, UPDLOCK)
        WHERE s.ServiceName = @ServiceName
                AND s.SettingName = @SettingNameOfLastLogSID

        UPDATE s
        SET s.Value = 'Completed'
        FROM bodb_CRM.dbo.SystemSetting s WITH(ROWLOCK, UPDLOCK)
        WHERE s.ServiceName = @ServiceName
                AND s.SettingName = @SettingNameOfJobStatus
                AND s.Value = 'Running'

        RETURN
    END

	-- Only import testing accounts with uat environment
	IF @Environment = 'UAT'
	BEGIN
		DELETE i FROM #tmpXMLData i WHERE i.IsTest = 0
	END
	-- Exclude UUS currency with LIVE environment
	IF @Environment = 'LIVE' AND @IncludeUUSCurrency = 0
	BEGIN
		DELETE i FROM #tmpXMLData i WHERE i.IsTest = 1
	END

	-- Break down XMLData to get LastLogSID of each SiteDBGroupId for ReferenceId column of table dbo.crmNotificationRefDetail
	CREATE TABLE #NewLogSID (
        LastLogSID		SMALLINT,
        SiteDBGroupId	SMALLINT,
        ListPendingSIDs VARCHAR(MAX)
    )
    INSERT INTO #NewLogSID (LastLogSID, SiteDBGroupId, ListPendingSIDs)
    SELECT
        t.c.value('@LastLogSID', 'SMALLINT')				AS LastLogSID,
        t.c.value('@SiteDBGroupId', 'SMALLINT')				AS SiteDBGroupId,
        t.c.value('@ListPendingSIDs', 'VARCHAR(MAX)')		AS ListPendingSIDs
    FROM @NewLogSID.nodes('root/r') t(c)
    OPTION (OPTIMIZE FOR (@NewLogSID = NULL))

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

    SELECT  @NotificationTemplateSetting = CONVERT(XML, Value) 
	FROM bodb_CRM.dbo.SystemSetting WITH (NOLOCK) 
	WHERE ServiceName = @ServiceName 
		AND SettingName = 'NotificationTemplate'
    
	-- + Create temp table for Notification Template
    CREATE TABLE #tmpNotificationTemplateSetting (
        NotificationTemplateId SMALLINT,
        NotificationTypeId     SMALLINT,
        IsTest                 BIT,
        LanguageId             INT,
        TemplateRequiredParam  NVARCHAR(MAX)
    )
    -- + Gen data to temp table
    INSERT INTO #tmpNotificationTemplateSetting 
    SELECT p.n.value('@NotificationTemplateID', 'SMALLINT')      AS NotificationTemplateId,
           p.n.value('@NotificationTypeID',     'SMALLINT')      AS NotificationTypeId,
           c.n.value('@IsTest',                 'BIT')           AS IsTest,
           c.n.value('@LanguageId',             'INT')           AS LanguageId,
           c.n.value('@Value',                  'NVARCHAR(MAX)') AS TemplateRequiredParam
    FROM @NotificationTemplateSetting.nodes('root/r') p(n)
         CROSS APPLY p.n.nodes('TemplateRequiredParam') c(n)

    -- + If no data means error
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
               IsTest
        FROM #tmpNotificationTemplateSetting
    )
    INSERT INTO #tmpNotificationTemplateData (
        NotificationTypeId,
        NotificationTemplateId,
        Title,
        IsTest,
        LanguageId,
        Content
    )
    SELECT s.NotificationTypeId      NotificationTypeId,
           nt.NotificationTemplateId NotificationTemplateId,
           nt.Title                  Title,
           s.IsTest                  IsTest,
           ntc.LanguageId            LanguageId,
           ntc.Content               Content
    FROM CTE_Setting s
         INNER JOIN bodb_CRM.dbo.crmNotificationTemplate nt WITH (NOLOCK) 
			ON s.NotificationTemplateId = nt.NotificationTemplateId
         INNER JOIN bodb_CRM.dbo.crmNotificationTemplateContent ntc WITH (NOLOCK) 
			ON nt.NotificationTemplateId = ntc.NotificationTemplateId

    -- Check require param | Day la buoc check cheo data quan trong nham dam bao tinh chinh xac cua du lieu
    IF EXISTS (
        SELECT 1
        FROM #tmpNotificationTemplateSetting st
        INNER JOIN #tmpNotificationTemplateData nt 
			ON st.NotificationTemplateId = nt.NotificationTemplateId
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
    --        + Mot Headline se co rat nhieu Direct Account khac nhau nhung thuong chi co mot vai PIC hay cung co the PIC la chinh Headline											   --
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
		SiteDBGroupID	SMALLINT,
        Username		VARCHAR(50),
		AffectedMember	VARCHAR(100),
        Supername		VARCHAR(50),
        DirectAccount	INT,
        HeadlineId		INT,
        IsTest			BIT,
        RecipientId		INT
    )
    -- + Gen data to temp table
    INSERT INTO #tmpNotificationMessageInfo (
		SiteDBGroupID,
		Username,
		AffectedMember,
        Supername,
        DirectAccount,
        HeadlineId,
        IsTest,
        RecipientId
    )
    SELECT m.SiteDBGroupID		SiteDBGroupID,
			mem.username		Username,
			m.AffectedMember	AffectedMember,
			sup.username		Supername,
			pm.CustId			DirectAccount,
			pm.HeadlineId		HeadlineId,
			m.IsTest			IsTest,
			r.RecipientId		RecipientId
    FROM #tmpXMLData m
	INNER JOIN bodb02.dbo.Customer mem WITH (NOLOCK) 
		ON m.CustId = mem.custid
	INNER JOIN bodb02.dbo.Customer sup WITH (NOLOCK) 
		ON mem.srecommend = sup.custid 
		AND sup.roleid = 4
	INNER JOIN bodb02.dbo.CustDirectAccount cda WITH (NOLOCK) 
		ON cda.CustId IN (m.CustId, m.Recommend, m.Mrecommend, m.Srecommend)
	INNER JOIN bodb_CRM.dbo.crmPicManagement pm WITH (NOLOCK) 
		ON cda.CustId = pm.CustId
	INNER JOIN bodb_CRM.dbo.crmRecipient r WITH (NOLOCK) 
		ON pm.PicId = r.SourceId 
		AND r.DataSource = 'bodb_CRM.dbo.crmPIC'
    
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
        ConversationGroupId        SMALLINT,
        ChannelId                  TINYINT,
        ChatTypeId                 TINYINT,
        LanguageId                 INT,
        DirectAccount              INT,
        NoRecipient                INT
    )
    INSERT INTO #tmpNotificationGroupChatInfo (
        ConversationGroupId,
        DirectAccount,
        NoRecipient
    )
    SELECT cgr.ConversationGroupId       ConversationGroupId,
           m.DirectAccount               DirectAccount,
           COUNT(DISTINCT m.RecipientId) NoRecipient
    FROM #tmpNotificationMessageInfo m
    INNER JOIN bodb_CRM.dbo.crmConversationGroupRecipient cgr WITH (NOLOCK) 
		ON m.RecipientId = cgr.RecipientId
    INNER JOIN bodb_CRM.dbo.crmConversationGroupHeadline cgh WITH (NOLOCK) 
		ON m.HeadlineId = cgh.HeadlineId 
		AND cgr.ConversationGroupId = cgh.ConversationGroupId
    INNER JOIN bodb_CRM.dbo.crmConversationGroup cg WITH (NOLOCK) 
		ON cgr.ConversationGroupId = cg.ConversationGroupId
    WHERE cg.IsActive = 1
    GROUP BY cgr.ConversationGroupId,
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
    --                  | Luu y khi xu ly issue tren PRO
    --                  | + Co nhieu truong hop user thac mac tai sao ko nhan duoc notification la do nguyen nhan nay
    --                  | + Ta can luu y den case nay de biet duong debug chi ra cho user thay va nhan ho khac phuc
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
    INNER JOIN bodb_CRM.dbo.crmConversationGroup cg WITH (NOLOCK) 
		ON t.ConversationGroupId = cg.ConversationGroupId

    ----------------------------------------------------------------------------------------------------------------------------
    -- [05] Prepare Notification Final Data                                                                                   -- 
    --      _ We have data of Group (ChatTypeId=1) and data of Personal (ChatTypeId=2)                                        --
    --      _ So if one PIC already receive inf from Group we no send notification to Personal to prevent duplicate send data --
    --      _ The way to group data here quite complicated and need to understand clearly                                     --
    ----------------------------------------------------------------------------------------------------------------------------

    -- Declare variables
    -- + Because of the maximum character in message of Letstalk/Telegram, so we need to limit info about affected list will appear on message
    DECLARE @MaxBatchOfLetstalkGroup INT = 150
    DECLARE @MaxBatchOfTelegramGroup INT = 100
    -- + For test Template status of Notification must be Draft
    DECLARE @Status VARCHAR(20) = 'Planned'
    IF EXISTS (SELECT 1 FROM #tmpNotificationTemplateData WHERE IsTest = 1) SET @Status = 'Draft'

    -- Get prepare data | O day ta lam hai viec
    --                  | + Dau tien la lay len nhung thong tin can thiet de tao notification
    --                  | + Thu hai la chia data thanh tung batch theo so luong username de dam bao ko bi qua tai so luong ky tu khi tao notification
    --                  | + Viec chia data thanh tung batch o day chi co y nghia cho Group vi den khi tao data cho Personal ta se can chia data lai
    -- + Create temp table
    CREATE TABLE #tmpNotificationPrepareData (
        -- Based Data
		SiteDBGroupID			SMALLINT,
        Username				VARCHAR(50),
		AffectedMember			VARCHAR(100),
        ConversationGroupId		SMALLINT,
        ChannelId				TINYINT,
        ChatTypeId				TINYINT,
        LanguageId				INT,
        BatchOfGroup			INT,
        -- Aggregated Data
        Supername				VARCHAR(50),
        HeadlineId				INT,
        IsTest					BIT,
        MessageId				INT,
    )
    -- + Gen data to temp table
    INSERT INTO #tmpNotificationPrepareData (
        -- Based Data
		SiteDBGroupID,
		Username,
		AffectedMember,
        ConversationGroupId,
        ChannelId,
        ChatTypeId,
        LanguageId,
        BatchOfGroup,
        -- Aggregated Data
        Supername,
        HeadlineId,
        IsTest
    )
    SELECT DISTINCT
           -- Based Data
			m.SiteDBGroupID,
		    m.Username,
			m.AffectedMember,
			g.ConversationGroupId,
			g.ChannelId,
			g.ChatTypeId,
			g.LanguageId,
			(
				(DENSE_RANK() OVER(PARTITION BY g.ConversationGroupId ORDER BY m.Username ASC) - 1)
				/
				(CASE WHEN g.ChannelId = 1 THEN @MaxBatchOfLetstalkGroup
						WHEN g.ChannelId = 2 THEN @MaxBatchOfTelegramGroup
						ELSE 1 END)
			) BatchOfGroup,
           -- Aggregated Data
           m.Supername,
           m.HeadlineId,
           m.IsTest
    FROM #tmpNotificationMessageInfo m
    INNER JOIN #tmpNotificationGroupChatInfo g 
		ON m.DirectAccount = g.DirectAccount
    INNER JOIN bodb_CRM.dbo.crmConversationGroupRecipient cgr WITH (NOLOCK) 
		ON m.RecipientId = cgr.RecipientId 
		AND g.ConversationGroupId = cgr.ConversationGroupId
    INNER JOIN bodb_CRM.dbo.crmConversationGroupHeadline cgh WITH (NOLOCK) 
		ON m.HeadlineId = cgh.HeadlineId 
		AND g.ConversationGroupId = cgh.ConversationGroupId

    -- Get final data | Ta tach lay data theo Group truoc roi moi lay data theo Personal
    --                | Va cong viec nay can thuc hien lien mach mot lan lien tuc chu ko the tach roi duoc
    --                | Boi vi ta can dam bao la neu mot PIC da nhan tin nhan trong Group roi thi se khong gui tin nhan Personal cho PIC do nua
    --                | Can xem ky cho code luc  gen data cho Personal de hieu vi sao ta ko tach thanh cac bang tam de code do cong kenh hon
    -- + Create temp table
    CREATE TABLE #tmpNotificationFinalData (
        -- Based Data
        Id					INT IDENTITY(1, 1),
		SiteDBGroupID		SMALLINT,
        ConversationGroupId SMALLINT,
        ChannelId			TINYINT,
        ChatTypeId			TINYINT,
        LanguageId			INT,
        Status				VARCHAR(20),		
        -- Aggregated Data
        AffectedList		VARCHAR(MAX),
        HeadlineList		VARCHAR(MAX),
        IsTest				BIT,
        RelatedIds			VARCHAR(1000)
    )
    -- + Gen data to temp table for Group (ChatTypeId=1) | De code them phan tuong minh va de hieu
    --                                                   | O day ta chia data thanh tung cum aggregate khac nhau roi cuoi cung join chung lai voi nhau
    --                                                   | Viec nay se phat sinh them nhieu CTE va lam code hoi dai dong nhung de hieu
    ;WITH
    -- + --> Group - DetailData
    CTE_Group_DetailData AS (
        SELECT SiteDBGroupID,
				AffectedMember,
				ConversationGroupId,
				ChannelId,
				ChatTypeId,
				LanguageId,
				BatchOfGroup,
				Supername,
				HeadlineId,
				IsTest
        FROM #tmpNotificationPrepareData
        WHERE ChatTypeId = 1
    ),
    -- + --> Group - AggregatedData - AffectedList
    --       _ Dau tien ta can remove duplicate data
    CTE_Group_AggregatedData_AffectedList_RemoveDuplicate AS (
        SELECT DISTINCT
				SiteDBGroupID,
				AffectedMember,
				ConversationGroupId,
				ChannelId,
				ChatTypeId,
				LanguageId,
				BatchOfGroup,
				Supername
        FROM CTE_Group_DetailData
    ),
    --       _ Sau do ta tien hanh tong hop data | Lan thu nhat
    CTE_Group_AggregatedData_AffectedList_Username AS (
        SELECT SiteDBGroupID,
				ConversationGroupId,
				ChannelId,
				ChatTypeId,
				LanguageId,
				BatchOfGroup,
				Supername,
				STRING_AGG(CAST(AffectedMember AS VARCHAR(MAX)), ', ') UsernameList
        FROM CTE_Group_AggregatedData_AffectedList_RemoveDuplicate
        GROUP BY SiteDBGroupID,
				ConversationGroupId,
				ChannelId,
				ChatTypeId,
				LanguageId,
				BatchOfGroup,
				Supername
    ),
    --       _ Sau do ta tien hanh tong hop data | Lan thu hai
    CTE_Group_AggregatedData_AffectedList AS (
        SELECT SiteDBGroupID,
				ConversationGroupId,
				ChannelId,
				ChatTypeId,
				LanguageId,
				BatchOfGroup,
				STRING_AGG(CAST(('- ' + Supername + ': ' + UsernameList) AS VARCHAR(MAX)), '<br/>') AffectedList
        FROM CTE_Group_AggregatedData_AffectedList_Username
        GROUP BY SiteDBGroupID,
				ConversationGroupId,
                ChannelId,
                ChatTypeId,
                LanguageId,
                BatchOfGroup
    ),
    -- + --> Group - AggregatedData - HeadlineList
    --       _ Dau tien ta can remove duplicate data
    CTE_Group_AggregatedData_HeadlineList_RemoveDuplicate AS (
        SELECT SiteDBGroupID,
				ConversationGroupId,
				ChannelId,
				ChatTypeId,
				LanguageId,
				BatchOfGroup,
				HeadlineId
        FROM CTE_Group_DetailData
        GROUP BY SiteDBGroupID,
				ConversationGroupId,
                ChannelId,
                ChatTypeId,
                LanguageId,
                BatchOfGroup,
                HeadlineId
    ),
    --       _ Sau do ta tien hanh tong hop data
    CTE_Group_AggregatedData_HeadlineList AS (
        SELECT SiteDBGroupID,
				ConversationGroupId,
				ChannelId,
				ChatTypeId,
				LanguageId,
				BatchOfGroup,
				STRING_AGG(CAST(HeadlineId AS VARCHAR(MAX)), ',') HeadlineList
        FROM CTE_Group_AggregatedData_HeadlineList_RemoveDuplicate
        GROUP BY SiteDBGroupID,
				ConversationGroupId,
                ChannelId,
                ChatTypeId,
                LanguageId,
                BatchOfGroup
    ),
    -- + --> Group - AggregatedData - IsTest
    CTE_Group_AggregatedData_IsTest AS (
        SELECT SiteDBGroupID,
				ConversationGroupId,
				ChannelId,
				ChatTypeId,
				LanguageId,
				BatchOfGroup,
				MIN(CONVERT(TINYINT, IsTest)) IsTest
        FROM CTE_Group_DetailData
        GROUP BY SiteDBGroupID,
				ConversationGroupId,
				ChannelId,
				ChatTypeId,
				LanguageId,
				BatchOfGroup
    )
    -- + --> Insert data to main table
    INSERT INTO #tmpNotificationFinalData (
        -- Based Data
		SiteDBGroupID,
        ConversationGroupId,
        ChannelId,
        ChatTypeId,
        LanguageId,
        Status,
        -- Aggregated Data
        AffectedList,
        HeadlineList,
        IsTest
    )
    SELECT -- Based Data
			af.SiteDBGroupID			SiteDBGroupID,
			af.ConversationGroupId		ConversationGroupId,
			af.ChannelId				ChannelId,
			af.ChatTypeId				ChatTypeId,
			af.LanguageId				LanguageId,
			@Status						[Status],
			-- Aggregated Data
			af.AffectedList				AffectedList,
			hl.HeadlineList				HeadlineList,
			it.IsTest					IsTest
    FROM CTE_Group_AggregatedData_AffectedList af
	LEFT JOIN CTE_Group_AggregatedData_HeadlineList hl 
		ON af.ConversationGroupId	= hl.ConversationGroupId        
		AND af.ChannelId			= hl.ChannelId                  
		AND af.ChatTypeId			= hl.ChatTypeId                 
		AND af.LanguageId			= hl.LanguageId                 
		AND af.BatchOfGroup			= hl.BatchOfGroup
		AND af.SiteDBGroupID		= hl.SiteDBGroupID
	LEFT JOIN CTE_Group_AggregatedData_IsTest it 
		ON af.ConversationGroupId	= it.ConversationGroupId        
		AND af.ChannelId			= it.ChannelId                  
		AND af.ChatTypeId			= it.ChatTypeId                 
		AND af.LanguageId			= it.LanguageId                 
		AND af.BatchOfGroup			= it.BatchOfGroup
		AND af.SiteDBGroupID		= it.SiteDBGroupID
    ---- + Gen data to temp table for Personal (ChatTypeId=2) | De code them phan tuong minh va de hieu
    ----                                                      | O day ta chia data thanh tung cum aggregate khac nhau roi cuoi cung join chung lai voi nhau
    ----                                                      | Viec nay se phat sinh them nhieu CTE va lam code hoi dai dong nhung de hieu
    ;WITH
    ---- + --> CTE_Group | Dau tien ta can lay ra danh sach Group can gui notification da tao kem theo thong tin RecipientId
    ----                 | Ta can thong tin nay de cross check voi thong tin cua Personal de biet duoc xem PIC nao data nhan notification tu group de khong gui lai lan nua
    CTE_Group AS (
        SELECT DISTINCT
               fd.Id,
               pd.Username,
               fd.ChannelId,
               cg.RecipientId
        FROM #tmpNotificationFinalData fd
		INNER JOIN #tmpNotificationPrepareData pd 
			ON fd.ConversationGroupId = pd.ConversationGroupId
		INNER JOIN bodb_CRM.dbo.crmConversationGroupRecipient cg WITH (NOLOCK) 
			ON fd.ConversationGroupId = cg.ConversationGroupId
        WHERE fd.ChatTypeId = 1
    ),
    -- + --> CTE_Personal_Detail | O buoc nay ta se lay len duoc thong tin detail cua Personal cung nhu biet duoc no thuoc Group nao
    --                           | Chu y ky cho cac dieu kien mapping
    CTE_Personal_DetailData AS (
        SELECT pd.SiteDBGroupID,
				pd.AffectedMember,
				pd.ConversationGroupId,
				pd.ChannelId,
				pd.ChatTypeId,
				pd.LanguageId,
				(DENSE_RANK() OVER(PARTITION BY pd.ConversationGroupId,
												CASE WHEN gr.Id IS NULL THEN 0 ELSE 1 END
									ORDER BY CASE WHEN gr.Id IS NULL THEN pd.Username ELSE '' END ASC) - 1)
				/
				(CASE WHEN pd.ChannelId = 1 THEN @MaxBatchOfLetstalkGroup
						WHEN pd.ChannelId = 2 THEN @MaxBatchOfTelegramGroup
						ELSE 1 END) AS BatchOfGroup,
				pd.Supername,
				pd.HeadlineId,
				pd.IsTest,
				gr.Id RelatedId,
				CASE WHEN gr.Id IS NOT NULL THEN 1 ELSE 0 END IsDuplicated
        FROM #tmpNotificationPrepareData pd
		INNER JOIN bodb_CRM.dbo.crmConversationGroupRecipient cg WITH (NOLOCK) 
			ON pd.ConversationGroupId = cg.ConversationGroupId
		LEFT JOIN CTE_Group gr 
			ON pd.Username		= gr.Username                   
			AND pd.ChannelId	= gr.ChannelId                  
			AND cg.RecipientId  = gr.RecipientId
        WHERE pd.ChatTypeId = 2
    ),
    -- + --> Personal - AggregatedData - AffectedList
    --       _ Dau tien ta can remove duplicate data
    CTE_Personal_AggregatedData_AffectedList_RemoveDuplicate AS (
        SELECT DISTINCT
				SiteDBGroupID,
				AffectedMember,
				ConversationGroupId,
				ChannelId,
				ChatTypeId,
				LanguageId,
				BatchOfGroup,
				IsDuplicated,
				Supername
        FROM CTE_Personal_DetailData

    ),
    --       _ Sau do ta tien hanh tong hop data | Lan thu nhat
    CTE_Personal_AggregatedData_AffectedList_Username AS (
        SELECT SiteDBGroupID,
				ConversationGroupId,
				ChannelId,
				ChatTypeId,
				LanguageId,
				BatchOfGroup,
				IsDuplicated,
				Supername,
				STRING_AGG(CAST(AffectedMember AS VARCHAR(MAX)), ', ') UsernameList
        FROM CTE_Personal_AggregatedData_AffectedList_RemoveDuplicate
        GROUP BY SiteDBGroupID,
				ConversationGroupId,
				ChannelId,
				ChatTypeId,
				LanguageId,
				BatchOfGroup,
				IsDuplicated,
				Supername
    ),
    --       _ Sau do ta tien hanh tong hop data | Lan thu hai
    CTE_Personal_AggregatedData_AffectedList AS (
        SELECT SiteDBGroupID,
				ConversationGroupId,
				ChannelId,
				ChatTypeId,
				LanguageId,
				BatchOfGroup,
				IsDuplicated,
				STRING_AGG(CAST(('- ' + Supername + ': ' + UsernameList) AS VARCHAR(MAX)), '<br/>') AffectedList
        FROM CTE_Personal_AggregatedData_AffectedList_Username
        GROUP BY SiteDBGroupID,
				ConversationGroupId,
				ChannelId,
				ChatTypeId,
				LanguageId,
				BatchOfGroup,
				IsDuplicated
    ),
    -- + --> Personal - AggregatedData - HeadlineList
    --       _ Dau tien ta can remove duplicate data
    CTE_Personal_AggregatedData_HeadlineList_RemoveDuplicate AS (
        SELECT DISTINCT
				SiteDBGroupID,
				ConversationGroupId,
				ChannelId,
				ChatTypeId,
				LanguageId,
				BatchOfGroup,
				IsDuplicated,
				HeadlineId
        FROM CTE_Personal_DetailData
    ),
    --       _ Sau do ta tien hanh tong hop data
    CTE_Personal_AggregatedData_HeadlineList AS (
        SELECT SiteDBGroupID,
				ConversationGroupId,
				ChannelId,
				ChatTypeId,
				LanguageId,
				BatchOfGroup,
				IsDuplicated,
				STRING_AGG(CAST(HeadlineId AS VARCHAR(MAX)), ',') HeadlineList
        FROM CTE_Personal_AggregatedData_HeadlineList_RemoveDuplicate
        GROUP BY SiteDBGroupID,
				ConversationGroupId,
				ChannelId,
				ChatTypeId,
				LanguageId,
				BatchOfGroup,
				IsDuplicated
    ),
    -- + --> Personal - AggregatedData - IsTest
    CTE_Personal_AggregatedData_IsTest AS (
        SELECT SiteDBGroupID,
				ConversationGroupId,
				ChannelId,
				ChatTypeId,
				LanguageId,
				BatchOfGroup,
				IsDuplicated,
				MIN(CONVERT(TINYINT, IsTest)) IsTest
        FROM CTE_Personal_DetailData
        GROUP BY SiteDBGroupID,
				ConversationGroupId,
                ChannelId,
                ChatTypeId,
                LanguageId,
                BatchOfGroup,
                IsDuplicated
    ),
    -- + --> Personal - AggregatedData - RelatedIds
    --       _ Dau tien ta can remove duplicate data
    CTE_Personal_AggregatedData_RelatedIds_RemoveDuplicate AS (
        SELECT DISTINCT
				SiteDBGroupID,
				ConversationGroupId,
				ChannelId,
				ChatTypeId,
				LanguageId,
				BatchOfGroup,
				IsDuplicated,
				RelatedId
        FROM CTE_Personal_DetailData
    ),
    --       _ Sau do ta tien hanh tong hop data
    CTE_Personal_AggregatedData_RelatedIds AS (
        SELECT SiteDBGroupID,
				ConversationGroupId,
				ChannelId,
				ChatTypeId,
				LanguageId,
				BatchOfGroup,
				IsDuplicated,
				STRING_AGG(CAST(RelatedId AS VARCHAR(MAX)), ',') RelatedIds
        FROM CTE_Personal_AggregatedData_RelatedIds_RemoveDuplicate
        GROUP BY SiteDBGroupID,
				ConversationGroupId,
				ChannelId,
				ChatTypeId,
				LanguageId,
				BatchOfGroup,
				IsDuplicated
    )
    -- + --> Insert data to main table
    INSERT INTO #tmpNotificationFinalData (
        -- Based Data
		SiteDBGroupID,
        ConversationGroupId,
        ChannelId,
        ChatTypeId,
        LanguageId,
        Status,
        -- Aggregated Data
        AffectedList,
        HeadlineList,
        IsTest,
        RelatedIds
    )
    SELECT -- Based Data
			af.SiteDBGroupID		SiteDBGroupID,
			af.ConversationGroupId	ConversationGroupId,
			af.ChannelId			ChannelId,
			af.ChatTypeId			ChatTypeId,
			af.LanguageId			LanguageId,
			CASE 
				WHEN af.IsDuplicated = 1 THEN 'Duplicated' 
				ELSE @Status
			END						[Status],
			-- Aggregated Data
			af.AffectedList			AffectedList,
			hl.HeadlineList			HeadlineList,
			it.IsTest				IsTest,
			rl.RelatedIds			RelatedIds
    FROM CTE_Personal_AggregatedData_AffectedList  af
    LEFT JOIN CTE_Personal_AggregatedData_HeadlineList  hl
		ON af.ConversationGroupId	= hl.ConversationGroupId        
		AND af.ChannelId			= hl.ChannelId                  
		AND af.ChatTypeId			= hl.ChatTypeId                 
		AND af.LanguageId			= hl.LanguageId                
		AND af.BatchOfGroup			= hl.BatchOfGroup               
		AND af.IsDuplicated			= hl.IsDuplicated
		AND af.SiteDBGroupID		= hl.SiteDBGroupID
    LEFT JOIN CTE_Personal_AggregatedData_IsTest  it 
		ON af.ConversationGroupId	= it.ConversationGroupId        
		AND af.ChannelId			= it.ChannelId                  
		AND af.ChatTypeId			= it.ChatTypeId                 
		AND af.LanguageId			= it.LanguageId                 
		AND af.BatchOfGroup			= it.BatchOfGroup               
		AND af.IsDuplicated			= it.IsDuplicated
		AND af.SiteDBGroupID		= it.SiteDBGroupID
    LEFT JOIN CTE_Personal_AggregatedData_RelatedIds  rl 
		ON af.ConversationGroupId	= rl.ConversationGroupId        
		AND af.ChannelId			= rl.ChannelId                  
		AND af.ChatTypeId			= rl.ChatTypeId                 
		AND af.LanguageId			= rl.LanguageId                 
		AND af.BatchOfGroup			= rl.BatchOfGroup               
		AND af.IsDuplicated			= rl.IsDuplicated
		AND af.SiteDBGroupID		= rl.SiteDBGroupID

    ---- + Update to correct data or to get data for NULL value
    ---- + --> AffectedList | Ta thay the ky tu '<br/>' bang ky tu xuong dong
    UPDATE tmp
    SET tmp.AffectedList = REPLACE(tmp.AffectedList, '<br/>', CHAR(13) + CHAR(10))
    FROM #tmpNotificationFinalData tmp
    ---- + --> Status | Chi gui di nhung tin nhan ma Template dang thu nhiem (Status='Draft') va no la ticket test (IsTest=1)
    ----              | Con nhung notification khac deu mark Status='Draft' tuc la se khong duoc gui di
    ----              | Thuong thi dang data nay chi duoc su dung khi test moi truong UAT
    UPDATE tmp
    SET tmp.Status = 'Planned'
    FROM #tmpNotificationFinalData tmp
    WHERE tmp.IsTest = 1
          AND tmp.Status = 'Draft'

    ----------------------------------------------------------
    ---- [06] Create Notification                           --
    ----      _ Run the while loop to create notification   --
    ----      _ Remember to insert data to secondary tables -- 
    ----------------------------------------------------------

    ---- Declare variables
    DECLARE @Sender         INT      = 10278938
    DECLARE @SendDate       DATETIME = GETDATE()
    DECLARE @NotificationId INT
    DECLARE @Id             INT = 1

    ---- Run the loop to process data
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
               REPLACE(nt.Content,'{Affected List}', r.AffectedList)                          Content,
               r.RelatedIds                                 RelatedNotificationIds,
               r.ChannelId                                  ChannelId
        FROM #tmpNotificationFinalData r
			INNER JOIN #tmpNotificationTemplateData nt 
				ON r.LanguageId = nt.LanguageId
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
             INNER JOIN #tmpNotificationFinalData r 
				ON r.ConversationGroupId = cgr.ConversationGroupId
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
				n.LastLogSID				ReferenceId,
               'SiteDB'+RIGHT('00' + CAST(r.SiteDBGroupID AS VARCHAR(2)), 2)+'.bodb02.dbo.SabaProgramStatus' AS DataSource,			   
               GETDATE()                    CreatedDate
        FROM #tmpNotificationFinalData r
			JOIN #NewLogSID n ON r.SiteDBGroupID = n.SiteDBGroupID
        WHERE r.Id = @Id

        -- + Update value column RelatedIds for Notification of Personal that be duplicate data with Group
        --   --> Ta can luu y la gia tri column RelatedNotificationIds cua bang crmNotification phai la gia tri NotificationID
        --   --> Va doan code nay giup giai quyet van de nay
        UPDATE r
        SET r.RelatedIds = RIGHT(LEFT(t.tmpRelatedIds, LEN(t.tmpRelatedIds) - 1), LEN(t.tmpRelatedIds) - 2)
        FROM #tmpNotificationFinalData r
             CROSS APPLY (
				SELECT tmpRelatedIds = REPLACE(','+r.RelatedIds+',' , ','+CONVERT(VARCHAR(20), @Id)+',' , ','+CONVERT(VARCHAR(20), @NotificationId)+',')
			 ) t
        WHERE r.Id > @Id
              AND r.ChatTypeId = 2
              AND ','+r.RelatedIds+',' LIKE '%,'+CONVERT(VARCHAR(20), @Id)+',%'

        -- + Set value to continue the loop
        SELECT @Id = @Id + 1
    END

    -----------------------------
    -- [07] Update job setting --

    BEGIN
		UPDATE s
        SET s.Value = CAST(@NewLogSID AS VARCHAR(300))
        FROM bodb_CRM.dbo.SystemSetting s WITH(ROWLOCK, UPDLOCK)
        WHERE s.ServiceName = @ServiceName
			AND s.SettingName = @SettingNameOfLastLogSID

        UPDATE s
        SET s.Value = 'Completed'
        FROM bodb_CRM.dbo.SystemSetting s WITH(ROWLOCK, UPDLOCK)
        WHERE s.ServiceName = @ServiceName
			AND s.SettingName = @SettingNameOfJobStatus
			AND s.Value = 'Running'
    END

    ---------------------------
    -- [08] Drop temp tables --

    DROP TABLE #tmpXMLData
	DROP TABLE #NewLogSID

    DROP TABLE #tmpNotificationTemplateSetting
    DROP TABLE #tmpNotificationTemplateData

    DROP TABLE #tmpNotificationMessageInfo
    DROP TABLE #tmpNotificationGroupChatInfo
    
    DROP TABLE #tmpNotificationPrepareData
    DROP TABLE #tmpNotificationFinalData

END

