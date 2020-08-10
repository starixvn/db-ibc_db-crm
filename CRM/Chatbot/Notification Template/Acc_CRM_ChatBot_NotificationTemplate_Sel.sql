/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_ChatBot_NotificationTemplate_Sel]
	@NotificationTemplateId		SMALLINT = NULL
	,@NotificationTemplateName	NVARCHAR(1000) = NULL
	,@NotificationTypeId		INT = NULL
	,@PageSize					INT = 0
	,@PageIndex					INT = 0
	,@TotalRows					INT = 0 OUTPUT
AS
/*
Created: 20200810@Malcolm
Task :  Get notification templates
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
		NotificationTemplateId		SMALLINT
		,NotificationTemplateName	NVARCHAR(1000)
		,NotificationTypeId			TINYINT
		,NotificationTypeName       NVARCHAR(500)
		,Title						NVARCHAR(2000)
		,RowNum						INT
	)
	
	INSERT INTO #Tmp
	(
		NotificationTemplateId,
		NotificationTemplateName,
		NotificationTypeId,
		NotificationTypeName,
		Title,
		RowNum
	)
	SELECT 
		nt.NotificationTemplateId,
		nt.NotificationTemplateName,
		nt.NotificationTypeId,
		n.NotificationTypeName,
		nt.Title,
		ROW_NUMBER() OVER (ORDER BY n.NotificationTypeName ASC ,nt.NotificationTemplateName ASC)
	FROM dbo.crmNotificationTemplate nt WITH (NOLOCK)
		INNER JOIN dbo.crmNotificationType n WITH(NOLOCK) ON nt.NotificationTypeId = n.NotificationTypeId
	WHERE (@NotificationTemplateName IS NULL OR nt.NotificationTemplateName LIKE '%' + @NotificationTemplateName + '%')
		AND (@NotificationTypeId IS NULL OR n.NotificationTypeId = @NotificationTypeId)
		AND (@NotificationTemplateId IS NULL OR nt.NotificationTemplateId = @NotificationTemplateId)

	SELECT @TotalRows = COUNT(*) FROM #Tmp

	IF @PageIndex >= 0 AND @PageSize > 0
	BEGIN
		DELETE t
		FROM #Tmp t
		WHERE t.RowNum < @RowStart OR t.RowNum > @RowEnd
	END

	SELECT 
		t.NotificationTemplateId,
		t.NotificationTemplateName,
		t.NotificationTypeId,
		t.NotificationTypeName,
		t.Title
	FROM #Tmp t
	ORDER BY t.NotificationTypeName ASC, t.NotificationTemplateName ASC

	SELECT 
		t.NotificationTemplateId,
		tc.LanguageId,
		s.SettingValue AS Language,
		tc.Content
	FROM #Tmp t
		INNER JOIN dbo.crmNotificationTemplateContent tc WITH(NOLOCK) ON tc.NotificationTemplateId = t.NotificationTemplateId
		INNER JOIN dbo.crmSetting s WITH(NOLOCK) ON tc.LanguageId = s.SettingID
	WHERE s.IsActive = 1	

	DROP TABLE #Tmp
END
GO