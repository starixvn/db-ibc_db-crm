/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_Chatbot_ProblemAccounts_Import]
		@XmlData				XML
		,@Environment			VARCHAR(50) = ''
		,@ErrCode				INT = 0 OUTPUT
		,@ErrMsg				NVARCHAR(4000) = '' OUTPUT
AS

/*
	Created: 20210426@Malcolm
	DB: DBCRM-bodb_CRM
	Task: CRM - Problem Account - Import Problem Accounts (Only member Level)

	Revisions:
		- 20210426@Malcolm: Initialize SP [RedmineId: #153119]
*/

BEGIN
	SET NOCOUNT ON

	SELECT @Environment = ISNULL(@Environment, '')
		   ,@SettingNameOfJobStatus = CASE WHEN @Environment = 'UAT' THEN 'JobStatusUAT' ELSE 'JobStatus' END
		   ,@SettingNameOflastLogId = CASE WHEN @Environment = 'UAT' THEN 'LastLogIdUAT' ELSE 'LastLogID' END

	UPDATE dbo.SystemSetting WITH(ROWLOCK)
		SET Value = 'running'
	WHERE ServiceName = 'ChatBot - Problem Account'
		AND SettingName = @SettingNameOfJobStatus
		AND Value = 'Completed'

	IF @@ROWCOUNT = 0
	BEGIN
		SELECT @ErrCode = 100, @ErrMsg = 'Job is running'
	END

	CREATE TABLE #ImportData (LogId	BIGINT, Username VARCHAR(30), CustId INT, Recommend INT, Mrecommend INT, Srecommend INT, CategoryId SMALLINT, CategoryName_en NVARCHAR(100), CategoryName_sc NVARCHAR(100), CategoryName_yn NVARCHAR(100))

	INSERT INTO #ImportData (LogId, CustId, Recommend, Mrecommend, Srecommend, CategoryId, CategoryName_en, CategoryName_sc, CategoryName_yn)
	SELECT 
		t.c.value('LogId', 'BIGINT')					AS LogId
		,t.c.value('CustId', 'INT')						AS CustId
		,t.c.value('Recommend', 'INT')					AS Recommend
		,t.c.value('Mrecommend', 'INT')					AS Mrecommend
		,t.c.value('Srecommend', 'INT')					AS Srecommend
		,t.c.value('CategoryId', 'SMALLINT')			AS CategoryId
		,t.c.value('CategoryName_en', 'NVARCHAR(100)')	AS CategoryName_en
		,t.c.value('CategoryName_sc', 'NVARCHAR(100)')	AS CategoryName_sc
		,t.c.value('CategoryName_yn', 'NVARCHAR(100)')	AS CategoryName_yn
	FROM @XmlData.nodes ('root/r') t(c)

	IF @@ROWCOUNT = 0
	BEGIN
		RETURN
	END

	UPDATE i	
		SET i.Username = c.Username
	FROM #ImportData i
		INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON c.custid = i.custid
	
	CREATE TABLE #Recipient (CustId INT, RecipientId INT, DirectAccountId INT, ConversationGroupId INT)

	INSERT INTO #Recipient (CustId, RecipientId, DirectAccountId, ConversationGroupId)
	SELECT i.CustId, r.RecipientId, cda.CustID, g.ConversationGroupId
	FROM #ImportData i
		INNER JOIN bodb02.dbo.CustDirectAccount cda WITH(NOLOCK) ON cda.CustID IN (i.CustId, i.Recommend, i.Mrecommend, i.Srecommend)
		INNER JOIN dbo.crmPicManagement m WITH(NOLOCK) ON m.CustID = cda.CustID
		INNER JOIN dbo.crmRecipient r WITH(NOLOCK) ON r.SourceId = m.PicID AND r.DataSource = 'bodb_CRM.dbo.crmPIC'
		INNER JOIN dbo.crmConversationGroupRecipient cgr WITH(NOLOCK) ON cgr.RecipientId = r.RecipientId
		INNER JOIN dbo.crmConversationGroup g WITH(NOLOCK) ON g.ConversationGroupId = cgr.ConversationGroupId 
	WHERE g.IsActive = 1

	;WITH CTE_Group AS
	(
		SELECT ConversationGroupId, CustId, COUNT(RecipientId) AS NumberOfRecipient
		FROM #Recipient
		GROUP BY ConversationGroupId, CustId
	), CTE_InValiedGroup AS
	(
		SELECT g.ConversationGroupId, g.CustId
		FROM CTE_Group g
		CROSS APPLY
		(
			SELECT COUNT(1) AS NumberOfRecipient
			FROM dbo.crmConversationGroupRecipient cgr WITH(NOLOCK)
			WHERE cgr.ConversationGroupId = g.ConversationGroupId
		)u(NumberOfRecipient)
		WHERE g.NumberOfRecipient <> u.NumberOfRecipient
	)
	DELETE r
	FROM #Recipient r
		INNER JOIN CTE_InValiedGroup g ON g.ConversationGroupId = r.ConversationGroupId AND g.CustId = r.CustId
	
	SELECT * FROM crmNotificationGROUP
	


	
	
END


