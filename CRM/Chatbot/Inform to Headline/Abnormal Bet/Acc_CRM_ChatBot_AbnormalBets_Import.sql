/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_Chatbot_AbnormalBets_Import]
	@XmlData	XML
	,@Messages	XML
	,@ErrCode	INT = 0 OUTPUT
	,@ErrMsg	NVARCHAR(4000) = '' OUTPUT
AS

/*
	Created: 20200811@Percy
	DB: DBCRM-bodb_CRM
	Task: CRM - ChatBot - Import Notification

	Revisions:
		- 20200811@Percy: Initialize SP [RedmineID: #130544]

	Param's Explanation:
		. @XmlData
			<root>
				<r MessageId="1" Username="XXX" CustId="114" Recommend="113" Mrecommend="112" Srecommend="111" IsTest="0" Content_en="" Content_cs="" Content_th="" Content_vn="" />
				<r MessageId="1" Username="XYZ" CustId="115" Recommend="113" Mrecommend="112" Srecommend="111" IsTest="0" Content_en="" Content_cs="" Content_th="" Content_vn="" />
			</root>
		. @Messages:
			<root>
				<r MessageID=1 RequestID=1 />
				<r MessageID=1 RequestID=2 />
				<r MessageID=3 RequestID=2 />
			</root>
*/

