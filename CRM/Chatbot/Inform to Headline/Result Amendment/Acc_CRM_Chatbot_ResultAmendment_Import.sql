/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_Chatbot_ResultAmendment_Import]
	@TicketData				XML
	,@EventData				XML
	,@MessageData           XML
	,@TargetMessage			XML
	,@InfoMessage			XML
	,@Environment			VARCHAR(50) = ''
	,@ErrCode				INT = 0 OUTPUT
	,@ErrMsg				NVARCHAR(4000) = '' OUTPUT
AS

/*
	Created: 20210731@Malcolm
	DB: DBCRM-bodb_CRM
	Task: CRM - ResultAmendment - Import Notification

	Revisions:
		- 20210731@Malcolm: Initialize SP [RedmineID: #151509]
	Param's Explanation:
		. @TicketData
			<root>
				<r TicketId="1" TicketEventId="" Seq="" CustId="114"  Username="XXX" Recommend="113" Mrecommend="112" Srecommend="111" IsTest="0" />
			</root>

		. @EventData
			<root>
				<r TicketEventId="" ProductId="1" EventDate="1" SubmitDate="" EventType="1" ActualResult="1" WrongResult="1" MessageId="1"  SportNameEN="SB"  SportNameSC="SB"  SportNameTH="SB"  SportNameYN="SB" HomeNameEN="SB"  HomeNameSC="SB"  HomeNameTH="SB"  HomeNameYN="SB" AwayNameEN="SB"  AwayNameSC="SB"  AwayNameTH="SB"  AwayNameYN="SB" LeagueNameEN="SB"  LeagueNameSC="SB"  LeagueNameTH="SB"  LeagueNameYN="SB" MatchCode ="" MatchInfoEN=""  MatchInfoSC=""  MatchInfoTH=""  MatchInfoYN="" Type=""
				/>
			</root>

		. @MessageData
			<root>
				<r TicketEventId="1" MessageId="" Content_en="" Content_cs="" Content_th="" Content_yn=""/>
			</root>
		. @TargetMessage
			<root>
				<r MessageId="1" MsgTargetId="2"/>
			</root>
		.@InfoMessage
			<root>
				<r MessageId="1" CustId="" Username="" Recommend="" Mrecommend="" Srecommend="" IsTest="" Type="" Content_en="" Content_cs="" Content_th="" Content_yn=""/>
			</root>
		.@EventData.Type: 
			Type = 1: Result Amendment Template - Sportsbook	
			Type = 2: Result Amendment Template - Virtual Sports 2	
			Type = 3: Result Amendment Template - Virtual Sports
			Type = 4: Result Amendment Template - Number Game (Number Game, Turbo Number Game, Happy 5, Happy 5 Linked Game)
			Type = 5: Result Amendment Template - Outright	
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @Submitdate DATETIME2(7), @TicketEventId INT, @Seq INT, @SettingNameOfJobStatus VARCHAR(50) = '',@SettingNameOfSubmitDate VARCHAR(50) = '', @IncludeUUSCurrency BIT
			,@SettingNameOfSeq VARCHAR(50) = '', @MaxGroup INT = 0, @MaxBatchOfGroup INT = 250, @ServerName NVARCHAR(200) = @@SERVERNAME

	SELECT @IncludeUUSCurrency = CONVERT(BIT, Value) FROM SystemSetting WHERE ServiceName = 'ChatBot - CWL' and SettingName = 'IncludeUUSCurrency'

	SELECT @Environment = ISNULL(@Environment, '')
		   ,@SettingNameOfJobStatus = CASE WHEN @Environment = 'UAT' THEN 'JobStatusUAT' ELSE 'JobStatus' END
		   ,@SettingNameOfSubmitDate = CASE WHEN @Environment = 'UAT' THEN 'SubmitDateUAT' ELSE 'SubmitDate' END
		   ,@SettingNameOfSeq = CASE WHEN @Environment = 'UAT' THEN 'SeqUAT' ELSE 'Seq' END

	-- Get Job Status
	UPDATE dbo.SystemSetting WITH (ROWLOCK)
	SET Value = 'running'
	WHERE ServiceName = 'ChatBot - ResultAmendment'
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
		,SubmitDate     DATETIME2(7)
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
		,MatchCode		NVARCHAR(100)
		,MatchInfoEN	NVARCHAR(1000)
		,MatchInfoSC	NVARCHAR(1000)
		,MatchInfoTH	NVARCHAR(1000)
		,MatchInfoYN	NVARCHAR(1000)
		,[Type]			TINYINT
	)
	-- Get Imported Data
	INSERT INTO #EventData
	(
		TicketEventId 
		,ProductId 
		,EventDate 
		,SubmitDate
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
		,MatchInfoEN
		,MatchInfoSC
		,MatchInfoTH
		,MatchInfoYN
		,Type 
	)
	SELECT
		t.c.value('@TicketEventId ', 'INT') AS TicketEventId
		,t.c.value('@ProductId', 'INT') AS ProductId
		,t.c.value('@EventDate', 'SMALLDATETIME') AS EventDate
		,t.c.value('@SubmitDate', 'DATETIME2(7)') AS SubmitDate
		,t.c.value('@EventType', 'TINYINT') AS EventType
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
		,t.c.value('@MatchCode', 'NVARCHAR(100)') AS MatchCode
		,t.c.value('@MatchInfoEN', 'NVARCHAR(1000)') AS MatchInfoEN
		,t.c.value('@MatchInfoSC', 'NVARCHAR(1000)') AS MatchInfoSC
		,t.c.value('@MatchInfoTH', 'NVARCHAR(1000)') AS MatchInfoTH
		,t.c.value('@MatchInfoYN', 'NVARCHAR(1000)') AS MatchInfoYN
		,t.c.value('@Type', 'TINYINT') AS Type
	FROM @EventData.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@EventData = NULL))

	CREATE TABLE #MessageData(TicketEventId INT,MessageId INT,Content_en NVARCHAR(4000),Content_cs NVARCHAR(4000),Content_th NVARCHAR(4000),Content_yn NVARCHAR(4000))
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

	CREATE TABLE #TicketData (TicketId INT,TicketEventId INT, Seq INT, CustId INT,Username VARCHAR(30),Recommend INT,Mrecommend INT,Srecommend INT,IsTest BIT)
	INSERT INTO #TicketData (TicketId, TicketEventId, Seq, CustId, Username, Recommend, Mrecommend, Srecommend, IsTest)
	SELECT
		t.c.value('@TicketId', 'INT') AS TicketId
		,t.c.value('@TicketEventId', 'INT') AS TicketEventId
		,t.c.value('@Seq', 'INT') AS Seq
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
		WHERE ServiceName = 'ChatBot - ResultAmendment'
			AND SettingName = @SettingNameOfJobStatus
			AND Value = 'running'

		RETURN
	END

	SELECT @Submitdate = MAX(SubmitDate) FROM #EventData

	SELECT @TicketEventId = TicketEventId FROM #EventData WHERE SubmitDate = @Submitdate

	SELECT @Seq = MAX(Seq) FROM #TicketData WHERE TicketEventId = @TicketEventId

		-- Only import testing accounts with uat environment
	IF @Environment = 'UAT'
	BEGIN
		DELETE i FROM #TicketData i WHERE i.IsTest = 0
	END
	--Exclude UUS currency with LIVE environment

	IF @Environment = 'LIVE' AND @IncludeUUSCurrency = 0
	BEGIN
		DELETE i FROM #TicketData i WHERE i.IsTest = 1
	END

	-- Get Job Setting
	DECLARE @Xml XML
	SELECT  @Xml = CONVERT(XML, Value) FROM dbo.SystemSetting WITH (NOLOCK)
	WHERE ServiceName = 'ChatBot - ResultAmendment'
		AND SettingName = 'NotificationTemplate'

	DECLARE @tmpSetting TABLE (NotificationTemplateId SMALLINT, NotificationTypeId SMALLINT, IsTest BIT, LanguageId INT, TemplateRequiredParam NVARCHAR(MAX), [Type] TINYINT, RecipientTypeId TINYINT)
	INSERT INTO @tmpSetting (NotificationTemplateId, NotificationTypeId, IsTest, LanguageId, TemplateRequiredParam, [Type], RecipientTypeId)
	SELECT
		t.c.value('@NotificationTemplateID', 'SMALLINT') AS NotificationTemplateId
		,t.c.value('@NotificationTypeID', 'SMALLINT') AS NotificationTypeId
		,t.c.value('@IsTest', 'BIT') AS IsTest
		,t1.c.value('@LanguageId', 'INT') AS LanguageId
		,t1.c.value('@Value', 'NVARCHAR(MAX)') AS TemplateRequiredParam
		,t.c.value('@Type', 'TINYINT') AS [Type]
		,r.c AS RecipientTypeId
	FROM @Xml.nodes('root/r') t(c)
		CROSS APPLY t.c.nodes('TemplateRequiredParam') t1(c)
		CROSS APPLY (
			select f.val 
			from dbo.f_CRM_strSplit(t.c.value('@RecipientTypeIds', 'VARCHAR(MAX)'), ',') AS  f
		) as r(c)

	IF @@ROWCOUNT = 0
	BEGIN
		SELECT @ErrCode = 101, @ErrMsg = 'Invalid SystemSetting!'
		
		UPDATE dbo.SystemSetting WITH (ROWLOCK)
		SET Value = 'Completed'
		WHERE ServiceName = 'ChatBot - ResultAmendment'
			AND SettingName = @SettingNameOfJobStatus
			AND Value = 'running'

		RETURN
	END

	-- Get Notification Template
	CREATE TABLE #NotificationTemplate (NotificationTypeId SMALLINT, NotificationTemplateId SMALLINT, Title NVARCHAR(2000), IsTest BIT, LanguageId INT, Content NVARCHAR(MAX), [Type] TINYINT, RecipientTypeId TINYINT)
	;WITH CTE_Setting AS (SELECT DISTINCT NotificationTemplateId, NotificationTypeId, IsTest, [Type], RecipientTypeId FROM @tmpSetting)
	INSERT INTO #NotificationTemplate (NotificationTypeId, NotificationTemplateId, Title, IsTest, LanguageId, Content, [Type], RecipientTypeId)
	SELECT s.NotificationTypeId, nt.NotificationTemplateId, nt.Title, s.IsTest, ntc.LanguageId, ntc.Content, s.[Type], s.RecipientTypeId
	FROM CTE_Setting s
		INNER JOIN dbo.crmNotificationTemplate nt WITH (NOLOCK) ON s.NotificationTemplateId = nt.NotificationTemplateId
		INNER JOIN dbo.crmNotificationTemplateContent ntc WITH (NOLOCK) ON nt.NotificationTemplateId = ntc.NotificationTemplateId

	-- Delete Logs which are imported into crmNotification
	DELETE i
	FROM #TicketData i
	CROSS APPLY (
		SELECT TOP 1 n.ReferenceId
		FROM dbo.crmNotificationReference n WITH(NOLOCK)
		WHERE n.ReferenceId = i.TicketId AND n.DataSource = @ServerName + '.bodb02.dbo.TicketAmendment_Detail'
	) AS c

	IF NOT EXISTS (SELECT 1 FROM #TicketData)
	BEGIN
		UPDATE dbo.SystemSetting WITH (ROWLOCK)
		SET Value = CONVERT(VARCHAR(50), @Submitdate)
		WHERE ServiceName = 'ChatBot - ResultAmendment'
			AND SettingName = @SettingNameOfSubmitDate

		UPDATE dbo.SystemSetting WITH (ROWLOCK)
		SET Value = CONVERT(VARCHAR(20), @Seq)
		WHERE ServiceName = 'ChatBot - ResultAmendment'
			AND SettingName = @SettingNameOfSeq

		UPDATE dbo.SystemSetting WITH (ROWLOCK)
		SET Value = 'Completed'
		WHERE ServiceName = 'ChatBot - ResultAmendment'
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
		,RecipientTypeId		TINYINT
	)
	INSERT INTO #tmpResult (TicketId, TicketEventId, ConversationGroupId, ChatTypeId, LanguageId, Username, HeadlineId, IsDuplicated, RecipientTypeId, IsTest)
	SELECT m.TicketId, m.TicketEventId, g.ConversationGroupId, g.ChatTypeId, g.LanguageId, m.Username, m.HeadlineId, 0, r.RecipientTypeId, m.IsTest
	FROM #LogRecipient m
		INNER JOIN #tmpGroup g ON m.TicketId = g.TicketId AND m.DirectAccount = g.DirectAccount
		INNER JOIN dbo.crmConversationGroupRecipient cgr WITH (NOLOCK) ON m.RecipientId = cgr.RecipientId AND g.ConversationGroupId = cgr.ConversationGroupId 
		INNER JOIN dbo.crmConversationGroupHeadline cgh WITH (NOLOCK) ON m.HeadlineId = cgh.HeadlineId AND g.ConversationGroupId = cgh.ConversationGroupId
		INNER JOIN dbo.crmRecipient r WITH(NOLOCK) ON r.RecipientId = cgr.RecipientId

	UPDATE t
		SET t.IsDuplicated = 1
	FROM #tmpResult t
	WHERE EXISTS (SELECT 1 FROM #tmpResult g WHERE g.ChatTypeId = 1 AND g.TicketId = t.TicketId) AND t.ChatTypeId = 2

	---- For Accounting PIC
	DECLARE @Group TABLE (ConversationGroupId SMALLINT, LanguageId INT, ChatTypeId TINYINT, RecipientTypeId TINYINT)

	INSERT INTO @Group (ConversationGroupId, LanguageId, ChatTypeId, RecipientTypeId)
	SELECT DISTINCT g.ConversationGroupId, g.LanguageId, 2, r.RecipientTypeId
	FROM dbo.crmConversationGroup g WITH(NOLOCK)
		INNER JOIN dbo.crmConversationGroupRecipient cgr WITH(NOLOCK) ON cgr.ConversationGroupId = g.ConversationGroupId
		INNER JOIN dbo.crmRecipient r WITH(NOLOCK) ON r.RecipientId = cgr.RecipientId
		INNER JOIN dbo.crmRecipientType rt WITH(NOLOCK) ON rt.RecipientTypeId = r.RecipientTypeId
	WHERE rt.RecipientTypeName = 'Accounting PIC' AND g.IsActive = 1-- Personal

	CREATE TABLE #DirectAccount (CustId INT PRIMARY KEY CLUSTERED)
	INSERT INTO #DirectAccount (CustId)
	SELECT cda.CustID
	FROM bodb02.dbo.CustDirectAccount cda WITH(NOLOCK)
		LEFT JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON c.custid = cda.CustID
	WHERE c.site <> 'CN88'

	INSERT INTO #tmpResult (TicketId, TicketEventId, ConversationGroupId, ChatTypeId, LanguageId, Username, HeadlineId, IsDuplicated, IsTest, RecipientTypeId)
	SELECT t.TicketId, t.TicketEventId, g.ConversationGroupId, g.ChatTypeId, g.LanguageId, '', ISNULL(cgh.CustID, 0) AS HeadlineId, 0, t.IsTest, g.RecipientTypeId
	FROM @Group g 
		CROSS JOIN #TicketData t 
		INNER JOIN #DirectAccount cda WITH(NOLOCK) ON cda.CustID IN (t.CustId, t.Recommend, t.Mrecommend, t.Srecommend)
		LEFT JOIN bodb02.dbo.custAccount ca WITH(NOLOCK) ON ca.custid = cda.CustID
		LEFT JOIN bodb02.dbo.CustGroupHeadline cgh WITH(NOLOCK) ON cgh.GroupID = ca.groupID
	
	CREATE TABLE #Result
	(
		Id						INT
		,TicketIdLst			NVARCHAR(MAX)
		,ConversationGroupId	SMALLINT
		,ChatTypeId				TINYINT
		,LanguageId				INT
		,Status					VARCHAR(20)
		,EventDate				VARCHAR(20)
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
		,ContentEN				NVARCHAR(4000)
		,ContentSC				NVARCHAR(4000)
		,ContentTH				NVARCHAR(4000)
		,ContentYN				NVARCHAR(4000)
		,HeadlineList			NVARCHAR(MAX)
		,RelatedIds				VARCHAR(1000)
		,UsernameLst			NVARCHAR(MAX)
		,MatchCode	            NVARCHAR(100)
		,MatchInfoEN            NVARCHAR(1000)
		,MatchInfoSC            NVARCHAR(1000)
		,MatchInfoTH            NVARCHAR(1000)
		,MatchInfoYN            NVARCHAR(1000)
		,RecipientTypeId		TINYINT
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
		SELECT t.TicketId, t.ticketEventId, t.ConversationGroupId, t.RelatedIds,((DENSE_RANK() OVER(PARTITION BY t.ticketEventId, t.ConversationGroupId, t.RelatedIds ORDER BY Username ASC) - 1)/ @MaxBatchOfGroup) AS BatchOfGroup
		FROM #tmpResult t
		WHERE t.IsDuplicated = 1
	), CTE_Group AS
	(
		SELECT TicketId, ConversationGroupId, DENSE_RANK() OVER(ORDER BY ticketEventId, ConversationGroupId, RelatedIds, BatchOfGroup) AS Id
		FROM CTE_Batch
	)
	UPDATE t
		SET t.Id = @MaxGroup + g.Id
	FROM #tmpResult t
		INNER JOIN CTE_Group g ON g.TicketId = t.TicketId AND g.ConversationGroupId = t.ConversationGroupId

	--Get Userame list, Headline list, ticket list
	;WITH CTE_Group AS
	(
		SELECT r.Id
			   ,r.TicketEventId
			   ,r.ConversationGroupId
			   ,r.ChatTypeId
			   ,r.LanguageId
			   ,r.RecipientTypeId
			   ,MIN(CASE WHEN IsTest = 1 THEN 1 ELSE 0 END) AS IsTest
			   ,MIN(ISNULL(r.RelatedIds,'')) AS RelatedIds
			   ,STUFF ((SELECT DISTINCT ',' + CONVERT(VARCHAR(30), HeadlineId) FROM #tmpResult t WHERE t.Id = r.Id FOR XML PATH('')), 1, 1, '') AS HeadlineIdLst
			   ,STUFF ((SELECT DISTINCT ',' + CONVERT(VARCHAR(30), TicketId) FROM #tmpResult t WHERE t.Id = r.Id FOR XML PATH('')), 1, 1, '') AS TicketIdLst
			   ,STUFF ((SELECT DISTINCT ',' + CONVERT(VARCHAR(30), Username) FROM #tmpResult t WHERE t.Id = r.Id FOR XML PATH('')), 1, 1, '') AS UserameLst
		FROM #tmpResult r
		GROUP BY r.Id, r.ticketEventId, r.RecipientTypeId, r.ConversationGroupId, r.ChatTypeId, r.LanguageId
	)
	INSERT INTO #Result 
	(
		Id
		,TicketIdLst
		,RelatedIds
		,HeadlineList
		,UsernameLst
		,ConversationGroupId
		,ChatTypeId
		,LanguageId
		,Status
		,EventDate 
		,ActualResult
		,WrongResult 
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
		,MatchInfoEN
		,MatchInfoSC
		,MatchInfoTH
		,MatchInfoYN
		,ContentEN
		,ContentSC
		,ContentTH
		,ContentYN
		,RecipientTypeId
		,[Type]
	)
	SELECT 
		g.Id 
		,g.TicketIdLst
		,ISNULL(g.RelatedIds,'')
		,g.HeadlineIdLst
		,g.UserameLst
		,g.ConversationGroupId
		,g.ChatTypeId
		,g.LanguageId
		,CASE WHEN g.Id > @MaxGroup THEN 'Duplicated' WHEN IsTest = 1 THEN 'Planned' ELSE @Status END AS [Status]
		,ISNULL(CONVERT(VARCHAR(2), DAY(ev.EventDate)) + '/' + CONVERT(VARCHAR(2), MONTH(ev.EventDate)), '') AS EventDate
		,ISNULL(ev.ActualResult,'')
		,ISNULL(ev.WrongResult,'')
		,ISNULL(ev.SportNameEN,'')
		,ISNULL(ev.SportNameSC,'')
		,ISNULL(ev.SportNameTH,'')
		,ISNULL(ev.SportNameYN,'')
		,ISNULL(ev.HomeNameEN,'')
		,ISNULL(ev.HomeNameSC,'')
		,ISNULL(ev.HomeNameTH,'')
		,ISNULL(ev.HomeNameYN,'')
		,ISNULL(ev.AwayNameEN,'')
		,ISNULL(ev.AwayNameSC,'')
		,ISNULL(ev.AwayNameTH,'')
		,ISNULL(ev.AwayNameYN,'')
		,ISNULL(ev.LeagueNameEN,'')
		,ISNULL(ev.LeagueNameSC,'')
		,ISNULL(ev.LeagueNameTH,'')
		,ISNULL(ev.LeagueNameYN,'')
		,ISNULL(ev.MatchCode,'')
		,ISNULL(ev.MatchInfoEN,'')
		,ISNULL(ev.MatchInfoSC,'')
		,ISNULL(ev.MatchInfoTH,'')
		,ISNULL(ev.MatchInfoYN,'')
		,ISNULL(m.Content_en,'')
		,ISNULL(m.Content_cs,'')
		,ISNULL(m.Content_th,'')
		,ISNULL(m.Content_yn,'')
		,g.RecipientTypeId
		,ev.[Type]
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
		SELECT NULL, '', nt.NotificationTypeId, @Sender, @SendDate, nt.Title, r.Status
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
			 										,'{round_match_info_en}', r.MatchInfoEN)
			 									,'{round_match_info_sc}', r.MatchInfoSC)
			 								,'{round_match_info_th}', r.MatchInfoTH)
			 							,'{round_match_info_yn}', r.MatchInfoYN)
			 						,'{match_code}', r.MatchCode)
			 					,'{message_content_en}', r.ContentEN)
			 				,'{message_content_sc}', r.ContentSC)
			 			,'{message_content_th}', r.ContentTH)
			 		,'{message_content_yn}', r.ContentYN)
			 	,'{affected_list}', r.UsernameLst)		
			 ,r.RelatedIds
		FROM #Result r
			INNER JOIN #NotificationTemplate nt ON r.LanguageId = nt.LanguageId AND nt.[Type] = r.[Type] AND r.RecipientTypeId = nt.RecipientTypeId
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
		SELECT DISTINCT @NotificationId, r.TicketId, @ServerName + '.bodb02.dbo.TicketAmendment_Detail'
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

	-- Update Submit date
	UPDATE dbo.SystemSetting WITH (ROWLOCK)
	SET Value = CONVERT(VARCHAR(50), @Submitdate)
	WHERE ServiceName = 'ChatBot - ResultAmendment'
		AND SettingName = @SettingNameOfSubmitDate

	-- Update Seq
	UPDATE dbo.SystemSetting WITH (ROWLOCK)
	SET Value = CONVERT(VARCHAR(20), @Seq)
	WHERE ServiceName = 'ChatBot - ResultAmendment'
		AND SettingName = @SettingNameOfSeq

	-- Update Status of Job
	UPDATE dbo.SystemSetting WITH (ROWLOCK)
	SET Value = 'Completed'
	WHERE ServiceName = 'ChatBot - ResultAmendment'
		AND SettingName = @SettingNameOfJobStatus
		AND Value = 'running'

	DROP TABLE #TicketData
	DROP TABLE #EventData
	DROP TABLE #MessageData
	DROP TABLE #LogRecipient
	DROP TABLE #NotificationTemplate
	DROP TABLE #Result
	DROP TABLE #tmpGroup
	DROP TABLE #DirectAccount
	DROP TABLE #tmpResult
END
GO