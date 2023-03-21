/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_Chatbot_AbnormalBets_Import]
	@XmlData				XML
	,@Messages				XML
	,@Environment			VARCHAR(50) = ''
	,@ErrCode				INT = 0 OUTPUT
	,@ErrMsg				NVARCHAR(4000) = '' OUTPUT
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

	Param's Explanation:
		- @XmlData
			<root>
				<r VoidingHistoryCollectionId="1" UsernameList="XXX" CustId="114" Recommend="113" Mrecommend="112" Srecommend="111" IsTest="0" Content_en="" Content_cs="" Content_th="" Content_vn="" Type="1"/>
				<r VoidingHistoryCollectionId="2" UsernameList="XYZ" CustId="115" Recommend="113" Mrecommend="112" Srecommend="111" IsTest="0" Content_en="" Content_cs="" Content_th="" Content_vn="" Type="2"/>
			</root>
				+ Type = 1 : get member of tickets belong to abnormal bets
				+ Type = 2 : Get direct account of tickets belong to abnormal accounts, IsTest : MIN(IsTest) of member have tickets voided
				+ Type = 3 : get member of tickets belong to abnormal bets (mix parlay)
		- @Messages:
			<root>
				<r VoidingHistoryCollectionId = "1" MessageID="1" RequestID="1"/>
				<r VoidingHistoryCollectionId = "2" MessageID="2" RequestID="2"/>
			</root>
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @SettingNameOfJobStatus VARCHAR(50) = '', @SettingNameOfLastRuntime VARCHAR(50) = '', @LastRuntime DATETIME, @SettingNameOfVoidingHistoryCollectionId VARCHAR(50)
	
	DECLARE @ServerName NVARCHAR(100) = @@SERVERNAME, @DBName NVARCHAR(100) = DB_NAME(), @SPName NVARCHAR(300) = OBJECT_NAME(@@PROCID)

	SELECT @Environment = ISNULL(@Environment, ''), @SettingNameOfJobStatus = CASE WHEN @Environment = 'UAT' THEN 'JobStatusUAT' ELSE 'JobStatus' END
		 ,@SettingNameOfLastRuntime = CASE WHEN @Environment = 'UAT' THEN 'LastRuntimeUAT' ELSE 'LastRuntime' END
		 ,@SettingNameOfVoidingHistoryCollectionId = CASE WHEN @Environment = 'UAT' THEN 'LastVoidingHistoryCollectionIdUAT' ELSE 'LastVoidingHistoryCollectionId' END

	-- Get Job Status
	UPDATE dbo.SystemSetting WITH (ROWLOCK)
	SET Value = 'running'
	WHERE ServiceName = 'ChatBot - AbnormalBets'
		AND SettingName = @SettingNameOfJobStatus
		AND Value = 'Completed'
	
	IF @@ROWCOUNT = 0
	BEGIN
		SELECT @LastRuntime = CONVERT(DATETIME, Value) FROM dbo.SystemSetting WITH(NOLOCK) WHERE SettingName = @SettingNameOfLastRuntime AND ServiceName = 'ChatBot - AbnormalBets'

		IF DATEDIFF(SECOND, @LastRuntime, GETDATE()) >= 5 * 60
		BEGIN
			UPDATE dbo.SystemSetting WITH (ROWLOCK)
			SET Value = 'Completed'
			WHERE ServiceName = 'ChatBot - AbnormalBets'
				AND SettingName = @SettingNameOfJobStatus
				AND Value = 'running'

			--Update LastRuntime
			UPDATE dbo.SystemSetting WITH (ROWLOCK)
			SET Value = CONVERT(VARCHAR(20), GETDATE(), 120)
			WHERE ServiceName = 'ChatBot - AbnormalBets'
				AND SettingName = @SettingNameOfLastRuntime
		END
		ELSE 
		BEGIN
			SELECT @ErrCode = 100, @ErrMsg = 'Server Name : ' + @ServerName + ' - Database Name : ' + @DBName + ' - SP Name : '+ @SPName + ' - Error Message : ' + 'ChatBot - AbnormalBets - Job is running.'
		END	
		RETURN
	END

	--Update LastRuntime
	UPDATE dbo.SystemSetting WITH (ROWLOCK)
	SET Value = CONVERT(VARCHAR(20), GETDATE(), 120)
	WHERE ServiceName = 'ChatBot - AbnormalBets'
		AND SettingName = @SettingNameOfLastRuntime

	-- Get messageId and requestId
	CREATE TABLE #MessageRequest (VoidingHistoryCollectionId INT, MessageID INT, RequestID INT)
	INSERT INTO #MessageRequest (VoidingHistoryCollectionId, MessageID, RequestID)
	SELECT 
		t.c.value('@VoidingHistoryCollectionId', 'INT') AS VoidingHistoryCollectionId
		,t.c.value('@MessageID', 'INT') AS MessageID
		,t.c.value('@RequestID', 'INT') AS RequestID
	FROM @Messages.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@Messages = NULL))

	DECLARE @VoidingHistoryCollectionId INT 

	SELECT @VoidingHistoryCollectionId = MAX(VoidingHistoryCollectionId) FROM #MessageRequest

	-- Get Imported Data
	CREATE TABLE #ImportMessage (
		VoidingHistoryCollectionId INT, Username VARCHAR(50), CustId INT, Recommend INT, Mrecommend INT, Srecommend INT, IsTest BIT, Content_en NVARCHAR(4000)
		,Content_cs NVARCHAR(4000), Content_th NVARCHAR(4000), Content_vn NVARCHAR(4000),[Type] TINYINT
	)
	INSERT INTO #ImportMessage (VoidingHistoryCollectionId, Username, CustId, Recommend, Mrecommend, Srecommend, IsTest, Content_en, Content_cs, Content_th, Content_vn, [Type])
	SELECT
		t.c.value('@VoidingHistoryCollectionId', 'INT') AS MessageId
		,ISNULL(l.Username, '') AS Username
		,t.c.value('@CustId', 'INT') AS CustId
		,t.c.value('@Recommend', 'INT') AS Recommend
		,t.c.value('@Mrecommend', 'INT') AS Mrecommend
		,t.c.value('@Srecommend', 'INT') AS Srecommend
		,t.c.value('@IsTest', 'BIT') AS IsTest
		,t.c.value('@Content_en', 'NVARCHAR(4000)') AS Content_en
		,t.c.value('@Content_cs', 'NVARCHAR(4000)') AS Content_cs
		,t.c.value('@Content_th', 'NVARCHAR(4000)') AS Content_th
		,t.c.value('@Content_vn', 'NVARCHAR(4000)') AS Content_vn
		,t.c.value('@Type', 'TINYINT') AS [Type]
	FROM @XmlData.nodes('root/r') t(c)
		OUTER APPLY (
			SELECT f.value AS Username FROM STRING_SPLIT(t.c.value('@UsernameList', 'NVARCHAR(MAX)'), ',') f WHERE f.value <> ''
		) l(Username)
	OPTION (OPTIMIZE FOR (@XmlData = NULL))

	IF @@ROWCOUNT = 0
	BEGIN
		UPDATE dbo.SystemSetting WITH (ROWLOCK)
		SET Value = 'Completed'
		WHERE ServiceName = 'ChatBot - AbnormalBets'
			AND SettingName = @SettingNameOfJobStatus
			AND Value = 'running'

		IF ISNULL(@VoidingHistoryCollectionId, 0) <> 0
		BEGIN
			UPDATE dbo.SystemSetting WITH(ROWLOCK, UPDLOCK)
				SET Value = CONVERT(VARCHAR(50), @VoidingHistoryCollectionId)
			WHERE ServiceName = 'ChatBot - AbnormalBets'
				AND SettingName = @SettingNameOfVoidingHistoryCollectionId
		END
		RETURN
	END

	-- Get Job Setting
	DECLARE @Xml XML
	SELECT  @Xml = CONVERT(XML, Value) FROM dbo.SystemSetting WITH (NOLOCK)
	WHERE ServiceName = 'ChatBot - AbnormalBets'
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
		SELECT @ErrCode = 101, @ErrMsg = 'Server Name : ' + @ServerName + ' - Database Name : ' + @DBName + ' - SP Name : '+ @SPName + ' - Error Message : ' + 'ChatBot - AbnormalBets - Invalid SystemSetting!'
		
		UPDATE dbo.SystemSetting WITH (ROWLOCK)
		SET Value = 'Completed'
		WHERE ServiceName = 'ChatBot - AbnormalBets'
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
		SELECT @ErrCode = 102, @ErrMsg = 'Server Name : ' + @ServerName + ' - Database Name : ' + @DBName + ' - SP Name : '+ @SPName + ' - Error Message : ' + 'ChatBot - AbnormalBets - Notification Template Content(s) are not include Required Param(s)'
		
		UPDATE dbo.SystemSetting WITH (ROWLOCK)
		SET Value = 'Completed'
		WHERE ServiceName = 'ChatBot - AbnormalBets'
			AND SettingName = @SettingNameOfJobStatus
			AND Value = 'running'

		RETURN
	END

	-- Get Recipient
	CREATE TABLE #MessageRecipient (
		VoidingHistoryCollectionId INT, Username VARCHAR(50), DirectAccount INT, HeadlineId INT, IsTest BIT, Content_en NVARCHAR(4000)
		,Content_cs NVARCHAR(4000), Content_th NVARCHAR(4000), Content_vn NVARCHAR(4000), RecipientId INT
	)
	INSERT INTO #MessageRecipient (VoidingHistoryCollectionId, Username, DirectAccount, HeadlineId, IsTest, Content_en, Content_cs, Content_th, Content_vn, RecipientId)
	SELECT m.VoidingHistoryCollectionId, m.Username, pm.CustId, pm.HeadlineId, m.IsTest, m.Content_en, m.Content_cs, m.Content_th, m.Content_vn, r.RecipientId
	FROM #ImportMessage m
		INNER JOIN bodb02.dbo.CustDirectAccount cda WITH (NOLOCK) ON cda.CustId IN (m.CustId, m.Recommend, m.Mrecommend, m.Srecommend)
		INNER JOIN dbo.crmPicManagement pm WITH (NOLOCK) ON cda.CustId = pm.CustId
		INNER JOIN dbo.crmRecipient r WITH (NOLOCK) ON pm.PicId = r.SourceId AND r.DataSource = 'bodb_CRM.dbo.crmPIC'
	
	-- Get group to receive message
	CREATE TABLE #tmpGroup (VoidingHistoryCollectionId INT, ConversationGroupId SMALLINT, ChatTypeId TINYINT, LanguageId INT, DirectAccount INT, NoRecipient INT)
	INSERT INTO #tmpGroup (VoidingHistoryCollectionId, ConversationGroupId, DirectAccount, NoRecipient)
	SELECT m.VoidingHistoryCollectionId, cgr.ConversationGroupId, m.DirectAccount, COUNT(DISTINCT m.RecipientId) AS NoRecipient
	FROM #MessageRecipient m
		INNER JOIN dbo.crmConversationGroupRecipient cgr WITH (NOLOCK) ON m.RecipientId = cgr.RecipientId
		INNER JOIN dbo.crmConversationGroupHeadline cgh WITH (NOLOCK) ON m.HeadlineId = cgh.HeadlineId AND cgr.ConversationGroupId = cgh.ConversationGroupId
		INNER JOIN dbo.crmConversationGroup cg WITH (NOLOCK) ON cgr.ConversationGroupId = cg.ConversationGroupId
	WHERE cg.IsActive = 1
	GROUP BY m.VoidingHistoryCollectionId, cgr.ConversationGroupId, m.DirectAccount

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

	CREATE TABLE #tmpResult (VoidingHistoryCollectionId INT, ConversationGroupId SMALLINT, ChatTypeId TINYINT, LanguageId INT, Username VARCHAR(50), HeadlineId INT, IsTest BIT)
	INSERT INTO #tmpResult (VoidingHistoryCollectionId, ConversationGroupId, ChatTypeId, LanguageId, Username, HeadlineId, IsTest)
	SELECT m.VoidingHistoryCollectionId, g.ConversationGroupId, g.ChatTypeId, g.LanguageId, m.Username, m.HeadlineId, m.IsTest
	FROM #MessageRecipient m
		INNER JOIN #tmpGroup g ON m.VoidingHistoryCollectionId = g.VoidingHistoryCollectionId AND m.DirectAccount = g.DirectAccount
		INNER JOIN dbo.crmConversationGroupRecipient cgr WITH (NOLOCK) ON m.RecipientId = cgr.RecipientId AND g.ConversationGroupId = cgr.ConversationGroupId 
		INNER JOIN dbo.crmConversationGroupHeadline cgh WITH (NOLOCK) ON m.HeadlineId = cgh.HeadlineId AND g.ConversationGroupId = cgh.ConversationGroupId

	CREATE TABLE #Result (
		Id INT IDENTITY(1, 1), VoidingHistoryCollectionId INT, Content_en NVARCHAR(4000), Content_cs NVARCHAR(4000), Content_th NVARCHAR(4000), Content_vn NVARCHAR(4000), ConversationGroupId SMALLINT
		,ChatTypeId TINYINT,LanguageId INT,AffectedList VARCHAR(MAX),HeadlineList VARCHAR(MAX),IsTest BIT,Status VARCHAR(20),RelatedIds VARCHAR(1000),[Type] TINYINT
	)

	DECLARE @Status VARCHAR(20) = 'Planned'
	IF EXISTS (SELECT 1 FROM #NotificationTemplate WHERE IsTest = 1)
		SET @Status = 'Draft'

	-- For Group
	INSERT INTO #Result (VoidingHistoryCollectionId, ConversationGroupId, ChatTypeId, LanguageId, AffectedList, HeadlineList, IsTest, Status)
	SELECT VoidingHistoryCollectionId, ConversationGroupId, ChatTypeId, LanguageId, AffectedList, HeadlineList, IsTest, @Status
	FROM (
		SELECT VoidingHistoryCollectionId, ConversationGroupId, ChatTypeId, LanguageId
			,STUFF(
					(SELECT DISTINCT ', ' + Username
						FROM #tmpResult t2
						WHERE t1.VoidingHistoryCollectionId = t2.VoidingHistoryCollectionId AND t1.ConversationGroupId = t2.ConversationGroupId
						FOR XML PATH ('')
					), 1, 1, ''
				) AS AffectedList
			,STUFF(
					(SELECT DISTINCT ',' + CONVERT(VARCHAR(20), HeadlineId)
						FROM #tmpResult t2
						WHERE t1.VoidingHistoryCollectionId = t2.VoidingHistoryCollectionId AND t1.ConversationGroupId = t2.ConversationGroupId
						FOR XML PATH ('')
					), 1, 1, ''
				) AS HeadlineList
			,MIN(CONVERT(TINYINT, t1.IsTest)) AS IsTest
		FROM #tmpResult t1
		WHERE t1.ChatTypeId = 1 -- Group
		GROUP BY VoidingHistoryCollectionId, ConversationGroupId, ChatTypeId, LanguageId
	) t

	-- For Personal
	;WITH CTE_tmpPersonal AS (
		SELECT p.VoidingHistoryCollectionId, p.ConversationGroupId, p.ChatTypeId, p.LanguageId, p.Username, p.HeadlineId, p.IsTest, t.Id AS RelatedId
		FROM #tmpResult p
			OUTER APPLY (
				SELECT DISTINCT r.Id
				FROM dbo.crmConversationGroupRecipient cgr1 WITH (NOLOCK)
					INNER JOIN dbo.crmConversationGroupRecipient cgr2 WITH (NOLOCK) ON cgr2.RecipientId = cgr1.RecipientId
					INNER JOIN #tmpResult g ON g.ConversationGroupId = cgr2.ConversationGroupId
					INNER JOIN #Result r ON g.VoidingHistoryCollectionId = r.VoidingHistoryCollectionId AND g.ConversationGroupId = r.ConversationGroupId
				WHERE p.ConversationGroupId = cgr1.ConversationGroupId AND p.VoidingHistoryCollectionId = g.VoidingHistoryCollectionId AND p.Username = g.Username AND g.ChatTypeId = 1 -- Group
			) t
		WHERE p.ChatTypeId = 2 -- Personal
	)
	,CTE_tempResult AS (
		SELECT VoidingHistoryCollectionId, ConversationGroupId, ChatTypeId, LanguageId, Username, HeadlineId, IsTest
			,CASE WHEN t1.RelatedId IS NULL THEN 0 ELSE 1 END AS IsDuplicated
			,STUFF(
					(SELECT DISTINCT ',' + CONVERT(VARCHAR(20), t2.RelatedId)
						FROM CTE_tmpPersonal t2
						WHERE t1.VoidingHistoryCollectionId = t2.VoidingHistoryCollectionId AND t1.ConversationGroupId = t2.ConversationGroupId
						FOR XML PATH ('')
					), 1, 1, ''
				) AS RelatedIds
		FROM CTE_tmpPersonal t1
		GROUP BY VoidingHistoryCollectionId, ConversationGroupId, ChatTypeId, LanguageId, Username, HeadlineId, IsTest
		,CASE WHEN t1.RelatedId IS NULL THEN 0 ELSE 1 END
	)
	INSERT INTO #Result (VoidingHistoryCollectionId, ConversationGroupId, ChatTypeId, LanguageId, AffectedList, HeadlineList, IsTest, Status, RelatedIds)
	SELECT VoidingHistoryCollectionId, ConversationGroupId, ChatTypeId, LanguageId, AffectedList, HeadlineList, IsTest, CASE WHEN IsDuplicated = 1 THEN 'Duplicated' ELSE @Status END, CASE WHEN IsDuplicated = 1 THEN RelatedIds END
	FROM (
		SELECT VoidingHistoryCollectionId, ConversationGroupId, ChatTypeId, LanguageId, IsDuplicated
			,STUFF(
					(SELECT DISTINCT ', ' + t2.Username
						FROM CTE_tempResult t2
						WHERE t1.VoidingHistoryCollectionId = t2.VoidingHistoryCollectionId AND t1.ConversationGroupId = t2.ConversationGroupId AND t1.IsDuplicated = t2.IsDuplicated
						FOR XML PATH ('')
					), 1, 1, ''
				) AS AffectedList
			,STUFF(
					(SELECT DISTINCT ',' + CONVERT(VARCHAR(20), t2.HeadlineId)
						FROM CTE_tempResult t2
						WHERE t1.VoidingHistoryCollectionId = t2.VoidingHistoryCollectionId AND t1.ConversationGroupId = t2.ConversationGroupId AND t1.IsDuplicated = t2.IsDuplicated
						FOR XML PATH ('')
					), 1, 1, ''
				) AS HeadlineList
			,STUFF(
					(SELECT DISTINCT ',' + t2.RelatedIds
						FROM CTE_tempResult t2
						WHERE t1.VoidingHistoryCollectionId = t2.VoidingHistoryCollectionId AND t1.ConversationGroupId = t2.ConversationGroupId AND t1.IsDuplicated = t2.IsDuplicated
						FOR XML PATH ('')
					), 1, 1, ''
				) AS RelatedIds
			,MIN(CONVERT(TINYINT, t1.IsTest)) AS IsTest
		FROM CTE_tempResult t1
		GROUP BY VoidingHistoryCollectionId, ConversationGroupId, ChatTypeId, LanguageId, IsDuplicated
	) t

	UPDATE #Result SET Status = 'Planned' WHERE IsTest = 1 AND Status = 'Draft'

	UPDATE r
	SET r.Content_en = m.Content_en, r.Content_cs = m.Content_cs, r.Content_th = m.Content_th, r.Content_vn = m.Content_vn, r.[Type] = m.[Type]
	FROM #Result r
		CROSS APPLY (
			SELECT TOP 1 m.Content_en, m.Content_cs, m.Content_th, m.Content_vn, m.[Type]
			FROM #ImportMessage m
			WHERE r.VoidingHistoryCollectionId = m.VoidingHistoryCollectionId
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

		INSERT INTO dbo.crmNotification (ReferenceId, DataSource ,NotificationTypeId, Sender, SendDate, Title, Status, Content, RelatedNotificationIds)
		SELECT NULL AS ReferenceId, NULL, nt.NotificationTypeId, @Sender, @SendDate, nt.Title, r.Status
			,REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(nt.Content, '{EN Announcement}', r.Content_en), '{SC Announcement}', r.Content_cs), '{TH Announcement}', r.Content_th), '{YN Announcement}', r.Content_vn), '{Affected List}', r.AffectedList)
			,r.RelatedIds
		FROM #Result r
			INNER JOIN #NotificationTemplate nt ON r.LanguageId = nt.LanguageId AND r.[Type] = nt.[Type]
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
		SELECT DISTINCT @NotificationId, f.value
		FROM #Result r
			CROSS APPLY STRING_SPLIT(r.HeadlineList, ',') f
		WHERE r.Id = @Id

		INSERT INTO dbo.crmNotificationRefDetail (NotificationId, ReferenceId, DataSource, CreatedDate)
		SELECT DISTINCT @NotificationId, mr.MessageID, 'DBMSG.bodb_Message.dbo.Msg', GETDATE()
		FROM #MessageRequest mr
			INNER JOIN #Result r ON mr.VoidingHistoryCollectionId = r.VoidingHistoryCollectionId 
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

	UPDATE dbo.SystemSetting WITH (ROWLOCK, UPDLOCK)
	SET Value = 'Completed'
	WHERE ServiceName = 'ChatBot - AbnormalBets'
		AND SettingName = @SettingNameOfJobStatus
		AND Value = 'running'

	UPDATE dbo.SystemSetting WITH(ROWLOCK, UPDLOCK)
		SET Value = CONVERT(VARCHAR(50), @VoidingHistoryCollectionId)
	WHERE ServiceName = 'ChatBot - AbnormalBets'
		AND SettingName = @SettingNameOfVoidingHistoryCollectionId
	
	DROP TABLE #ImportMessage
	DROP TABLE #MessageRecipient
	DROP TABLE #NotificationTemplate
	DROP TABLE #Result
	DROP TABLE #tmpGroup
	DROP TABLE #tmpResult
	DROP TABLE #MessageRequest
END
GO