BEGIN
	SET NOCOUNT ON

	-- Get Job Status
	UPDATE dbo.SystemSetting WITH (ROWLOCK)
	SET Value = 'running'
	WHERE ServiceName = 'ChatBot - AbnormalBets'
		AND SettingName = 'JobStatus'
		AND Value = 'Completed'
	
	IF @@ROWCOUNT = 0
	BEGIN
		SELECT @ErrCode = 100, @ErrMsg = 'Job is running.'
		RETURN
	END

	-- Get Imported Data
	CREATE TABLE #ImportMessage
	(
		MessageId INT
		,Username VARCHAR(50)
		,CustId INT
		,Recommend INT
		,Mrecommend INT
		,Srecommend INT
		,IsTest BIT
		,Content_en NVARCHAR(4000)
		,Content_cs NVARCHAR(4000)
		,Content_th NVARCHAR(4000)
		,Content_vn NVARCHAR(4000)
	)
	INSERT INTO #ImportMessage (MessageId, Username, CustId, Recommend, Mrecommend, Srecommend, IsTest, Content_en, Content_cs, Content_th, Content_vn)
	SELECT
		t.c.value('@MessageId', 'INT') AS MessageId
		,t.c.value('@Username', 'VARCHAR(50)') AS Username
		,t.c.value('@CustId', 'INT') AS CustId
		,t.c.value('@Recommend', 'INT') AS Recommend
		,t.c.value('@Mrecommend', 'INT') AS Mrecommend
		,t.c.value('@Srecommend', 'INT') AS Srecommend
		,t.c.value('@IsTest', 'BIT') AS IsTest
		,t.c.value('@Content_en', 'NVARCHAR(4000)') AS Content_en
		,t.c.value('@Content_cs', 'NVARCHAR(4000)') AS Content_cs
		,t.c.value('@Content_th', 'NVARCHAR(4000)') AS Content_th
		,t.c.value('@Content_vn', 'NVARCHAR(4000)') AS Content_vn
	FROM @XmlData.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@XmlData = NULL))

	IF @@ROWCOUNT = 0
	BEGIN
		-- Update crmMessageImport
		EXEC dbo.Acc_CRM_ChatBot_crmMessageImport_Upd @Messages = @Messages

		UPDATE dbo.SystemSetting WITH (ROWLOCK)
		SET Value = 'Completed'
		WHERE ServiceName = 'ChatBot - AbnormalBets'
			AND SettingName = 'JobStatus'
			AND Value = 'running'

		RETURN
	END

	-- Get Job Setting
	DECLARE @Xml XML
	SELECT  @Xml = CONVERT(XML, Value) FROM dbo.SystemSetting WITH (NOLOCK)
	WHERE ServiceName = 'ChatBot - AbnormalBets'
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
		WHERE ServiceName = 'ChatBot - AbnormalBets'
			AND SettingName = 'JobStatus'
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
		WHERE ServiceName = 'ChatBot - AbnormalBets'
			AND SettingName = 'JobStatus'
			AND Value = 'running'

		RETURN
	END

	-- Get Recipient
	CREATE TABLE #MessageRecipient
	(
		MessageId INT
		,Username VARCHAR(50)
		,HeadlineId INT
		,IsTest BIT
		,Content_en NVARCHAR(4000)
		,Content_cs NVARCHAR(4000)
		,Content_th NVARCHAR(4000)
		,Content_vn NVARCHAR(4000)
		,RecipientId INT
	)
	INSERT INTO #MessageRecipient (MessageId, Username, HeadlineId, IsTest, Content_en, Content_cs, Content_th, Content_vn, RecipientId)
	SELECT m.MessageId, m.Username, pm.HeadlineId, m.IsTest, m.Content_en, m.Content_cs, m.Content_th, m.Content_vn, r.RecipientId
	FROM #ImportMessage m
		INNER JOIN bodb02.dbo.CustDirectAccount cda WITH (NOLOCK) ON cda.CustId IN (m.CustId, m.Recommend, m.Mrecommend, m.Srecommend)
		INNER JOIN dbo.crmPicManagement pm WITH (NOLOCK) ON cda.CustId = pm.CustId
		INNER JOIN dbo.crmRecipient r WITH (NOLOCK) ON pm.PicId = r.SourceId AND r.DataSource = 'bodb_CRM.dbo.crmPIC'
	
	-- Get group to receive message
	CREATE TABLE #tmpGroup (MessageId INT, ConversationGroupId SMALLINT, NoRecipient INT)
	INSERT INTO #tmpGroup (MessageId, ConversationGroupId, NoRecipient)
	SELECT m.MessageId, cgr.ConversationGroupId, COUNT(1) AS NoRecipient
	FROM #MessageRecipient m
		INNER JOIN dbo.crmConversationGroupRecipient cgr WITH (NOLOCK) ON m.RecipientId = cgr.RecipientId
		INNER JOIN dbo.crmConversationGroupHeadline cgh WITH (NOLOCK) ON m.HeadlineId = cgh.HeadlineId AND cgr.ConversationGroupId = cgh.ConversationGroupId
		INNER JOIN dbo.crmConversationGroup cg WITH (NOLOCK) ON cgr.ConversationGroupId = cg.ConversationGroupId
	WHERE cg.IsActive = 1
	GROUP BY m.MessageId, cgr.ConversationGroupId

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

	CREATE TABLE #tmpResult (MessageId INT, ConversationGroupId SMALLINT, Username VARCHAR(50), HeadlineId INT, IsTest BIT)
	INSERT INTO #tmpResult (MessageId, ConversationGroupId, Username, HeadlineId, IsTest)
	SELECT m.MessageId, g.ConversationGroupId, m.Username, m.HeadlineId, m.IsTest
	FROM dbo.crmConversationGroupRecipient cgr WITH (NOLOCK)
		INNER JOIN #tmpGroup g ON g.ConversationGroupId = cgr.ConversationGroupId
		INNER JOIN #MessageRecipient m ON m.MessageId = g.MessageId AND m.RecipientId = cgr.RecipientId
	GROUP BY m.MessageId, g.ConversationGroupId, m.Username, m.HeadlineId, m.IsTest

	CREATE TABLE #Result
	(
		Id INT IDENTITY(1, 1)
		,MessageId INT
		,Content_en NVARCHAR(4000)
		,Content_cs NVARCHAR(4000)
		,Content_th NVARCHAR(4000)
		,Content_vn NVARCHAR(4000)
		,ConversationGroupId SMALLINT
		,ChatTypeId TINYINT
		,LanguageId INT
		,AffectedList VARCHAR(MAX)
		,HeadlineList VARCHAR(MAX)
		,IsTest BIT
		,Status VARCHAR(20)
		,RelatedIds VARCHAR(1000)
	)

	DECLARE @Status VARCHAR(20) = 'Planned'
	IF EXISTS (SELECT 1 FROM #NotificationTemplate WHERE IsTest = 1)
		SET @Status = 'Draft'

	INSERT INTO #Result (MessageId, ConversationGroupId, ChatTypeId, LanguageId, AffectedList, HeadlineList, IsTest, Status)
	SELECT t.MessageId, t.ConversationGroupId, cg.ChatTypeId, cg.LanguageId, t.AffectedList, t.HeadlineList, t.IsTest, t.Status
	FROM (
		SELECT MessageId, ConversationGroupId
			,STUFF(
					(SELECT ', ' + Username
						FROM #tmpResult t2
						WHERE t1.MessageId = t2.MessageId AND t1.ConversationGroupId = t2.ConversationGroupId
						FOR XML PATH ('')
					), 1, 1, ''
				) AS AffectedList
			,STUFF(
					(SELECT DISTINCT ',' + CONVERT(VARCHAR(20), HeadlineId)
						FROM #tmpResult t2
						WHERE t1.MessageId = t2.MessageId AND t1.ConversationGroupId = t2.ConversationGroupId
						FOR XML PATH ('')
					), 1, 1, ''
				) AS HeadlineList
			,MAX(CONVERT(TINYINT, t1.IsTest)) AS IsTest
			,@Status AS Status
		FROM #tmpResult t1
		GROUP BY MessageId, ConversationGroupId
	) t
		INNER JOIN dbo.crmConversationGroup cg WITH (NOLOCK) ON t.ConversationGroupId = cg.ConversationGroupId
	ORDER BY cg.ChatTypeId ASC

	UPDATE #Result SET Status = 'Draft' WHERE IsTest = 1 AND Status = 'Planned'

	UPDATE r
	SET r.Content_en = m.Content_en, r.Content_cs = m.Content_cs, r.Content_th = m.Content_th, r.Content_vn = m.Content_vn
	FROM #Result r
		CROSS APPLY (
			SELECT TOP 1 m.Content_en, m.Content_cs, m.Content_th, m.Content_vn
			FROM #ImportMessage m
			WHERE r.MessageId = m.MessageId
		) m
	
	-- If message just in group --> personal is marked duplicated
	UPDATE r1
	SET r1.Status = 'Duplicated'
		,r1.RelatedIds = RIGHT(r2.RelatedIds, LEN(r2.RelatedIds) - 1)
	FROM #Result r1
		CROSS APPLY (
			SELECT (
				SELECT ',' + CONVERT(VARCHAR(10), r2.Id)
				FROM #Result r2
				WHERE r1.MessageId = r2.MessageId
					AND r2.ChatTypeId = 1 -- Group
					AND r1.AffectedList = r2.AffectedList
				FOR XML PATH('')
			) AS RelatedIds
		) r2
	WHERE r1.ChatTypeId = 2 -- Personal
		AND r2.RelatedIds IS NOT NULL
		AND Status = 'Planned'

	-- Import Notification
	DECLARE @Sender				INT = 10278938 -- StarixIT
			,@SendDate			DATETIME = GETDATE()
			,@NotificationId	INT
			,@Id				INT = 1

	WHILE 1 = 1
	BEGIN
		IF NOT EXISTS (SELECT 1 FROM #Result WHERE Id = @Id)
			BREAK

		INSERT INTO dbo.crmNotification (MessageId, NotificationTypeId, Sender, SendDate, Title, Status, Content, RelatedNotificationIds)
		SELECT r.MessageId, nt.NotificationTypeId, @Sender, @SendDate, nt.Title, r.Status
			,REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(nt.Content, '{EN Announcement}', r.Content_en), '{SC Announcement}', r.Content_cs), '{TH Announcement}', r.Content_th), '{YN Announcement}', r.Content_vn), '{Affected List}', r.AffectedList)
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

		SELECT @Id = @Id + 1
	END

	-- Update crmMessageImport
	EXEC dbo.Acc_CRM_ChatBot_crmMessageImport_Upd @Messages = @Messages

	UPDATE dbo.SystemSetting WITH (ROWLOCK)
	SET Value = 'Completed'
	WHERE ServiceName = 'ChatBot - AbnormalBets'
		AND SettingName = 'JobStatus'
		AND Value = 'running'

	DROP TABLE #ImportMessage
	DROP TABLE #MessageRecipient
	DROP TABLE #NotificationTemplate
	DROP TABLE #Result
	DROP TABLE #tmpGroup
	DROP TABLE #tmpResult
END
GO