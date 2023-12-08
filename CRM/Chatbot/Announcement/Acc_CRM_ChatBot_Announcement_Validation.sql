/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE [dbo].[Acc_CRM_ChatBot_Announcement_Validation]
	@HeadlineNameList			NVARCHAR(MAX) = ''
	,@SiteNameList				NVARCHAR(MAX) = ''
	,@CurrencyList				VARCHAR(MAX) = ''
	,@HeadlineType				TINYINT = NULL
	,@Title						NVARCHAR(2000) = ''
	,@Contents					XML
	,@FileName					NVARCHAR(2000)
	,@SendDate					DATETIME = NULL
	,@SendImmediately			BIT 
	,@Status					VARCHAR(20)
	,@ErrCode					INT = 0 OUTPUT
	,@ErrMsg					NVARCHAR(2000) = '' OUTPUT
AS

/*
	Created: 20221213@Malcolm
	Task :  Announcement - Annoucement list - New annoucement (Insert a new announcement)/ Edit announcement - Validation
	DB: DBCRM/bodb_CRM
	Original:
		Revisions:
			- 20221213@Malcolm: Initialize SPs [Redmine: #192158]
            - 20231208@Ned.Le: Fix error relate to STRING_AGG function

	Param's Explanation:

	- @Contents:
			<Contents>
					<Content LanguageId = "50000" Value = "Content EN"/>
					<Content LanguageId = "50001" Value = "Content SC"/>
					<Content LanguageId = "50002" Value = "Content EN SC"/>
					<Content LanguageId = "50003" Value = "Content TH"/>
					<Content LanguageId = "50004" Value = "Content YN"/>
			</Contents>
			
	- @HeadlineType = 0 : Normal
		              = 1 : VIP
					  = 2 : All
		
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @NotificationTypeId SMALLINT, @CurrentDate DATETIME = GETDATE(),  @DirectAccountList NVARCHAR(MAX) = ''

	SELECT @NotificationTypeId = NotificationTypeId FROM dbo.crmNotificationType WITH(NOLOCK) WHERE NotificationTypeName = 'Upload Announcement'

	DECLARE @Headline TABLE (CustId INT, Username VARCHAR(30), ErrCode TINYINT DEFAULT(6))

	DECLARE @HeadlineGroup TABLE (HeadlineId INT PRIMARY KEY)
	DECLARE @DirectAccount TABLE (CustId INT PRIMARY KEY) -- Not Assign Group
	CREATE TABLE #ConversationGroupRecipient (CustId INT, ConversationGroupId INT, NoRecipient INT)
	CREATE CLUSTERED INDEX CIX_ConversationGroupId ON #ConversationGroupRecipient (ConversationGroupId)

	--Get headline
	IF @Status = 'Planned'
	BEGIN
		BEGIN
			DECLARE @TabError TABLE (ErrCode TINYINT, ErrMsg NVARCHAR(MAX))

			INSERT INTO @TabError (ErrCode, ErrMsg)
			VALUES (1, 'Invalid Headline')
				,(2, 'Not Mapped Headline')
				,(3, 'Bot Removed Headline')
				,(4, 'In-Active Headline')
				,(5, 'Ignored Headline')

			IF ISNULL(@HeadlineNameList, '') <> ''
			BEGIN
				SELECT @SiteNameList = NULL, @CurrencyList = NULL, @HeadlineType = NULL 

				INSERT INTO @Headline (Username, CustId, ErrCode)
				SELECT DISTINCT f.value AS Username, n.CustId, CASE WHEN n.CustId IS NULL THEN 1 ELSE 6 END
				FROM STRING_SPLIT(@HeadlineNameList, ',') f
				OUTER APPLY (
					SELECT c.custid
					FROM bodb02.dbo.Customer c WITH(NOLOCK)
					WHERE c.username = CONVERT(VARCHAR(30), f.value)
				) AS n
				WHERE f.value <> ''

				UPDATE h
					SET h.ErrCode = 1
				FROM @Headline h 
					LEFT JOIN bodb02.dbo.CustGroupHeadline cgh WITH(NOLOCK) ON cgh.CustID = h.CustId
				WHERE h.ErrCode = 6 AND cgh.CustID IS NULL

				UPDATE h
					SET h.ErrCode = n.ErrCode
				FROM @Headline h
				CROSS APPLY (
					SELECT TOP(1) 0 AS ErrCode
					FROM dbo.crmConversationGroupHeadline cgh WITH(NOLOCK) 
						INNER JOIN dbo.crmConversationGroupBot cgb WITH(NOLOCK) ON cgb.ConversationGroupId = cgh.ConversationGroupId
						INNER JOIN dbo.crmConversationGroup g WITH(NOLOCK) ON g.ConversationGroupId = cgh.ConversationGroupId
						INNER JOIN dbo.crmConversationGroupRecipient cgr WITH(NOLOCK) ON cgr.ConversationGroupId = g.ConversationGroupId
						LEFT JOIN dbo.crmIgnoredNotificationType nt WITH(NOLOCK) ON nt.ConversationGroupId = g.ConversationGroupId AND nt.NotificationTypeId = @NotificationTypeId
					WHERE g.IsActive = 1 AND cgh.HeadlineId = h.CustId AND nt.ConversationGroupId IS NULL
				) AS n
				WHERE h.ErrCode = 6

				UPDATE h
					SET h.ErrCode = CASE WHEN n.NotMapped IS NULL THEN 2 -- NotMapped
										 WHEN n.BotRemoved IS NULL THEN 3 -- BotRemoved
										 WHEN ISNULL(n.InActive,0) = 0 THEN 4 -- InActive
										 WHEN n.[IgnoredAnnouncement] IS NOT NULL THEN 5 -- Ignored Headline
									ELSE 0 END 
				FROM @Headline h
				OUTER APPLY (
					SELECT TOP(1) g.ConversationGroupId AS [NotMapped], cgb.BotId AS [BotRemoved], CONVERT(TINYINT, g.IsActive) AS [InActive], nt.ConversationGroupId AS [IgnoredAnnouncement]
					FROM dbo.crmConversationGroupHeadline cgh WITH(NOLOCK)
						INNER JOIN dbo.crmConversationGroup g WITH(NOLOCK) ON g.ConversationGroupId = cgh.ConversationGroupId
						INNER JOIN dbo.crmConversationGroupRecipient cgr WITH(NOLOCK) ON cgr.ConversationGroupId = cgh.ConversationGroupId
						LEFT JOIN dbo.crmConversationGroupBot cgb WITH(NOLOCK) ON cgb.ConversationGroupId = cgh.ConversationGroupId	
						LEFT JOIN dbo.crmIgnoredNotificationType nt WITH(NOLOCK) ON nt.ConversationGroupId = g.ConversationGroupId AND nt.NotificationTypeId = @NotificationTypeId
					WHERE cgh.HeadlineId = h.CustId AND g.IsDeleted = 0
				) AS n ([NotMapped], [BotRemoved], [InActive], [IgnoredAnnouncement])
				WHERE h.ErrCode = 6

				IF EXISTS (SELECT 1 FROM @Headline WHERE ErrCode <> 0)
				BEGIN
					;WITH CTE AS
					(
						SELECT h.ErrCode, STRING_AGG(CONVERT(VARCHAR(MAX), h.Username), ',') AS UsernameList
						FROM @Headline h 
						WHERE h.ErrCode <> 0
						GROUP BY h.ErrCode
					)
					SELECT @ErrCode = 100, @ErrMsg = ISNULL(@ErrMsg, '') + t.ErrMsg + ': ' + c.UsernameList + ';'
					FROM CTE c
						INNER JOIN @TabError t ON t.ErrCode = c.ErrCode
					ORDER BY t.ErrCode ASC

					SELECT @ErrMsg = SUBSTRING(@ErrMsg, 1, LEN(@ErrMsg)-1)
					RETURN 
				END

				SELECT @HeadlineNameList = STRING_AGG(CONVERT(VARCHAR(MAX), Username), ',') WITHIN GROUP (ORDER BY Username)
				FROM @Headline
			END
			ELSE 
			BEGIN -- Get headline from Site, Currency, Headline type

				SELECT @HeadlineNameList = NULL

				INSERT INTO @HeadlineGroup (HeadlineId)
				SELECT DISTINCT p.HeadlineID
				FROM dbo.crmPicManagement p WITH(NOLOCK)
				CROSS APPLY (
					SELECT TOP 1 1 AS Id
					FROM bodb02.dbo.Customer c WITH(NOLOCK)
					WHERE c.custid = p.CustID AND ',' + @SiteNameList + ',' LIKE '%,' + c.site + ',%' 
							AND ',' + @CurrencyList + ',' LIKE '%,' + CONVERT(VARCHAR(4), c.currency) +  ',%'
				) AS c
				WHERE p.HeadlineID <> 0
				
				INSERT INTO @Headline (CustId, ErrCode)
				SELECT DISTINCT e.HeadlineId, 0
				FROM @HeadlineGroup e 
					INNER JOIN dbo.crmConversationGroupHeadline cg WITH(NOLOCK) ON cg.HeadlineId = e.HeadlineId
					INNER JOIN dbo.crmConversationGroupRecipient cgr WITH(NOLOCK) ON cgr.ConversationGroupId = cg.ConversationGroupId
					INNER JOIN dbo.crmConversationGroup g WITH(NOLOCK) ON g.ConversationGroupId = cgr.ConversationGroupId
					INNER JOIN dbo.crmConversationGroupBot cgb WITH(NOLOCK) ON cgb.ConversationGroupId = g.ConversationGroupId
					LEFT JOIN dbo.crmIgnoredNotificationType nt WITH(NOLOCK) ON nt.ConversationGroupId = g.ConversationGroupId AND nt.NotificationTypeId = @NotificationTypeId
				WHERE g.IsActive = 1 AND nt.NotificationTypeId IS NULL

				IF @HeadlineType <> 2
				BEGIN
					DELETE h
					FROM @Headline h
						LEFT JOIN dbo.crmCustomer c WITH(NOLOCK) ON c.CustID = h.CustId
					WHERE ISNULL(c.IsVIP, 0) <> @HeadlineType
				END
				ELSE 
				BEGIN -- Get Direct account belong to Not Assign Group
					;WITH CTE_Pic AS
					(
						SELECT p.CustID, p.HeadlineID, p.PicID
						FROM dbo.crmPicManagement p WITH(NOLOCK)
						CROSS APPLY (
							SELECT TOP 1 1 AS Id
							FROM bodb02.dbo.Customer c WITH(NOLOCK)
							WHERE c.custid = p.CustID AND ',' + @SiteNameList + ',' LIKE '%,' + c.site + ',%' 
									AND ',' + @CurrencyList + ',' LIKE '%,' + CONVERT(VARCHAR(4), c.currency) +  ',%'
						) AS c
						WHERE p.HeadlineID = 0
					)
					INSERT INTO #ConversationGroupRecipient (CustId, ConversationGroupId, NoRecipient)
					SELECT p.CustID, cgh.ConversationGroupId, COUNT(DISTINCT cgr.RecipientId) AS [NoRecipient]
					FROM CTE_Pic p
						INNER JOIN dbo.crmRecipient r WITH(NOLOCK) ON r.SourceId = p.PicID AND r.DataSource = 'bodb_CRM.dbo.crmPIC'
						INNER JOIN dbo.crmConversationGroupHeadline cgh WITH(NOLOCK) ON cgh.HeadlineId = p.HeadlineID
						INNER JOIN dbo.crmConversationGroupRecipient cgr WITH(NOLOCK) ON cgr.ConversationGroupId = cgh.ConversationGroupId AND r.RecipientId = cgr.RecipientId
						INNER JOIN dbo.crmConversationGroup g WITH(NOLOCK) ON g.ConversationGroupId = cgh.ConversationGroupId 
						INNER JOIN dbo.crmConversationGroupBot cgb WITH(NOLOCK) ON cgb.ConversationGroupId = g.ConversationGroupId
						LEFT JOIN dbo.crmIgnoredNotificationType nt WITH(NOLOCK) ON nt.ConversationGroupId = g.ConversationGroupId AND nt.NotificationTypeId = @NotificationTypeId
					WHERE g.IsActive = 1 AND nt.NotificationTypeId IS NULL
					GROUP BY p.CustID, cgh.ConversationGroupId

					;WITH CTE_ConversationGroup AS
					(
						SELECT g.ConversationGroupId, COUNT(RecipientId) AS [TotalRecipient]
						FROM dbo.crmConversationGroupRecipient g WITH(NOLOCK)
						WHERE EXISTS (SELECT 1 FROM #ConversationGroupRecipient r WHERE r.ConversationGroupId = g.ConversationGroupId)
						GROUP BY g.ConversationGroupId
					)
					INSERT INTO @DirectAccount (CustId)
					SELECT DISTINCT gr.CustID
					FROM #ConversationGroupRecipient gr 
						INNER JOIN CTE_ConversationGroup g ON g.ConversationGroupId = gr.ConversationGroupId AND g.TotalRecipient = gr.NoRecipient

					IF EXISTS (SELECT 1 FROM @DirectAccount)
					BEGIN 
						INSERT INTO @Headline (CustId, ErrCode, Username)
						VALUES (0, 0, '')
					END
				END

				IF NOT EXISTS (SELECT 1 FROM @Headline)
				BEGIN
					SELECT @ErrCode = 102, @ErrMsg = 'No Group Headline info'
					RETURN
				END

				SELECT @HeadlineNameList = 
				(
					SELECT STRING_AGG(CONVERT(VARCHAR(MAX), c.username), ',') 
					FROM bodb02.dbo.Customer c WITH(NOLOCK)
					WHERE EXISTS (SELECT 1 FROM @Headline h WHERE h.CustId = c.custid)
				)
			END
		END

	END 
	ELSE
	BEGIN
		SELECT @ErrCode = 0, @ErrMsg = ''
		
		SELECT NULL AS HeadlineNameList, NULL AS CurrencyList, NULL AS SiteNameList, NULL AS SendDate, NULL	AS SendImmediately, NULL AS DirectAccountList, NULL AS HeadlineType 
		RETURN
	END
	
	IF @ErrCode = 0
	BEGIN
		SELECT @DirectAccountList = STRING_AGG(CONVERT(VARCHAR(MAX), c.username), ',') WITHIN GROUP (ORDER BY c.Username ASC)
		FROM @DirectAccount d
			INNER JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON c.custid = d.CustId

		SELECT @HeadlineNameList AS HeadlineNameList, @CurrencyList AS CurrencyList, @SiteNameList AS SiteNameList, @SendDate AS SendDate, @SendImmediately	AS SendImmediately, @DirectAccountList AS DirectAccountList, @HeadlineType AS HeadlineType 
	END
	ELSE
	BEGIN
		SELECT NULL AS HeadlineNameList, NULL AS CurrencyList, NULL AS SiteNameList, NULL AS SendDate, NULL	AS SendImmediately, NULL AS DirectAccountList, NULL AS HeadlineType 
	END

	DROP TABLE #ConversationGroupRecipient
END
GO