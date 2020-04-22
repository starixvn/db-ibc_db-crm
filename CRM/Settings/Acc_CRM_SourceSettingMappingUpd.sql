/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.Acc_CRM_SourceSettingMappingUpd
	@SettingID VARCHAR(50),
	@SettingSource VARCHAR(MAX) = '', 
	@UserID INT =0,
	@IP VARCHAR(15)=''
AS
/*
	Created: 20200422@Johnson	
	Task: get source setting for crm setting 
	DB:	DBCRM/bodb_CRM
	Original:
	
	Revisions:
		- 20200421@Johnson: initial sp [redmine:#130949]
	
	Parameter's Explanations:
*/	
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @tmpSettingSource TABLE(SettingSource VARCHAR(50))
	DECLARE @SettingSource_Old VARCHAR(MAX) = ''
	
	SELECT @SettingSource = NULLIF(@SettingSource,'')
	
	INSERT INTO @tmpSettingSource(SettingSource)
	SELECT val
	FROM f_CRM_StrSplit(@SettingSource,',')
	
	--check any setting change
	IF NOT EXISTS(SELECT 1 FROM @tmpSettingSource t
				LEFT JOIN crmSettingMapping m WITH(NOLOCK) ON m.SettingID = @SettingID
															AND m.SettingSource = t.SettingSource
				WHERE m.SettingID IS NULL 											
	)--dont have new setting
	AND NOT EXISTS(SELECT 1 FROM crmSettingMapping m WITH(NOLOCK)
				LEFT JOIN @tmpSettingSource t ON m.SettingID = @SettingID
											AND m.SettingSource = t.SettingSource														
				WHERE t.SettingSource IS NULL								
	)--dont remove any setting
	RETURN ;
	
	SELECT @SettingSource_Old = STUFF(
		(
			SELECT ',' + SettingSource
			FROM crmSettingMapping WITH(NOLOCK)
			WHERE settingID = @SettingID
			ORDER BY SettingSource ASC
			FOR XML PATH('')
		),1,1,'')
	
	
	DELETE crmSettingMapping WITH(UPDLOCK,ROWLOCK)	
	WHERE SettingID = @SettingID
		AND SettingSource NOT IN (SELECT SettingSource FROM @tmpSettingSource)
	
	INSERT INTO crmSettingMapping(SettingID,SettingSource)
	SELECT @SettingID, t.SettingSource		
	FROM @tmpSettingSource t
		LEFT JOIN crmSettingMapping s WITH(NOLOCK) ON @SettingID = s.SettingID
											AND t.SettingSource = s.SettingSource
	WHERE s.settingID IS NULL										
	
	-- Write log
	DECLARE	@NewValues		XML
		,	@OldValues		XML;

	SELECT @NewValues = (
		SELECT	@SettingSource	AS 'SettingSource'
		FOR XML PATH ('Acc_CRM_SourceSettingMappingUpd')
	,	TYPE
	);
	SELECT @OldValues = (
		SELECT	@SettingSource_old	AS 'SettingSource'
		FOR XML PATH ('Acc_CRM_SourceSettingMappingUpd')
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
END	