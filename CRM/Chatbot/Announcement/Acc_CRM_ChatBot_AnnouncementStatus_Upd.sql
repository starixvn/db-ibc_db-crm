/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_ChatBot_AnnouncementStatus_Upd]
	@UserId				INT
	,@AnnouncementId	INT
	,@Status			VARCHAR(20) = 'Cancelled'
	,@ErrCode			INT = 0 OUTPUT
	,@ErrMsg			NVARCHAR(2000) = '' OUTPUT
	,@LoginIP			VARCHAR(50) = ''
AS
/*
	Created: 20221213@Malcolm
	Task :  Annoucement - Announcement List - Update planned Status to Cancelled Status
	DB: DBCRM/bodb_CRM
	Original:
		Revisions:
			- 20221213@Malcolm: Initialize SPs [Redmine: #179118]
	Param's Explanation:
		
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @NewValues NVARCHAR(MAX),  @OldValues NVARCHAR(MAX)

	UPDATE a WITH(ROWLOCK, UPDLOCK)
		SET a.Status = @Status
	FROM dbo.crmAnnouncement a 
	WHERE a.Status = 'Planned' AND a.AnnouncementId = @AnnouncementId

	IF @@ROWCOUNT = 0
	BEGIN
		SELECT @ErrCode = 100, @ErrMsg = 'Status of this announcement has been updated please check again.'
		RETURN
	END

	SELECT @OldValues = CONVERT(VARCHAR(MAX),(SELECT @AnnouncementId AS '@AnnouncementId','Planned' AS '@Status' FOR XML PATH('Acc_CRM_ChatBot_AnnouncementStatus_Upd')))

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