/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_ChatBot_NotificationType_Sel]
	@NotificationTypeName	NVARCHAR(500) = NULL
	,@RecipientTypeIds		VARCHAR(MAX) = NULL
	,@ChatTypeIds			VARCHAR(200) = NULL
	,@SystemId				VARCHAR(100) = NULL
	,@PageSize				INT = 0
	,@PageIndex				INT = 0
	,@TotalRows				INT = 0 OUTPUT
AS
/*
Created: 20200810@Malcolm
Task :  Get notification types
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

	CREATE TABLE #Tmp 
	(
		NotificationTypeId		SMALLINT PRIMARY KEY CLUSTERED,
		NotificationTypeName	NVARCHAR(500),
		SystemId			    TINYINT,
		RowNum					INT
	)

	INSERT INTO #Tmp
	(
		NotificationTypeId,
		NotificationTypeName,
		SystemId
	)
	SELECT	
		nt.NotificationTypeId, 
		nt.NotificationTypeName,
		nt.SystemId
	FROM dbo.crmNotificationType nt WITH(NOLOCK)
	WHERE (@NotificationTypeName IS NULL OR nt.NotificationTypeName LIKE '%' + @NotificationTypeName + '%')
		AND (EXISTS(SELECT 1 FROM bodb02.dbo.f_StringSplit(@SystemId,',') f WHERE f.val = nt.SystemId) OR @SystemId IS NULL)
		
	IF @RecipientTypeIds IS NOT NULL
	BEGIN
		DELETE t
		FROM #Tmp t
		WHERE NOT EXISTS(
			SELECT 1 
			FROM dbo.f_CRM_strSplit(@RecipientTypeIds,',') f
				INNER JOIN dbo.crmNotificationRecipientType nr WITH(NOLOCK) 
					ON f.val = nr.RecipientTypeId
			WHERE t.NotificationTypeId = nr.NotificationTypeId)
	END
	
	IF @ChatTypeIds IS NOT NULL
	BEGIN
		DELETE t
		FROM #Tmp t
		WHERE NOT EXISTS(
			SELECT 1 
			FROM dbo.f_CRM_strSplit(@ChatTypeIds,',') f
				INNER JOIN dbo.crmNotificationChatType nc WITH(NOLOCK) 
					ON f.val = nc.ChatTypeId
			WHERE t.NotificationTypeId = nc.NotificationTypeId)
	END
	
	SELECT @TotalRows = COUNT(*) FROM #Tmp

	UPDATE x
	SET x.ROWNUM = x.NewRowNum
	FROM (
		SELECT RowNum, 
			   ROW_NUMBER() OVER(ORDER BY NotificationTypeName ASC) AS NewRowNum
		FROM #Tmp t
    ) x

	IF @PageSize > 0 AND @PageIndex >= 0
	BEGIN	
		DELETE t
		FROM #Tmp t
		WHERE t.RowNum < @RowStart OR t.RowNum > @RowEnd
	END

	SELECT 
		t.NotificationTypeId,
		t.NotificationTypeName,
		s.SystemId,
		s.SystemName	
	FROM #Tmp t
		INNER JOIN dbo.crmSystem s WITH(NOLOCK) ON t.SystemId = s.SystemId
	ORDER BY t.NotificationTypeName ASC
		
	SELECT 
		t.NotificationTypeId,
		nr.RecipientTypeId,
		rt.RecipientTypeName
	FROM #Tmp t
		INNER JOIN dbo.crmNotificationRecipientType nr WITH(NOLOCK) ON nr.NotificationTypeId = t.NotificationTypeId
		INNER JOIN dbo.crmRecipientType rt WITH(NOLOCK) ON rt.RecipientTypeId = nr.RecipientTypeId

			
	SELECT 
		t.NotificationTypeId,
		nct.ChatTypeId
	FROM #Tmp t
		INNER JOIN dbo.crmNotificationChatType nct WITH(NOLOCK) ON t.NotificationTypeId = nct.NotificationTypeId

	DROP TABLE #Tmp
END
GO