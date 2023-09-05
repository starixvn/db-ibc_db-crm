/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_ChatBot_Notification_Import]	
	@AnnouncementId INT
	,@ErrCode		INT = 0 OUTPUT
	,@ErrMsg		NVARCHAR(MAX) = '' OUTPUT
AS
/*
	Created: 20221213@Malcolm
	Task : Create notifications from a annoucement
	DB: DBCRM/bodb_CRM
	Original:
		Revisions:
			- 20221213@Malcolm: Initialize SPs [Redmine: #179118]
			- 20230508@Malcolm: Offer Telegram bot service for Headlines [RedmineId : #179119]
	Param's Explanation:
		
*/

BEGIN
	SET NOCOUNT ON
	
	SELECT @ErrCode = 0, @ErrMsg = ''

	DECLARE @ConversationGroupId INT = 0, @NotificationId INT = 0, @UserId INT, @Title NVARCHAR(2000), @NotificationTypeId SMALLINT, @NotificationTemplateId SMALLINT, @Status VARCHAR(20), @MaxGroup INT

	DECLARE @Notificationlist TABLE (NotificationId INT PRIMARY KEY)

	CREATE TABLE #ConversationGroupHeadline (Id INT, ConversationGroupId SMALLINT, CustId INT, IsGroupHeadline BIT, RelatedIds VARCHAR(MAX), ChatTypeId TINYINT, ChannelId TINYINT, IsDuplicated BIT DEFAULT 0)
	
	CREATE TABLE #Result (Id INT, ConversationGroupId SMALLINT, Status VARCHAR(20), LanguageId INT, ChatTypeId TINYINT, ChannelId TINYINT, RelatedIds VARCHAR(MAX))

	CREATE TABLE #ConversationGroupRecipient (CustId INT, ConversationGroupId SMALLINT, NoRecipient INT)
	CREATE CLUSTERED INDEX CIX_ConversationGroupId ON #ConversationGroupRecipient (ConversationGroupId)

	UPDATE dbo.crmAnnouncement WITH(ROWLOCK, UPDLOCK)
		SET Status = 'In-progress'
	WHERE AnnouncementId = @AnnouncementId AND Status = 'Planned'

	IF @@ROWCOUNT = 0
		RETURN

	SELECT @NotificationTemplateId = NotificationTemplateId, @UserId = CreatedBy, @Title = Title FROM dbo.crmAnnouncement a WITH(NOLOCK) WHERE a.AnnouncementId = @AnnouncementId

	SELECT @NotificationTypeId = NotificationTypeId FROM dbo.crmNotificationType WITH(NOLOCK) WHERE NotificationTypeName = 'Upload Announcement'

	--1. Group which headline
	INSERT INTO #ConversationGroupHeadline (ConversationGroupId, CustId, IsGroupHeadline)
	SELECT DISTINCT g.ConversationGroupId, cgh.HeadlineId, 1
	FROM dbo.crmConversationGroup g WITH(NOLOCK)
		INNER JOIN dbo.crmConversationGroupRecipient cgr WITH(NOLOCK) ON cgr.ConversationGroupId = g.ConversationGroupId
		INNER JOIN dbo.crmConversationGroupHeadline cgh WITH(NOLOCK) ON cgh.ConversationGroupId = g.ConversationGroupId
		LEFT JOIN dbo.crmIgnoredNotificationType nt WITH(NOLOCK) ON nt.NotificationTypeId = @NotificationTypeId AND nt.ConversationGroupId = g.ConversationGroupId
	WHERE EXISTS (SELECT 1 FROM dbo.crmAnnouncementHeadline ah WITH(NOLOCK) WHERE ah.AnnouncementId = @AnnouncementId AND cgh.HeadlineId = ah.CustId AND ah.CustId <> 0) 
		AND g.IsActive = 1 AND nt.ConversationGroupId IS NULL

	--2. Not Assign Group
	INSERT INTO #ConversationGroupRecipient (CustId, ConversationGroupId, NoRecipient)
	SELECT p.CustID, cgh.ConversationGroupId, COUNT(DISTINCT cgr.RecipientId) AS [NoRecipient]
	FROM dbo.crmAnnouncementDirectAccount d WITH(NOLOCK)
		INNER JOIN dbo.crmPicManagement p WITH(NOLOCK) ON p.CustID = d.CustId AND p.HeadlineID = 0
		INNER JOIN dbo.crmRecipient r WITH(NOLOCK) ON r.SourceId = p.PicID AND r.DataSource = 'bodb_CRM.dbo.crmPIC'
		INNER JOIN dbo.crmConversationGroupHeadline cgh WITH(NOLOCK) ON cgh.HeadlineId = p.HeadlineID
		INNER JOIN dbo.crmConversationGroupRecipient cgr WITH(NOLOCK) ON cgr.ConversationGroupId = cgh.ConversationGroupId AND r.RecipientId = cgr.RecipientId
		INNER JOIN dbo.crmConversationGroup g WITH(NOLOCK) ON g.ConversationGroupId = cgh.ConversationGroupId 
		LEFT JOIN dbo.crmIgnoredNotificationType nt WITH(NOLOCK) ON nt.ConversationGroupId = g.ConversationGroupId AND nt.NotificationTypeId = @NotificationTypeId
	WHERE g.IsActive = 1 AND nt.NotificationTypeId IS NULL AND d.AnnouncementId = @AnnouncementId
	GROUP BY p.CustID, cgh.ConversationGroupId
	
	;WITH CTE_ConversationGroupCount AS
	(
		SELECT g.ConversationGroupId, COUNT(RecipientId) AS [TotalRecipient]
		FROM dbo.crmConversationGroupRecipient g WITH(NOLOCK)
		WHERE EXISTS (SELECT 1 FROM #ConversationGroupRecipient r WHERE r.ConversationGroupId = g.ConversationGroupId)
		GROUP BY g.ConversationGroupId
	),CTE_ConversationGroup AS
	(
		SELECT DISTINCT r.ConversationGroupId, r.CustId
		FROM #ConversationGroupRecipient r
			INNER JOIN CTE_ConversationGroupCount gc ON gc.ConversationGroupId = r.ConversationGroupId
		WHERE r.NoRecipient = gc.TotalRecipient
	)
	INSERT INTO #ConversationGroupHeadline (ConversationGroupId, CustId, IsGroupHeadline)
	SELECT g.ConversationGroupId, g.CustId, 0 AS IsGroupHeadline
	FROM #ConversationGroupRecipient g WITH(NOLOCK)
	WHERE EXISTS (SELECT 1 FROM CTE_ConversationGroup cg WHERE g.ConversationGroupId = cg.ConversationGroupId AND cg.CustId = g.CustId)

	IF NOT EXISTS (SELECT 1 FROM #ConversationGroupHeadline)
	BEGIN
		UPDATE dbo.crmAnnouncement WITH(ROWLOCK, UPDLOCK)
			SET Status = 'Completed'
		WHERE AnnouncementId = @AnnouncementId AND Status = 'In-progress'
		RETURN
	END

	UPDATE cgh
		SET cgh.ChatTypeId = g.ChatTypeId, cgh.ChannelId = g.ChannelId
	FROM #ConversationGroupHeadline cgh 
		INNER JOIN dbo.crmConversationGroup g WITH(NOLOCK) ON g.ConversationGroupId = cgh.ConversationGroupId

	UPDATE g
		SET g.IsDuplicated = n.IsDuplicated
	FROM #ConversationGroupHeadline g
		INNER JOIN dbo.crmConversationGroupRecipient cgr WITH(NOLOCK) ON cgr.ConversationGroupId = g.ConversationGroupId
		CROSS APPLY (
			SELECT 1 AS IsDuplicated
			FROM #ConversationGroupHeadline r
				INNER JOIN dbo.crmConversationGroupRecipient cr WITH(NOLOCK) ON cr.ConversationGroupId = r.ConversationGroupId
			WHERE r.ChatTypeId = 1 AND cr.RecipientId = cgr.RecipientId AND r.IsGroupHeadline = g.IsGroupHeadline AND g.CustId = r.CustId AND r.ChannelId = g.ChannelId
		) AS n
	WHERE g.ChatTypeId = 2 

	---IsDuplicated = 0	
	;WITH CTE_Group AS
	(
		SELECT ConversationGroupId, DENSE_RANK() OVER(ORDER BY ChannelId, ChatTypeId ASC, ConversationGroupId ASC) AS Id
		FROM #ConversationGroupHeadline
		WHERE IsDuplicated = 0
	)
	UPDATE g
		SET g.Id = c.Id, g.RelatedIds = ''
	FROM #ConversationGroupHeadline g 
		INNER JOIN CTE_Group c ON c.ConversationGroupId = g.ConversationGroupId
	WHERE IsDuplicated = 0

	SELECT @MaxGroup = MAX(Id) FROM #ConversationGroupHeadline

	--IsDuplicated = 1
	UPDATE g
		SET g.RelatedIds = n.RelatedIds
	FROM #ConversationGroupHeadline g
		INNER JOIN dbo.crmConversationGroupRecipient cgr WITH(NOLOCK) ON cgr.ConversationGroupId = g.ConversationGroupId
		CROSS APPLY (
			SELECT STRING_AGG(n.Id, ',') AS RelatedIds
			FROM (
				SELECT DISTINCT r.Id
				FROM #ConversationGroupHeadline r
					INNER JOIN dbo.crmConversationGroupRecipient cr WITH(NOLOCK) ON cr.ConversationGroupId = r.ConversationGroupId
				WHERE r.ChatTypeId = 1 AND r.IsDuplicated = 0 AND cr.RecipientId = cgr.RecipientId AND r.IsGroupHeadline = g.IsGroupHeadline AND g.CustId = r.CustId AND g.ChannelId = r.ChannelId
			) AS n
		) AS n
	WHERE g.ChatTypeId = 2 AND g.IsDuplicated = 1

	;WITH CTE_Group AS
	(
		SELECT g.CustId, g.IsGroupHeadline, g.IsDuplicated, g.ConversationGroupId, g.RelatedIds, DENSE_RANK() OVER(ORDER BY g.ChannelId, g.ConversationGroupId, g.RelatedIds) as Id
		FROM #ConversationGroupHeadline g
		WHERE g.IsDuplicated = 1
	)
	UPDATE g
		SET g.Id = @MaxGroup + c.Id 
	FROM #ConversationGroupHeadline g
		INNER JOIN CTE_Group c ON c.CustId = g.CustId AND c.IsGroupHeadline = g.IsGroupHeadline AND c.ConversationGroupId = g.ConversationGroupId AND c.IsDuplicated = g.IsDuplicated

	;WITH CTE_ConversationGroup AS
	(
		SELECT Id, ConversationGroupId, IsDuplicated, RelatedIds
		FROM #ConversationGroupHeadline g
		GROUP BY g.Id, g.ConversationGroupId, g.IsDuplicated, g.RelatedIds
	)
	INSERT INTO #Result (Id, ConversationGroupId, Status, LanguageId, ChatTypeId, RelatedIds, ChannelId)
	SELECT Id, g.ConversationGroupId, CASE WHEN cg.IsDuplicated = 1 THEN 'Duplicated' ELSE 'Planned' END AS Status, g.LanguageId, g.ChatTypeId, cg.RelatedIds, g.ChannelId
	FROM CTE_ConversationGroup cg
		INNER JOIN dbo.crmConversationGroup g WITH(NOLOCK) ON g.ConversationGroupId = cg.ConversationGroupId

	DECLARE @Id INT = 1

	BEGIN TRY
		WHILE EXISTS (SELECT 1 FROM #Result WHERE Id = @Id)
		BEGIN
			SELECT @ConversationGroupId = ConversationGroupId, @Status = [Status] FROM #Result WHERE Id = @Id

			INSERT INTO dbo.crmNotification
			(
				NotificationTypeId
				,Sender
				,SendDate
				,Title
				,Content
				,Status
				,ResolvedRemark
				,RelatedNotificationIds
				,ResolvedBy
				,ChannelId
			)
			SELECT @NotificationTypeId, @UserId, GETDATE(), @Title, c.Content,g.Status, '', g.RelatedIds, NULL, g.ChannelId
			FROM #Result g
			OUTER APPLY (
				SELECT TOP(1) ac.Content
				FROM dbo.crmAnnouncementContent ac WITH(NOLOCK) 
				WHERE ac.AnnouncementId = @AnnouncementId AND ac.LanguageId IN (g.LanguageId, 50000)
				ORDER BY ac.LanguageId DESC
			) AS c
			WHERE g.Id = @Id

			SELECT @NotificationId = SCOPE_IDENTITY()

			INSERT INTO @Notificationlist (NotificationId)
			VALUES (@NotificationId)

			INSERT INTO dbo.crmNotificationGroup (NotificationId, ConversationGroupId, Status)
			SELECT @NotificationId, @ConversationGroupId, @Status

			INSERT INTO dbo.crmNotificationRecipient (NotificationId, RecipientId, ConversationGroupId)
			SELECT @NotificationId, RecipientId, @ConversationGroupId
			FROM dbo.crmConversationGroupRecipient WITH(NOLOCK)
			WHERE ConversationGroupId = @ConversationGroupId

			INSERT INTO dbo.crmNotificationHeadline (NotificationId, HeadlineId)
			SELECT DISTINCT @NotificationId, CASE WHEN cgh.IsGroupHeadline = 0 THEN 0 ELSE cgh.CustId END AS HeadlineId
			FROM #ConversationGroupHeadline cgh
			WHERE cgh.Id = @Id 
			
			INSERT INTO dbo.crmAnnouncementNotification (AnnouncementId, NotificationId)
			VALUES (@AnnouncementId, @NotificationId)

			INSERT INTO dbo.crmNotificationRefDetail (NotificationId, ReferenceId, DataSource)
			VALUES (@NotificationId, @AnnouncementId, 'DBCRM.bodb_CRM.dbo.crmAnnouncement')

			UPDATE g
				SET g.RelatedIds = RIGHT(LEFT(tmpRelatedIds, LEN(tmpRelatedIds) - 1), LEN(tmpRelatedIds) - 2)
			FROM #Result g
				CROSS APPLY (
					SELECT tmpRelatedIds = REPLACE(',' + g.RelatedIds + ',', ',' + CONVERT(VARCHAR(50), @Id) + ',', ',' + CONVERT(VARCHAR(50), @NotificationId)+ ',')
				) AS t
			WHERE g.ChatTypeId = 2
				AND ',' + CONVERT(VARCHAR(50), g.RelatedIds) + ',' LIKE '%,' + CONVERT(VARCHAR(50), @Id) + ',%'
			
			SET @Id += 1
		END
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = ERROR_NUMBER(), @ErrMsg = ERROR_MESSAGE()

		DELETE n WITH(ROWLOCK, UPDLOCK)
		FROM dbo.crmNotification n
		WHERE EXISTS (SELECT 1 FROM @Notificationlist nl WHERE nl.NotificationId = n.NotificationId)

		DELETE n WITH(ROWLOCK, UPDLOCK)
		FROM dbo.crmNotificationGroup n
		WHERE EXISTS (SELECT 1 FROM @Notificationlist nl WHERE nl.NotificationId = n.NotificationId)

		DELETE n WITH(ROWLOCK, UPDLOCK)
		FROM dbo.crmNotificationRecipient n
		WHERE EXISTS (SELECT 1 FROM @Notificationlist nl WHERE nl.NotificationId = n.NotificationId)

		DELETE n WITH(ROWLOCK, UPDLOCK)
		FROM dbo.crmNotificationHeadline n
		WHERE EXISTS (SELECT 1 FROM @Notificationlist nl WHERE nl.NotificationId = n.NotificationId)

		DELETE dbo.crmAnnouncementNotification WITH(ROWLOCK, UPDLOCK)
		WHERE AnnouncementId = @AnnouncementId

		DELETE dbo.crmNotificationRefDetail WITH(ROWLOCK, UPDLOCK)
		WHERE DataSource = 'DBCRM.bodb_CRM.dbo.crmAnnouncement' AND ReferenceId = @AnnouncementId

		UPDATE dbo.crmAnnouncement WITH(ROWLOCK, UPDLOCK)
			SET Status = 'Planned'
		WHERE AnnouncementId = @AnnouncementId AND Status = 'In-progress'

		RETURN
	END CATCH

	DROP TABLE #ConversationGroupRecipient
	DROP TABLE #ConversationGroupHeadline
	DROP TABLE #Result

END
GO