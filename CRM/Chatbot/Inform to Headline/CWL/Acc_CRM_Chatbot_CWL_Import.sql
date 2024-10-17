/*<info serverAlias="DBCRM-bodb_CRM" executers="wsv_nap" isFunction="0" isNested="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE [dbo].[Acc_CRM_Chatbot_CWL_Import]
	@XmlData				XML
	,@Environment			VARCHAR(50) = ''
	,@ErrCode				INT = 0 OUTPUT
	,@ErrMsg				NVARCHAR(4000) = '' OUTPUT
AS

/*
	Created: 20201104@Malcolm
	DB: DBCRM-bodb_CRM
	Task: CRM - CWL - Import Notification

	Revisions:
		- 20201104@Malcolm: Initialize SP [RedmineID: #144841]
		- 20210303@Malcolm: Change format of winloss [RedmineID: #144841]
		- 20210726@Malcolm: Change data type of logId [RedmineID: #157303]
		- 20220112@Malcolm: Update job status = 'Completed' when job runs longer than 5 minutes [RedmineID: #167358]
		- 20230508@Malcolm: Offer Telegram bot service for Headlines [RedmineId : #179119]
        - 20240719@Ned.Le:  CRM - Auto FB and Headline Notification - CWL service for 777 site - Adjust product name to TaraPlay xD for SABA xD (#203438)

	Param's Explanation:
		. @XmlData
			<root>
				<r LogId="1" CustId="114" CurrencyName="USD" Username="XXX" Recommend="113" Mrecommend="112" Srecommend="111" Winloss="100" ProductNameEN="SB" ProductNameSC="SB" ProductNameTH="SB" ProductNameVN="SB" LevelId="" GroupId=""/>
			</root>
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @lastLogId BIGINT, @SettingNameOfJobStatus VARCHAR(50) = '',@SettingNameOflastLogId VARCHAR(50) = '', @IncludeUUSCurrency BIT, @LastRuntime DATETIME 
			,@SettingNameOfLastRuntime VARCHAR(50) = ''

	DECLARE @ServerName NVARCHAR(100) = @@SERVERNAME, @DBName NVARCHAR(100) = DB_NAME(), @SPName NVARCHAR(300) = OBJECT_NAME(@@PROCID)

	SELECT @IncludeUUSCurrency = CONVERT(BIT, Value) FROM SystemSetting WHERE ServiceName = 'ChatBot - CWL' and SettingName = 'IncludeUUSCurrency'

	SELECT @Environment = ISNULL(@Environment, '')
		   ,@SettingNameOfJobStatus = CASE WHEN @Environment = 'UAT' THEN 'JobStatusUAT' ELSE 'JobStatus' END
		   ,@SettingNameOflastLogId = CASE WHEN @Environment = 'UAT' THEN 'LastLogIdUAT' ELSE 'LastLogID' END
		   ,@SettingNameOfLastRuntime = CASE WHEN @Environment = 'UAT' THEN 'LastRuntimeUAT' ELSE 'LastRuntime' END

	-- Get Job Status
	UPDATE dbo.SystemSetting WITH (ROWLOCK)
	SET Value = 'running'
	WHERE ServiceName = 'ChatBot - CWL'
		AND SettingName = @SettingNameOfJobStatus
		AND Value = 'Completed'
	
	IF @@ROWCOUNT = 0
	BEGIN
		SELECT @LastRuntime = CONVERT(DATETIME, Value) FROM dbo.SystemSetting WITH(NOLOCK) WHERE SettingName = @SettingNameOfLastRuntime AND ServiceName = 'ChatBot - CWL'

		IF DATEDIFF(SECOND, @LastRuntime, GETDATE()) >= 5 * 60
		BEGIN
			UPDATE dbo.SystemSetting WITH (ROWLOCK)
			SET Value = 'Completed'
			WHERE ServiceName = 'ChatBot - CWL'
				AND SettingName = @SettingNameOfJobStatus
				AND Value = 'running'

			--Update LastRuntime
			UPDATE dbo.SystemSetting WITH (ROWLOCK)
			SET Value = CONVERT(VARCHAR(20), GETDATE(), 120)
			WHERE ServiceName = 'ChatBot - CWL'
				AND SettingName = @SettingNameOfLastRuntime
		END
		ELSE 
		BEGIN
			SELECT @ErrCode = 100, @ErrMsg = 'Server Name : ' + @ServerName + ' - Database Name : ' + @DBName + ' - SP Name : '+ @SPName + ' - Error Message : '+ 'ChatBot - CWL - Job is running.'
		END	
		RETURN
	END

	--Update LastRuntime
	UPDATE dbo.SystemSetting WITH (ROWLOCK)
	SET Value = CONVERT(VARCHAR(20), GETDATE(), 120)
	WHERE ServiceName = 'ChatBot - CWL'
		AND SettingName = @SettingNameOfLastRuntime

	-- Get Imported Data
	CREATE TABLE #ImportData
	(
		LogId				BIGINT
		,CustId				INT
		,CurrencyName		NVARCHAR(50)
		,Username			VARCHAR(30)
		,Recommend			INT
		,Mrecommend			INT
		,Srecommend			INT
		,Winloss			MONEY
		,ProductNameEN		NVARCHAR(50)
		,ProductNameSC		NVARCHAR(50)
		,ProductNameTH		NVARCHAR(50)
		,ProductNameVN		NVARCHAR(50)
		,LevelId			INT
		,GroupId			INT
	)
	INSERT INTO #ImportData (LogId, CustId, CurrencyName, Username, Recommend, Mrecommend, Srecommend, Winloss, ProductNameEN, ProductNameSC, ProductNameTH, ProductNameVN, LevelId, GroupId)
	SELECT
		t.c.value('@LogId', 'BIGINT') AS LogId
		,t.c.value('@CustId', 'INT') AS CustId
		,t.c.value('@CurrencyName', 'NVARCHAR(50)') AS CurrencyName
		,t.c.value('@Username', 'VARCHAR(30)') AS Username
		,t.c.value('@Recommend', 'INT') AS Recommend
		,t.c.value('@Mrecommend', 'INT') AS Mrecommend
		,t.c.value('@Srecommend', 'INT') AS Srecommend
		,t.c.value('@Winloss', 'MONEY') AS Winloss
		,t.c.value('@ProductNameEN', 'NVARCHAR(50)') AS ProductNameEN
		,t.c.value('@ProductNameSC', 'NVARCHAR(50)') AS ProductNameSC
		,t.c.value('@ProductNameTH', 'NVARCHAR(50)') AS ProductNameTH
		,t.c.value('@ProductNameVN', 'NVARCHAR(50)') AS ProductNameVN
		,t.c.value('@LevelId', 'INT') AS LevelId
		,t.c.value('@GroupId', 'INT') AS GroupId
	FROM @XmlData.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@XmlData = NULL))

	IF @@ROWCOUNT = 0
	BEGIN	
		UPDATE dbo.SystemSetting WITH (ROWLOCK)
		SET Value = 'Completed'
		WHERE ServiceName = 'ChatBot - CWL'
			AND SettingName = @SettingNameOfJobStatus
			AND Value = 'running'

		RETURN
	END

    UPDATE tmp
    SET tmp.ProductNameEN = CASE WHEN ISNULL(c.site, '') = '777777' AND ProductNameEN = 'SABA xD' THEN 'TaraPlays xD' ELSE tmp.ProductNameEN END,
        tmp.ProductNameSC = CASE WHEN ISNULL(c.site, '') = '777777' AND ProductNameEN = 'SABA xD' THEN 'TaraPlays xD' ELSE tmp.ProductNameSC END,
        tmp.ProductNameTH = CASE WHEN ISNULL(c.site, '') = '777777' AND ProductNameEN = 'SABA xD' THEN 'TaraPlays xD' ELSE tmp.ProductNameTH END,
        tmp.ProductNameVN = CASE WHEN ISNULL(c.site, '') = '777777' AND ProductNameEN = 'SABA xD' THEN 'TaraPlays xD' ELSE tmp.ProductNameVN END
    FROM #ImportData tmp
         LEFT JOIN bodb02.dbo.Customer c WITH (NOLOCK) ON tmp.CustId = c.custid

	SELECT @lastLogId = MAX(LogId) FROM #ImportData

		-- Only import testing accounts with uat environment
	IF @Environment = 'UAT'
	BEGIN
		DELETE i FROM #ImportData i WHERE i.CurrencyName <> 'UUS'
	END
	--Exclude UUS currency with LIVE environment

	IF @Environment = 'LIVE' AND @IncludeUUSCurrency = 0
	BEGIN
		DELETE i FROM #ImportData i WHERE i.CurrencyName = 'UUS'
	END

	-- Get Job Setting
	DECLARE @Xml XML
	SELECT  @Xml = CONVERT(XML, Value) FROM dbo.SystemSetting WITH (NOLOCK)
	WHERE ServiceName = 'ChatBot - CWL'
		AND SettingName = 'NotificationTemplate'

	DECLARE @tmpSetting TABLE (NotificationTemplateId SMALLINT, NotificationTypeId SMALLINT, IsTest BIT, LanguageId INT, TemplateRequiredParam NVARCHAR(MAX), GroupIds VARCHAR(100), LevelIds VARCHAR(100))
	INSERT INTO @tmpSetting (NotificationTemplateId, NotificationTypeId, IsTest, LanguageId, TemplateRequiredParam, GroupIds, LevelIds)
	SELECT
		t.c.value('@NotificationTemplateID', 'SMALLINT') AS NotificationTemplateId
		,t.c.value('@NotificationTypeID', 'SMALLINT') AS NotificationTypeId
		,t.c.value('@IsTest', 'BIT') AS IsTest
		,t1.c.value('@LanguageId', 'INT') AS LanguageId
		,t1.c.value('@Value', 'NVARCHAR(MAX)') AS TemplateRequiredParam
		,t.c.value('@GroupIds', 'VARCHAR(100)') AS GroupIds
		,t.c.value('@LevelIds', 'VARCHAR(100)') AS LevelIds
	FROM @Xml.nodes('root/r') t(c)
		CROSS APPLY t.c.nodes('TemplateRequiredParam') t1(c)

	IF @@ROWCOUNT = 0
	BEGIN
		SELECT @ErrCode = 101, @ErrMsg = 'Server Name : ' + @ServerName + ' - Database Name : ' + @DBName + ' - SP Name : '+ @SPName + ' - Error Message : '+ 'ChatBot - CWL - Invalid SystemSetting!'
		
		UPDATE dbo.SystemSetting WITH (ROWLOCK)
		SET Value = 'Completed'
		WHERE ServiceName = 'ChatBot - CWL'
			AND SettingName = @SettingNameOfJobStatus
			AND Value = 'running'

		RETURN
	END

	-- Get Notification Template
	CREATE TABLE #NotificationTemplate (NotificationTypeId SMALLINT, NotificationTemplateId SMALLINT, Title NVARCHAR(2000), IsTest BIT, LanguageId INT, Content NVARCHAR(MAX), GroupId INT, LevelId INT)
	;WITH CTE_Setting AS (SELECT DISTINCT NotificationTemplateId, NotificationTypeId, IsTest, LevelIds, GroupIds FROM @tmpSetting)
	INSERT INTO #NotificationTemplate (NotificationTypeId, NotificationTemplateId, Title, IsTest, LanguageId, Content, GroupId, LevelId)
	SELECT s.NotificationTypeId, nt.NotificationTemplateId, nt.Title, s.IsTest, ntc.LanguageId, ntc.Content, t.GroupId, t.LevelId
	FROM CTE_Setting s
		INNER JOIN dbo.crmNotificationTemplate nt WITH (NOLOCK) ON s.NotificationTemplateId = nt.NotificationTemplateId
		INNER JOIN dbo.crmNotificationTemplateContent ntc WITH (NOLOCK) ON nt.NotificationTemplateId = ntc.NotificationTemplateId
	CROSS APPLY(
		SELECT l.value as LevelId, g.value AS GroupId
		FROM STRING_SPLIT(s.LevelIds, ',') l
			CROSS JOIN STRING_SPLIT(s.GroupIds, ',') g 
	) t(LevelId, GroupId)
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
		SELECT @ErrCode = 102, @ErrMsg = 'Server Name : ' + @ServerName + ' - Database Name : ' + @DBName + ' - SP Name : '+ @SPName + ' - Error Message : '+ 'ChatBot - CWL - Notification Template Content(s) are not include Required Param(s)'
		
		UPDATE dbo.SystemSetting WITH (ROWLOCK)
		SET Value = 'Completed'
		WHERE ServiceName = 'ChatBot - CWL'
			AND SettingName = @SettingNameOfJobStatus
			AND Value = 'running'

		RETURN
	END

	-- Delete Logs which are imported into crmNotification
	DELETE i
	FROM #ImportData i
	CROSS APPLY (
		SELECT TOP 1 n.ReferenceId
		FROM dbo.crmNotificationRefDetail n WITH(NOLOCK)
		WHERE n.ReferenceId = i.LogId AND n.DataSource = 'DBCUST.CustDB.dbo.WinLimit_CustGameMonitoring_History'
	) AS c

	IF NOT EXISTS (SELECT 1 FROM #ImportData)
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
	CREATE TABLE #LogRecipient
	(
		LogId				BIGINT
		,Username			VARCHAR(30)
		,DirectAccount		INT
		,HeadlineId			INT
		,Winloss			MONEY
		,CurrencyName		NVARCHAR(50)
		,ProductNameEN		NVARCHAR(50)
		,ProductNameSC		NVARCHAR(50)
		,ProductNameTH		NVARCHAR(50)
		,ProductNameVN		NVARCHAR(50)
		,RecipientId		INT
	)
	INSERT INTO #LogRecipient (LogId, Username, DirectAccount, HeadlineId, Winloss, CurrencyName, ProductNameEN, ProductNameSC, ProductNameTH, ProductNameVN, RecipientId)
	SELECT m.LogId, m.Username, pm.CustId, pm.HeadlineId, m.Winloss, m.CurrencyName, m.ProductNameEN, m.ProductNameSC, m.ProductNameTH, m.ProductNameVN, r.RecipientId
	FROM #ImportData m
		INNER JOIN bodb02.dbo.CustDirectAccount cda WITH (NOLOCK) ON cda.CustId IN (m.CustId, m.Recommend, m.Mrecommend, m.Srecommend)
		INNER JOIN dbo.crmPicManagement pm WITH (NOLOCK) ON cda.CustId = pm.CustId
		INNER JOIN dbo.crmRecipient r WITH (NOLOCK) ON pm.PicId = r.SourceId AND r.DataSource = 'bodb_CRM.dbo.crmPIC'
	
	-- Get group to receive message
	CREATE TABLE #tmpGroup (LogId BIGINT, ConversationGroupId SMALLINT, ChannelId TINYINT, ChatTypeId TINYINT, LanguageId INT, DirectAccount INT, NoRecipient INT)
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
	SET t.ChatTypeId = cg.ChatTypeId, t.LanguageId = cg.LanguageId, t.ChannelId = cg.ChannelId
	FROM #tmpGroup t
		INNER JOIN dbo.crmConversationGroup cg WITH (NOLOCK) ON t.ConversationGroupId = cg.ConversationGroupId

	CREATE TABLE #tmpResult (LogId BIGINT, ConversationGroupId SMALLINT, ChannelId TINYINT, ChatTypeId TINYINT, LanguageId INT, Username VARCHAR(50), HeadlineId INT)
	INSERT INTO #tmpResult (LogId, ConversationGroupId, ChannelId, ChatTypeId, LanguageId, Username, HeadlineId)
	SELECT m.LogId, g.ConversationGroupId, g.ChannelId, g.ChatTypeId, g.LanguageId, m.Username, m.HeadlineId
	FROM #LogRecipient m
		INNER JOIN #tmpGroup g ON m.LogId = g.LogId AND m.DirectAccount = g.DirectAccount
		INNER JOIN dbo.crmConversationGroupRecipient cgr WITH (NOLOCK) ON m.RecipientId = cgr.RecipientId AND g.ConversationGroupId = cgr.ConversationGroupId 
		INNER JOIN dbo.crmConversationGroupHeadline cgh WITH (NOLOCK) ON m.HeadlineId = cgh.HeadlineId AND g.ConversationGroupId = cgh.ConversationGroupId

	CREATE TABLE #Result
	(
		Id						INT IDENTITY(1, 1)
		,LogId					BIGINT
		,Username				VARCHAR(30)
		,Winloss				MONEY
		,CurrencyName			NVARCHAR(50)
		,ProductNameEN			NVARCHAR(50)
		,ProductNameSC			NVARCHAR(50)
		,ProductNameTH			NVARCHAR(50)
		,ProductNameVN			NVARCHAR(50)
		,ConversationGroupId	SMALLINT
		,ChannelId				TINYINT
		,ChatTypeId				TINYINT
		,LanguageId				INT
		,HeadlineList			VARCHAR(MAX)
		,Status					VARCHAR(20)
		,RelatedIds				VARCHAR(1000)
		,LevelId				INT
		,GroupId				INT
	)

	DECLARE @Status VARCHAR(20) = 'Planned'
	IF EXISTS (SELECT 1 FROM #NotificationTemplate WHERE IsTest = 1)
		SET @Status = 'Draft'

	-- For Group
	INSERT INTO #Result (LogId, ConversationGroupId, ChannelId, ChatTypeId, LanguageId, HeadlineList, Status)
	SELECT LogId, ConversationGroupId, ChannelId, ChatTypeId, LanguageId, HeadlineList, @Status
	FROM (
		SELECT LogId, ChannelId, ConversationGroupId, ChatTypeId, LanguageId
			,STUFF(
					(SELECT DISTINCT ',' + CONVERT(VARCHAR(20), HeadlineId)
						FROM #tmpResult t2
						WHERE t1.LogId = t2.LogId AND t1.ConversationGroupId = t2.ConversationGroupId
						FOR XML PATH ('')
					), 1, 1, ''
				) AS HeadlineList
		FROM #tmpResult t1
		WHERE t1.ChatTypeId = 1 -- Group
		GROUP BY LogId, ChannelId, ConversationGroupId, ChatTypeId, LanguageId
	) t

	-- For Personal
	;WITH CTE_tmpPersonal AS (
		SELECT p.LogId, p.ConversationGroupId, p.ChannelId, p.ChatTypeId, p.LanguageId, p.Username, p.HeadlineId, t.Id AS RelatedId
		FROM #tmpResult p
			OUTER APPLY (
				SELECT DISTINCT r.Id
				FROM dbo.crmConversationGroupRecipient cgr1 WITH (NOLOCK)
					INNER JOIN dbo.crmConversationGroupRecipient cgr2 WITH (NOLOCK) ON cgr2.RecipientId = cgr1.RecipientId
					INNER JOIN #tmpResult g ON g.ConversationGroupId = cgr2.ConversationGroupId
					INNER JOIN #Result r ON g.LogId = r.LogId AND g.ConversationGroupId = r.ConversationGroupId
				WHERE p.ConversationGroupId = cgr1.ConversationGroupId AND p.LogId = g.LogId AND p.Username = g.Username AND p.ChannelId = g.ChannelId AND g.ChatTypeId = 1 -- Group
			) t
		WHERE p.ChatTypeId = 2 -- Personal
	)
	,CTE_tempResult AS (
		SELECT LogId, ChannelId, ConversationGroupId, ChatTypeId, LanguageId, Username, HeadlineId
			,CASE WHEN t1.RelatedId IS NULL THEN 0 ELSE 1 END AS IsDuplicated
			,STUFF(
					(SELECT DISTINCT ',' + CONVERT(VARCHAR(20), t2.RelatedId)
						FROM CTE_tmpPersonal t2
						WHERE t1.LogId = t2.LogId AND t1.ConversationGroupId = t2.ConversationGroupId
						FOR XML PATH ('')
					), 1, 1, ''
				) AS RelatedIds
		FROM CTE_tmpPersonal t1
		GROUP BY LogId, ChannelId, ConversationGroupId, ChatTypeId, LanguageId, Username, HeadlineId
		,CASE WHEN t1.RelatedId IS NULL THEN 0 ELSE 1 END
	)
	INSERT INTO #Result (LogId, ConversationGroupId, ChannelId, ChatTypeId, LanguageId, HeadlineList, Status, RelatedIds)
	SELECT LogId, ConversationGroupId, ChannelId, ChatTypeId, LanguageId, HeadlineList, CASE WHEN IsDuplicated = 1 THEN 'Duplicated' ELSE @Status END, CASE WHEN IsDuplicated = 1 THEN RelatedIds END
	FROM (
		SELECT LogId, ConversationGroupId, ChannelId, ChatTypeId, LanguageId, IsDuplicated
			,STUFF(
					(SELECT DISTINCT ',' + CONVERT(VARCHAR(20), t2.HeadlineId)
						FROM CTE_tempResult t2
						WHERE t1.LogId = t2.LogId AND t1.ConversationGroupId = t2.ConversationGroupId AND t1.IsDuplicated = t2.IsDuplicated
						FOR XML PATH ('')
					), 1, 1, ''
				) AS HeadlineList
			,STUFF(
					(SELECT DISTINCT ',' + t2.RelatedIds
						FROM CTE_tempResult t2
						WHERE t1.LogId = t2.LogId AND t1.ConversationGroupId = t2.ConversationGroupId AND t1.IsDuplicated = t2.IsDuplicated
						FOR XML PATH ('')
					), 1, 1, ''
				) AS RelatedIds
		FROM CTE_tempResult t1
		GROUP BY LogId, ChannelId, ConversationGroupId, ChatTypeId, LanguageId, IsDuplicated
	) t

	UPDATE r
	SET r.Username = m.Username
		,r.Winloss = m.Winloss
		,r.CurrencyName = m.CurrencyName
		,r.ProductNameEN = m.ProductNameEN
		,r.ProductNameSC = m.ProductNameSC
		,r.ProductNameTH = m.ProductNameTH
		,r.ProductNameVN = m.ProductNameVN
		,r.LevelId = m.LevelId
		,r.GroupId = m.GroupId
		,r.Status = CASE WHEN m.CurrencyName = 'UUS' AND r.Status = 'Draft' THEN 'Planned' ELSE r.Status END
	FROM #Result r
		CROSS APPLY (
			SELECT TOP 1 m.Username, m.Winloss, m.CurrencyName, m.ProductNameEN, m.ProductNameSC, m.ProductNameTH, m.ProductNameVN, m.LevelId, m.GroupId
			FROM #ImportData m
			WHERE r.logid = m.LogId
		) m

	-- Import Notification
	DECLARE @Sender				INT = 10278938 -- StarixIT
			,@SendDate			DATETIME = GETDATE()
			,@NotificationId	INT
			,@Id				INT = 1

	WHILE 1 = 1
	BEGIN
		IF NOT EXISTS (SELECT 1 FROM #Result WHERE Id = @Id)
			BREAK

		INSERT INTO dbo.crmNotification (NotificationTypeId, Sender, SendDate, Title, Status, Content, RelatedNotificationIds, ChannelId)
		SELECT TOP(1) nt.NotificationTypeId, @Sender, @SendDate, nt.Title, r.Status
			,REPLACE(
				REPLACE(
					REPLACE(
						REPLACE(
							REPLACE(
								REPLACE(
									REPLACE(nt.Content, '{player_username}', r.Username)
									,'{player_wl_amount}', REPLACE(CONVERT(VARCHAR(20), ROUND(r.Winloss, 0, 1), 1), '.00', ''))
								,'{player_currency}', r.CurrencyName)
							,'{product_name_en}', r.ProductNameEN)
						,'{product_name_th}', r.ProductNameTH)
					,'{product_name_sc}', r.ProductNameSC)
				,'{product_name_yn}', r.ProductNameVN)
			,r.RelatedIds, r.ChannelId
		FROM #Result r
			INNER JOIN #NotificationTemplate nt ON r.LanguageId = nt.LanguageId AND r.LevelId = nt.LevelId AND nt.GroupId IN (r.GroupId, 0)
		WHERE r.Id = @Id 
		ORDER BY nt.GroupId DESC

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
		SELECT DISTINCT @NotificationId, f.value
		FROM #Result r
			CROSS APPLY STRING_SPLIT(r.HeadlineList, ',') f
		WHERE r.Id = @Id

		INSERT INTO dbo.crmNotificationRefDetail (NotificationId, ReferenceId, DataSource)
		SELECT @NotificationId AS NotificationId, r.LogId, 'DBCUST.CustDB.dbo.WinLimit_CustGameMonitoring_History' AS DataSource
		FROM #Result r
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

	DROP TABLE #ImportData
	DROP TABLE #LogRecipient
	DROP TABLE #NotificationTemplate
	DROP TABLE #Result
	DROP TABLE #tmpGroup
	DROP TABLE #tmpResult
END
GO