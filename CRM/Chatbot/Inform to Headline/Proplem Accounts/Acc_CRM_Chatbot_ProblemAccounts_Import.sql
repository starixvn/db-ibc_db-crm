/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_Chatbot_ProblemAccounts_Import]
	@XmlData				XML
	,@Environment			VARCHAR(50) = ''
	,@ErrCode				INT = 0 OUTPUT
	,@ErrMsg				NVARCHAR(4000) = '' OUTPUT
AS

/*
	Created: 20210428@Malcolm
	DB: DBCRM-bodb_CRM
	Task: CRM - Problem Accounts - Import Notification

	Revisions:
		- 20210428@Malcolm: Initialize SP [RedmineID: #153119]

	Param's Explanation:
		. @XmlData = '<root>
							<r LogId="1" CustId="114" Username="XXX" Recommend="113" Mrecommend="112" Srecommend="111" CategoryId="100" CategoryNameEN="" CategoryNameSC="" CategoryNameTH="" CategoryNameYN="" IsTest="0" />
					  </root>'
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @lastLogId BIGINT, @SettingNameOfJobStatus VARCHAR(50) = '',@SettingNameOflastLogId VARCHAR(50) = '', @IncludeUUSCurrency BIT

	DECLARE @MaxGroup 		 INT = 0,
			@MaxBatchOfGroup INT = 250

	SELECT @IncludeUUSCurrency = CONVERT(BIT, Value) FROM SystemSetting WHERE ServiceName = 'ChatBot - ProblemAccounts' and SettingName = 'IncludeUUSCurrency'

	SELECT @Environment = ISNULL(@Environment, '')
		   ,@SettingNameOfJobStatus = CASE WHEN @Environment = 'UAT' THEN 'JobStatusUAT' ELSE 'JobStatus' END
		   ,@SettingNameOflastLogId = CASE WHEN @Environment = 'UAT' THEN 'LastLogIdUAT' ELSE 'LastLogID' END

	-- Get Job Status
	UPDATE dbo.SystemSetting WITH (ROWLOCK)
	SET Value = 'running'
	WHERE ServiceName = 'ChatBot - ProblemAccounts'
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
		LogId				BIGINT, 
		Username			VARCHAR(30), 
		CustId				INT, 
		Recommend			INT, 
		Mrecommend			INT, 
		Srecommend			INT, 
		CategoryId			SMALLINT, 
		CategoryNameEN		NVARCHAR(100), 
		CategoryNameSC		NVARCHAR(100), 
		CategoryNameTH		NVARCHAR(100),
		CategoryNameYN		NVARCHAR(100),
		IsTest				BIT
	)

	INSERT INTO #ImportData (LogId, CustId, Username, IsTest, Recommend, Mrecommend, Srecommend, CategoryId, CategoryNameEN, CategoryNameSC, CategoryNameTH, CategoryNameYN)
	SELECT 
		t.c.value('@LogId', 'BIGINT')					    AS LogId
		,t.c.value('@CustId', 'INT')						AS CustId
		,t.c.value('@Username', 'VARCHAR(30)')				AS Username
		,t.c.value('@IsTest', 'BIT')						AS IsTest
		,t.c.value('@Recommend', 'INT')						AS Recommend
		,t.c.value('@Mrecommend', 'INT')					AS Mrecommend
		,t.c.value('@Srecommend', 'INT')					AS Srecommend
		,t.c.value('@CategoryId', 'SMALLINT')			    AS CategoryId
		,t.c.value('@CategoryNameEN', 'NVARCHAR(100)')		AS CategoryNameEN
		,t.c.value('@CategoryNameSC', 'NVARCHAR(100)')		AS CategoryNameSC
		,t.c.value('@CategoryNameTH', 'NVARCHAR(100)')		AS CategoryNameTH
		,t.c.value('@CategoryNameYN', 'NVARCHAR(100)')		AS CategoryNameYN
	FROM @XmlData.nodes ('root/r') t(c)
	OPTION (OPTIMIZE FOR (@XmlData = NULL))

	IF @@ROWCOUNT = 0
	BEGIN	
		UPDATE dbo.SystemSetting WITH (ROWLOCK)
		SET Value = 'Completed'
		WHERE ServiceName = 'ChatBot - ProblemAccounts'
			AND SettingName = @SettingNameOfJobStatus
			AND Value = 'running'

		RETURN
	END

	SELECT @lastLogId = MAX(LogId) FROM #ImportData

		-- Only import testing accounts with uat environment
	IF @Environment = 'UAT'
	BEGIN
		DELETE i FROM #ImportData i WHERE i.IsTest = 0
	END
	--Exclude UUS currency with LIVE environment

	IF @Environment = 'LIVE' AND @IncludeUUSCurrency = 0
	BEGIN
		DELETE i FROM #ImportData i WHERE i.IsTest = 1
	END

	-- Get Job Setting
	DECLARE @Xml XML
	SELECT  @Xml = CONVERT(XML, Value) FROM dbo.SystemSetting WITH (NOLOCK)
	WHERE ServiceName = 'ChatBot - ProblemAccounts'
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
		WHERE ServiceName = 'ChatBot - ProblemAccounts'
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
		WHERE ServiceName = 'ChatBot - ProblemAccounts'
			AND SettingName = @SettingNameOfJobStatus
			AND Value = 'running'

		RETURN
	END

	-- Delete Logs which are imported into crmNotification
	DELETE i
	FROM #ImportData i
	CROSS APPLY (
		SELECT TOP 1 n.ReferenceId
		FROM dbo.crmNotificationReference n WITH(NOLOCK)
		WHERE n.ReferenceId = i.LogId AND n.DataSource = 'DBCust.CustDB.dbo.CustCategoryHistory'
	) AS c

	IF NOT EXISTS (SELECT 1 FROM #ImportData)
	BEGIN
		UPDATE dbo.SystemSetting WITH (ROWLOCK)
		SET Value = CONVERT(VARCHAR(20), @lastLogId)
		WHERE ServiceName = 'ChatBot - ProblemAccounts'
			AND SettingName = @SettingNameOflastLogId

		UPDATE dbo.SystemSetting WITH (ROWLOCK)
		SET Value = 'Completed'
		WHERE ServiceName = 'ChatBot - ProblemAccounts'
			AND SettingName = @SettingNameOfJobStatus
			AND Value = 'running'

		RETURN
	END

	-- Get Recipient
	CREATE TABLE #LogRecipient
	(
		LogId				BIGINT
		,Username			VARCHAR(30)
		,DirectAccount		INT
		,HeadlineId			INT
		,CustId				INT 
		,Recommend			INT 
		,Mrecommend			INT 
		,Srecommend			INT 
		,CategoryId			SMALLINT
		,RecipientId		INT
		,CategoryNameEn		NVARCHAR(100)
		,CategoryNameSC		NVARCHAR(100)
		,CategoryNameTH		NVARCHAR(100)
		,CategoryNameYN		NVARCHAR(100)
		,IsTest				BIT
	)
	INSERT INTO #LogRecipient (LogId, CustId, CategoryId, CategoryNameEn, CategoryNameSC, CategoryNameTH, CategoryNameYN, Username, DirectAccount, HeadlineId, IsTest, RecipientId)
	SELECT m.LogId, m.CustId, m.CategoryId, m.CategoryNameEN, m.CategoryNameSC, m.CategoryNameTH, m.CategoryNameYN, m.Username, pm.CustId, pm.HeadlineId, m.IsTest, r.RecipientId
	FROM #ImportData m
		INNER JOIN bodb02.dbo.CustDirectAccount cda WITH (NOLOCK) ON cda.CustId IN (m.CustId, m.Recommend, m.Mrecommend, m.Srecommend)
		INNER JOIN dbo.crmPicManagement pm WITH (NOLOCK) ON cda.CustId = pm.CustId
		INNER JOIN dbo.crmRecipient r WITH (NOLOCK) ON pm.PicId = r.SourceId AND r.DataSource = 'bodb_CRM.dbo.crmPIC'
	
	-- Get group to receive message
	CREATE TABLE #tmpGroup (LogId BIGINT, ConversationGroupId SMALLINT, ChatTypeId TINYINT, LanguageId INT, DirectAccount INT, NoRecipient INT)
	INSERT INTO #tmpGroup (LogId, ConversationGroupId, DirectAccount, NoRecipient)
	SELECT m.LogId, cgr.ConversationGroupId, m.DirectAccount, COUNT(DISTINCT m.RecipientId) AS NoRecipient
	FROM #LogRecipient m
		INNER JOIN dbo.crmConversationGroupRecipient cgr WITH (NOLOCK) ON m.RecipientId = cgr.RecipientId
		INNER JOIN dbo.crmConversationGroupHeadline cgh WITH (NOLOCK) ON m.HeadlineId = cgh.HeadlineId AND cgr.ConversationGroupId = cgh.ConversationGroupId
		INNER JOIN dbo.crmConversationGroup cg WITH (NOLOCK) ON cgr.ConversationGroupId = cg.ConversationGroupId
	WHERE cg.IsActive = 1
	GROUP BY m.LogId, cgr.ConversationGroupId, m.DirectAccount

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
		Id					INT, 
		LogId				BIGINT, 
		CustId				INT, 
		CategoryId			SMALLINT, 
		ConversationGroupId	SMALLINT, 
		ChatTypeId			TINYINT, 
		LanguageId			INT, 
		Username			VARCHAR(50), 
		HeadlineId			INT, 
		IsDuplicated		BIT,
		CategoryNameEN		NVARCHAR(100),
		CategoryNameSC		NVARCHAR(100),
		CategoryNameTH		NVARCHAR(100),
		CategoryNameYN		NVARCHAR(100),
		RelatedIdLst		NVARCHAR(MAX),
		IsTest				BIT
	)
	INSERT INTO #tmpResult (LogId, CustId, ConversationGroupId, CategoryId, CategoryNameEN, CategoryNameSC, CategoryNameTH, CategoryNameYN, ChatTypeId, LanguageId, Username, HeadlineId, IsDuplicated, IsTest)
	SELECT m.LogId, m.CustId, g.ConversationGroupId, m.CategoryId, m.CategoryNameEN, m.CategoryNameSC, m.CategoryNameTH, m.CategoryNameYN ,g.ChatTypeId, g.LanguageId, m.Username, m.HeadlineId, 0, IsTest
	FROM #LogRecipient m
		INNER JOIN #tmpGroup g ON m.LogId = g.LogId AND m.DirectAccount = g.DirectAccount
		INNER JOIN dbo.crmConversationGroupRecipient cgr WITH (NOLOCK) ON m.RecipientId = cgr.RecipientId AND g.ConversationGroupId = cgr.ConversationGroupId 
		INNER JOIN dbo.crmConversationGroupHeadline cgh WITH (NOLOCK) ON m.HeadlineId = cgh.HeadlineId AND g.ConversationGroupId = cgh.ConversationGroupId

	UPDATE t
		SET t.IsDuplicated = 1
	FROM #tmpResult t
	WHERE EXISTS (SELECT 1 FROM #tmpResult g WHERE g.ChatTypeId = 1 AND g.LogId = t.LogId) AND t.ChatTypeId = 2

	CREATE TABLE #Result
	(
		Id						INT
		,LogIdLst				NVARCHAR(MAX)
		,ConversationGroupId	SMALLINT
		,ChatTypeId				TINYINT
		,LanguageId				INT
		,Status					VARCHAR(20)
		,ContentEN				NVARCHAR(MAX)
		,ContentSC				NVARCHAR(MAX)
		,ContentTH				NVARCHAR(MAX)
		,ContentYN				NVARCHAR(MAX)
		,ContentENSC			NVARCHAR(MAX)
		,HeadlineList			NVARCHAR(MAX)
		,RelatedIds				VARCHAR(1000)
	)

	DECLARE @Status VARCHAR(20) = 'Planned'
	IF EXISTS (SELECT 1 FROM #NotificationTemplate WHERE IsTest = 1)
		SET @Status = 'Draft'

	-- For Group, Personal Which have IsDuplicated = 0
	;WITH CTE_Batch AS (
		SELECT t.LogId, t.ConversationGroupId, (DENSE_RANK() OVER(PARTITION BY ConversationGroupId ORDER BY CategoryId ASC, CustId ASC) - 1)/ @MaxBatchOfGroup AS BatchOfGroup
		FROM #tmpResult t
		WHERE t.IsDuplicated = 0
	)
	,CTE_Group AS (
		SELECT t.LogId, t.ConversationGroupId, DENSE_RANK() OVER(ORDER BY ConversationGroupId, BatchOfGroup) AS Id
		FROM CTE_Batch t
	)
	UPDATE t
		SET t.Id = g.Id
	FROM #tmpResult t
		INNER JOIN CTE_Group g ON g.LogId = t.LogId AND g.ConversationGroupId = t.ConversationGroupId

	--Group which have IsDuplicated = 1
	UPDATE t
	SET t.RelatedIdLst = u.RelatedLst
	FROM #tmpResult t
	CROSS APPLY (
		SELECT STUFF
			   ( 
					(
						SELECT DISTINCT ',' + CONVERT(VARCHAR(30), p.Id)
						FROM #tmpResult p
						WHERE p.ChatTypeId = 1 AND p.CustId = t.CustId AND p.CategoryId = t.CategoryId
						FOR XML PATH ('')
					), 1, 1, ''
				) AS RelatedLst
	) u(RelatedLst)
	WHERE t.IsDuplicated = 1

	--Get Max Group
	SELECT @MaxGroup = MAX(Id) FROM #tmpResult WHERE IsDuplicated = 0
	
	CREATE CLUSTERED INDEX IX_tmpResult ON #tmpResult (Id)
		
	-- For Personal (Groups have IsDuplicated = 1)
	;WITH CTE_Batch AS
	(
		SELECT LogId, ConversationGroupId, RelatedIdLst, ((DENSE_RANK() OVER(PARTITION BY ConversationGroupId, RelatedIdLst ORDER BY CategoryId, CustId) - 1)/ @MaxBatchOfGroup) AS BatchOfGroup
		FROM #tmpResult t
		WHERE t.IsDuplicated = 1
	), CTE_Group AS
	(
		SELECT LogId, ConversationGroupId, DENSE_RANK() OVER(ORDER BY ConversationGroupId, RelatedIdLst, BatchOfGroup) AS Id
		FROM CTE_Batch
	)
	UPDATE t
		SET t.Id = @MaxGroup + g.Id
	FROM #tmpResult t
		INNER JOIN CTE_Group g ON g.LogId = t.LogId AND g.ConversationGroupId = t.ConversationGroupId

	--Get Content and Headline list
	;WITH CTE_Group AS
	(
		SELECT r.Id
			   ,r.ConversationGroupId
			   ,r.ChatTypeId
			   ,r.LanguageId
			   ,MAX(CASE WHEN IsTest = 1 THEN 1 ELSE 0 END) AS IsTest
			   ,MAX(ISNULL(r.RelatedIdLst,'')) AS RelatedIdLst
			   ,STUFF ((SELECT DISTINCT ',' + CONVERT(VARCHAR(30), HeadlineId) FROM #tmpResult t WHERE t.Id = r.Id FOR XML PATH('')), 1, 1, '') AS HeadlineIdLst
			   ,STUFF ((SELECT DISTINCT ',' + CONVERT(VARCHAR(30), LogId) FROM #tmpResult t WHERE t.Id = r.Id FOR XML PATH('')), 1, 1, '') AS LogIdLst
		FROM #tmpResult r
		GROUP BY r.Id, r.ConversationGroupId, r.ChatTypeId, r.LanguageId
	),CTE_Category AS 
	(
		SELECT t.Id , t.LanguageId ,t.CategoryId, t.CategoryNameEN, t.CategoryNameSC, t.CategoryNameTH, t.CategoryNameYN
			   ,STUFF ((SELECT DISTINCT ', ' + Username FROM #tmpResult d WHERE d.Id = t.Id AND d.CategoryId = t.CategoryId ORDER BY (', ' + Username) ASC FOR XML PATH('')), 1, 1, '') AS UsernameLst
		FROM #tmpResult t
		GROUP BY t.Id, t.LanguageId, t.CategoryId, t.CategoryNameEN, t.CategoryNameSC, t.CategoryNameTH, t.CategoryNameYN 
	),CTE_Content AS 
	(	
		SELECT	i.Id
			   ,STUFF ((SELECT CHAR(10) + ' - ' + e.CategoryNameEN  + ' : ' + UsernameLst FROM CTE_Category e WHERE e.Id = i.Id ORDER BY e.CategoryNameEN FOR XML PATH('')), 1, 1, '') AS ContentEN
			   ,STUFF ((SELECT CHAR(10) + ' - ' + e.CategoryNameSC  + ' : ' + UsernameLst FROM CTE_Category e WHERE e.Id = i.Id ORDER BY e.CategoryNameEN FOR XML PATH('')), 1, 1, '') AS ContentSC
			   ,STUFF ((SELECT CHAR(10) + ' - ' + e.CategoryNameTH  + ' : ' + UsernameLst FROM CTE_Category e WHERE e.Id = i.Id ORDER BY e.CategoryNameEN FOR XML PATH('')), 1, 1, '') AS ContentTH
			   ,STUFF ((SELECT CHAR(10) + ' - ' + e.CategoryNameYN  + ' : ' + UsernameLst FROM CTE_Category e WHERE e.Id = i.Id ORDER BY e.CategoryNameYN FOR XML PATH('')), 1, 1, '') AS ContentYN
			   ,STUFF ((SELECT CHAR(10) + ' - ' + e.CategoryNameEN  + '/' +  e.CategoryNameSC + ' : ' + UsernameLst FROM CTE_Category e WHERE e.Id = i.Id ORDER BY e.CategoryNameEN FOR XML PATH('')), 1, 1, '') AS ContentENSC
			   ,i.HeadlineIdLst
		FROM CTE_Group i 
	)
	INSERT INTO #Result (Id, LogIdLst, ConversationGroupId ,ChatTypeId, LanguageId, Status, ContentEN, ContentSC, ContentTH, ContentYN, ContentENSC, HeadlineList, RelatedIds)
	SELECT 
		g.Id 
		,g.LogIdLst
		,g.ConversationGroupId
		,g.ChatTypeId
		,g.LanguageId
		,CASE WHEN g.Id > @MaxGroup THEN 'Duplicated' WHEN IsTest = 1 THEN 'Planned' ELSE @Status END AS [Status]
		,c.ContentEN
		,c.ContentSC
		,c.ContentTH
		,c.ContentYN
		,c.ContentENSC
		,c.HeadlineIdLst
		,g.RelatedIdLst
	FROM CTE_Group g
		INNER JOIN CTE_Content c ON g.Id = c.Id
	
	-- Import Notification
	DECLARE @Sender				INT = 10278938 -- StarixIT
			,@SendDate			DATETIME = GETDATE()
			,@NotificationId	INT
			,@Id				INT = 1
			,@Content			NVARCHAR(MAX)

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
								REPLACE(nt.Content, '{Content_en}', r.ContentEN)
									,'{Content_sc}', r.ContentSC)
								,'{Content_th}', r.ContentTH)
							,'{Content_yn}', r.ContentYN)
						,'{content_en_sc}', r.ContentENSC)
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

		INSERT INTO dbo.crmNotificationReference (NotificationId, ReferenceId, DataSource)
		SELECT DISTINCT @NotificationId, r.LogId, 'DBCust.CustDB.dbo.CustCategoryHistory'
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
	WHERE ServiceName = 'ChatBot - ProblemAccounts'
		AND SettingName = @SettingNameOflastLogId

	-- Update crmMessageImport
	UPDATE dbo.SystemSetting WITH (ROWLOCK)
	SET Value = 'Completed'
	WHERE ServiceName = 'ChatBot - ProblemAccounts'
		AND SettingName = @SettingNameOfJobStatus
		AND Value = 'running'

	DROP TABLE #ImportData
	DROP TABLE #LogRecipient
	DROP TABLE #NotificationTemplate
	DROP TABLE #Result
	DROP TABLE #tmpGroup
	DROP TABLE #tmpResult
END
GO