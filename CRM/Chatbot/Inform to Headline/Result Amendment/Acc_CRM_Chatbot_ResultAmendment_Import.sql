/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_Chatbot_ResultAmendment_Import]
	@TicketData				XML
	,@EventData				XML
	,@MessageData           XML
	,@Environment			VARCHAR(50) = ''
	,@ErrCode				INT = 0 OUTPUT
	,@ErrMsg				NVARCHAR(4000) = '' OUTPUT
AS

/*
	Created: 20210731@Malcolm
	DB: DBCRM-bodb_CRM
	Task: CRM - CWL - Import Notification

	Revisions:
		- 20210731@Malcolm: Initialize SP [RedmineID: #151509]
	Param's Explanation:
		. @TicketData
			<root>
				<r TicketId="1" TicketEventId="" CustId="114"  Username="XXX" Recommend="113" Mrecommend="112" Srecommend="111" IsTest="0" />
			</root>

		. @EventData
			<root>
				<r TicketEventId="" ProductId="1" EventDate="1" EventType="1" ActualResult="1" WrongResult="1" MessageId="1"  SportNameEN="SB"  SportNameSC="SB"  SportNameTH="SB"  SportNameYN="SB" HomeNameEN="SB"  HomeNameSC="SB"  HomeNameTH="SB"  HomeNameYN="SB" AwayNameEN="SB"  AwayNameSC="SB"  AwayNameTH="SB"  AwayNameYN="SB" LeagueNameEN="SB"  LeagueNameSC="SB"  LeagueNameTH="SB"  LeagueNameYN="SB" MatchCode ="" Type=""
				/>
			</root>

		. @MessageData
			<root>
				<r TicketEventId="1" MessageId="" Content_en="" Content_cs="" Content_th="" Content_yn=""/>
			</root>
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @lastLogId BIGINT, @SettingNameOfJobStatus VARCHAR(50) = '',@SettingNameOflastLogId VARCHAR(50) = '', @IncludeUUSCurrency BIT

	DECLARE @MaxGroup INT = 0, @MaxBatchOfGroup INT = 250

	SELECT @IncludeUUSCurrency = CONVERT(BIT, Value) FROM SystemSetting WHERE ServiceName = 'ChatBot - CWL' and SettingName = 'IncludeUUSCurrency'

	SELECT @Environment = ISNULL(@Environment, '')
		   ,@SettingNameOfJobStatus = CASE WHEN @Environment = 'UAT' THEN 'JobStatusUAT' ELSE 'JobStatus' END
		   ,@SettingNameOflastLogId = CASE WHEN @Environment = 'UAT' THEN 'LastLogIdUAT' ELSE 'LastLogID' END

	-- Get Job Status
	UPDATE dbo.SystemSetting WITH (ROWLOCK)
	SET Value = 'running'
	WHERE ServiceName = 'ChatBot - CWL'
		AND SettingName = @SettingNameOfJobStatus
		AND Value = 'Completed'
	
	IF @@ROWCOUNT = 0
	BEGIN
		SELECT @ErrCode = 100, @ErrMsg = 'Job is running.'
		RETURN
	END

	CREATE TABLE #EventData
	(
		TicketEventId	INT
		,ProductId		TINYINT
		,EventDate		SMALLDATETIME
		,EventType		TINYINT
		,ActualResult	NVARCHAR(MAX)
		,WrongResult	NVARCHAR(MAX)
		,MessageId		INT
		,SportNameEN	NVARCHAR(50)
		,SportNameSC	NVARCHAR(50)
		,SportNameTH	NVARCHAR(50)
		,SportNameYN	NVARCHAR(50)
		,HomeNameEN		NVARCHAR(100)
		,HomeNameSC		NVARCHAR(100) 
		,HomeNameTH		NVARCHAR(100)
		,HomeNameYN		NVARCHAR(100)
		,AwayNameEN		NVARCHAR(100)
		,AwayNameSC		NVARCHAR(100)
		,AwayNameTH		NVARCHAR(100)
		,AwayNameYN		NVARCHAR(100)
		,LeagueNameEN	NVARCHAR(500)
		,LeagueNameSC	NVARCHAR(500)
		,LeagueNameTH	NVARCHAR(500)
		,LeagueNameYN	NVARCHAR(500)
		,MatchCode		NVARCHAR(500)
		,[Type]			TINYINT
	)
	-- Get Imported Data
	INSERT INTO #EventData
	(
		TicketEventId 
		,ProductId 
		,EventDate 
		,EventType 
		,ActualResult 
		,WrongResult 
		,MessageId 
		,SportNameEN 
		,SportNameSC 
		,SportNameTH
		,SportNameYN
		,HomeNameEN 
		,HomeNameSC 
		,HomeNameTH 
		,HomeNameYN 
		,AwayNameEN 
		,AwayNameSC 
		,AwayNameTH 
		,AwayNameYN 
		,LeagueNameEN 
		,LeagueNameSC 
		,LeagueNameTH 
		,LeagueNameYN 
		,MatchCode
		,Type 
	)
	SELECT
		t.c.value('@TicketEventId ', 'INT') AS TicketEventId
		,t.c.value('@ProductId', 'INT') AS ProductId
		,t.c.value('@EventDate', 'DATETIME') AS EventDate
		,t.c.value('@EventType', 'INT') AS EventType
		,t.c.value('@ActualResult', 'NVARCHAR(MAX)') AS ActualResult
		,t.c.value('@WrongResult', 'NVARCHAR(MAX)') AS WrongResult
		,t.c.value('@MessageId', 'INT') AS MessageId
		,t.c.value('@SportNameEN', 'NVARCHAR(50)') AS SportNameEN
		,t.c.value('@SportNameSC', 'NVARCHAR(50)') AS SportNameSC
		,t.c.value('@SportNameTH', 'NVARCHAR(50)') AS SportNameTH
		,t.c.value('@SportNameYN', 'NVARCHAR(50)') AS SportNameYN
		,t.c.value('@HomeNameEN', 'NVARCHAR(100)') AS HomeNameEN
		,t.c.value('@HomeNameSC', 'NVARCHAR(100)') AS HomeNameSC
		,t.c.value('@HomeNameTH', 'NVARCHAR(100)') AS HomeNameTH
		,t.c.value('@HomeNameYN', 'NVARCHAR(100)') AS HomeNameYN
		,t.c.value('@AwayNameEN', 'NVARCHAR(100)') AS AwayNameEN
		,t.c.value('@AwayNameSC', 'NVARCHAR(100)') AS AwayNameSC
		,t.c.value('@AwayNameTH', 'NVARCHAR(100)') AS AwayNameTH
		,t.c.value('@AwayNameYN', 'NVARCHAR(100)') AS AwayNameYN
		,t.c.value('@LeagueNameEN', 'NVARCHAR(500)') AS LeagueNameEN
		,t.c.value('@LeagueNameSC', 'NVARCHAR(500)') AS LeagueNameSC
		,t.c.value('@LeagueNameTH', 'NVARCHAR(500)') AS LeagueNameTH
		,t.c.value('@LeagueNameYN', 'NVARCHAR(500)') AS LeagueNameYN
		,t.c.value('@MatchCode', 'NVARCHAR(500)') AS MatchCode
		,t.c.value('@Type', 'TINYINT') AS Type
	FROM @EventData.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@EventData = NULL))

	CREATE TABLE #MessageData(TicketEventId INT,MessageId INT,Content_en NVARCHAR(200),Content_cs NVARCHAR(200),Content_th NVARCHAR(200),Content_yn NVARCHAR(200))
	INSERT INTO #MessageData (TicketEventId ,MessageId ,Content_en ,Content_cs ,Content_th ,Content_yn)
	SELECT 
		t.c.value('@TicketEventId', 'INT') AS TicketEventId
		,t.c.value('@MessageId', 'INT') AS MessageId
		,t.c.value('@Content_en', 'NVARCHAR(4000)') AS Content_en
		,t.c.value('@Content_cs', 'NVARCHAR(4000)') AS Content_cs
		,t.c.value('@Content_th', 'NVARCHAR(4000)') AS Content_th
		,t.c.value('@Content_yn', 'NVARCHAR(4000)') AS Content_yn
	FROM @MessageData.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@MessageData = NULL))

	CREATE TABLE #TicketData (TicketId INT,TicketEventId INT,CustId INT,Username VARCHAR(30),Recommend INT,Mrecommend INT,Srecommend INT,IsTest BIT)
	INSERT INTO #TicketData (TicketId, TicketEventId, CustId, Username, Recommend, Mrecommend, Srecommend, IsTest)
	SELECT
		t.c.value('@TicketId', 'BIGINT') AS TicketId
		,t.c.value('@TicketEventId', 'INT') AS TicketEventId
		,t.c.value('@CustId', 'INT') AS CustId
		,t.c.value('@Username', 'VARCHAR(30)') AS Username
		,t.c.value('@Recommend', 'INT') AS Recommend
		,t.c.value('@Mrecommend', 'INT') AS Mrecommend
		,t.c.value('@Srecommend', 'INT') AS Srecommend
		,t.c.value('@IsTest', 'BIT') AS IsTest
	FROM @TicketData.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@TicketData = NULL))

	IF @@ROWCOUNT = 0
	BEGIN	
		UPDATE dbo.SystemSetting WITH (ROWLOCK)
		SET Value = 'Completed'
		WHERE ServiceName = 'ChatBot - CWL'
			AND SettingName = @SettingNameOfJobStatus
			AND Value = 'running'

		RETURN
	END

	SELECT @lastLogId = MAX(TicketId) FROM #TicketData

		-- Only import testing accounts with uat environment
	IF @Environment = 'UAT'
	BEGIN
		DELETE i FROM #TicketData i WHERE i.IsTest = 0
	END
	--Exclude UUS currency with LIVE environment

	IF @Environment = 'LIVE' AND @IncludeUUSCurrency = 0
	BEGIN
		DELETE i FROM #TicketData i WHERE i.IsTest = 0
	END

	-- Get Job Setting
	DECLARE @Xml XML
	SELECT  @Xml = CONVERT(XML, Value) FROM dbo.SystemSetting WITH (NOLOCK)
	WHERE ServiceName = 'ChatBot - CWL'
		AND SettingName = 'NotificationTemplate'

	DECLARE @tmpSetting TABLE (NotificationTemplateId SMALLINT, NotificationTypeId SMALLINT, IsTest BIT, LanguageId INT, TemplateRequiredParam NVARCHAR(MAX), [Type] TINYINT)
	INSERT INTO @tmpSetting (NotificationTemplateId, NotificationTypeId, IsTest, LanguageId, TemplateRequiredParam, [Type])
	SELECT
		t.c.value('@NotificationTemplateID', 'SMALLINT') AS NotificationTemplateId
		,t.c.value('@NotificationTypeID', 'SMALLINT') AS NotificationTypeId
		,t.c.value('@IsTest', 'BIT') AS IsTest
		,t1.c.value('@LanguageId', 'INT') AS LanguageId
		,t1.c.value('@Value', 'NVARCHAR(MAX)') AS TemplateRequiredParam
		,t.c.value('@Type', 'TINYINT') AS [Type]
	FROM @Xml.nodes('root/r') t(c)
		CROSS APPLY t.c.nodes('TemplateRequiredParam') t1(c)

	IF @@ROWCOUNT = 0
	BEGIN
		SELECT @ErrCode = 101, @ErrMsg = 'Invalid SystemSetting!'
		
		UPDATE dbo.SystemSetting WITH (ROWLOCK)
		SET Value = 'Completed'
		WHERE ServiceName = 'ChatBot - CWL'
			AND SettingName = @SettingNameOfJobStatus
			AND Value = 'running'

		RETURN
	END

	-- Get Notification Template
	CREATE TABLE #NotificationTemplate (NotificationTypeId SMALLINT, NotificationTemplateId SMALLINT, Title NVARCHAR(2000), IsTest BIT, LanguageId INT, Content NVARCHAR(MAX), [Type] TINYINT)
	;WITH CTE_Setting AS (SELECT DISTINCT NotificationTemplateId, NotificationTypeId, IsTest, [Type] FROM @tmpSetting)
	INSERT INTO #NotificationTemplate (NotificationTypeId, NotificationTemplateId, Title, IsTest, LanguageId, Content, [Type])
	SELECT s.NotificationTypeId, nt.NotificationTemplateId, nt.Title, s.IsTest, ntc.LanguageId, ntc.Content, s.[Type]
	FROM CTE_Setting s
		INNER JOIN dbo.crmNotificationTemplate nt WITH (NOLOCK) ON s.NotificationTemplateId = nt.NotificationTemplateId
		INNER JOIN dbo.crmNotificationTemplateContent ntc WITH (NOLOCK) ON nt.NotificationTemplateId = ntc.NotificationTemplateId

	-- Check require param
	IF EXISTS (
		SELECT 1
		FROM @tmpSetting s
			INNER JOIN #NotificationTemplate nt
				ON		s.NotificationTemplateId = nt.NotificationTemplateId
					AND s.NotificationTypeId = nt.NotificationTypeId
					AND s.LanguageId = nt.LanguageId
		WHERE nt.Content NOT LIKE N'%' + s.TemplateRequiredParam + N'%'
	)
	BEGIN
		SELECT @ErrCode = 102, @ErrMsg = 'Notification Template Content(s) are not include Required Param(s)'
		
		UPDATE dbo.SystemSetting WITH (ROWLOCK)
		SET Value = 'Completed'
		WHERE ServiceName = 'ChatBot - CWL'
			AND SettingName = @SettingNameOfJobStatus
			AND Value = 'running'

		RETURN
	END

	IF NOT EXISTS (SELECT 1 FROM #TicketData)
	BEGIN
		UPDATE dbo.SystemSetting WITH (ROWLOCK)
		SET Value = CONVERT(VARCHAR(20), @lastLogId)
		WHERE ServiceName = 'ChatBot - CWL'
			AND SettingName = @SettingNameOflastLogId

		UPDATE dbo.SystemSetting WITH (ROWLOCK)
		SET Value = 'Completed'
		WHERE ServiceName = 'ChatBot - CWL'
			AND SettingName = @SettingNameOfJobStatus
			AND Value = 'running'

		RETURN
	END

	-- Get Recipient
	CREATE TABLE #LogRecipient (TicketId INT,TicketEventId INT,Username VARCHAR(30),DirectAccount INT,HeadlineId INT,RecipientId INT,IsTest BIT)
	INSERT INTO #LogRecipient (TicketId, TicketEventId, Username, DirectAccount, HeadlineId, RecipientId, IsTest)
	SELECT m.TicketId, m.TicketEventId, m.Username, pm.CustId, pm.HeadlineId, r.RecipientId, m.IsTest
	FROM #TicketData m
		INNER JOIN bodb02.dbo.CustDirectAccount cda WITH (NOLOCK) ON cda.CustId IN (m.CustId, m.Recommend, m.Mrecommend, m.Srecommend)
		INNER JOIN dbo.crmPicManagement pm WITH (NOLOCK) ON cda.CustId = pm.CustId
		INNER JOIN dbo.crmRecipient r WITH (NOLOCK) ON pm.PicId = r.SourceId AND r.DataSource = 'bodb_CRM.dbo.crmPIC'
	
	-- Get group to receive message
	CREATE TABLE #tmpGroup (TicketId INT, TicketEventId INT, ConversationGroupId SMALLINT, ChatTypeId TINYINT, LanguageId INT, DirectAccount INT, NoRecipient INT)
	INSERT INTO #tmpGroup (TicketId, TicketEventId, ConversationGroupId, DirectAccount, NoRecipient)
	SELECT m.TicketId, m.TicketEventId, cgr.ConversationGroupId, m.DirectAccount, COUNT(DISTINCT m.RecipientId) AS NoRecipient
	FROM #LogRecipient m
		INNER JOIN dbo.crmConversationGroupRecipient cgr WITH (NOLOCK) ON m.RecipientId = cgr.RecipientId
		INNER JOIN dbo.crmConversationGroupHeadline cgh WITH (NOLOCK) ON m.HeadlineId = cgh.HeadlineId AND cgr.ConversationGroupId = cgh.ConversationGroupId
		INNER JOIN dbo.crmConversationGroup cg WITH (NOLOCK) ON cgr.ConversationGroupId = cg.ConversationGroupId
	WHERE cg.IsActive = 1
	GROUP BY m.TicketId, m.TicketEventId, cgr.ConversationGroupId, m.DirectAccount

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

	CREATE TABLE #tmpResult 
	(
		Id						INT 
		,TicketId				INT 
		,TicketEventId			INT
		,ConversationGroupId	SMALLINT
		,ChatTypeId				TINYINT
		,LanguageId				INT
		,Username				VARCHAR(50)
		,HeadlineId				INT
		,IsDuplicated			BIT
		,RelatedIds				NVARCHAR(MAX)
		,IsTest					BIT
		,PICTye					TINYINT DEFAULT 0 -- 1 for accouting pic
	)
	INSERT INTO #tmpResult (TicketId, TicketEventId, ConversationGroupId, ChatTypeId, LanguageId, Username, HeadlineId, IsDuplicated, IsTest)
	SELECT m.TicketId, m.TicketEventId, g.ConversationGroupId, g.ChatTypeId, g.LanguageId, m.Username, m.HeadlineId, 0, m.IsTest
	FROM #LogRecipient m
		INNER JOIN #tmpGroup g ON m.TicketId = g.TicketId AND m.DirectAccount = g.DirectAccount
		INNER JOIN dbo.crmConversationGroupRecipient cgr WITH (NOLOCK) ON m.RecipientId = cgr.RecipientId AND g.ConversationGroupId = cgr.ConversationGroupId 
		INNER JOIN dbo.crmConversationGroupHeadline cgh WITH (NOLOCK) ON m.HeadlineId = cgh.HeadlineId AND g.ConversationGroupId = cgh.ConversationGroupId

	UPDATE t
		SET t.IsDuplicated = 1
	FROM #tmpResult t
	WHERE EXISTS (SELECT 1 FROM #tmpResult g WHERE g.ChatTypeId = 1 AND g.TicketId = t.TicketId) AND t.ChatTypeId = 2

	---- For Accounting PIC
	DECLARE @Group TABLE (ConversationGroupId SMALLINT, LanguageId INT, ChatTypeId TINYINT)

	INSERT INTO @Group (ConversationGroupId, LanguageId, ChatTypeId)
	SELECT DISTINCT g.ConversationGroupId, g.LanguageId, 2
	FROM dbo.crmConversationGroup g WITH(NOLOCK)
		INNER JOIN dbo.crmConversationGroupRecipient cgr WITH(NOLOCK) ON cgr.ConversationGroupId = g.ConversationGroupId
		INNER JOIN dbo.crmRecipient r WITH(NOLOCK) ON r.RecipientId = cgr.RecipientId
		INNER JOIN dbo.crmRecipientType rt WITH(NOLOCK) ON rt.RecipientTypeId = r.RecipientTypeId
	WHERE rt.RecipientTypeName = 'Accouting PIC' AND g.ChatTypeId = 2 -- Personal

	INSERT INTO #tmpResult (TicketId, TicketEventId, ConversationGroupId, ChatTypeId, LanguageId, Username, HeadlineId, IsDuplicated, IsTest, PICTye)
	SELECT t.TicketId, t.TicketEventId, g.ConversationGroupId, g.ChatTypeId, g.LanguageId, t.Username, ISNULL(cgh.CustID, 0) AS HeadlineId, 0, t.IsTest, 1
	FROM @Group g 
		CROSS JOIN #TicketData t 
		INNER JOIN bodb02.dbo.CustDirectAccount cda WITH(NOLOCK) ON cda.CustID IN (t.CustId, t.Recommend, t.Mrecommend, t.Srecommend)
		LEFT JOIN bodb02.dbo.custAccount ca WITH(NOLOCK) ON ca.custid = cda.CustID
		LEFT JOIN bodb02.dbo.CustGroupHeadline cgh WITH(NOLOCK) ON cgh.GroupID = ca.groupID
	
	CREATE TABLE #Result
	(
		Id						INT
		,LogIdLst				NVARCHAR(MAX)
		,ConversationGroupId	SMALLINT
		,ChatTypeId				TINYINT
		,LanguageId				INT
		,Status					VARCHAR(20)
		,EventDate				DATETIME
		,ActualResult			NVARCHAR(MAX)
		,WrongResult			NVARCHAR(MAX)
		,SportNameEN			NVARCHAR(50)
		,SportNameSC			NVARCHAR(50)
		,SportNameTH			NVARCHAR(50)
		,SportNameYN			NVARCHAR(50)
		,HomeNameEN				NVARCHAR(100)
		,HomeNameSC				NVARCHAR(100)
		,HomeNameTH				NVARCHAR(100)
		,HomeNameYN				NVARCHAR(100)
		,AwayNameEN				NVARCHAR(100)
		,AwayNameSC				NVARCHAR(100)
		,AwayNameTH				NVARCHAR(100)
		,AwayNameYN				NVARCHAR(100)
		,LeagueNameEN			NVARCHAR(500)
		,LeagueNameSC			NVARCHAR(500)
		,LeagueNameTH			NVARCHAR(500)
		,LeagueNameYN			NVARCHAR(500)
		,ContentEN				NVARCHAR(MAX)
		,ContentSC				NVARCHAR(MAX)
		,ContentTH				NVARCHAR(MAX)
		,ContentYN				NVARCHAR(MAX)
		,ContentENSC			NVARCHAR(MAX)
		,HeadlineList			NVARCHAR(MAX)
		,RelatedIds				VARCHAR(1000)
		,UsernameLst			NVARCHAR(MAX)
		,MatchCode	            NVARCHAR(500)
		,[Type]					TINYINT
	)

	DECLARE @Status VARCHAR(20) = 'Planned'
	IF EXISTS (SELECT 1 FROM #NotificationTemplate WHERE IsTest = 1)
		SET @Status = 'Draft'

	-- For Group, Personal Which have IsDuplicated = 0
	;WITH CTE_Batch AS (
		SELECT t.TicketEventId, t.TicketId, t.ConversationGroupId, (DENSE_RANK() OVER(PARTITION BY t.TicketEventId, t.ConversationGroupId ORDER BY Username ASC) - 1)/ @MaxBatchOfGroup AS BatchOfGroup
		FROM #tmpResult t
		WHERE t.IsDuplicated = 0
	)
	,CTE_Group AS (
		SELECT t.TicketEventId, t.TicketId, t.ConversationGroupId, DENSE_RANK() OVER(ORDER BY t.TicketEventId, ConversationGroupId, BatchOfGroup) AS Id
		FROM CTE_Batch t
	)
	UPDATE t
		SET t.Id = g.Id
	FROM #tmpResult t
		INNER JOIN CTE_Group g ON g.TicketId = t.TicketId AND g.ConversationGroupId = t.ConversationGroupId AND g.TicketEventId = t.TicketEventId

	--Group which have IsDuplicated = 1
	UPDATE t
	SET t.RelatedIds = u.RelatedIds
	FROM #tmpResult t
	CROSS APPLY (
		SELECT STUFF
			   ( 
					(
						SELECT DISTINCT ',' + CONVERT(VARCHAR(30), p.Id)
						FROM #tmpResult p
						WHERE p.ChatTypeId = 1 AND p.TicketId = t.TicketId 
						FOR XML PATH ('')
					), 1, 1, ''
				) AS RelatedIds
	) u(RelatedIds)
	WHERE t.IsDuplicated = 1

	--Get Max Group
	SELECT @MaxGroup = MAX(Id) FROM #tmpResult WHERE IsDuplicated = 0

	CREATE CLUSTERED INDEX IX_tmpResult ON #tmpResult (Id)

	--For Personal (Groups have IsDuplicated = 1)
	;WITH CTE_Batch AS
	(
		SELECT t.TicketId, ConversationGroupId, RelatedIds,((DENSE_RANK() OVER(PARTITION BY t.ticketEventId, t.ConversationGroupId, t.RelatedIds ORDER BY Username ASC) - 1)/ @MaxBatchOfGroup) AS BatchOfGroup
		FROM #tmpResult t
		WHERE t.IsDuplicated = 1
	), CTE_Group AS
	(
		SELECT TicketId, ConversationGroupId, DENSE_RANK() OVER(ORDER BY ticketEventId, ConversationGroupId, RelatedIdLst, BatchOfGroup) AS Id
		FROM CTE_Batch
	)
	UPDATE t
		SET t.Id = @MaxGroup + g.Id
	FROM #tmpResult t
		INNER JOIN CTE_Group g ON g.TicketId = t.TicketId AND g.ConversationGroupId = t.ConversationGroupId

	--Get Userame list and Headline list
	;WITH CTE_Group AS
	(
		SELECT r.Id
			   ,r.TicketEventId
			   ,r.ConversationGroupId
			   ,r.ChatTypeId
			   ,r.LanguageId
			   ,r.PICTye
			   ,MIN(CASE WHEN IsTest = 1 THEN 1 ELSE 0 END) AS IsTest
			   ,MIN(ISNULL(r.RelatedIds,'')) AS RelatedIds
			   ,STUFF ((SELECT DISTINCT ',' + CONVERT(VARCHAR(30), HeadlineId) FROM #tmpResult t WHERE t.Id = r.Id FOR XML PATH('')), 1, 1, '') AS HeadlineIdLst
			   ,STUFF ((SELECT DISTINCT ',' + CONVERT(VARCHAR(30), TicketId) FROM #tmpResult t WHERE t.Id = r.Id FOR XML PATH('')), 1, 1, '') AS LogIdLst
			   ,STUFF ((SELECT DISTINCT ',' + CONVERT(VARCHAR(30), Username) FROM #tmpResult t WHERE t.Id = r.Id FOR XML PATH('')), 1, 1, '') AS UserameLst
		FROM #tmpResult r
		GROUP BY r.Id, r.ticketEventId, r.ConversationGroupId, r.ChatTypeId, r.LanguageId
	)
	INSERT INTO #Result (Id, RelatedIds, ConversationGroupId ,ChatTypeId, LanguageId, Status, ContentEN, ContentSC, ContentTH, ContentYN, ContentENSC, HeadlineList, RelatedIds, UsernameLst)
	SELECT 
		g.Id 
		,g.LogIdLst
		,g.ConversationGroupId
		,g.ChatTypeId
		,g.LanguageId
		,CASE WHEN g.Id > @MaxGroup THEN 'Duplicated' WHEN IsTest = 1 THEN 'Planned' ELSE @Status END AS [Status]
		,g.RelatedIds
		,ev.EventDate
		,ev.ActualResult
		,ev.WrongResult
		,ev.SportNameEN
		,ev.SportNameSC
		,ev.SportNameTH
		,ev.SportNameYN
		,ev.HomeNameEN
		,ev.HomeNameSC
		,ev.HomeNameTH
		,ev.HomeNameYN
		,ev.LeagueNameEN
		,ev.LeagueNameSC
		,ev.LeagueNameTH
		,ev.LeagueNameYN
		,ev.MatchCode
		,m.Content_en
		,m.Content_cs
		,m.Content_th
		,m.Content_yn
		,CASE WHEN g.PICTye = 1 THEN ev.[Type] + 100 ELSE ev.[Type] END AS [Type]
		,g.UserameLst
	FROM CTE_Group g
		INNER JOIN #EventData ev ON ev.TicketEventId = g.TicketEventId
		LEFT JOIN #MessageData m ON m.TicketEventId = g.TicketEventId

	-- Import Notification
	DECLARE @Sender				INT = 10278938 -- StarixIT
			,@SendDate			DATETIME = GETDATE()
			,@NotificationId	INT
			,@Id				INT = 1

	WHILE 1 = 1
	BEGIN
		IF NOT EXISTS (SELECT 1 FROM #Result WHERE Id = @Id)
			BREAK

		INSERT INTO dbo.crmNotification (ReferenceId, DataSource, NotificationTypeId, Sender, SendDate, Title, Status, Content, RelatedNotificationIds)
		SELECT TOP(1) NULL, '', nt.NotificationTypeId, @Sender, @SendDate, nt.Title, r.Status
			,REPLACE(
				REPLACE(
					REPLACE(
						REPLACE(
							REPLACE(
								REPLACE(
									REPLACE(
										REPLACE(
											REPLACE(
												REPLACE(
													REPLACE(
														REPLACE(
															REPLACE(
																REPLACE(
																	REPLACE(
																		REPLACE(
																			REPLACE(
																				REPLACE(
																					REPLACE(
																						REPLACE(
																							REPLACE(
																								REPLACE(
																									REPLACE(
																										REPLACE(
																											REPLACE(
																												REPLACE(
																													REPLACE(
																														nt.Content, '{sport_name_en}', r.SportNameEN)
																													,'{sport_name_sc}', r.SportNameSC)
																												,'{sport_name_th}', r.SportNameTH)
																											,'{sport_name_yn}', r.SportNameYN)
																										,'{home_name_en}', r.HomeNameEN)
																									,'{home_name_sc}', r.HomeNameSC)
																								,'{home_name_th}', r.HomeNameTH)
																							,'{home_name_yn}', r.HomeNameYN)
																						,'{away_name_en}', r.AwayNameEN)
																					,'{away_name_sc}', r.AwayNameSC)
																				,'{away_name_th}', r.AwayNameTH)
																			,'{away_name_yn}', r.AwayNameYN)
																		,'{league_name_en}', r.LeagueNameEN)
																	,'{league_name_sc}', r.LeagueNameSC)
																,'{league_name_th}', r.LeagueNameTH)
															,'{league_name_yn}', r.LeagueNameYN)
														,'{date}', r.EventDate)
													,'{actual_result}', r.ActualResult)
												,'{wrong_result}', r.WrongResult)
											,'{round_match_info}', r.MatchCode)
										,'{match_code}', r.MatchCode)
									,'{message_content_en}', r.ContentEN)
								,'{message_content_sc}', r.ContentSC)
							,'{message_content_th}', r.ContentTH)
						,'{message_content_yn}', r.ContentYN)
					,'{message_content_ensc}', r.ContentENSC)
				,'{affected_list}', r.UsernameLst)		
			, r.RelatedIds
		FROM #Result r
			INNER JOIN #NotificationTemplate nt ON r.LanguageId = nt.LanguageId AND nt.[Type] = r.[Type] 
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

		INSERT INTO dbo.crmNotificationReference (NotificationId, ReferenceId, DataSource)
		SELECT DISTINCT @NotificationId, r.TicketId, 'DBEXT.bodb02.dbo.TicketAmendment_Detail'
		FROM #tmpResult r 
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

		SELECT @Id = @Id + 1
	END

	-- Update lastLogId
	UPDATE dbo.SystemSetting WITH (ROWLOCK)
	SET Value = CONVERT(VARCHAR(20), @lastLogId)
	WHERE ServiceName = 'ChatBot - CWL'
		AND SettingName = @SettingNameOflastLogId

	-- Update crmMessageImport
	UPDATE dbo.SystemSetting WITH (ROWLOCK)
	SET Value = 'Completed'
	WHERE ServiceName = 'ChatBot - CWL'
		AND SettingName = @SettingNameOfJobStatus
		AND Value = 'running'

	DROP TABLE #TicketData
	DROP TABLE #EventData
	DROP TABLE #MessageData
	DROP TABLE #LogRecipient
	DROP TABLE #NotificationTemplate
	DROP TABLE #Result
	DROP TABLE #tmpGroup
	DROP TABLE #tmpResult
END
GO