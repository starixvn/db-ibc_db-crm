/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_ChatBot_AnnouncementStatus_Upd]
	@UserId				INT
	,@AnnouncementId	INT
	,@Status			VARCHAR(20) 
	,@ErrCode			INT = 0 OUTPUT
	,@ErrMsg			NVARCHAR(2000) = '' OUTPUT
	,@LoginIP			VARCHAR(45) = ''
AS
/*
	Created: 20221213@Malcolm
	Task :  Annoucement - Announcement List - Update planned Status to Cancelled Status
	DB: DBCRM/bodb_CRM
	Original:
		Revisions:
			- 20221213@Malcolm: Initialize SPs [Redmine: #179118]
			- 20230508@Malcolm: Offer Telegram bot service for Headlines [RedmineId : #179119]
			- 20230804@Malcolm: Add Draft Status [Redmine: #192158]

	Param's Explanation:
		
*/

BEGIN
	SET NOCOUNT ON

		SET NOCOUNT ON

	DECLARE @NewValues NVARCHAR(MAX),  @OldValues NVARCHAR(MAX), @OldStatus VARCHAR(20) = ''

	SELECT @OldStatus = Status FROM dbo.crmAnnouncement WHERE AnnouncementId = @AnnouncementId

	UPDATE a WITH(ROWLOCK, UPDLOCK)
		SET a.Status = @Status
	FROM dbo.crmAnnouncement a 
	WHERE a.AnnouncementId = @AnnouncementId

	IF @@ROWCOUNT = 0
	BEGIN
		SELECT @ErrCode = 100, @ErrMsg = 'Status of this announcement has been updated please check again.'
		RETURN
	END

	SELECT @OldValues = CONVERT(VARCHAR(MAX),(SELECT @AnnouncementId AS '@AnnouncementId',@OldStatus AS '@Status' FOR XML PATH('Acc_CRM_ChatBot_AnnouncementStatus_Upd')))

	SELECT @NewValues = CONVERT(VARCHAR(MAX),(SELECT @AnnouncementId AS '@AnnouncementId',@Status AS '@Status' FOR XML PATH('Acc_CRM_ChatBot_AnnouncementStatus_Upd')))

	EXEC dbo.WriteLog_UserLog_crmUserLog_RunSP
			@UserID = @UserID,
			@CustID = NULL,
			@ActionID = 1012,
			@IP = @LoginIP,
			@NewValues = @NewValues,
			@OldValues = @OldValues,
			@CustIds = NULL,
			@ReferenceIds = NULL

END
GO