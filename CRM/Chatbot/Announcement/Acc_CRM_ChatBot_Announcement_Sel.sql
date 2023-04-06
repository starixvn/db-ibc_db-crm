/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_ChatBot_Announcement_Sel]	
	@AnnouncementId INT = NULL
	,@Title			NVARCHAR(2000) = ''
	,@FromDate		DATETIME = NULL
	,@ToDate		DATETIME = NULL
	,@Status		VARCHAR(400)
	,@PageSize		INT = 100
	,@PageIndex		INT = 1
	,@TotalRows		INT = 0 OUTPUT
AS
/*
	Created: 20221213@Malcolm
	Task :  Annoucement - Annoucement list - Submit (get annoucements)
	DB: DBCRM/bodb_CRM
	Original:
		Revisions:
			- 20221213@Malcolm: Initialize SPs [Redmine: #179118]
	Param's Explanation:
		
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @Result TABLE (AnnouncementId INT, NotificationTemplateId SMALLINT, SendDate DATETIME, Title NVARCHAR(2000), CreatedBy INT, CreatedDate DATETIME, Status VARCHAR(20), TotalRows INT)

	SELECT @ToDate = DATEADD(DAY, 1, @ToDate)

	IF @AnnouncementId IS NULL 
	BEGIN
		INSERT INTO @Result (AnnouncementId, NotificationTemplateId, SendDate, Title, CreatedBy, CreatedDate, Status, TotalRows)
		SELECT a.AnnouncementId, a.NotificationTemplateId, a.SendDate, a.Title, a.CreatedBy, a.CreatedDate, a.Status, COUNT(1) OVER()
		FROM dbo.crmAnnouncement a WITH(NOLOCK)
		WHERE (a.Title LIKE '%' + @Title + '%' OR @Title = '')
			AND (SendDate >= @FromDate AND SendDate < @ToDate)
			AND ',' + @Status + ',' LIKE '%,' + a.Status + ',%'
		ORDER BY AnnouncementId DESC
		OFFSET @PageSize * (@PageIndex - 1) ROWS
		FETCH FIRST @PageSize ROWS ONLY
	END
	ELSE 
	BEGIN
		INSERT INTO @Result (AnnouncementId, NotificationTemplateId, SendDate, Title, CreatedBy, CreatedDate, Status, TotalRows)
		SELECT a.AnnouncementId, a.NotificationTemplateId, a.SendDate, a.Title, a.CreatedBy, a.CreatedDate, a.Status, COUNT(1) OVER()
		FROM dbo.crmAnnouncement a WITH(NOLOCK)
		WHERE (a.AnnouncementId = @AnnouncementId)
			AND (a.Title LIKE '%' + @Title + '%' OR @Title = '')
			AND ',' + @Status + ',' LIKE '%,' + a.Status + ',%'
		ORDER BY AnnouncementId DESC
		OFFSET @PageSize * (@PageIndex - 1) ROWS
		FETCH FIRST @PageSize ROWS ONLY
	END

	SELECT TOP(1) @TotalRows = TotalRows FROM @Result

	;WITH CTE_Completed AS
	(
		SELECT 
			r.AnnouncementId
			,COUNT(CASE WHEN n.Status = 'Sent' THEN 1 ELSE NULL END) AS [Sent]
			,COUNT(CASE WHEN n.Status = 'Duplicated' THEN 1 ELSE NULL END) AS [Duplicated]
			,COUNT(CASE WHEN n.Status NOT IN ('Sent', 'Duplicated') THEN 1 ELSE NULL END) AS [Error]
		FROM @Result r
			LEFT JOIN dbo.crmAnnouncementNotification an WITH(NOLOCK) ON r.AnnouncementId = an.AnnouncementId
			LEFT JOIN dbo.crmNotification n WITH(NOLOCK) ON n.NotificationId = an.NotificationId
		WHERE r.Status = 'Completed'
		GROUP BY r.AnnouncementId
	)
	SELECT 
		r.AnnouncementId
		,r.NotificationTemplateId
		,nt.NotificationTemplateName
		,r.SendDate
		,r.Title
		,r.Status
		,c.username AS [CreatedBy]
		,r.CreatedDate AS CreatedTime
		,CASE WHEN r.Status = 'Completed' THEN '(S:[' + CONVERT(VARCHAR(20), e.Sent) + '], D:[' + CONVERT(VARCHAR(20), e.Duplicated) + '], E:[' + CONVERT(VARCHAR(20), e.Error) + '])' ELSE '' END AS [Description]
	FROM @Result r
		LEFT JOIN dbo.crmNotificationTemplate nt WITH(NOLOCK) ON nt.NotificationTemplateId = r.NotificationTemplateId
		LEFT JOIN bodb02.dbo.Customer c WITH(NOLOCK) ON c.custid = r.CreatedBy
		LEFT JOIN CTE_Completed e ON e.AnnouncementId = r.AnnouncementId
	ORDER BY r.AnnouncementId DESC

END
GO