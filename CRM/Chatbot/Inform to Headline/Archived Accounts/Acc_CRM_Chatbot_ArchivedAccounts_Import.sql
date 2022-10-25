/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_Chatbot_ArchivedAccounts_Import]
	@XmlData				XML
	,@Environment			VARCHAR(50) = ''
	,@ErrCode				INT = 0 OUTPUT
	,@ErrMsg				NVARCHAR(4000) = '' OUTPUT
AS

/*
	Created: 20221025@Malcolm
	DB: DBCRM-bodb_CRM
	Task: CRM - Archived Accounts - Import Notification

	Revisions:
		- 20221025@Malcolm: Initialize SP [RedmineID: #158258]

	Param's Explanation:
		. @XmlData = '<root>
							<r LogId="1" CustId="114" Username="XXX" IsTest="0" />
					  </root>'
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @lastLogId BIGINT, @SettingNameOfJobStatus VARCHAR(50) = '',@SettingNameOflastLogId VARCHAR(50) = '', @IncludeUUSCurrency BIT, @IsSyncSettingsForUAT BIT = 0
			,@SettingNameOfLastRuntime VARCHAR(50) = '', @LastRuntime DATETIME 

	DECLARE @ServerName NVARCHAR(100) = @@SERVERNAME, @DBName NVARCHAR(100) = DB_NAME(), @SPName NVARCHAR(300) = OBJECT_NAME(@@PROCID)

	DECLARE @MaxGroup 		 INT = 0,
			@MaxBatchOfGroup INT = 250

	SELECT @IncludeUUSCurrency = CONVERT(BIT, Value) FROM SystemSetting WITH(NOLOCK) WHERE ServiceName = 'ChatBot - ArchivedAccounts' AND SettingName = 'IncludeUUSCurrency'
	SELECT @IsSyncSettingsForUAT = CONVERT(BIT, Value) FROM SystemSetting WITH(NOLOCK) WHERE ServiceName = 'ChatBot - ArchivedAccounts' AND SettingName = 'IsSyncSettingsForUAT' AND @Environment <> 'UAT'

	SELECT @Environment = ISNULL(@Environment, '')
		   ,@SettingNameOfJobStatus = CASE WHEN @Environment = 'UAT' THEN 'JobStatusUAT' ELSE 'JobStatus' END
		   ,@SettingNameOflastLogId = CASE WHEN @Environment = 'UAT' THEN 'LastLogIdUAT' ELSE 'LastLogID' END
		   ,@SettingNameOfLastRuntime = CASE WHEN @Environment = 'UAT' THEN 'LastRuntimeUAT' ELSE 'LastRuntime' END

	-- Get Job Status
	UPDATE dbo.SystemSetting WITH (ROWLOCK)
	SET Value = 'running'
	WHERE ServiceName = 'ChatBot - ArchivedAccounts'
		AND SettingName = @SettingNameOfJobStatus
		AND Value = 'Completed'
	
	IF @@ROWCOUNT = 0
	BEGIN
		SELECT @LastRuntime = CONVERT(DATETIME, Value) FROM dbo.SystemSetting WITH(NOLOCK) WHERE SettingName = @SettingNameOfLastRuntime AND ServiceName = 'ChatBot - ArchivedAccounts'

		IF DATEDIFF(SECOND, @LastRuntime, GETDATE()) >= 5 * 60
		BEGIN
			UPDATE dbo.SystemSetting WITH (ROWLOCK)
			SET Value = 'Completed'
			WHERE ServiceName = 'ChatBot - ArchivedAccounts'
				AND SettingName = @SettingNameOfJobStatus
				AND Value = 'running'

			--Update LastRuntime
			UPDATE dbo.SystemSetting WITH (ROWLOCK)
			SET Value = CONVERT(VARCHAR(20), GETDATE(), 120)
			WHERE ServiceName = 'ChatBot - ArchivedAccounts'
				AND SettingName = @SettingNameOfLastRuntime
		END
		ELSE 
		BEGIN
			SELECT @ErrCode = 100, @ErrMsg = 'Server Name : ' + @ServerName + ' - Database Name : ' + @DBName + ' - SP Name : '+ @SPName + ' - Error Message : '+'ChatBot - ArchivedAccounts - Job is running.'
		END	
		RETURN
	END

	--Update LastRuntime
	UPDATE dbo.SystemSetting WITH (ROWLOCK)
	SET Value = CONVERT(VARCHAR(20), GETDATE(), 120)
	WHERE ServiceName = 'ChatBot - ArchivedAccounts'
		AND SettingName = @SettingNameOfLastRuntime

	-- Get Imported Data
	CREATE TABLE #ImportData (LogId BIGINT, Username VARCHAR(30), CustId INT, IsTest BIT)

	INSERT INTO #ImportData (LogId, CustId, Username, IsTest)
	SELECT 
		t.c.value('@LogId', 'BIGINT')			AS LogId
		,t.c.value('@CustId', 'INT')			AS CustId
		,t.c.value('@Username', 'VARCHAR(30)')	AS Username
		,t.c.value('@IsTest', 'BIT')			AS IsTest
	FROM @XmlData.nodes ('root/r') t(c)
	OPTION (OPTIMIZE FOR (@XmlData = NULL))

	IF @@ROWCOUNT = 0
	BEGIN	
		UPDATE dbo.SystemSetting WITH (ROWLOCK)
		SET Value = 'Completed'
		WHERE ServiceName = 'ChatBot - ArchivedAccounts'
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
	WHERE ServiceName = 'ChatBot - ArchivedAccounts'
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
		SELECT @ErrCode = 101, @ErrMsg = 'Server Name : ' + @ServerName + ' - Database Name : ' + @DBName + ' - SP Name : '+ @SPName + ' - Error Message : '+'ChatBot - ArchivedAccounts - Invalid SystemSetting!'
		
		UPDATE dbo.SystemSetting WITH (ROWLOCK)
		SET Value = 'Completed'
		WHERE ServiceName = 'ChatBot - ArchivedAccounts'
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
		SELECT @ErrCode = 102, @ErrMsg = 'Server Name : ' + @ServerName + ' - Database Name : ' + @DBName + ' - SP Name : '+ @SPName + ' - Error Message : '+'ChatBot - ArchivedAccounts - Notification Template Content(s) are not include Required Param(s)'
		
		UPDATE dbo.SystemSetting WITH (ROWLOCK)
		SET Value = 'Completed'
		WHERE ServiceName = 'ChatBot - ArchivedAccounts'
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
		WHERE n.ReferenceId = i.LogId AND n.DataSource = 'DBCRM.bodb_CRM.dbo.crmArchivedAccount'
	) AS c

	IF NOT EXISTS (SELECT 1 FROM #ImportData)
	BEGIN
		--Update lastlogId
		UPDATE dbo.SystemSetting WITH (ROWLOCK)
		SET Value = CONVERT(VARCHAR(20), @lastLogId)
		WHERE ServiceName = 'ChatBot - ArchivedAccounts'
			AND SettingName = @SettingNameOflastLogId

		-- Update LastLogId for UAT
		UPDATE dbo.SystemSetting WITH (ROWLOCK)
		SET Value = CONVERT(VARCHAR(20), @lastLogId)
		WHERE ServiceName = 'ChatBot - ArchivedAccounts'
			AND SettingName = @SettingNameOflastLogId + 'UAT'
			AND @IsSyncSettingsForUAT = 1

		UPDATE dbo.SystemSetting WITH (ROWLOCK)
		SET Value = 'Completed'
		WHERE ServiceName = 'ChatBot - ArchivedAccounts'
			AND SettingName = @SettingNameOfJobStatus
			AND Value = 'running'

		RETURN
	END

	-- Get Recipient
	CREATE TABLE #LogRecipient(LogId BIGINT, CustId INT, Username VARCHAR(30), DirectAccount INT, HeadlineId INT, IsTest BIT, RecipientId INT)
	INSERT INTO #LogRecipient (LogId, CustId, Username, DirectAccount, HeadlineId, IsTest, RecipientId)
	SELECT m.LogId, m.CustId, m.Username, pm.CustId, pm.HeadlineId, m.IsTest, r.RecipientId
	FROM #ImportData m
		INNER JOIN dbo.crmPicManagement pm WITH (NOLOCK) ON m.CustId = pm.CustId
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
		ConversationGroupId	SMALLINT, 
		ChatTypeId			TINYINT, 
		LanguageId			INT, 
		Username			VARCHAR(50), 
		HeadlineId			INT, 
		IsDuplicated		BIT,
		RelatedIdLst		NVARCHAR(MAX),
		IsTest				BIT
	)
	INSERT INTO #tmpResult (LogId, CustId, ConversationGroupId, ChatTypeId, LanguageId, Username, HeadlineId, IsDuplicated, IsTest)
	SELECT m.LogId, m.CustId, g.ConversationGroupId,g.ChatTypeId, g.LanguageId, m.Username, m.HeadlineId, 0, m.IsTest
	FROM #LogRecipient m
		INNER JOIN #tmpGroup g ON m.LogId = g.LogId AND m.DirectAccount = g.DirectAccount
		INNER JOIN dbo.crmConversationGroupRecipient cgr WITH (NOLOCK) ON m.RecipientId = cgr.RecipientId AND g.ConversationGroupId = cgr.ConversationGroupId 
		INNER JOIN dbo.crmConversationGroupHeadline cgh WITH (NOLOCK) ON m.HeadlineId = cgh.HeadlineId AND g.ConversationGroupId = cgh.ConversationGroupId

	UPDATE t
		SET t.IsDuplicated = 1
	FROM #tmpResult t
		INNER JOIN dbo.crmConversationGroupRecipient cgr WITH(NOLOCK) ON cgr.ConversationGroupId = t.ConversationGroupId 
	WHERE EXISTS (
			SELECT 1 
			FROM #tmpResult g 
				INNER JOIN dbo.crmConversationGroupRecipient cg WITH(NOLOCK) ON cg.ConversationGroupId = g.ConversationGroupId
			WHERE g.ChatTypeId = 1 AND g.LogId = t.LogId AND cg.RecipientId = cgr.RecipientId
	) AND t.ChatTypeId = 2

	CREATE TABLE #Result (Id INT, ConversationGroupId SMALLINT, ChatTypeId TINYINT, LanguageId INT, Status VARCHAR(20), UsernameList VARCHAR(MAX), RelatedIds VARCHAR(1000))

	DECLARE @Status VARCHAR(20) = 'Planned'
	IF EXISTS (SELECT 1 FROM #NotificationTemplate WHERE IsTest = 1)
		SET @Status = 'Draft'

	-- For Group, Personal Which have IsDuplicated = 0
	;WITH CTE_Batch AS (
		SELECT t.LogId, t.ConversationGroupId, (DENSE_RANK() OVER(PARTITION BY ConversationGroupId ORDER BY CustId ASC) - 1)/ @MaxBatchOfGroup AS BatchOfGroup
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

	--Personal which have IsDuplicated = 1
	;WITH CTE AS
	(
		SELECT n.LogId, n.RecipientId, STRING_AGG(CONVERT(VARCHAR(20), n.Id), ',') WITHIN  GROUP (ORDER BY Id ASC) AS RelatedLst
		FROM (
			SELECT DISTINCT p.LogId, cg.RecipientId, Id
			FROM #tmpResult p
				INNER JOIN dbo.crmConversationGroupRecipient cg WITH(NOLOCK) ON cg.ConversationGroupId = p.ConversationGroupId
			WHERE p.ChatTypeId = 1
			GROUP BY p.LogId, cg.RecipientId, p.Id
		) AS n
		GROUP BY n.LogId, n.RecipientId
	)
	UPDATE t
	SET t.RelatedIdLst = e.RelatedLst
	FROM #tmpResult t
		INNER JOIN dbo.crmConversationGroupRecipient cgr WITH(NOLOCK) ON cgr.ConversationGroupId = t.ConversationGroupId
		INNER JOIN CTE e ON e.LogId = t.LogId AND e.RecipientId = cgr.RecipientId
	WHERE t.IsDuplicated = 1

	--Get Max Group
	SELECT @MaxGroup = MAX(Id) FROM #tmpResult WHERE IsDuplicated = 0
	
	CREATE CLUSTERED INDEX IX_tmpResult ON #tmpResult (Id)
		
	-- For Personal (IsDuplicated = 1)
	;WITH CTE_Batch AS
	(
		SELECT LogId, ConversationGroupId, RelatedIdLst, ((DENSE_RANK() OVER(PARTITION BY ConversationGroupId, RelatedIdLst ORDER BY CustId ASC) - 1)/ @MaxBatchOfGroup) AS BatchOfGroup
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
	;WITH CTE_UsernameList AS
	(
		SELECT n.Id, STRING_AGG(Username, ', ') WITHIN  GROUP (ORDER BY Username ASC) AS UsernameList
		FROM (
			SELECT Id, Username 
			FROM #tmpResult 
			GROUP BY Id, Username
		) AS n
		GROUP BY n.Id
	),CTE_Group AS
	(
		SELECT r.Id
			   ,r.ConversationGroupId
			   ,r.ChatTypeId
			   ,r.LanguageId
			   ,MIN(CASE WHEN r.IsTest = 1 THEN 1 ELSE 0 END) AS IsTest
			   ,MIN(ISNULL(r.RelatedIdLst,'')) AS RelatedIdLst
		FROM #tmpResult r
		GROUP BY r.Id, r.ConversationGroupId, r.ChatTypeId, r.LanguageId
	)
	INSERT INTO #Result (Id, ConversationGroupId ,ChatTypeId, LanguageId, Status, UsernameList, RelatedIds)
	SELECT 
		g.Id 
		,g.ConversationGroupId
		,g.ChatTypeId
		,g.LanguageId
		,CASE WHEN g.Id > @MaxGroup THEN 'Duplicated' WHEN g.IsTest = 1 THEN 'Planned' ELSE @Status END AS [Status]
		,u.UsernameList
		,g.RelatedIdLst
	FROM CTE_Group g
		INNER JOIN CTE_UsernameList u ON u.Id = g.Id
	
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
		SELECT NULL, '', nt.NotificationTypeId, @Sender, @SendDate, nt.Title, r.Status,REPLACE(nt.Content, '{Affected List}', r.UsernameList) AS Content, r.RelatedIds
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
		SELECT DISTINCT @NotificationId, r.HeadlineId
		FROM #tmpResult r
		WHERE r.Id = @Id

		INSERT INTO dbo.crmNotificationReference (NotificationId, ReferenceId, DataSource)
		SELECT DISTINCT @NotificationId, r.LogId, 'DBCRM.bodb_CRM.dbo.crmArchivedAccount'
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
	WHERE ServiceName = 'ChatBot - ArchivedAccounts'
		AND SettingName = @SettingNameOflastLogId

	-- Update LastLogId for UAT
	UPDATE dbo.SystemSetting WITH (ROWLOCK)
		SET Value = CONVERT(VARCHAR(20), @lastLogId)
		WHERE ServiceName = 'ChatBot - ArchivedAccounts'
			AND SettingName = @SettingNameOflastLogId + 'UAT'
			AND @IsSyncSettingsForUAT = 1

	-- Update crmMessageImport
	UPDATE dbo.SystemSetting WITH (ROWLOCK)
	SET Value = 'Completed'
	WHERE ServiceName = 'ChatBot - ArchivedAccounts'
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