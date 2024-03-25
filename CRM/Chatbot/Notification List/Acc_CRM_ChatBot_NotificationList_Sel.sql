/*<info serverAlias="DBCRM-bodb_CRM" executers="wsv_nap" isFunction="0" isNested="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE [dbo].[Acc_CRM_ChatBot_NotificationList_Sel]
	@NotificationTypeIds	VARCHAR(MAX) = ''
	,@FromDate				DATETIME = NULL
	,@ToDate				DATETIME = NULL
	,@ChannelId				TINYINT = NULL
	,@NotificationIdUpper	INT = NULL
	,@NotificationIdLower	INT = NULL
	,@Headline				VARCHAR(30) =''
	,@RecipientName			NVARCHAR(200)=''
	,@MessageId				INT = NULL
	,@AnnouncementId		INT = NULL
	,@NotificationId		INT = NULL
	,@Content				NVARCHAR(MAX)=''
	,@Status				VARCHAR(200) =''
	,@PageSize				INT = 0
	,@PageIndex				INT = 0
	,@TotalRows				INT = 0 OUTPUT
AS

/*
	Created: 20200810@Malcolm
	Task : CRM - Headline Notification - Notification List - Submit
	DB: DBCRM/bodb_CRM
	Original:
	Revisions:
        - 20200810@Malcolm: Initialize SPs [Redmine: #130544]
        - 20201116@Malcolm: Only filter notifications following MessageId [Redmine: #144265]
        - 20210731@Malcolm : Add alias [RedmineId : #151509] 
        - 20210731@Malcolm : Avoid page splits [RedmineId : #176977] 
        - 20220113@Malcolm : Scale out for CRM [RedmineId : #181906] 
        - 20221222@Malcolm : Add filter by AnnouncementId [RedmineId : #179118]
        - 20230508@Malcolm: Offer Telegram bot service for Headlines [RedmineId : #179119]
        - 20240327@Ned.Le: CRM - Headline Announcement - Enhancement - Allow to attach separate screenshots for a specific language AND Allow to push Notifications with empty content [Redmine: #201042]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @RowStart INT, @RowEnd INT, @MaxRetry INT = 5, @Id INT = 0, @Msg NVARCHAR(MAX) = ''

	SELECT @PageIndex = @PageIndex - 1, @RowStart = @PageIndex * @PageSize + 1, @RowEnd = @RowStart + @PageSize - 1
	
	SELECT @ToDate = DATEADD(DAY, 1, @ToDate)

	DECLARE @RecipientId INT = NULL, @HeadlineId INT = NULL

	DECLARE @NotificationIdList TABLE (NotificationId INT PRIMARY KEY)
	DECLARE @NotificationTypeList TABLE (NotificationTypeId INT)

	INSERT INTO @NotificationTypeList (NotificationTypeId)
	SELECT f.value
	FROM STRING_SPLIT(@NotificationTypeIds,',') f
	WHERE f.value <> ''

	IF @RecipientName <> ''
	BEGIN
		--For DataSource = 'bodb_CRM.dbo.crmPIC'
		SELECT @RecipientId = r.RecipientId 
		FROM dbo.crmPIC p WITH(NOLOCK) 
			INNER JOIN dbo.crmRecipient r WITH(NOLOCK) ON r.SourceId = p.PicID
		WHERE p.Username = @RecipientName
	END
	

	IF ISNULL(@Headline,'') <> ''
	BEGIN
		SELECT @HeadlineId = CustId FROM bodb02.dbo.Customer WITH(NOLOCK) WHERE username = @Headline
	END

	CREATE TABLE #Tmp
	(
		NotificationId			INT PRIMARY KEY CLUSTERED
		,ReferenceId			BIGINT
		,DataSource				VARCHAR(128)
		,NotificationTypeId		SMALLINT
		,NotificationTypeName	nvarchar(500)
		,Sender					INT
		,SendDate				DATETIME
		,Title					NVARCHAR(2000)
		,Content				NVARCHAR(MAX)
		,Status					VARCHAR(20)
		,ResolvedRemark			NVARCHAR(2000)
		,ResolvedBy				INT
		,RelatedNotificationIds NVARCHAR(1000)
		,ChannelId				TINYINT
		,RowNum					INT
	)
	
	WHILE @Id < @MaxRetry
	BEGIN
		BEGIN TRY
			SET @Msg = ''
			
			TRUNCATE TABLE #Tmp
			
			IF @FromDate IS NOT NULL
			BEGIN
				INSERT INTO #Tmp
				(
					NotificationId			
					,ReferenceId	
					,DataSource
					,NotificationTypeId		
					,NotificationTypeName	
					,Sender					
					,SendDate				
					,Title					
					,Content				
					,Status	
					,ResolvedRemark
					,ResolvedBy
					,RelatedNotificationIds
					,ChannelId
				)
				SELECT 
					n.NotificationId,
					n.ReferenceId,
					n.DataSource,
					n.NotificationTypeId,
					nt.NotificationTypeName,
					n.Sender,
					n.SendDate,
					n.Title,
					n.Content,
					n.Status,
					n.ResolvedRemark,
					n.ResolvedBy,
					n.RelatedNotificationIds,
					n.ChannelId
				FROM dbo.crmNotification n WITH(NOLOCK)
					INNER JOIN dbo.crmNotificationType nt WITH(NOLOCK) ON n.NotificationTypeId = nt.NotificationTypeId
				WHERE n.SendDate >= @FromDate
					AND n.SendDate < @ToDate 
					AND (',' + @Status + ',' LIKE '%,' + n.Status + ',%')
					AND (n.Content LIKE '%' + @Content + '%' OR @Content = '')
					AND n.NotificationTypeId IN (SELECT NotificationTypeId FROM @NotificationTypeList)
					AND (n.ChannelId = @ChannelId OR @ChannelId IS NULL)
			END
			ELSE
			BEGIN
				IF @MessageId IS NOT NULL OR @AnnouncementId IS NOT NULL
				BEGIN
					INSERT INTO @NotificationIdList (NotificationId)
					SELECT DISTINCT NotificationId 
					FROM dbo.crmNotificationRefDetail WITH(NOLOCK)
					WHERE ReferenceId = @MessageId AND DataSource = 'DBMSG.bodb_Message.dbo.Msg'
						OR ReferenceId = @AnnouncementId AND DataSource = 'DBCRM.bodb_CRM.dbo.crmAnnouncement'

					IF @NotificationIdLower IS NULL
					BEGIN
						SELECT @NotificationIdLower = 0, @NotificationIdUpper = 0
						SELECT @NotificationIdLower= MIN(NotificationId), @NotificationIdUpper = MAX(NotificationId) FROM @NotificationIdList
					END
				END

				INSERT INTO #Tmp
				(
					NotificationId			
					,ReferenceId	
					,DataSource
					,NotificationTypeId		
					,NotificationTypeName	
					,Sender					
					,SendDate				
					,Title					
					,Content				
					,Status	
					,ResolvedRemark
					,ResolvedBy
					,RelatedNotificationIds
					,ChannelId
				)
				SELECT 
					n.NotificationId,
					n.ReferenceId,
					n.DataSource,
					n.NotificationTypeId,
					nt.NotificationTypeName,
					n.Sender,
					n.SendDate,
					n.Title,
					n.Content,
					n.Status,
					n.ResolvedRemark,
					n.ResolvedBy,
					n.RelatedNotificationIds,
					n.ChannelId
				FROM dbo.crmNotification n WITH(NOLOCK)
					INNER JOIN dbo.crmNotificationType nt WITH(NOLOCK) ON n.NotificationTypeId = nt.NotificationTypeId
					LEFT JOIN @NotificationIdList nl ON nl.NotificationId = n.NotificationId
				WHERE (',' + @Status + ',' LIKE '%,' + n.Status + ',%')
					AND (n.Content LIKE '%' + @Content + '%' OR @Content = '')
					AND (n.NotificationId >= @NotificationIdLower)
					AND (n.NotificationId <= @NotificationIdUpper)
					AND n.NotificationTypeId IN (SELECT NotificationTypeId FROM @NotificationTypeList)
					AND ((@MessageId IS NULL AND @AnnouncementId IS NULL) OR nl.NotificationId IS NOT NULL)
					AND (n.ChannelId = @ChannelId OR @ChannelId IS NULL)
			END	
		END TRY
		BEGIN CATCH
			IF @@ERROR = 2627
			BEGIN
				SET @Id = @Id + 1
			END
			ELSE 
				SET @Id = @MaxRetry
			SET @Msg = ERROR_MESSAGE()
		END CATCH
		
		IF @Msg = ''
			BREAK
	END

	IF @Msg <> ''
	BEGIN
		RAISERROR(@Msg, 16, 1)
		RETURN
	END

	IF @Headline <> ''
	BEGIN
		DELETE t
		FROM #Tmp t
		WHERE NOT EXISTS(SELECT 1 
					FROM dbo.crmNotificationHeadline gh WITH(NOLOCK)
					WHERE t.NotificationId = gh.NotificationId 
						AND gh.HeadlineId = @HeadlineId)
	END
	
	IF @RecipientName <> ''
	BEGIN
		DELETE t
		FROM #Tmp t
		WHERE NOT EXISTS(SELECT 1 
				   FROM dbo.crmNotificationRecipient nr WITH(NOLOCK)
				   WHERE RecipientId = @RecipientId
					AND t.NotificationId = nr.NotificationId)
	END

	SELECT @TotalRows = COUNT(*) FROM #Tmp

	UPDATE x
	SET x.RowNum = x.NewRowNum
	FROM(
		SELECT RowNum,
			   ROW_NUMBER() OVER(ORDER BY t.NotificationId DESC) AS NewRowNum
		FROM #Tmp t
	)x

	IF @PageIndex >= 0 AND @PageSize > 0
	BEGIN
		DELETE t
		FROM #Tmp t
		WHERE t.RowNum < @RowStart OR t.RowNum > @RowEnd
	END

	;WITH CTE AS
	(
		SELECT nrd.NotificationId, nrd.DataSource, STRING_AGG(CONVERT(VARCHAR(50), nrd.ReferenceId), ',') WITHIN  GROUP (ORDER BY nrd.ReferenceId ASC) AS ReferenceIdList
		FROM dbo.crmNotificationRefDetail nrd WITH(NOLOCK)
			INNER JOIN #Tmp t ON t.NotificationId = nrd.NotificationId
		GROUP BY nrd.NotificationId, nrd.DataSource
	)
	SELECT 
		t.NotificationId
		,e.ReferenceIdList
		,e.DataSource
		,c.username AS Sender
		,t.NotificationTypeId
		,t.NotificationTypeName
		,t.SendDate
		,t.Title
		,t.Content
		,t.Status
		,t.ResolvedRemark
		,o.username AS ResolvedBy
		,nr.Reason
		,cg.ConversationGroupName AS [DisplayName]
		,t.RelatedNotificationIds
		,t.ChannelId
        ,ac.FileName
	FROM #Tmp t
		LEFT JOIN dbo.crmNotificationGroup nr WITH(NOLOCK) ON t.NotificationId = nr.NotificationId
		LEFT JOIN dbo.crmConversationGroup cg WITH(NOLOCK) ON cg.ConversationGroupId = nr.ConversationGroupId
		LEFT JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON c.custid = t.Sender
		LEFT JOIN bodb02.dbo.Customer o WITH(NOLOCK) ON o.custid = t.ResolvedBy
		LEFT JOIN CTE e ON e.NotificationId = t.NotificationId
        LEFT JOIN bodb_CRM.dbo.crmAnnouncementNotification an (NOLOCK) ON t.NotificationId = an.NotificationId
        LEFT JOIN bodb_CRM.dbo.crmAnnouncementContent ac (NOLOCK) ON an.AnnouncementId = ac.AnnouncementId AND cg.LanguageId = ac.LanguageId
	ORDER BY t.NotificationId DESC

	SELECT 
		t.NotificationId		
		,nr.RecipientId 
		,p.Username AS RecipientName
		,p.Role AS RoleId
		,s.SettingValue AS RoleName
	FROM #Tmp t
		LEFT JOIN dbo.crmNotificationRecipient nr WITH(NOLOCK) ON t.NotificationId = nr.NotificationId
		LEFT JOIN dbo.crmRecipient r WITH(NOLOCK) ON r.RecipientId = nr.RecipientId
		LEFT JOIN dbo.crmPIC p WITH(NOLOCK) ON r.SourceId = p.PicID
		LEFT JOIN dbo.crmSetting s WITH(NOLOCK) ON p.Role = s.SettingID
	WHERE r.DataSource = 'bodb_CRM.dbo.crmPIC'
		AND p.IsActive = 1
		
    SELECT 
		t.NotificationId
		,nh.HeadlineId
		,CASE WHEN nh.HeadlineId = 0 THEN 'Not Assigned Group' ELSE c.username END  HeadlineName
	FROM #Tmp t
		LEFT JOIN dbo.crmNotificationHeadline nh WITH(NOLOCK) ON nh.NotificationId = t.NotificationId
		LEFT JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON nh.HeadlineId = c.custid

	DROP TABLE #Tmp
END
GO