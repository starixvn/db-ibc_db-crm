
ALTER PROCEDURE [dbo].[Acc_CRM_SettingRelationDel]
(
	@UserID			INT,
	@SettingID		INT,
	@ParentID		INT,	
	@IP				VARCHAR(15),
	@ErrCode		INT = 0 OUTPUT,
	@ErrMsg			NVARCHAR(4000) = '' OUTPUT
)
AS
/*
Created: Lukas
Date: 20101119
Task : delete SettingRealtion.
DB: DBCRM/bodb_CRM
Original:

Revisions:
	- 20130121@Johnson: change linked server DB03 to DBPOLICY
Param's Explanation:
	
*/
BEGIN
	SET NOCOUNT ON

	--Check permission
	EXEC DBPOLICY.bodb02.dbo.Acc_Con_CheckPermission @custid=@UserID,@funcname='[SettingRelationManagement]',@ErrCode=@ErrCode OUTPUT,@ErrMsg=@ErrMsg OUTPUT
	IF @ErrCode <> 0
		RETURN

	SELECT	@ErrCode	= 0,
			@ErrMsg		= ''

	DELETE FROM crmSettingRelation 
	WHERE 
		SettingID = @SettingID
		AND
		ParentID = @ParentID
	IF @@ERROR <> 0
	BEGIN
		SELECT	@ErrCode = 100,
				@ErrMsg  = 'Delete setting relation unsuccessfuly'
	END
	-- write log
	DECLARE @LogElement XML

	SELECT @LogElement = 				
					'<Acc_CRM_SettingRelationDel>' + --SP Name
					'</Acc_CRM_SettingRelationDel>' 
				

	EXEC [dbo].[WriteLog_UserLog_crmLogSetting]
					@SettingID = @SettingID, 
					@ParentID = @ParentID, 
					@UserID = @UserID, 
					@ActionID = 303, 
					@IP = @IP, 
					@Doing = @LogElement
END




GO
GRANT EXECUTE ON [dbo].[Acc_CRM_SettingRelationDel] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_SettingRelationDel] TO [vnteam]