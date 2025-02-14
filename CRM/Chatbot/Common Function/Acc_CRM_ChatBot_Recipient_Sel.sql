/*<info serverAlias="DBCRM-bodb_CRM" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_ChatBot_Recipient_Sel]
	@RecipientType	TINYINT = NULL
	,@RecipientName NVARCHAR(200) = ''
	,@RecipientIds  VARCHAR(MAX) = ''
	,@BotId			BIGINT = NULL 
	,@Limit			INT = NULL	
AS
/*
	Created: 20200810@Malcolm
	Task :  Get recipients
	DB: DBCRM/bodb_CRM
	Original:
	Revisions:
		- 20200810@Malcolm: Initialize SPs [Redmine: #130544]
		- 20201126@Malcolm: Change bodb02.dbo.f_StringSplit to dbo.f_CRM_strSplit [Redmine: #144265]
		- 20230508@Malcolm: Offer Telegram bot service for Headlines [RedmineId : #179119]
		- 20250214@Virgil: Show incorrect text in Chat Type Mapping [Hotfix: #217923]

	Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	SELECT @RecipientName = ISNULL(@RecipientName,'')

	DECLARE @SettingLetstalk INT, @SettingTelegram INT

	DECLARE @Recipients TABLE (RecipientId INT PRIMARY KEY)

	DECLARE @Tmp TABLE (RecipientId INT, RecipientName NVARCHAR(200), LetsTalkIds NVARCHAR(MAX), Usernames NVARCHAR(MAX), RowNum INT)

	INSERT INTO @Recipients (RecipientId)
	SELECT DISTINCT f.value
	FROM STRING_SPLIT(@RecipientIds, ',') f

	SELECT 
		@SettingLetstalk = CASE WHEN SettingValue = 'LetsTalk' THEN SettingId ELSE @SettingLetstalk END
		,@SettingTelegram = CASE WHEN SettingValue = 'Telegram' THEN SettingId ELSE @SettingTelegram END
	FROM dbo.crmSetting WITH (NOLOCK)
	WHERE SettingName = 'PICCommunicationTool' AND SettingValue IN ('LetsTalk', 'Telegram') AND IsActive = 1

	INSERT INTO @Tmp (RecipientId, RecipientName, LetsTalkIds, Usernames, RowNum)
	SELECT r.RecipientId, p.Username AS RecipientName, n.LetsTalkIds, n.Usernames, ROW_NUMBER() OVER(ORDER BY p.Username)
	FROM dbo.crmRecipient r WITH(NOLOCK)
		INNER JOIN dbo.crmPIC p WITH(NOLOCK) ON p.PicID = r.SourceId AND p.IsActive = 1
		OUTER APPLY (
			SELECT 
				MAX(CASE WHEN cpc.CommunicationID = @SettingLetstalk THEN cpc.CommunicationValue ELSE NULL END) AS LetsTalkIds
				,MAX(CASE WHEN cpc.CommunicationID = @SettingTelegram THEN cpc.CommunicationValue ELSE NULL END) AS Usernames
			FROM dbo.crmPICCommunication cpc WITH(NOLOCK)
			WHERE cpc.PicID = p.PicID AND cpc.CommunicationID IN (@SettingLetstalk, @SettingTelegram)
		) AS n
	WHERE (r.RecipientTypeId = @RecipientType OR @RecipientType IS NULL)
		AND (p.Username LIKE '%' + @RecipientName + '%' OR @RecipientName IS NULL)	
		AND (EXISTS(SELECT 1 FROM @Recipients ri WHERE ri.RecipientId = r.RecipientId) OR @RecipientIds = '')
		AND r.DataSource = 'bodb_CRM.dbo.crmPIC'

	SELECT RecipientId, RecipientName, LetsTalkIds, Usernames
	FROM @Tmp
	WHERE (RowNum <= @Limit OR @Limit IS NULL)

	;WITH CTE AS (
		SELECT DISTINCT TRIM(f.value) AS Username
		FROM @Tmp t 
		CROSS APPLY STRING_SPLIT(t.Usernames, ',') f
		WHERE (RowNum <= @Limit OR @Limit IS NULL)
	)
	SELECT DISTINCT e.Username, cp.ConversationId AS [ChatId], cpb.BotId
	FROM CTE e
		INNER JOIN dbo.crmConversationPersonal cp WITH(NOLOCK) ON e.Username = cp.Username
		INNER JOIN dbo.crmConversationPersonalBot cpb WITH(NOLOCK) ON cpb.ConversationId = cp.ConversationId AND cpb.ChannelId = cp.ChannelId 
	WHERE cpb.BotId = @BotId OR @BotId IS NULL

END
GO