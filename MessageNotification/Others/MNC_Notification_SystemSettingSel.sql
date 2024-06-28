/*<info serverAlias="DBCRM-MessageNotification" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE MNC_Notification_SystemSettingSel
	@Environment VARCHAR(50) = ''
AS
/*
	Created: 20231213@Roy
	Task: Get configuration value 
	DB: DBCRM.MessageNotification
	Revisions:
		20231121@Roy: CRM - Implement Message Notifications Center for Result Amendment of Cricket(#197621)
	
	Example:
		EXEC MessageNotification.dbo.MNC_Notification_SystemSettingSel
*/
BEGIN
	SET NOCOUNT ON

	SELECT @Environment = ISNULL(@Environment, '')
	
	SELECT CONVERT(BIT, VValue) AS ServiceFlag
	FROM dbo.SystemSetting WITH (NOLOCK)
	WHERE VName LIKE '%UAT%'
		AND @Environment = 'UAT'
		AND VName = 'ServiceFlag'
	
	UNION ALL
	
	SELECT CONVERT(BIT, VValue) AS ServiceFlag
	FROM dbo.SystemSetting WITH (NOLOCK)
	WHERE VName NOT LIKE '%UAT%'
		AND @Environment <> 'UAT'
		AND VName = 'ServiceFlag'
END

