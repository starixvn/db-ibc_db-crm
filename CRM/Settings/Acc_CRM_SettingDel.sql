
ALTER PROCEDURE [dbo].[Acc_CRM_SettingDel]
(
	@UserID			INT,
	@SettingID		INT,
	@IP				VARCHAR(15),
	@ErrCode		INT = 0 OUTPUT,
	@ErrMsg			NVARCHAR(4000) = '' OUTPUT
)
AS
/*
Created: Lukas
Date: 20101117
Task : delete setting
DB: DBCRM/bodb_CRM
Original:

Revisions:
	- 20130121@Johnson: change linked server DB03 to DBPOLICY
Param's Explanation:
	
*/
BEGIN
	SET NOCOUNT ON
	
	--Check permission
	EXEC DBPOLICY.bodb02.dbo.Acc_Con_CheckPermission @custid=@UserID,@funcname='[SettingManagement]',@ErrCode=@ErrCode OUTPUT,@ErrMsg=@ErrMsg OUTPUT
	IF @ErrCode <> 0
		RETURN
		
		
	IF	NOT EXISTS (SELECT 1 FROM crmSetting WITH(NOLOCK) WHERE SettingID = @SettingID) 		
	BEGIN
		SELECT @ErrCode = 100, @ErrMsg = 'Setting does not exist.'
		RETURN
	END

	--- delete setting with changing IsActive = 0
	UPDATE crmSetting WITH(ROWLOCK,UPDLOCK)
	SET	
		IsActive = 0
	WHERE 
		SettingID = @SettingID
	
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrCode = 101, @ErrMsg = 'Delete setting unsuccessfuly.'
		RETURN
	END

	-- write log
	DECLARE @LogElement XML

	SELECT @LogElement = 				
					'<Acc_CRM_SettingDel>'	+ --SP Name						
					'</Acc_CRM_SettingDel>' 
				

	EXEC [dbo].[WriteLog_UserLog_crmLogSetting]
					@SettingID = @SettingID, 
					@ParentID = 0, 
					@UserID = @UserID, 
					@ActionID = 304, 
					@IP = @IP, 
					@Doing = @LogElement
END


GO
GRANT EXECUTE ON [dbo].[Acc_CRM_SettingDel] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_SettingDel] TO [vnteam] 