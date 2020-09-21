/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_ChatBot_NotificationList_Sel]
	@NotificationTypeIds	VARCHAR(200) = ''
	,@FromDate				DATETIME = NULL
	,@ToDate				DATETIME = NULL
	,@NotificationIdUpper	INT = NULL
	,@NotificationIdLower	INT = NULL
	,@Headline				VARCHAR(30) =''
	,@RecipientName			NVARCHAR(200)=''
	,@MessageId				INT = NULL
	,@NotificationId		INT = NULL
	,@Content				NVARCHAR(MAX)=''
	,@Status				VARCHAR(200) =''
	,@PageSize				INT = 0
	,@PageIndex				INT = 0
	,@TotalRows				INT = 0 OUTPUT
AS
/*
Created: 20200810@Malcolm
Task :  Get the notification list
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

	DECLARE @RecipientId INT = NULL, @HeadlineId INT = NULL

	DECLARE @_NotificationTypeIds TABLE (NotificationTypeId INT)

	INSERT INTO @_NotificationTypeIds(NotificationTypeId)
	SELECT val
	FROM bodb02.dbo.f_StringSplit(@NotificationTypeIds,',')


	IF @RecipientName <> ''
	BEGIN
		--For DataSource = 'bodb_CRM.dbo.crmPIC'
		SELECT @RecipientId = r.RecipientId 
		FROM dbo.crmPIC p WITH(NOLOCK) 
			INNER JOIN dbo.crmRecipient r WITH(NOLOCK) ON r.SourceId = p.PicID
		WHERE Username = @RecipientName
	END
	

	IF ISNULL(@Headline,'') <> ''
	BEGIN
		SELECT @HeadlineId = CustId FROM bodb02.dbo.Customer WITH(NOLOCK) WHERE username = @Headline
	END

	CREATE TABLE #Tmp
	(
		NotificationId			INT PRIMARY KEY CLUSTERED
		,MessageId				INT
		,NotificationTypeId		SMALLINT
		,NotificationTypeName	nvarchar(500)
		,Sender					INT
		,SendDate				DATETIME
		,Title					NVARCHAR(2000)
		,Content				NVARCHAR(MAX)
		,Status					VARCHAR(20)
		,ResolvedRemark			NVARCHAR(2000)
		,RelatedNotificationIds NVARCHAR(1000)
		,RowNum					INT
	)

	INSERT INTO #Tmp
	(
		NotificationId			
		,MessageId				
		,NotificationTypeId		
		,NotificationTypeName	
		,Sender					
		,SendDate				
		,Title					
		,Content				
		,Status	
		,ResolvedRemark
		,RelatedNotificationIds
	)
	SELECT 
		n.NotificationId,
		n.MessageId,
		n.NotificationTypeId,
		nt.NotificationTypeName,
		n.Sender,
		n.SendDate,
		n.Title,
		n.Content,
		n.Status,
		n.ResolvedRemark,
		n.RelatedNotificationIds
	FROM dbo.crmNotification n WITH(NOLOCK)
		INNER JOIN dbo.crmNotificationType nt WITH(NOLOCK) ON n.NotificationTypeId = nt.NotificationTypeId
	WHERE (n.MessageId = @MessageId OR @MessageId IS NULL)
		AND (n.SendDate >= @FromDate OR @FromDate IS NULL)
		AND (n.SendDate <= @ToDate OR @ToDate IS NULL)
		AND (',' + @Status + ',' LIKE '%,' + n.Status + ',%' OR @Status = '')
		AND (n.Content LIKE '%' + @Content + '%' OR @Content = '')
		AND (n.NotificationId >= @NotificationIdLower OR @NotificationIdLower IS NULL)
		AND (n.NotificationId <= @NotificationIdUpper OR @NotificationIdUpper IS NULL)
		AND (n.NotificationTypeId IN (SELECT NotificationTypeId FROM @_NotificationTypeIds) OR @NotificationTypeIds = '')

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

	SELECT 
		t.NotificationId
		,t.MessageId
		,c.username AS Sender
		,t.NotificationTypeId
		,t.NotificationTypeName
		,t.SendDate
		,t.Title
		,t.Content
		,t.Status
		,t.ResolvedRemark
		,nr.Reason
		,cg.ConversationGroupName AS LetstalkName
		,t.RelatedNotificationIds
	FROM #Tmp t
		LEFT JOIN dbo.crmNotificationGroup nr WITH(NOLOCK) ON t.NotificationId = nr.NotificationId
		LEFT JOIN dbo.crmConversationGroup cg WITH(NOLOCK) ON cg.ConversationGroupId = nr.ConversationGroupId
		LEFT JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON c.custid = t.Sender
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