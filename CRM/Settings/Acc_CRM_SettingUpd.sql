
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.Acc_CRM_SettingUpd    Script Date: 3/26/2014 6:06:09 PM ******/

CREATE PROCEDURE [dbo].[Acc_CRM_SettingUpd]
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
	- 20140303@Dom: Modify for new structure
Param's Explanation:
	
*/
BEGIN
	SET NOCOUNT ON

	SELECT	@ErrCode	= 0,
			@ErrMsg		= ''

	IF	NOT EXISTS (SELECT 1 FROM crmSetting WITH(NOLOCK) WHERE SettingID = @SettingID) 		
	BEGIN
		SELECT @ErrCode = 100, @ErrMsg = 'Setting does not exist.'
		RETURN
	END

	DECLARE @SettingValue_Old	NVARCHAR(100), 
	@SettingName_Old	VARCHAR(50),
	@DisplayOrder_Old	INT

	SELECT	
		@SettingValue_Old	= SettingValue,
		@SettingName_Old	= SettingName,
		@DisplayOrder_Old	= DisplayOrder
	FROM crmSetting WITH(NOLOCK)
	WHERE 
		SettingID = @SettingID

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
	DECLARE @NewValues XML,@OldValues XML

	SELECT @OldValues = 				
					'<Acc_CRM_SettingUpd>'	+ --SP Name
						'<SettingName>'		+ ISNULL(@SettingName_Old,'')						+ '</SettingName>'	+
						'<SettingValue>'	+ ISNULL(@SettingValue_Old,'')						+ '</SettingValue>'	+
						'<DisplayOrder>'	+ ISNULL(CONVERT(VARCHAR(10),@DisplayOrder_Old),'')	+ '</DisplayOrder>' +
					'</Acc_CRM_SettingUpd>' 

	SELECT @NewValues = 				
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
					@NewValues = @NewValues,
					@OldValues = @OldValues
 END

 select @ErrCode,
		@ErrMsg,
		@@error


GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_SettingUpd] TO [bodbAdminNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_SettingUpd] TO [vnteam]
GO 
