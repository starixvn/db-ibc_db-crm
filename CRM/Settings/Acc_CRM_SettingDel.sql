SET QUOTED_IDENTIFIER ON; 
GO
SET ANSI_NULLS ON; 
GO

ALTER PROCEDURE	[dbo].[Acc_CRM_SettingDel] (
					@UserID			INT
				,	@SettingID		INT
				,	@isActive		BIT
				,	@IP				VARCHAR(15)
				,	@ErrCode		INT				= 0		OUTPUT
				,	@ErrMsg			NVARCHAR(4000)	= ''	OUTPUT
)
AS
/*
	Created:	Lukas
	Date:		20101117
	Task:		delete setting
	DB:			DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20130121@Johnson: change linked server DB03 to DBPOLICY
		- 20140221@Dom: Update Log writing
		- 20160301@Billy: Change status of a setting value (Active/Inactive) - [Redmine: #53173]

	Param's Explanation:
	
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE	@OldIsActive		BIT;
	
	SELECT	@OldIsActive = cs.IsActive
	FROM	dbo.crmSetting AS cs WITH (NOLOCK)
	WHERE	cs.SettingID = @SettingID;

	IF	@OldIsActive IS NULL	
	BEGIN
		SELECT	@ErrCode	= 100
			,	@ErrMsg		= 'Setting does not exist.';
		RETURN;
	END;

	IF	@OldIsActive = @isActive
		RETURN;

	-- Update isActive value
	UPDATE	dbo.crmSetting WITH (ROWLOCK, UPDLOCK)
	SET		IsActive = @isActive
	WHERE	SettingID = @SettingID;

	IF @@ERROR <> 0
	BEGIN
		SELECT	@ErrCode	= 101
			,	@ErrMsg		= CASE @isActive WHEN 0	THEN 'Deactivate setting unsuccessfully.'
													ELSE 'Active setting unsuccessfully.'
							  END;
		RETURN;
	END;

	-- Write log
	DECLARE	@NewValues		XML
		,	@OldValues		XML;

	SELECT @NewValues = (
		SELECT	@isActive		AS 'IsActive'
		FOR XML PATH ('Acc_CRM_SettingUpdStatus')
	,	TYPE
	);
	SELECT @OldValues = (
		SELECT	@OldIsActive	AS 'IsActive'
		FOR XML PATH ('Acc_CRM_SettingUpdStatus')
	,	TYPE
	);

	EXEC [dbo].[WriteLog_UserLog_crmLogSetting]
					@SettingID = @SettingID, 
					@ParentID = 0, 
					@UserID = @UserID, 
					@ActionID = 304, 
					@IP = @IP, 
					@NewValues = @NewValues,
					@OldValues = @OldValues;
END;
GO 

GRANT EXECUTE ON [dbo].[Acc_CRM_SettingDel] TO [bodbAdminNet];
GO 
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_SettingDel] TO [vnteam];
GO 
