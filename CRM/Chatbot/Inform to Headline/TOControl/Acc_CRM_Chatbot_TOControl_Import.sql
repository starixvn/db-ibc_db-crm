/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_Chatbot_TOControl_Import]
	@XmlData				XML
	,@Environment			VARCHAR(50) = ''
	,@ErrCode				INT = 0 OUTPUT
	,@ErrMsg				NVARCHAR(4000) = '' OUTPUT
AS

/*
	Created: 20201104@Malcolm
	DB: DBCRM-bodb_CRM
	Task: CRM - TOControl - Import Notification

	Revisions:
		- 20201104@Malcolm: Initialize SP [RedmineID: #146735]
		- 20210726@Malcolm: Change data type of logId [RedmineID: #157303]
		- 20220112@Malcolm: Update job status = 'Completed' when job runs longer than 5 minutes [RedmineID: #167358]

	Param's Explanation:
		. @XmlData
			<root>
				<r LogId="1" CustId="46386637" Username="superrbRM2111" Recommend="46386636" Mrecommend="46386635" Srecommend="46386634" CurrencyName="UUS" RoleEN="RoleEN" RoleSC="RoleSC" RoleTH="RoleTH" RoleYN="RoleYN" SportNameEN="SportNameEN"  SportNameSC="SportNameSC"  SportNameTH="SportNameTH"  SportNameYN="SportNameYN" LeagueNameEN="LeagueNameEN" LeagueNameSC="LeagueNameSC" LeagueNameTH="LeagueNameTH" LeagueNameYN ="LeagueNameYN" HomeNameEN	="HomeNameEN" HomeNameSC="HomeNameSC" HomeNameTH="HomeNameTH" HomeNameYN="HomeNameYN" AwayNameEN="AwayNameEN" AwayNameSC="AwayNameSC" AwayNameTH="AwayNameTH" AwayNameYN="AwayNameYN" Outstanding="11"></r>
				<r LogId="2" CustId="46386637" Username="superrbRM2111" Recommend="46386636" Mrecommend="46386635" Srecommend="46386634" CurrencyName="UUS" RoleEN="RoleEN" RoleSC="RoleSC" RoleTH="RoleTH" RoleYN="RoleYN" SportNameEN="SportNameEN"  SportNameSC="SportNameSC"  SportNameTH="SportNameTH"  SportNameYN="SportNameYN" LeagueNameEN="LeagueNameEN" LeagueNameSC="LeagueNameSC" LeagueNameTH="LeagueNameTH" LeagueNameYN ="LeagueNameYN" HomeNameEN	="HomeNameEN" HomeNameSC="HomeNameSC" HomeNameTH="HomeNameTH" HomeNameYN="HomeNameYN" AwayNameEN="AwayNameEN" AwayNameSC="AwayNameSC" AwayNameTH="AwayNameTH" AwayNameYN="AwayNameYN" Outstanding="11"></r>
			</root>
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @lastLogId BIGINT, @SettingNameOfJobStatus VARCHAR(50) = '',@SettingNameOflastLogId VARCHAR(50) = '', @IncludeUUSCurrency BIT, @LastRuntime DATETIME 
			,@SettingNameOfLastRuntime VARCHAR(50) = ''

	SELECT @IncludeUUSCurrency = CONVERT(BIT, Value) FROM SystemSetting WHERE ServiceName = 'ChatBot - TOControl' and SettingName = 'IncludeUUSCurrency'

	SELECT @Environment = ISNULL(@Environment, '')
		   ,@SettingNameOfJobStatus = CASE WHEN @Environment = 'UAT' THEN 'JobStatusUAT' ELSE 'JobStatus' END
		   ,@SettingNameOflastLogId = CASE WHEN @Environment = 'UAT' THEN 'LastLogIdUAT' ELSE 'LastLogID' END
		   ,@SettingNameOfLastRuntime = CASE WHEN @Environment = 'UAT' THEN 'LastRuntimeUAT' ELSE 'LastRuntime' END

	-- Get Job Status
	UPDATE dbo.SystemSetting WITH (ROWLOCK)
	SET Value = 'running'
	WHERE ServiceName = 'ChatBot - TOControl'
		AND SettingName = @SettingNameOfJobStatus
		AND Value = 'Completed'
	
	IF @@ROWCOUNT = 0
	BEGIN
		SELECT @LastRuntime = CONVERT(DATETIME, Value) FROM dbo.SystemSetting WITH(NOLOCK) WHERE SettingName = @SettingNameOfLastRuntime AND ServiceName = 'ChatBot - TOControl'

		IF DATEDIFF(SECOND, @LastRuntime, GETDATE()) >= 5 * 60
		BEGIN
			UPDATE dbo.SystemSetting WITH (ROWLOCK)
			SET Value = 'Completed'
			WHERE ServiceName = 'ChatBot - TOControl'
				AND SettingName = @SettingNameOfJobStatus
				AND Value = 'running'
		END
		ELSE 
		BEGIN
			SELECT @ErrCode = 100, @ErrMsg = 'ChatBot - TOControl - Job is running.'
			RETURN
		END	
	END

	--Update LastRuntime
	UPDATE dbo.SystemSetting WITH (ROWLOCK)
	SET Value = CONVERT(VARCHAR(20), GETDATE(), 120)
	WHERE ServiceName = 'ChatBot - TOControl'
		AND SettingName = @SettingNameOfLastRuntime

	-- Get Imported Data
	CREATE TABLE #ImportData
	(
		LogId					BIGINT
		,CustId					INT
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
		SELECT @ErrCode = 101, @ErrMsg = 'ChatBot - TOControl - Invalid SystemSetting!'
		
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

	-- Delete Logs which are imported into crmNotification
	DELETE i
	FROM #ImportData i
	CROSS APPLY (
		SELECT TOP 1 n.ReferenceId
		FROM dbo.crmNotification n WITH(NOLOCK)
		WHERE n.ReferenceId = i.LogId AND n.DataSource = 'TOControl'
	) AS c

	IF NOT EXISTS (SELECT 1 FROM #ImportData)
	BEGIN
		UPDATE dbo.SystemSetting WITH (ROWLOCK)
		SET Value = CONVERT(VARCHAR(20), @lastLogId)
		WHERE ServiceName = 'ChatBot - TOControl'
			AND SettingName = @SettingNameOflastLogId

		UPDATE dbo.SystemSetting WITH (ROWLOCK)
		SET Value = 'Completed'
		WHERE ServiceName = 'ChatBot - TOControl'
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
		,RecipientId		INT
	)
	INSERT INTO #LogRecipient 
	(
		LogId			
		,Username		
		,DirectAccount	
		,HeadlineId		
		,RecipientId	
	)
	SELECT 
		m.LogId			
		,m.Username		
		,pm.CustId	
		,pm.HeadlineId		
		,r.RecipientId
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

	CREATE TABLE #tmpResult (LogId BIGINT, ConversationGroupId SMALLINT, ChatTypeId TINYINT, LanguageId INT, Username VARCHAR(50), HeadlineId INT)
	INSERT INTO #tmpResult (LogId, ConversationGroupId, ChatTypeId, LanguageId, Username, HeadlineId)
	SELECT m.LogId, g.ConversationGroupId, g.ChatTypeId, g.LanguageId, m.Username, m.HeadlineId
	FROM #LogRecipient m
		INNER JOIN #tmpGroup g ON m.LogId = g.LogId AND m.DirectAccount = g.DirectAccount
		INNER JOIN dbo.crmConversationGroupRecipient cgr WITH (NOLOCK) ON m.RecipientId = cgr.RecipientId AND g.ConversationGroupId = cgr.ConversationGroupId 
		INNER JOIN dbo.crmConversationGroupHeadline cgh WITH (NOLOCK) ON m.HeadlineId = cgh.HeadlineId AND g.ConversationGroupId = cgh.ConversationGroupId

	CREATE TABLE #Result
	(
		Id						INT IDENTITY(1, 1)
		,LogId					BIGINT
		,Username				VARCHAR(30)
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
		,ConversationGroupId	SMALLINT
		,ChatTypeId				TINYINT
		,LanguageId				INT
		,HeadlineList			VARCHAR(MAX)
		,Status					VARCHAR(20)
		,RelatedIds				VARCHAR(1000)
	)

	DECLARE @Status VARCHAR(20) = 'Planned'
	IF EXISTS (SELECT 1 FROM #NotificationTemplate WHERE IsTest = 1)
		SET @Status = 'Draft'

	-- For Group
	INSERT INTO #Result (LogId, ConversationGroupId, ChatTypeId, LanguageId, HeadlineList, Status)
	SELECT LogId, ConversationGroupId, ChatTypeId, LanguageId, HeadlineList, @Status
	FROM (
		SELECT LogId, ConversationGroupId, ChatTypeId, LanguageId
			,STUFF(
					(SELECT DISTINCT ',' + CONVERT(VARCHAR(20), HeadlineId)
						FROM #tmpResult t2
						WHERE t1.LogId = t2.LogId AND t1.ConversationGroupId = t2.ConversationGroupId
						FOR XML PATH ('')
					), 1, 1, ''
				) AS HeadlineList
		FROM #tmpResult t1
		WHERE t1.ChatTypeId = 1 -- Group
		GROUP BY LogId, ConversationGroupId, ChatTypeId, LanguageId
	) t

	-- For Personal
	;WITH CTE_tmpPersonal AS (
		SELECT p.LogId, p.ConversationGroupId, p.ChatTypeId, p.LanguageId, p.Username, p.HeadlineId, t.Id AS RelatedId
		FROM #tmpResult p
			OUTER APPLY (
				SELECT DISTINCT r.Id
				FROM dbo.crmConversationGroupRecipient cgr1 WITH (NOLOCK)
					INNER JOIN dbo.crmConversationGroupRecipient cgr2 WITH (NOLOCK) ON cgr2.RecipientId = cgr1.RecipientId
					INNER JOIN #tmpResult g ON g.ConversationGroupId = cgr2.ConversationGroupId
					INNER JOIN #Result r ON g.LogId = r.LogId AND g.ConversationGroupId = r.ConversationGroupId
				WHERE p.ConversationGroupId = cgr1.ConversationGroupId AND p.LogId = g.LogId AND p.Username = g.Username AND g.ChatTypeId = 1 -- Group
			) t
		WHERE p.ChatTypeId = 2 -- Personal
	)
	,CTE_tempResult AS (
		SELECT LogId, ConversationGroupId, ChatTypeId, LanguageId, Username, HeadlineId
			,CASE WHEN t1.RelatedId IS NULL THEN 0 ELSE 1 END AS IsDuplicated
			,STUFF(
					(SELECT DISTINCT ',' + CONVERT(VARCHAR(20), t2.RelatedId)
						FROM CTE_tmpPersonal t2
						WHERE t1.LogId = t2.LogId AND t1.ConversationGroupId = t2.ConversationGroupId
						FOR XML PATH ('')
					), 1, 1, ''
				) AS RelatedIds
		FROM CTE_tmpPersonal t1
		GROUP BY LogId, ConversationGroupId, ChatTypeId, LanguageId, Username, HeadlineId
		,CASE WHEN t1.RelatedId IS NULL THEN 0 ELSE 1 END
	)
	INSERT INTO #Result (LogId, ConversationGroupId, ChatTypeId, LanguageId, HeadlineList, Status, RelatedIds)
	SELECT LogId, ConversationGroupId, ChatTypeId, LanguageId, HeadlineList, CASE WHEN IsDuplicated = 1 THEN 'Duplicated' ELSE @Status END, CASE WHEN IsDuplicated = 1 THEN RelatedIds END
	FROM (
		SELECT LogId, ConversationGroupId, ChatTypeId, LanguageId, IsDuplicated
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
		GROUP BY LogId, ConversationGroupId, ChatTypeId, LanguageId, IsDuplicated
	) t

	UPDATE r
	SET r.Username = m.Username
		,r.CurrencyName	= m.CurrencyName
		,r.RoleEN		= m.RoleEN		
		,r.RoleSC		= m.RoleSC				
		,r.RoleTH		= m.RoleTH			
		,r.RoleYN		= m.RoleYN			
		,r.SportNameEN	= m.SportNameEN	
		,r.SportNameSC	= m.SportNameSC
		,r.SportNameTH	= m.SportNameTH	
		,r.SportNameYN	= m.SportNameYN		
		,r.LeagueNameEN = m.LeagueNameEN		
		,r.LeagueNameSC = m.LeagueNameSC		
		,r.LeagueNameTH = m.LeagueNameTH	
		,r.LeagueNameYN = m.LeagueNameYN
		,r.HomeNameEN	= m.HomeNameEN			
		,r.HomeNameSC	= m.HomeNameSC		
		,r.HomeNameTH	= m.HomeNameTH			
		,r.HomeNameYN	= m.HomeNameYN			
		,r.AwayNameEN	= m.AwayNameEN		
		,r.AwayNameSC	= m.AwayNameSC			
		,r.AwayNameTH	= m.AwayNameTH			
		,r.AwayNameYN	= m.AwayNameYN			
		,r.Outstanding	= m.Outstanding	
		,r.Status = CASE WHEN m.CurrencyName = 'UUS' AND r.Status = 'Draft' THEN 'Planned' ELSE r.Status END
	FROM #Result r
		CROSS APPLY (
			SELECT TOP 1 
				m.Username
				,m.CurrencyName	
				,m.RoleEN		
				,m.RoleSC		
				,m.RoleTH		
				,m.RoleYN		
				,m.SportNameEN	
				,m.SportNameSC	
				,m.SportNameTH	
				,m.SportNameYN	
				,m.LeagueNameEN 
				,m.LeagueNameSC 
				,m.LeagueNameTH 
				,m.LeagueNameYN 
				,m.HomeNameEN	
				,m.HomeNameSC	
				,m.HomeNameTH	
				,m.HomeNameYN	
				,m.AwayNameEN	
				,m.AwayNameSC	
				,m.AwayNameTH	
				,m.AwayNameYN	
				,m.Outstanding	
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

		INSERT INTO dbo.crmNotification (ReferenceId, DataSource, NotificationTypeId, Sender, SendDate, Title, Status, Content, RelatedNotificationIds)
		SELECT r.LogId, 'TOControl', nt.NotificationTypeId, @Sender, @SendDate, nt.Title, r.Status
			,REPLACE
				(REPLACE
					(REPLACE
						(REPLACE
							(REPLACE
								(REPLACE
									(REPLACE
										(REPLACE
											(REPLACE
												(REPLACE
													(REPLACE
														(REPLACE
															(REPLACE
																(REPLACE
																	(REPLACE
																		(REPLACE
																			(REPLACE(
																				REPLACE(
																					REPLACE(
																						REPLACE(
																							REPLACE(
																								REPLACE(
																									REPLACE(nt.Content, '{event_outstanding}', CONVERT(VARCHAR, r.Outstanding, 1))
																								,'{currency_name}', r.CurrencyName)
																							,'{sport_name_en}', r.SportNameEN)
																						,'{sport_name_sc}', r.SportNameSC)
																					,'{sport_name_th}', r.SportNameTH)
																				,'{sport_name_yn}', r.SportNameYN)
																			,'{league_name_en}', r.LeagueNameEN)
																		,'{league_name_sc}', r.LeagueNameSC)
																	,'{league_name_th}', r.LeagueNameTH)
																,'{league_name_yn}', r.LeagueNameYN)
															,'{home_name_en}', r.HomeNameEN)
														,'{home_name_sc}', r.HomeNameSC)
													,'{home_name_th}', r.HomeNameTH)
												,'{home_name_yn}', r.HomeNameYN)
											,'{away_name_en}', r.AwayNameEN)
										,'{away_name_sc}', r.AwayNameSC)
									,'{away_name_th}', r.AwayNameTH)
								,'{away_name_yn}', r.AwayNameYN)
							,'{SMA_level_en}', r.RoleEN)
						,'{SMA_level_sc}', r.RoleSC)
					,'{SMA_level_th}', r.RoleTH)
				,'{SMA_level_yn}', r.RoleYN)
			,'{SMA_username}', r.Username)
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

	-- Update lastLogId
	UPDATE dbo.SystemSetting WITH (ROWLOCK)
	SET Value = CONVERT(VARCHAR(20), @lastLogId)
	WHERE ServiceName = 'ChatBot - TOControl'
		AND SettingName = @SettingNameOflastLogId

	-- Update crmMessageImport
	UPDATE dbo.SystemSetting WITH (ROWLOCK)
	SET Value = 'Completed'
	WHERE ServiceName = 'ChatBot - TOControl'
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