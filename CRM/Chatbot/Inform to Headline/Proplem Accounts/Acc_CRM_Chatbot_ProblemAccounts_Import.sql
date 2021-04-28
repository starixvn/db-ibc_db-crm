/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_Chatbot_ProblemAccounts_Import]
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
							<r LogId="1" CustId="114" Username="XXX" Recommend="113" Mrecommend="112" Srecommend="111" CategoryId="100" CategoryName_en="" CategoryName_sc="" CategoryName_ensc="" IsTest="0"/>
					  </root>'
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @lastLogId BIGINT, @SettingNameOfJobStatus VARCHAR(50) = '',@SettingNameOflastLogId VARCHAR(50) = '', @IncludeUUSCurrency BIT

	DECLARE @LanguegeEN INT = 50000, @LanguegeSC INT = 50001, @LanguegeEN_SC INT = 50002

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
		LogId			BIGINT, 
		Username		VARCHAR(30), 
		CustId			INT, 
		Recommend		INT, 
		Mrecommend		INT, 
		Srecommend		INT, 
		CategoryId		SMALLINT, 
		CategoryName_EN NVARCHAR(100), 
		CategoryName_SC NVARCHAR(100), 
		CategoryName_ENSC NVARCHAR(100),
		IsTest			BIT
	)

	INSERT INTO #ImportData (LogId, CustId, Username, IsTest, Recommend, Mrecommend, Srecommend, CategoryId, CategoryName_en, CategoryName_sc, CategoryName_yn)
	SELECT 
		t.c.value('LogId', 'BIGINT')					AS LogId
		,t.c.value('CustId', 'INT')						AS CustId
		,t.c.value('Username', 'VARCHAR(30)')			AS Username
		,t.c.value('IsTest', 'BIT')						AS IsTest
		,t.c.value('Recommend', 'INT')					AS Recommend
		,t.c.value('Mrecommend', 'INT')					AS Mrecommend
		,t.c.value('Srecommend', 'INT')					AS Srecommend
		,t.c.value('CategoryId', 'SMALLINT')			AS CategoryId
		,t.c.value('CategoryName_en', 'NVARCHAR(100)')	AS CategoryName_en
		,t.c.value('CategoryName_sc', 'NVARCHAR(100)')	AS CategoryName_sc
		,t.c.value('CategoryName_ensc', 'NVARCHAR(100)')AS CategoryName_ENSC
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
		FROM dbo.crmNotification n WITH(NOLOCK)
		WHERE n.ReferenceId = i.LogId AND n.DataSource = 'LogId'
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
		LogId			INT
		,Username		VARCHAR(30)
		,DirectAccount	INT
		,HeadlineId		INT
		,CustId			INT 
		,Recommend		INT 
		,Mrecommend		INT 
		,Srecommend		INT 
		,CategoryId		SMALLINT
		,RecipientId	INT
		,CategoryEn		NVARCHAR(100)
		,CategorySC		NVARCHAR(100)
		,CategoryEn_SC	NVARCHAR(100)
		,IsTest			BIT
	)
	INSERT INTO #LogRecipient (LogId, CustId, CategoryId, CategoryEn, CategorySC, CategoryEn_SC, Username, DirectAccount, HeadlineId, IsTest, RecipientId)
	SELECT m.LogId, m.CustId, m.CategoryId, m.CategoryName_en, m.CategoryName_sc, m.CategoryName_ENSC,m.Username, pm.CustId, pm.HeadlineId, m.IsTest, r.RecipientId
	FROM #ImportData m
		INNER JOIN bodb02.dbo.CustDirectAccount cda WITH (NOLOCK) ON cda.CustId IN (m.CustId, m.Recommend, m.Mrecommend, m.Srecommend)
		INNER JOIN dbo.crmPicManagement pm WITH (NOLOCK) ON cda.CustId = pm.CustId
		INNER JOIN dbo.crmRecipient r WITH (NOLOCK) ON pm.PicId = r.SourceId AND r.DataSource = 'bodb_CRM.dbo.crmPIC'
	
	-- Get group to receive message
	CREATE TABLE #tmpGroup 
	(
		LogId				INT, 
		CustId				INT, 
		CategoryId			SMALLINT, 
		ConversationGroupId SMALLINT, 
		ChatTypeId			TINYINT, 
		LanguageId			INT, 
		DirectAccount		INT, 
		NoRecipient			INT

	)
	INSERT INTO #tmpGroup (LogId, CustId, CategoryId, ConversationGroupId, DirectAccount, NoRecipient)
	SELECT m.LogId, m.CustId, m.CategoryId, cgr.ConversationGroupId, m.DirectAccount, COUNT(DISTINCT m.RecipientId) AS NoRecipient
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
		LogId				INT, 
		CustId				INT, 
		CategoryId			SMALLINT, 
		ConversationGroupId	SMALLINT, 
		ChatTypeId			TINYINT, 
		LanguageId			INT, 
		Username			VARCHAR(50), 
		HeadlineId			INT, 
		IsDuplicated		BIT,
		CategoryEn			NVARCHAR(100),
		CategorySC			NVARCHAR(100),
		CategoryEn_SC		NVARCHAR(100),
		IsTest				BIT
	)
	INSERT INTO #tmpResult (LogId, CustId, ConversationGroupId, CategoryId, CategoryEn, CategorySC, CategoryEn_SC, ChatTypeId, LanguageId, Username, HeadlineId, IsDuplicated, IsTest)
	SELECT m.LogId, m.CustId, g.ConversationGroupId, m.CategoryId, m.CategoryEn, m.CategorySC, m.CategoryEn_SC, g.ChatTypeId, g.LanguageId, m.Username, m.HeadlineId, 0, IsTest
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
		Id						INT IDENTITY (1,1)
		,LogIdLst				NVARCHAR(MAX)
		,CurrencyName			NVARCHAR(50)
		,ConversationGroupId	SMALLINT
		,ChatTypeId				TINYINT
		,LanguageId				INT
		,Status					VARCHAR(20)
		,Content				NVARCHAR(MAX)
		,HeadlineList			NVARCHAR(MAX)
		,RelatedIds				VARCHAR(1000)
	)

	DECLARE @Status VARCHAR(20) = 'Planned'
	IF EXISTS (SELECT 1 FROM #NotificationTemplate WHERE IsTest = 1)
		SET @Status = 'Draft'

	-- For Group, Personal Which have IsDuplicated = 0
	;WITH CTE_RowId AS (
		SELECT t.LogId, t.ConversationGroupId, ROW_NUMBER() OVER(PARTITION BY ConversationGroupId ORDER BY CustId ASC) AS RowId
		FROM #tmpResult t
		WHERE t.IsDuplicated = 0
	)
	,CTE_IndexingGroup AS (
		SELECT t.LogId, t.ConversationGroupId, DENSE_RANK() OVER(ORDER BY (t.RowId - 1)/ 250, t.ConversationGroupId) AS Id
		FROM CTE_RowId t
	)
	UPDATE t
		SET t.Id = g.Id
	FROM #tmpResult t
		INNER JOIN CTE_IndexingGroup g ON g.LogId = t.LogId AND g.ConversationGroupId = t.ConversationGroupId

	;WITH CTE_Group AS (
		SELECT t.Id, t.ConversationGroupId, t.ChatTypeId, t.LanguageId, MAX(IsTest) AS Istest
			   ,STUFF ((SELECT ',' + CONVERT(VARCHAR(50), i.LogId) FROM #tmpResult i WHERE i.Id = t.id FOR XML PATH('')), 1, 1, '') AS LogIdLst
		FROM #tmpResult t
		WHERE t.IsDuplicated = 0
		GROUP BY t.Id, t.ConversationGroupId, t.ChatTypeId, t.LanguageId
	)
	INSERT INTO #Result (Id, LogIdLst, ConversationGroupId, ChatTypeId, LanguageId, RelatedIds, Status)
	SELECT g.Id, g.LogIdLst, g.ConversationGroupId, g.ChatTypeId, g.LanguageId, 0, CASE WHEN g.Istest = 1 THEN 'Planned' ELSE @Status END AS Status
	FROM CTE_Group g	

	DECLARE @MaxId INT

	SELECT @MaxId = MAX(Id) FROM #Result
		
	-- For Personal (Groups have IsDuplicated = 1)
	;WITH CTE_tmpPersonal AS (
		SELECT p.LogId, p.ConversationGroupId, p.ChatTypeId, p.LanguageId, t.RelatedIds 
		FROM #tmpResult p
		CROSS APPLY (SELECT STUFF ((SELECT DISTINCT ',' + CONVERT(VARCHAR(5), r.Id) FROM #tmpResult r WHERE p.LogId = r.LogId FOR XML PATH('')), 1, 1, '') AS RelatedIds) t(RelatedIds)
		WHERE p.IsDuplicated = 1 -- Personal
	),CTE_tempResult AS (
		SELECT t.ConversationGroupId, t.ChatTypeId, t.LanguageId, t.RelatedIds
				,STUFF ((SELECT ',' + CONVERT(VARCHAR(50), g.LogId) FROM CTE_tmpPersonal g WHERE g.RelatedIds = t.RelatedIds AND g.ConversationGroupId = t.ConversationGroupId FOR XML PATH('')), 1, 1, '') AS LogIdLst	
				,@MaxId + ROW_NUMBER() OVER(ORDER BY t.ConversationGroupId ASC) AS Id
		FROM CTE_tmpPersonal t
		GROUP BY t.ConversationGroupId, t.ChatTypeId, t.LanguageId, t.RelatedIds
	)
	INSERT INTO #Result (id, LogIdLst, ConversationGroupId, ChatTypeId, LanguageId, Status, RelatedIds)
	SELECT t.Id, t.LogIdLst, t.ConversationGroupId, t.ChatTypeId, t.LanguageId, 'Duplicated', t.RelatedIds
	FROM CTE_tempResult t

	;WITH CTE AS
	(
		SELECT r.Id, r.ConversationGroupId, f.val AS LogId
		FROM #Result r
		CROSS APPLY dbo.f_CRM_strSplit(r.LogIdLst, ',') f
		WHERE r.Id > @MaxId
	)
	UPDATE t
		SET t.Id = r.Id
	FROM #tmpResult t
		INNER JOIN CTE r ON r.ConversationGroupId = t.ConversationGroupId AND r.LogId = t.LogId
	WHERE t.IsDuplicated = 1

	--Update Content and Headline list
	;WITH CTE_index AS	(
		SELECT r.Id, STUFF ((SELECT ',' + CONVERT(VARCHAR(30), HeadlineId) FROM #tmpResult t WHERE t.Id = r.Id FOR XML PATH('')), 1, 1, '') AS HeadlineIdLst
		FROM #tmpResult r
		GROUP BY r.Id

	),CTE_Category AS (
		SELECT t.Id , t.LanguageId ,t.CategoryId, t.CategoryEn, t.CategorySC, t.CategoryEn_SC,
				STUFF ((SELECT ',' + Username FROM #tmpResult d WHERE d.Id = t.Id AND d.CategoryId = t.CategoryId FOR XML PATH('')), 1, 1, '') AS UsernameLst
		FROM #tmpResult t
		GROUP BY t.Id, t.CategoryId
	),CTE_Content AS (	
		SELECT I.Id
			   ,STUFF 
			   (
					(
						SELECT CHAR(10) + CHAR(13) + CASE e.LanguageId WHEN @LanguegeEN    THEN CategoryEn
													                   WHEN @LanguegeSC    THEN CategorySC
													                   WHEN @LanguegeEN_SC THEN CategoryEn_SC 
								      ELSE '' END  + ' : ' + UsernameLst 
						FROM CTE_Category e 
						WHERE e.Id = i.Id
					), 1, 1, ''
				) AS Content
				,i.HeadlineIdLst
		FROM CTE_index i 
	)
	UPDATE r
		SET r.Content = c.Content, r.HeadlineList = c.HeadlineIdLst
	FROM #Result r
		INNER JOIN CTE_Content c ON c.Id = r.Id
	
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
		SELECT '', '', nt.NotificationTypeId, @Sender, @SendDate, nt.Title, r.Status, REPLACE(nt.Content, '{Content}', r.content), r.RelatedIds
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