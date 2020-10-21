/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_ChatBot_ChatTypeMapping_Sel]
	@ChatTypeId				TINYINT = NULL
	,@ConversationGroupName	NVARCHAR(1000) = ''
	,@Headline				VARCHAR(30) = ''
	,@RecipientName			NVARCHAR(200) = ''
	,@LetstalkID			VARCHAR(200) = ''
	,@LanguageId			INT = NULL
	,@IsActive				BIT = NULL
	,@BotId					INT = NULL
	,@MappingStatus         VARCHAR(20) = ''
	,@PageSize				INT = 0
	,@PageIndex				INT = 0
	,@TotalRows				INT = 0 OUTPUT
AS
/*
Created: 20200810@Malcolm
Task :  Get chat type mapping
DB: DBCRM/bodb_CRM
Original:
	Revisions:
		- 20200810@Malcolm: Initialize SPs [Redmine: #130544]
	Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @RowStart INT, @RowEnd INT

	SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageIndex * @PageSize + 1, @RowEnd = @RowStart + @PageSize - 1

	DECLARE @PICCommunicationLetStalkId INT
	SELECT  @PICCommunicationLetStalkId = SettingId FROM dbo.crmSetting WITH (NOLOCK)
	WHERE	SettingName = 'PICCommunicationTool' AND SettingValue = 'LetsTalk' AND IsActive = 1

	CREATE TABLE #HeadlineId (Id INT)

	CREATE TABLE #Tmp
	(
		 ConversationGroupId	SMALLINT
		 ,ConversationGroupName NVARCHAR(1000)
		 ,ConversationId        VARCHAR(200)
		 ,ChatTypeId			TINYINT
		 ,BotName				NVARCHAR(1000)
		 ,BotId					INT
		 ,LanguageId			INT
		 ,Language				NVARCHAR(200)
		 ,IsActive				BIT
		 ,Remark				NVARCHAR(2000)
		 ,MappingStatusID       INT
		 ,RowNum                INT
	)

	INSERT INTO #Tmp
	(
		ConversationGroupId	
		,ConversationGroupName 		
		,ConversationId
		,ChatTypeId			
		,BotName	
		,BotId		
		,LanguageId		
		,Language
		,IsActive	
		,Remark
	)
	SELECT 
		cg.ConversationGroupId
		,cg.ConversationGroupName
		,cg.ConversationId
		,cg.ChatTypeId
		,cb.BotName
		,cb.BotId
		,cg.LanguageId
		,l.SettingValue
		,cg.IsActive
		,cg.Remark
	FROM dbo.crmConversationGroup cg WITH (NOLOCK)
		LEFT JOIN dbo.crmConversationGroupBot cgb WITH (NOLOCK) ON cg.ConversationGroupId = cgb.ConversationGroupId
		LEFT JOIN dbo.crmConversationBot cb WITH (NOLOCK) ON cgb.BotId = cb.BotId
		LEFT JOIN dbo.crmSetting l WITH(NOLOCK) ON cg.LanguageId = l.SettingID AND l.IsActive = 1
	WHERE (@IsActive IS NULL OR cg.IsActive = @IsActive)
	    AND (@ChatTypeId IS NULL OR cg.ChatTypeId = @ChatTypeId)	
		AND (@ConversationGroupName = '' OR CHARINDEX(@ConversationGroupName, cg.ConversationGroupName, 1) > 0)			
		AND (cg.LanguageId = @LanguageId OR @LanguageId IS NULL)
		AND (cgb.BotId = @BotId OR @BotId IS NULL)

	IF @Headline <> ''
	BEGIN
		INSERT INTO #HeadlineId (ID)
		SELECT gh.HeadlineId
		FROM dbo.crmConversationGroupHeadline gh WITH (NOLOCK)
			CROSS APPLY (
				SELECT TOP 1 c.CustId FROM bodb02.dbo.Customer c WITH (NOLOCK)
				WHERE c.custid = gh.HeadlineId
					AND c.username LIKE '%' + @Headline + '%'
			) c

		DELETE t
		FROM #Tmp t
		WHERE NOT EXISTS(
				SELECT 1 
				FROM dbo.crmConversationGroupHeadline gh WITH(NOLOCK)
					INNER JOIN #HeadlineId h ON h.Id = gh.HeadlineId
				WHERE t.ConversationGroupId = gh.ConversationGroupId
		)
	END

	IF @RecipientName <> ''
	BEGIN
		DELETE t
		FROM #Tmp t
		WHERE NOT EXISTS(
			SELECT 1
			FROM dbo.crmPIC p WITH(NOLOCK)
				INNER JOIN dbo.crmRecipient r WITH(NOLOCK) ON r.SourceId = p.PicID
				INNER JOIN dbo.crmConversationGroupRecipient cgr WITH(NOLOCK) ON r.RecipientId = cgr.RecipientId 
			WHERE t.ConversationGroupId = cgr.ConversationGroupId
				AND p.Username LIKE '%' + @RecipientName + '%'
		)
	END

	IF @LetstalkID <> ''
	BEGIN		
		DELETE t
		FROM #Tmp t
		WHERE (t.ConversationId NOT LIKE '%' + @LetstalkID + '%' AND t.ChatTypeId = 2)
			OR t.ChatTypeId = 1
	END

	
	IF ',' + @MappingStatus + ',' NOT LIKE '%,0,%' --Bot Removed
	BEGIN
		DELETE t
		FROM #Tmp t
		WHERE t.ChatTypeId = 1
			AND NOT EXISTS(
				SELECT 1
				FROM dbo.crmConversationGroupBot gb WITH(NOLOCK)
				WHERE gb.ConversationGroupId = t.ConversationGroupId
			)
	END

	IF ',' + @MappingStatus + ',' NOT LIKE '%,1,%'-- Not Mapped
	BEGIN
		DELETE t
		FROM #Tmp t
		WHERE t.ChatTypeId = 1
			AND EXISTS (
				SELECT 1
				FROM dbo.crmConversationGroupBot gb WITH(NOLOCK)
				WHERE gb.ConversationGroupId = t.ConversationGroupId
			)
			AND NOT EXISTS (
				SELECT 1
				FROM dbo.crmConversationGroupHeadline gh WITH(NOLOCK)
					INNER JOIN dbo.crmConversationGroupRecipient gr WITH(NOLOCK) ON gr.ConversationGroupId = gh.ConversationGroupId
				WHERE gh.ConversationGroupId = t.ConversationGroupId
			)
	END

	IF ',' + @MappingStatus + ',' NOT LIKE '%,2,%'--Mapped
	BEGIN
		DELETE t
		FROM #Tmp t
		WHERE t.ChatTypeId = 1
			AND EXISTS (
				SELECT 1
				FROM dbo.crmConversationGroupBot gb WITH(NOLOCK)
				WHERE gb.ConversationGroupId = t.ConversationGroupId
			)
			AND EXISTS (
				SELECT 1
				FROM dbo.crmConversationGroupHeadline gh WITH(NOLOCK)
					INNER JOIN dbo.crmConversationGroupRecipient gr WITH(NOLOCK) ON gr.ConversationGroupId = gh.ConversationGroupId
				WHERE gh.ConversationGroupId = t.ConversationGroupId
			)
	END
	
	
	SELECT @TotalRows = COUNT(*) FROM #Tmp

	UPDATE x
	SET	x.RowNum = x.NewRowNum 
	FROM(
		SELECT 
			RowNum,
			ROW_NUMBER() OVER(ORDER BY t.ChatTypeId DESC, t.ConversationGroupName) AS NewRowNum				
		FROM #Tmp t
	) x
	IF @PageIndex >= 0 AND @PageSize > 0
	BEGIN
		DELETE t
		FROM #Tmp t
		WHERE t.RowNum > @RowEnd OR t.RowNum < @RowStart
	END

	--Update mapping status

	IF ',' + @MappingStatus + ',' LIKE '%,0,%' -- Bot Removed 
	BEGIN
		UPDATE t
		SET t.MappingStatusID = 0
		FROM #Tmp t
		WHERE t.ChatTypeId = 1
		AND NOT EXISTS (
			SELECT 1
			FROM dbo.crmConversationGroupBot gb WITH(NOLOCK)
			WHERE gb.ConversationGroupId = t.ConversationGroupId
		) 
	END

	IF ',' + @MappingStatus + ',' LIKE '%,1,%'  -- Not Mapped
	BEGIN
		UPDATE t
		SET t.MappingStatusID = 1
		FROM #Tmp t
		WHERE t.ChatTypeId = 1
			AND EXISTS (
				SELECT 1
				FROM dbo.crmConversationGroupBot gb WITH(NOLOCK)
				WHERE gb.ConversationGroupId = t.ConversationGroupId
			)
			AND NOT EXISTS (
				SELECT 1
				FROM dbo.crmConversationGroupHeadline gh WITH(NOLOCK)
					INNER JOIN dbo.crmConversationGroupRecipient gr WITH(NOLOCK) ON gr.ConversationGroupId = gh.ConversationGroupId
				WHERE gh.ConversationGroupId = t.ConversationGroupId
			)
	END

	IF ',' + @MappingStatus + ',' LIKE '%,2,%'  --Mapped
	BEGIN
		UPDATE t
		SET t.MappingStatusID = 2
		FROM #Tmp t
		WHERE t.ChatTypeId = 1
			AND EXISTS (
				SELECT 1
				FROM dbo.crmConversationGroupBot gb WITH(NOLOCK)
				WHERE gb.ConversationGroupId = t.ConversationGroupId
			)
			AND EXISTS (
				SELECT 1
				FROM dbo.crmConversationGroupHeadline gh WITH(NOLOCK)
					INNER JOIN dbo.crmConversationGroupRecipient gr WITH(NOLOCK) ON gr.ConversationGroupId = gh.ConversationGroupId
				WHERE gh.ConversationGroupId = t.ConversationGroupId
			)
	END

	SELECT 
		t.ConversationGroupId	
		,t.ConversationGroupName 	
		,t.ConversationId
		,t.ChatTypeId			
		,t.BotName	
		,t.BotId	
		,t.LanguageId	
		,t.Language
		,t.IsActive	
		,t.MappingStatusID
		,t.Remark
	FROM #Tmp t
	ORDER BY t.ChatTypeId DESC, t.ConversationGroupName  

	SELECT 
		t.ConversationGroupId,
		gh.HeadlineId,
		ISNULL(c.username,'Not Assigned Group') AS HeadlineName 
	FROM #Tmp t
		INNER JOIN dbo.crmConversationGroupHeadline gh WITH(NOLOCK) ON gh.ConversationGroupId = t.ConversationGroupId 
		LEFT JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON gh.HeadlineId = c.custid

	SELECT 
		cgr.RecipientId
		,p.Username AS RecipientName
		,s.SettingValue AS [RoleName]
		,rt.RecipientTypeId
		,rt.RecipientTypeName
		,cm.CommunicationValue AS LetstalkId
		,t.ConversationGroupId
	FROM #Tmp t
		INNER JOIN dbo.crmConversationGroupRecipient cgr WITH(NOLOCK) ON cgr.ConversationGroupId = t.ConversationGroupId
		INNER JOIN dbo.crmRecipient r WITH(NOLOCK) ON r.RecipientId = cgr.RecipientId
		INNER JOIN dbo.crmRecipientType rt WITH(NOLOCK) ON rt.RecipientTypeId = r.RecipientTypeId
		INNER JOIN dbo.crmPIC p WITH(NOLOCK) ON r.SourceId = p.PicId AND r.DataSource = 'bodb_CRM.dbo.crmPIC'
		INNER JOIN dbo.crmSetting s WITH(NOLOCK) ON s.SettingID = p.Role
		LEFT JOIN dbo.crmPICCommunication cm WITH(NOLOCK) ON p.PicID = cm.PicID AND cm.CommunicationID = @PICCommunicationLetStalkId

	DROP TABLE #Tmp

	DROP TABLE #HeadlineId
END
GO

