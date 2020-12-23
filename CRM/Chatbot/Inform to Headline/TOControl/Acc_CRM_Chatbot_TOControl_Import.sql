/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_Chatbot_TOControl_Import]
	@XmlData		XML
	,@Environment	VARCHAR(50) = ''
	,@ErrCode		INT = 0 OUTPUT
	,@ErrMsg		NVARCHAR(4000) = '' OUTPUT
AS

/*
	Created: 20201214@Malcolm
	DB: DBCRM-bodb_CRM
	Task: CRM - ChatBot - Import Notification

	Revisions:
		- 20201214@Malcolm: Initialize SP [RedmineID: #130544]

	Param's Explanation:
		. @XmlData
			<root>
				<r LogId="1" MatchId="" CustId="46386637" Username="superrbRM2111" Recommend="46386636" Mrecommend="46386635" Srecommend="46386634" CurrencyName="UUS" RoleEN="RoleEN" RoleSC="RoleSC" RoleTH="RoleTH" RoleYN="RoleYN" SportNameEN="SportNameEN"  SportNameSC="SportNameSC"  SportNameTH="SportNameTH"  SportNameYN="SportNameYN" LeagueNameEN="LeagueNameEN" LeagueNameSC="LeagueNameSC" LeagueNameTH="LeagueNameTH" LeagueNameYN ="LeagueNameYN" HomeNameEN	="HomeNameEN" HomeNameSC="HomeNameSC" HomeNameTH="HomeNameTH" HomeNameYN="HomeNameYN" AwayNameEN="AwayNameEN" AwayNameSC="AwayNameSC" AwayNameTH="AwayNameTH" AwayNameYN="AwayNameYN" Outstanding="11" IsTest="0" </>
				<r LogId="2" MatchId="" CustId="46386637" Username="superrbRM2111" Recommend="46386636" Mrecommend="46386635" Srecommend="46386634" CurrencyName="UUS" RoleEN="RoleEN" RoleSC="RoleSC" RoleTH="RoleTH" RoleYN="RoleYN" SportNameEN="SportNameEN"  SportNameSC="SportNameSC"  SportNameTH="SportNameTH"  SportNameYN="SportNameYN" LeagueNameEN="LeagueNameEN" LeagueNameSC="LeagueNameSC" LeagueNameTH="LeagueNameTH" LeagueNameYN ="LeagueNameYN" HomeNameEN	="HomeNameEN" HomeNameSC="HomeNameSC" HomeNameTH="HomeNameTH" HomeNameYN="HomeNameYN" AwayNameEN="AwayNameEN" AwayNameSC="AwayNameSC" AwayNameTH="AwayNameTH" AwayNameYN="AwayNameYN" Outstanding="11" IsTest="0" </>
			</root>
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @Template_EN NVARCHAR(MAX), @Template_SC NVARCHAR(MAX), @Template_TH NVARCHAR(MAX), @Template_YN NVARCHAR(MAX), @Even_Info_EN NVARCHAR(MAX), @Even_Info_SC NVARCHAR(MAX), @Even_Info_TH NVARCHAR(MAX), @Even_Info_YN NVARCHAR(MAX)

	SELECT @Template_EN = N'Outstanding: {event_outstanding} ({currency_name})'+ CHAR(10) +'Sport: {sport_name_en}'+ CHAR(10) +'League: {league_name_en}'+ CHAR(10) +'Team: {home_name_en} -vs- {away_name_en}'
         ,@Template_SC = N'未结束交易额: {event_outstanding} ({currency_name})'+ CHAR(10) +'产品：{sport_name_sc}'+ CHAR(10) +'联赛：{league_name_sc}'+ CHAR(10) +'队名：{home_name_sc} -vs- {away_name_sc}'
		,@Template_TH= N'ยอดคงค้าง:  {event_outstanding} ({currency_name})'+ CHAR(10) +'โปรดักส์:  {sport_name_th}'+ CHAR(10) +'ลีก: {league_name_th}'+ CHAR(10) +'ชื่อทีม: {home_name_th} -vs- {away_name_th}'
		,@Template_YN = N'Số dư chưa xử lý: {event_outstanding} ({currency_name})'+ CHAR(10) +'Môn thể thao: {sport_name_yn}'+ CHAR(10) +'Giải đấu: {league_name_yn}'+ CHAR(10) +'Trận đấu: {home_name_yn} -vs- {away_name_yn}'

	DECLARE @SettingNameOfJobStatus VARCHAR(50) = '', @IncludeUUSCurrency BIT

	SELECT @IncludeUUSCurrency = CONVERT(BIT, Value) FROM SystemSetting WHERE ServiceName = 'ChatBot - TOControl' and SettingName = 'IncludeUUSCurrency'

	SELECT @Environment = ISNULL(@Environment, ''), @SettingNameOfJobStatus = CASE WHEN @Environment = 'UAT' THEN 'JobStatusUAT' ELSE 'JobStatus' END

	-- Get Job Status
	UPDATE dbo.SystemSetting WITH (ROWLOCK)
	SET Value = 'running'
	WHERE ServiceName = 'ChatBot - TOControl'
		AND SettingName = @SettingNameOfJobStatus
		AND Value = 'Completed'
	
	IF @@ROWCOUNT = 0
	BEGIN
		SELECT @ErrCode = 100, @ErrMsg = 'Job is running.'
		RETURN
	END

	-- Get Imported Data
	CREATE TABLE #ImportData
	(
		LogId					BIGINT
		,CustId					INT
		,MatchId				INT
		,Username				VARCHAR(30)
		,Recommend				INT
		,Mrecommend				INT
		,Srecommend				INT
		,CurrencyName			NVARCHAR(50)
		,RoleEN					NVARCHAR(50)
		,RoleSC					NVARCHAR(50)
		,RoleTH					NVARCHAR(50)
		,RoleYN					NVARCHAR(50)
		,SportNameEN			NVARCHAR(50)
		,SportNameSC			NVARCHAR(50)
		,SportNameTH			NVARCHAR(50)
		,SportNameYN			NVARCHAR(50)
		,LeagueNameEN			NVARCHAR(500)
		,LeagueNameSC			NVARCHAR(500)
		,LeagueNameTH			NVARCHAR(500)
		,LeagueNameYN			NVARCHAR(500)
		,HomeNameEN				NVARCHAR(100)
		,HomeNameSC				NVARCHAR(100)
		,HomeNameTH				NVARCHAR(100)
		,HomeNameYN				NVARCHAR(100)
		,AwayNameEN				NVARCHAR(100)
		,AwayNameSC				NVARCHAR(100)
		,AwayNameTH				NVARCHAR(100)
		,AwayNameYN				NVARCHAR(100)
		,Outstanding			MONEY
		,IsTest					BIT
	)
	INSERT INTO #ImportData 
	(
		LogId
		,CustId			
		,Username		
		,Recommend
		,Mrecommend
		,Srecommend
		,RoleEN	
		,RoleSC	
		,RoleTH	
		,RoleYN	
		,CurrencyName			
		,SportNameEN	
		,SportNameSC	
		,SportNameTH	
		,SportNameYN	
		,LeagueNameEN	
		,LeagueNameSC	
		,LeagueNameTH	
		,LeagueNameYN	
		,HomeNameEN		
		,HomeNameSC		
		,HomeNameTH		
		,HomeNameYN		
		,AwayNameEN		
		,AwayNameSC		
		,AwayNameTH		
		,AwayNameYN	
		,Outstanding
		,IsTest
	)
	SELECT
		t.c.value('@LogId', 'BIGINT')					AS LogId
		,t.c.value('@CustId', 'INT')					AS CustId
		,t.c.value('@Username', 'VARCHAR(30)')			AS Username
		,t.c.value('@Recommend', 'INT')					AS Recommend
		,t.c.value('@Mrecommend', 'INT')				AS Mrecommend
		,t.c.value('@Srecommend', 'INT')				AS Srecommend
		,t.c.value('@RoleEN', 'NVARCHAR(50)')			AS RoleEN
		,t.c.value('@RoleSC', 'NVARCHAR(50)')			AS RoleSC
		,t.c.value('@RoleTH', 'NVARCHAR(50)')			AS RoleTH
		,t.c.value('@RoleYN', 'NVARCHAR(50)')			AS RoleYN
		,t.c.value('@CurrencyName', 'NVARCHAR(50)')		AS CurrencyName
		,t.c.value('@SportNameEN', 'NVARCHAR(50)')		AS SportNameEN
		,t.c.value('@SportNameSC', 'NVARCHAR(50)')		AS SportNameSC
		,t.c.value('@SportNameTH', 'NVARCHAR(50)')		AS SportNameTH
		,t.c.value('@SportNameYN', 'NVARCHAR(50)')		AS SportNameYN
		,t.c.value('@LeagueNameEN', 'NVARCHAR(500)')	AS LeagueNameEN
		,t.c.value('@LeagueNameSC', 'NVARCHAR(500)')	AS LeagueNameSC
		,t.c.value('@LeagueNameTH', 'NVARCHAR(500)')	AS LeagueNameTH
		,t.c.value('@LeagueNameYN', 'NVARCHAR(500)')	AS LeagueNameYN
		,t.c.value('@HomeNameEN', 'NVARCHAR(100)')		AS HomeNameEN
		,t.c.value('@HomeNameSC', 'NVARCHAR(100)')		AS HomeNameSC
		,t.c.value('@HomeNameTH', 'NVARCHAR(100)')		AS HomeNameTH
		,t.c.value('@HomeNameYN', 'NVARCHAR(100)')		AS HomeNameYN
		,t.c.value('@AwayNameEN', 'NVARCHAR(100)')		AS AwayNameEN
		,t.c.value('@AwayNameSC', 'NVARCHAR(100)')		AS AwayNameSC
		,t.c.value('@AwayNameTH', 'NVARCHAR(100)')		AS AwayNameTH
		,t.c.value('@AwayNameYN', 'NVARCHAR(100)')		AS AwayNameYN
		,t.c.value('@Outstanding', 'MONEY')				AS Outstanding
		,t.c.value('@IsTest', 'BIT')					AS IsTest
	FROM @XmlData.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@XmlData = NULL))

	IF @@ROWCOUNT = 0
	BEGIN

		UPDATE dbo.SystemSetting WITH (ROWLOCK)
		SET Value = 'Completed'
		WHERE ServiceName = 'ChatBot - TOControl'
			AND SettingName = @SettingNameOfJobStatus
			AND Value = 'running'

		RETURN
	END

		-- Only import testing data for UAT environment
	IF @Environment = 'UAT'
	BEGIN
		DELETE i FROM #ImportData i WHERE i.IsTest = 0
	END

	--Exclude testing data if @IncludeUUSCurrency = 0 and @environment = 'LIVE'
	IF @Environment = 'LIVE' AND @IncludeUUSCurrency = 0
	BEGIN
		DELETE i FROM #ImportData i WHERE i.IsTest = 1
	END

	DELETE i
	FROM #ImportData i
	WHERE EXISTS(SELECT 1 FROM dbo.crmNotificationReference r WITH(NOLOCK) WHERE r.LogId = i.LogId AND r.DataSource = 'TOControl')

	-- Get Job Setting
	DECLARE @Xml XML
	SELECT  @Xml = CONVERT(XML, Value) FROM dbo.SystemSetting WITH (NOLOCK)
	WHERE ServiceName = 'ChatBot - TOControl'
		AND SettingName = 'NotificationTemplate'

	DECLARE @tmpSetting TABLE (NotificationTemplateId SMALLINT, NotificationTypeId SMALLINT, IsTest BIT, LanguageId INT, TemplateRequiredParam NVARCHAR(MAX))
	INSERT INTO @tmpSetting (NotificationTemplateId, NotificationTypeId, IsTest, LanguageId, TemplateRequiredParam)
	SELECT
		t.c.value('@NotificationTemplateID', 'SMALLINT') AS NotificationTemplateId
		,t.c.value('@NotificationTypeID', 'SMALLINT') AS NotificationTypeId
		,t.c.value('@IsTest', 'BIT') AS IsTest
		,t1.c.value('@LanguageId', 'INT') AS LanguageId
		,t1.c.value('@Value', 'NVARCHAR(MAX)') AS TemplateRequiredParam
	FROM @Xml.nodes('root/r') t(c)
		CROSS APPLY t.c.nodes('TemplateRequiredParam') t1(c)

	IF @@ROWCOUNT = 0
	BEGIN
		SELECT @ErrCode = 101, @ErrMsg = 'Invalid SystemSetting!'
		
		UPDATE dbo.SystemSetting WITH (ROWLOCK)
		SET Value = 'Completed'
		WHERE ServiceName = 'ChatBot - TOControl'
			AND SettingName = @SettingNameOfJobStatus
			AND Value = 'running'

		RETURN
	END

	-- Get Notification Template
	CREATE TABLE #NotificationTemplate (NotificationTypeId SMALLINT, NotificationTemplateId SMALLINT, Title NVARCHAR(2000), IsTest BIT, LanguageId INT, Content NVARCHAR(MAX))
	;WITH CTE_Setting AS (SELECT DISTINCT NotificationTemplateId, NotificationTypeId, IsTest FROM @tmpSetting)
	INSERT INTO #NotificationTemplate (NotificationTypeId, NotificationTemplateId, Title, IsTest, LanguageId, Content)
	SELECT s.NotificationTypeId, nt.NotificationTemplateId, nt.Title, s.IsTest, ntc.LanguageId, ntc.Content
	FROM CTE_Setting s
		INNER JOIN dbo.crmNotificationTemplate nt WITH (NOLOCK) ON s.NotificationTemplateId = nt.NotificationTemplateId
		INNER JOIN dbo.crmNotificationTemplateContent ntc WITH (NOLOCK) ON nt.NotificationTemplateId = ntc.NotificationTemplateId

	-- Get Recipient
	CREATE TABLE #Recipient
	(
		LogId BIGINT
		,Username VARCHAR(30)
		,DirectAccount INT
		,HeadlineId INT
		,IsTest BIT
		,RecipientId INT
	)
	INSERT INTO #Recipient (LogId, Username, DirectAccount, HeadlineId, IsTest, RecipientId)
	SELECT m.LogId, m.Username, pm.CustId, pm.HeadlineId, m.IsTest, r.RecipientId
	FROM #ImportData m
		INNER JOIN bodb02.dbo.CustDirectAccount cda WITH (NOLOCK) ON cda.CustId IN (m.CustId, m.Recommend, m.Mrecommend, m.Srecommend)
		INNER JOIN dbo.crmPicManagement pm WITH (NOLOCK) ON cda.CustId = pm.CustId
		INNER JOIN dbo.crmRecipient r WITH (NOLOCK) ON pm.PicId = r.SourceId AND r.DataSource = 'bodb_CRM.dbo.crmPIC'

	CREATE TABLE #LogRecipient
	(
		Username		VARCHAR(50)
		,DirectAccount	INT
		,HeadlineId		INT
		,IsTest			BIT
		,RecipientId	INT
	)

	;WITH CTE AS
	(
		SELECT Username, DirectAccount, HeadlineId, IsTest, RecipientId
		FROM #Recipient h
		GROUP BY Username, DirectAccount, HeadlineId, IsTest, RecipientId
	)
	INSERT INTO #LogRecipient(Username, DirectAccount, HeadlineId, IsTest, RecipientId)
	SELECT e.Username, e.DirectAccount, e.HeadlineId, e.IsTest, e.RecipientId
	FROM CTE e

	-- Get group to receive message
	CREATE TABLE #tmpGroup (Username VARCHAR(30),ConversationGroupId SMALLINT, ChatTypeId TINYINT, LanguageId INT, DirectAccount INT, NoRecipient INT)
	INSERT INTO #tmpGroup (Username, ConversationGroupId, DirectAccount, NoRecipient)
	SELECT m.Username ,cgr.ConversationGroupId, m.DirectAccount, COUNT(DISTINCT m.RecipientId) AS NoRecipient
	FROM #LogRecipient m
		INNER JOIN dbo.crmConversationGroupRecipient cgr WITH (NOLOCK) ON m.RecipientId = cgr.RecipientId
		INNER JOIN dbo.crmConversationGroupHeadline cgh WITH (NOLOCK) ON m.HeadlineId = cgh.HeadlineId AND cgr.ConversationGroupId = cgh.ConversationGroupId
		INNER JOIN dbo.crmConversationGroup cg WITH (NOLOCK) ON cgr.ConversationGroupId = cg.ConversationGroupId
	WHERE cg.IsActive = 1
	GROUP BY m.Username, cgr.ConversationGroupId, m.DirectAccount

	;WITH CTE_Group AS
	(
		SELECT DISTINCT ConversationGroupId FROM #tmpGroup
	)
	,CTE_GroupPIC AS
	(
		SELECT ConversationGroupId, COUNT(1) AS NoRecipient
		FROM dbo.crmConversationGroupRecipient cgr WITH (NOLOCK)
		WHERE EXISTS (SELECT 1 FROM CTE_Group g WHERE g.ConversationGroupId = cgr.ConversationGroupId)
		GROUP BY ConversationGroupId
	)
	DELETE t
	FROM #tmpGroup t
		INNER JOIN CTE_GroupPIC g ON t.ConversationGroupId = g.ConversationGroupId
	WHERE t.NoRecipient < g.NoRecipient

	UPDATE t
	SET t.ChatTypeId = cg.ChatTypeId, t.LanguageId = cg.LanguageId
	FROM #tmpGroup t
		INNER JOIN dbo.crmConversationGroup cg WITH (NOLOCK) ON t.ConversationGroupId = cg.ConversationGroupId

	CREATE TABLE #tmpResult (Username VARCHAR(30), ConversationGroupId SMALLINT, ChatTypeId TINYINT, LanguageId INT, HeadlineId INT, IsTest BIT)
	INSERT INTO #tmpResult (Username, ConversationGroupId, ChatTypeId, LanguageId, HeadlineId, IsTest)
	SELECT m.Username, g.ConversationGroupId, g.ChatTypeId, g.LanguageId, m.HeadlineId, m.IsTest
	FROM #LogRecipient m
		INNER JOIN #tmpGroup g ON m.Username = g.Username AND m.DirectAccount = g.DirectAccount
		INNER JOIN dbo.crmConversationGroupRecipient cgr WITH (NOLOCK) ON m.RecipientId = cgr.RecipientId AND g.ConversationGroupId = cgr.ConversationGroupId 
		INNER JOIN dbo.crmConversationGroupHeadline cgh WITH (NOLOCK) ON m.HeadlineId = cgh.HeadlineId AND g.ConversationGroupId = cgh.ConversationGroupId

	CREATE TABLE #Result
	(
		Id						INT IDENTITY(1, 1)
		,Username               VARCHAR(30)
		,IsTest					BIT
		,ConversationGroupId	SMALLINT
		,ChatTypeId				TINYINT
		,LanguageId				INT
		,HeadlineList			VARCHAR(MAX)
		,Status					VARCHAR(20)
		,RelatedIds				VARCHAR(1000)
	)
	--CustId MatchId NotifiedPercentValue
	DECLARE @Status VARCHAR(20) = 'Planned'
	IF EXISTS (SELECT 1 FROM #NotificationTemplate WHERE IsTest = 1)
		SET @Status = 'Draft'

	-- For Group
	INSERT INTO #Result (Username, ConversationGroupId, ChatTypeId, LanguageId, HeadlineList, IsTest, Status)
	SELECT Username, ConversationGroupId, ChatTypeId, LanguageId, HeadlineList, IsTest, @Status
	FROM (
		SELECT Username, ConversationGroupId, ChatTypeId, LanguageId
			,STUFF(
					(SELECT DISTINCT ',' + CONVERT(VARCHAR(20), HeadlineId)
						FROM #tmpResult t2
						WHERE t1.Username = t2.Username AND t1.ConversationGroupId = t2.ConversationGroupId
						FOR XML PATH ('')
					), 1, 1, ''
				) AS HeadlineList
			,MAX(CONVERT(TINYINT, t1.IsTest)) AS IsTest
		FROM #tmpResult t1
		WHERE t1.ChatTypeId = 1 -- Group
		GROUP BY Username , ConversationGroupId, ChatTypeId, LanguageId
	) t

	-- For Personal
	;WITH CTE_tmpPersonal AS (
		SELECT P.Username, p.ConversationGroupId, p.ChatTypeId, p.LanguageId, p.HeadlineId, p.IsTest, t.Id AS RelatedId
		FROM #tmpResult p
			OUTER APPLY (
				SELECT DISTINCT r.Id
				FROM dbo.crmConversationGroupRecipient cgr1 WITH (NOLOCK)
					INNER JOIN dbo.crmConversationGroupRecipient cgr2 WITH (NOLOCK) ON cgr2.RecipientId = cgr1.RecipientId
					INNER JOIN #tmpResult g ON g.ConversationGroupId = cgr2.ConversationGroupId
					INNER JOIN #Result r ON g.Username = r.Username AND g.ConversationGroupId = r.ConversationGroupId
				WHERE p.ConversationGroupId = cgr1.ConversationGroupId AND p.Username = g.Username AND p.Username = g.Username AND g.ChatTypeId = 1 -- Group
			) t
		WHERE p.ChatTypeId = 2 -- Personal
	)
	,CTE_tempResult AS (
		SELECT ConversationGroupId, ChatTypeId, LanguageId, Username, HeadlineId, IsTest
			,CASE WHEN t1.RelatedId IS NULL THEN 0 ELSE 1 END AS IsDuplicated
			,STUFF(
					(SELECT DISTINCT ',' + CONVERT(VARCHAR(20), t2.RelatedId)
						FROM CTE_tmpPersonal t2
						WHERE t1.Username = t2.Username AND t1.ConversationGroupId = t2.ConversationGroupId
						FOR XML PATH ('')
					), 1, 1, ''
				) AS RelatedIds
		FROM CTE_tmpPersonal t1
		GROUP BY ConversationGroupId, ChatTypeId, LanguageId, Username, HeadlineId, IsTest
		,CASE WHEN t1.RelatedId IS NULL THEN 0 ELSE 1 END
	)
	INSERT INTO #Result (Username , ConversationGroupId, ChatTypeId, LanguageId, HeadlineList, IsTest, Status, RelatedIds)
	SELECT Username, ConversationGroupId, ChatTypeId, LanguageId, HeadlineList, IsTest, CASE WHEN IsDuplicated = 1 THEN 'Duplicated' ELSE @Status END, CASE WHEN IsDuplicated = 1 THEN RelatedIds END
	FROM (
		SELECT Username, ConversationGroupId, ChatTypeId, LanguageId, IsDuplicated
			,STUFF(
					(SELECT DISTINCT ',' + CONVERT(VARCHAR(20), t2.HeadlineId)
						FROM CTE_tempResult t2
						WHERE t1.Username = t2.Username AND t1.ConversationGroupId = t2.ConversationGroupId AND t1.IsDuplicated = t2.IsDuplicated
						FOR XML PATH ('')
					), 1, 1, ''
				) AS HeadlineList
			,STUFF(
					(SELECT DISTINCT ',' + t2.RelatedIds
						FROM CTE_tempResult t2
						WHERE t1.Username = t2.Username AND t1.ConversationGroupId = t2.ConversationGroupId AND t1.IsDuplicated = t2.IsDuplicated
						FOR XML PATH ('')
					), 1, 1, ''
				) AS RelatedIds
			,MAX(CONVERT(TINYINT, t1.IsTest)) AS IsTest
		FROM CTE_tempResult t1
		GROUP BY Username, ConversationGroupId, ChatTypeId, LanguageId, IsDuplicated
	) t

	UPDATE #Result SET Status = 'Planned' WHERE IsTest = 1 AND Status = 'Draft'

	-- Import Notification
	DECLARE @Sender				INT = 10278938 -- StarixIT
			,@SendDate			DATETIME = GETDATE()
			,@NotificationId	INT
			,@Id				INT = 1
			,@Username			VARCHAR(30)

	WHILE 1 = 1
	BEGIN
		IF NOT EXISTS (SELECT 1 FROM #Result WHERE Id = @Id)
			BREAK

		SELECT @Even_Info_EN = '', @Even_Info_SC = '', @Even_Info_TH = '', @Even_Info_YN = ''

		SELECT @Username = Username FROM #Result WHERE Id = @Id

		;WITH CTE AS
		(
			SELECT DISTINCT MatchID, Username FROM #ImportData i WHERE i.Username = @Username
		)
		SELECT @Even_Info_EN += REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@Template_EN,'{event_outstanding}', i.Outstanding),'{currency_name}', i.CurrencyName),'{sport_name_en}', i.SportNameEN),'{league_name_en}', i.LeagueNameEN),'{home_name_en}', i.HomeNameEN),'{away_name_en}', i.awayNameEN) + CHAR(10) + CHAR(10)
				,@Even_Info_SC += REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@Template_SC,'{event_outstanding}', i.Outstanding),'{currency_name}', i.CurrencyName),'{sport_name_sc}', i.SportNameSC),'{league_name_sc}', i.LeagueNameSC),'{home_name_sc}', i.HomeNameSC),'{away_name_sc}', i.AwayNameSC) + CHAR(10) + CHAR(10)
				,@Even_Info_TH += REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@Template_TH,'{event_outstanding}', i.Outstanding),'{currency_name}', i.CurrencyName),'{sport_name_th}', i.SportNameTH),'{league_name_th}', i.LeagueNameTH),'{home_name_th}', i.HomeNameTH),'{away_name_th}', i.awayNameth) + CHAR(10) + CHAR(10)
				,@Even_Info_YN += REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@Template_YN,'{event_outstanding}', i.Outstanding),'{currency_name}', i.CurrencyName),'{sport_name_yn}', i.SportNameYN),'{league_name_yn}', i.LeagueNameYN),'{home_name_yn}', i.HomeNameYN),'{away_name_yn}', i.AwayNameYN) + CHAR(10) + CHAR(10)
		FROM CTE e
		CROSS APPLY(
			SELECT TOP 1 * FROM #ImportData i WHERE i.Username = e.Username AND i.MatchId = e.MatchId
			ORDER BY i.LogId DESC
		) i	

		INSERT INTO dbo.crmNotification (ReferenceId, DataSource,NotificationTypeId, Sender, SendDate, Title, Status, Content, RelatedNotificationIds)
		SELECT -1 ,'TOControl',nt.NotificationTypeId, @Sender, @SendDate, nt.Title, r.Status
			,REPLACE(REPLACE(REPLACE(REPLACE(nt.Content, '{event_info_en}', @Even_Info_EN), '{event_info_sc}', @Even_Info_SC), '{event_info_th}', @Even_Info_TH), '{event_info_yn}', @Even_Info_YN)
			,r.RelatedIds
		FROM #Result r
			INNER JOIN #NotificationTemplate nt ON r.LanguageId = nt.LanguageId
		WHERE r.Id = @Id

		SELECT @NotificationId = SCOPE_IDENTITY()

		INSERT INTO dbo.crmNotificationGroup (NotificationId, ConversationGroupId, Status)
		SELECT @NotificationId, ConversationGroupId, Status
		FROM #Result
		WHERE Id = @Id

		INSERT INTO dbo.crmNotificationRecipient (NotificationId, RecipientId, ConversationGroupId)
		SELECT @NotificationId, cgr.RecipientId, r.ConversationGroupId
		FROM dbo.crmConversationGroupRecipient cgr WITH (NOLOCK)
			INNER JOIN #Result r ON r.ConversationGroupId = cgr.ConversationGroupId
		WHERE r.Id = @Id

		INSERT INTO dbo.crmNotificationHeadline (NotificationId, HeadlineId)
		SELECT DISTINCT @NotificationId, f.val
		FROM #Result r
			CROSS APPLY dbo.f_CRM_strSplit(r.HeadlineList, ',') f
		WHERE r.Id = @Id

		UPDATE r
		SET r.RelatedIds = RIGHT(LEFT(t.tmpRelatedIds, LEN(t.tmpRelatedIds) - 1), LEN(t.tmpRelatedIds) - 2)
		FROM #Result r
			CROSS APPLY (
				SELECT tmpRelatedIds = REPLACE(',' + r.RelatedIds + ',', ',' + CONVERT(VARCHAR(20), @Id) + ',', ',' + CONVERT(VARCHAR(20), @NotificationId) + ',')
			) t
		WHERE r.Id > @Id
			AND r.ChatTypeId = 2
			AND ',' + r.RelatedIds + ',' LIKE '%,' + CONVERT(VARCHAR(20), @Id) + ',%'

		INSERT INTO dbo.crmNotificationReference (LogId, NotificationId, DataSource)
		SELECT LogId, @NotificationId, 'TOControl'
		FROM #ImportData i
		WHERE i.Username = @Username

		SELECT @Id = @Id + 1
	END

	 --Update crmMessageImport

	UPDATE dbo.SystemSetting WITH (ROWLOCK)
	SET Value = 'Completed'
	WHERE ServiceName = 'ChatBot - AbnormalBets'
		AND SettingName = @SettingNameOfJobStatus
		AND Value = 'running'

	DROP TABLE #ImportData
	DROP TABLE #Recipient
	DROP TABLE #NotificationTemplate
	DROP TABLE #Result
	DROP TABLE #tmpGroup
	DROP TABLE #tmpResult
END
GO