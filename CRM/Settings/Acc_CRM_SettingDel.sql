
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.Acc_CRM_SettingDel    Script Date: 3/26/2014 6:06:09 PM ******/

CREATE PROCEDURE [dbo].[Acc_CRM_SettingDel]
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
	- 20140221@Dom: Update Log writing
Param's Explanation:
	
*/
BEGIN
	SET NOCOUNT ON
		
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
	DECLARE @NewValues XML,@OldValues XML

	SELECT @NewValues = 				
					'<Acc_CRM_SettingDel>'	+ --SP Name						
					'<IsActive>0</IsActive>'+
					'</Acc_CRM_SettingDel>' 
	SELECT @OldValues = 				
					'<Acc_CRM_SettingDel>'	+ --SP Name						
					'<IsActive>1</IsActive>'+
					'</Acc_CRM_SettingDel>' 
				

	EXEC [dbo].[WriteLog_UserLog_crmLogSetting]
					@SettingID = @SettingID, 
					@ParentID = 0, 
					@UserID = @UserID, 
					@ActionID = 304, 
					@IP = @IP, 
					@NewValues = @NewValues,
					@OldValues = @OldValues
END



GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_SettingDel] TO [bodbAdminNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_SettingDel] TO [vnteam]
GO 
