/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.Acc_CRM_SourceLicenseeMappingUpd
	@SettingID INT,
	@SourceMapping VARCHAR(50)='',
	@LicenseeManager VARCHAR(50)='',
	@UserID INT,
	@IP VARCHAR(15)='',
	@Errcode INT=0 OUTPUT,
	@ErrMsg VARCHAR(500)='' OUTPUT
AS
/*
	Created: 20200423@Johnson	
	Task: update Licensee mapping  
	DB:	DBCRM/bodb_CRM
	Original:
	
	Revisions:
		- 20200422@Johnson: initial sp [redmine:#130949]
	
	Parameter's Explanations:
*/	
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @LicenseeManagerID INT
	
	IF @LicenseeManager <> ''
	BEGIN
		SELECT @LicenseeManagerID = custid
		FROM crmCustomer WITH(NOLOCK) 
		WHERE username = @LicenseeManager
	END
	
	IF @LicenseeManager <> '' AND @LicenseeManagerID IS NULL	
	BEGIN
		SELECT @Errcode = 100,
			@ErrMsg = 'Incorrect Licensee Manager. Please check!'
		RETURN
	END	
	
	IF EXISTS (SELECT 1 FROM crmLicenseeMapping WITH(NOLOCK) 
			WHERE custid = @LicenseeManagerID 
			AND SettingID <> @SettingID)
	BEGIN
		SELECT @Errcode = 101,
			@ErrMsg = 'This '+@LicenseeManager+' has been assigned for '+s.SettingValue+'. Please check!'
		FROM crmSetting s WITH(NOLOCK)
			INNER JOIN crmLicenseeMapping m WITH(NOLOCK) ON s.SettingID = m.SettingID
		WHERE m.custid = @LicenseeManagerID 
			AND m.SettingID <> @SettingID		
		RETURN;	
	END	
	
	DECLARE @Site_old VARCHAR(50),
			@LicenseeManagerID_Old INT,
			@LicenseeManager_old VARCHAR(50)
			
	SELECT @Site_old = site,
		@LicenseeManagerID_Old = custid
	FROM crmLicenseeMapping WITH(NOLOCK)
	WHERE SettingID = @SettingID
	
	SELECT @LicenseeManager_old = username
	FROM crmCustomer WITH(NOLOCK)
	WHERE custid = @LicenseeManagerID_Old
	
	--dont change setting
	IF (@SourceMapping = '' 
		AND @LicenseeManager = ''
		AND NOT EXISTS (SELECT 1 FROM crmLicenseeMapping WITH(NOLOCK) 
						WHERE SettingID = @SettingID)
		)
	OR (@SourceMapping=@Site_old 
		AND @LicenseeManager = @LicenseeManager_old
		)
	RETURN;
	
	--add new mapping
	IF NOT EXISTS(SELECT 1 FROM crmLicenseeMapping WHERE SettingID = @SettingID)
	BEGIN
		INSERT INTO crmLicenseeMapping(SettingID,Site,CustID)
		VALUES(@SettingID,@SourceMapping,@LicenseeManagerID)
	END
	ELSE 
	BEGIN
		UPDATE s
		SET Site = @SourceMapping,
			custid = @LicenseeManagerID
		FROM crmLicenseeMapping s WITH(UPDLOCK,ROWLOCK)
		WHERE SettingID = @SettingID
	END
	
	-- write log
	DECLARE @NewValues XML,@OldValues XML

	SELECT @OldValues =	(	SELECT	ISNULL(@site_Old, '') AS	'SourceMapping',
									ISNULL(@LicenseeManager_old, '') AS	'LicenseeManager'								
							FOR XML PATH ('Acc_CRM_SourceLicenseeMappingUpd')
						)

	SELECT @NewValues =	(	SELECT	ISNULL(@SourceMapping, '') AS	'SourceMapping',
									ISNULL(@LicenseeManager, '') AS	'LicenseeManager'								
							FOR XML PATH ('Acc_CRM_SourceLicenseeMappingUpd')
						)				

	EXEC [dbo].[WriteLog_UserLog_crmLogSetting]
					@SettingID = @SettingID, 
					@ParentID = 0, 
					@UserID = @UserID, 
					@ActionID = 310, 
					@IP = @IP, 
					@NewValues = @NewValues,
					@OldValues = @OldValues
END	