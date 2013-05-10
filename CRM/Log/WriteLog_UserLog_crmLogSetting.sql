
ALTER PROCEDURE [dbo].[WriteLog_UserLog_crmLogSetting]
(
	@SettingID	INT, 
	@ParentID	INT,
	@UserID		VARCHAR(50), 
	@ActionID	INT, 
	@IP			VARCHAR(15),	
	@Doing		XML
)
AS
/*
Created: Lukas
Date: 20101103
Task : write crmLogSetting
DB: DB06.bodb_CRM
Original:

Revisions:
	
Param's Explanation:
	- @UserID: UserId perform this action
	- @CustID: 
	- @ActionID: Log action Id
	- @Doing: xml string format
*/
BEGIN
	SET NOCOUNT ON

	INSERT INTO crmLogSetting
				(
					LogDate, 
					SettingID, 
					ParentID, 
					UserID, 
					ActionID, 
					IP, 
					Doing
				)
			VALUES
				(
					getdate(), 
					@SettingID, 
					@ParentID, 
					@UserID, 
					@ActionID, 
					@IP, 
					@Doing
				)
END


GO
GRANT EXECUTE ON [dbo].[WriteLog_UserLog_crmLogSetting] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[WriteLog_UserLog_crmLogSetting] TO [vnteam]