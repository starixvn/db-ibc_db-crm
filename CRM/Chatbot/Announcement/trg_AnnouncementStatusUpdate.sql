/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
USE bodb_CRM
GO

CREATE OR ALTER TRIGGER dbo.trg_AnnouncementStatusUpdate ON dbo.crmNotification
AFTER UPDATE
AS
/*
	Created: 20221213@Malcolm
	Task : Update annoucement status
	DB: DBCRM/bodb_CRM
	Original:
		Revisions:
			- 20221213@Malcolm: Initialize Tigger [Redmine: #179118]
	Param's Explanation:
		
*/
BEGIN
	IF @@ROWCOUNT = 0
		RETURN

	SET NOCOUNT ON

	DECLARE @AnnouncementList TABLE (AnnouncementId INT PRIMARY KEY)

	INSERT INTO @AnnouncementList (AnnouncementId)
	SELECT DISTINCT an.AnnouncementId
	FROM deleted d
		INNER JOIN dbo.crmAnnouncementNotification an WITH(NOLOCK) ON an.NotificationId = d.NotificationId

	IF NOT EXISTS (SELECT 1 FROM @AnnouncementList)
	BEGIN
		RETURN
	END

	UPDATE a WITH(ROWLOCK, UPDLOCK)
		SET a.Status = CASE WHEN r.NotificationId IS NULL THEN 'Completed' ELSE 'In-progress' END 
	FROM dbo.crmAnnouncement a
	OUTER APPLY (
		SELECT TOP(1) an.NotificationId
		FROM dbo.crmAnnouncementNotification an WITH(NOLOCK)
			INNER JOIN dbo.crmNotification n WITH(NOLOCK) ON n.NotificationId = an.NotificationId
		WHERE n.Status IN ('Planned', 'Sending') AND an.AnnouncementId = a.AnnouncementId
	) AS r (NotificationId)
	WHERE EXISTS (SELECT 1 FROM @AnnouncementList e WHERE e.AnnouncementId = a.AnnouncementId)

END