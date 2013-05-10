
ALTER PROCEDURE [dbo].[Acc_CRM_SettingUpd]
(
	@UserID			INT,
	@SettingID		INT,	
	@SettingValue	NVARCHAR(100), 
	@SettingName	VARCHAR(50),
	@DisplayOrder	INT,
	@IP				VARCHAR(15),
	@ErrCode		INT = 0 OUTPUT,
	@ErrMsg			NVARCHAR(4000) = '' OUTPUT
)
AS
/*
Created: Lukas
Date: 20101117
Task : update setting
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

	SELECT	@ErrCode	= 0,
			@ErrMsg		= ''

	IF	NOT EXISTS (SELECT 1 FROM crmSetting WITH(NOLOCK) WHERE SettingID = @SettingID) 		
	BEGIN
		SELECT @ErrCode = 100, @ErrMsg = 'Setting does not exist.'
		RETURN
	END

	--- update setting
	UPDATE crmSetting WITH(ROWLOCK,UPDLOCK)
	SET	
		SettingValue	= @SettingValue,
		SettingName		= @SettingName,
		DisplayOrder	= @DisplayOrder
	WHERE 
		SettingID = @SettingID
	
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrCode = 101, @ErrMsg = 'Update setting unsuccessfuly.'
		RETURN
	END

	-- write log
	DECLARE @LogElement XML

	SELECT @LogElement = 				
					'<Acc_CRM_SettingUpd>'	+ --SP Name
						'<SettingName>'		+ ISNULL(@SettingName,'')						+ '</SettingName>'	+
						'<SettingValue>'	+ ISNULL(@SettingValue,'')						+ '</SettingValue>'	+
						'<DisplayOrder>'	+ ISNULL(CONVERT(VARCHAR(10),@DisplayOrder),'')	+ '</DisplayOrder>' +
					'</Acc_CRM_SettingUpd>' 
				

	EXEC [dbo].[WriteLog_UserLog_crmLogSetting]
					@SettingID = @SettingID, 
					@ParentID = 0, 
					@UserID = @UserID, 
					@ActionID = 301, 
					@IP = @IP, 
					@Doing = @LogElement
END



GO
GRANT EXECUTE ON [dbo].[Acc_CRM_SettingUpd] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_SettingUpd] TO [vnteam] 