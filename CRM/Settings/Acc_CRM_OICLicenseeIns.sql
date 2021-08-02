/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.Acc_CRM_OICLicenseeIns
	@Licensees xml = '',
	@Environment	VARCHAR(50) = 'LIVE',
	@ErrCode INT = 0 OUTPUT,
	@ErrMsg VARCHAR(1000) = '' OUTPUT
AS
/*
	Created: 20210526@Johnson	
	Task: get list OIC licensees to synchronize into CRM
	DB:	DBCRM/bodb_CRM
	Original:
	
	Revisions:
		- 20210526@Johnson: initial sp [redmine:#154840]
	
	Parameter's Explanations:
		@Licensees = '<ROOT>
					<r Name="108bet" status="4" />
					<r Name="10BET" status="4" />
					<r Name="12BET" status="3" />				
					</ROOT>'
*/	
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @tmpLicensee TABLE (
						LicenseeName	NVARCHAR(100),
						StatusID		INT,
						IsActive 		BIT,
						IsProcessed		BIT DEFAULT 0
						)
	
	DECLARE @tmpCRMSite TABLE (settingid 		INT, 
								site			NVARCHAR(200), 
								isActive 		BIT, 
								DisplayOrder 	INT)
								
	;WITH t AS (
		SELECT t.c.value('@Name[1]','nvarchar(100)') LicenseeName,
			t.c.value('@status[1]','tinyint') statusid
		FROM @Licensees.nodes('/ROOT/r') t(c)
	)	
	INSERT INTO @tmpLicensee(LicenseeName,StatusID,IsActive)
	SELECT LicenseeName, statusid, CASE WHEN statusid <> 4 THEN 1 ELSE 0 END
	FROM t
		
	--mapping IBO,KeanOcean to Kzing,LIVV88 in crm
	UPDATE @tmpLicensee
	SET LicenseeName = CASE WHEN LicenseeName = 'IBO' THEN 'Kzing'
							WHEN LicenseeName = 'KeanOcean' THEN 'LIVV88'
							ELSE LicenseeName END
		
	DECLARE @LicenseeSiteID INT,
			@DisplayOrderMax INT,
			@site 			NVARCHAR(100),
			@SettingID		INT,
			@IsActive		BIT,
			@ConfigTestLicensee	BIT
	
	SELECT @ConfigTestLicensee = ISNULL(value,0)
	FROM SystemSetting WITH(NOLOCK)
	WHERE ServiceName = 'SyncOICLicensee'
		AND SettingName = 'ConfigTestLicensee'
	
	DELETE @tmpLicensee
	WHERE 1= CASE WHEN @Environment = 'UAT' AND LicenseeName = 'Spondemo' THEN 0
				WHEN @Environment = 'LIVE' AND (LicenseeName <> 'Spondemo' 
												OR (LicenseeName='Spondemo' AND @ConfigTestLicensee = 1)
											) THEN 0
				ELSE 1 END
			
	SELECT @LicenseeSiteID = SettingID 
	FROM crmSetting WITH(NOLOCK)
	WHERE SettingValue = 'LicenseeSite'
		
	INSERT INTO @tmpCRMSite(settingid, site, isActive, DisplayOrder)
	SELECT settingid, SettingValue as Site, IsActive, DisplayOrder
	FROM crmSetting WITH(NOLOCK)
	WHERE SettingID IN (SELECT settingid 
						FROM crmSettingRelation WITH(NOLOCK) 
						WHERE ParentID= @LicenseeSiteID)

	DELETE t 
	FROM @tmpLicensee t
	WHERE EXISTS (SELECT 1 FROM @tmpCRMSite s WHERE s.site = t.LicenseeName AND s.IsActive = t.IsActive)
	
	SELECT @DisplayOrderMax = MAX(DisplayOrder)
	FROM @tmpCRMSite
	
	--add new Licensees in OIC
	WHILE(1=1)
	BEGIN
		UPDATE TOP (1) t
		SET IsProcessed = 1,
			@site = t.LicenseeName,
			@isActive = t.IsActive
		FROM @tmpLicensee t
			LEFT JOIN @tmpCRMSite s ON t.LicenseeName = s.Site
		WHERE s.site IS NULL
			AND IsProcessed = 0
		
		IF @@ROWCOUNT = 0
			BREAK;
		
		SELECT @DisplayOrderMax = @DisplayOrderMax + 1
		
		EXEC Acc_CRM_SettingIns @UserID = 10278938 --starixIT
			,@UserRole = 2
			,@IP = '125.227.140.97'
			,@SettingSource = DEFAULT
			,@DisplayOrder = @DisplayOrderMax
			,@ErrCode = @ErrCode OUTPUT
			,@SettingValue = @site
			,@ErrMsg = @ErrMsg OUTPUT
			,@SettingName = 'Site'
			,@ParentID = @LicenseeSiteID

		IF @ErrCode > 0
			RETURN;
	END					
	
	--Update status for Licensee in CRM	
	WHILE(1=1)
	BEGIN
		UPDATE TOP (1) t
		SET IsProcessed = 1,
			@site = t.LicenseeName,
			@SettingID = s.SettingID,
			@isActive = t.IsActive
		FROM @tmpLicensee t
			INNER JOIN @tmpCRMSite s ON t.LicenseeName = s.Site
		WHERE IsProcessed = 0
			AND t.IsActive <> s.IsActive
		
		IF @@ROWCOUNT = 0
			BREAK;
		
		EXEC Acc_CRM_SettingDel @UserID = 10278938 --starixIT
			,@IP = '125.227.140.97'
			,@SettingID = @SettingID
			,@UserRole = 2
			,@ErrCode = @ErrCode OUTPUT
			,@ErrMsg = @ErrMsg OUTPUT
			,@isActive = @IsActive
	END	
END	