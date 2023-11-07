USE bodb_CRM
GO

CREATE PROCEDURE [dbo].[Acc_CRM_SettingRelationIns]
(
	@UserID			INT,
	@SettingID		INT,
	@ParentID		INT,
	@DisplayOrder	INT = 0,
	@IP				VARCHAR(15),
	@ErrCode		INT = 0 OUTPUT,
	@ErrMsg			NVARCHAR(4000) = '' OUTPUT
)
AS

/*
Created:
Date:
Task : insert to SettingRealtion.
DB: DB06.bodb_CRM
Original:

Revisions:
	- 20140221@Dom: Update Log writing
    - 20230918@Ned.Le: CRM - Category/sub-category/admin tool (Setting Management) can show by Alphabet (#193380)

Param's Explanation:

*/

BEGIN
	SET NOCOUNT ON

--	--Check permission
--	EXEC db03.bodb02.dbo.Acc_Con_CheckPermission @custid=@UserID,@funcname='[SettingRelationManagement]',@ErrCode=@ErrCode OUTPUT,@ErrMsg=@ErrMsg OUTPUT
--	IF @ErrCode <> 0
--		RETURN

	SELECT	@ErrCode	= 0,
			@ErrMsg		= ''

	SELECT @ParentID = CASE WHEN @ParentID = 0 THEN NULL ELSE @ParentID END

	IF	NOT EXISTS (SELECT 1 FROM crmSetting WITH(NOLOCK) WHERE SettingID = @SettingID) 
		OR 
		NOT EXISTS (SELECT TOP 1 1 FROM crmSetting WITH(NOLOCK) WHERE SettingID = COALESCE(@ParentID,SettingID) ) 
	BEGIN
		SELECT @ErrCode = 100, @ErrMsg = 'Setting does not exist.'
		RETURN
	END	

	SELECT @ParentID = ISNULL(@ParentID,0)
	IF EXISTS (	SELECT 1 
				FROM crmSettingRelation WITH(NOLOCK) 
				WHERE SettingID = @SettingID 
						AND 
					  ParentID = @ParentID
			  )
	BEGIN
		SELECT @ErrCode = 101, @ErrMsg = 'Setting relation existed already.'
		RETURN
	END

	-- insert to crmSettingRelation	

	INSERT INTO crmSettingRelation	
				(
					SettingID, 
					ParentID, 
					DisplayOrder
				)
			VALUES
				(
					@SettingID, 
					@ParentID, 
					@DisplayOrder
				)
	IF @@ERROR <> 0
	BEGIN
		SELECT @ErrCode = 102, @ErrMsg = 'Insert setting relation unsuccessfuly.'
		RETURN
	END

	-- write log
	DECLARE @LogElement XML

	SELECT @LogElement = 				
					'<Acc_CRM_SettingRelationIns>' + --SP Name
						'<DisplayOrder>'	+ ISNULL(CONVERT(VARCHAR(10),@DisplayOrder),'') + '</DisplayOrder>' +
					'</Acc_CRM_SettingRelationIns>'				

	EXEC [dbo].[WriteLog_UserLog_crmLogSetting]
					@SettingID = @SettingID, 
					@ParentID = @ParentID, 
					@UserID = @UserID, 
					@ActionID = 302, 
					@IP = @IP, 
					@NewValues = @LogElement
END


GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_SettingRelationIns] TO [bodbAdminNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_SettingRelationIns] TO [vnteam]
GO 
