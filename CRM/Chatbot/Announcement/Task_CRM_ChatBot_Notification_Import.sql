/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Task_CRM_ChatBot_Notification_Import]	
AS
/*
	Created: 20221213@Malcolm
	Task :  Import notification for announcements
	DB: DBCRM/bodb_CRM
	Original:
		Revisions:
			- 20221213@Malcolm: Initialize SPs [Redmine: #179118]
	Param's Explanation:
		
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @Id INT = 1, @AnnouncementId INT = NULL, @ErrCode INT = 0, @ErrMsg NVARCHAR(MAX) = '' 
	DECLARE @AnnouncementIdList TABLE (Id INT IDENTITY(1, 1) PRIMARY KEY, AnnouncementId INT)

	INSERT INTO @AnnouncementIdList (AnnouncementId)
	SELECT a.AnnouncementId
	FROM dbo.crmAnnouncement a WITH(NOLOCK)
	WHERE SendImmediately = 0 AND SendDate <= GETDATE() AND a.Status = 'Planned'
	ORDER BY AnnouncementId ASC
	
	WHILE EXISTS (SELECT 1 FROM @AnnouncementIdList WHERE Id = @Id)
	BEGIN
		
		SELECT @AnnouncementId = AnnouncementId FROM @AnnouncementIdList WHERE Id = @Id

		EXEC dbo.Acc_CRM_ChatBot_Notification_Import @AnnouncementId = @AnnouncementId, @ErrCode = @ErrCode OUTPUT, @ErrMsg = @ErrMsg OUTPUT
		
		IF ISNULL(@ErrCode, 0) <> 0
			BREAK
			
		SET @Id += 1
	END
	
	IF ISNULL(@ErrCode, 0) <> 0
	BEGIN
		SELECT @ErrMsg = 'SQL Server Job System: ''bodb_CRM: Import Notification for Announcement Page'' failed on' + @@SERVERNAME + ', Message : ' + ISNULL(@ErrMsg, '')
		RAISERROR (@ErrMsg, 16, 1)
		RETURN
	END
END
GO