
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.Acc_CRM_SettingRelationDel    Script Date: 3/26/2014 6:06:09 PM ******/

CREATE PROCEDURE [dbo].[Acc_CRM_SettingRelationDel]
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
	- 20140221@Dom: Update Log Writing
Param's Explanation:
	
*/
BEGIN
	SET NOCOUNT ON

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
		RETURN
	END
	-- write log
	DECLARE @NewValues XML,@OldValues XML

	SELECT @OldValues = 				
					'<Acc_CRM_SettingRelationDel>' + --SP Name
					'<SettingID>'+CAST(@SettingID AS NCHAR(10))+'</SettingID>'+
					'<ParentID>'+CAST(@ParentID AS NCHAR(10))+'</ParentID>'+
					'</Acc_CRM_SettingRelationDel>' 
	SELECT @NewValues = 				
					'<Acc_CRM_SettingRelationDel>' + --SP Name
					'</Acc_CRM_SettingRelationDel>' 
				

	EXEC [dbo].[WriteLog_UserLog_crmLogSetting]
					@SettingID = @SettingID, 
					@ParentID = @ParentID, 
					@UserID = @UserID, 
					@ActionID = 303, 
					@IP = @IP, 
					@NewValues = @NewValues,
					@OldValues= @OldValues
END





GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_SettingRelationDel] TO [bodbAdminNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_SettingRelationDel] TO [vnteam]
GO 
