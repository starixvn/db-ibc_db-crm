/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_ConfigAutoFeedback_SettingSel] 
	@ServiceName VARCHAR(100) = '',
	@Envr VARCHAR(10) = 'UAT',
	@SettingName VARCHAR(100) = ''
AS
/*
	Created: Winfred
	Task : Get system setting for all service
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20221028@Winfred: Get all system setting config for service [redmine:#158258]
	
	Parameter's Explanation:
		- @ServiceName = '': ''= ALL  or Service Name
		- @Envr = 'UAT': 'UAT' / 'PRO'	
		- @SettingName = ''= ALL Or Setting Name	
*/
BEGIN
	SET NOCOUNT ON
				
	SELECT  ID , SettingName, Value, ServiceName, DataType
	FROM SystemSetting WITH(NOLOCK)
	WHERE (@ServiceName = '' OR ServiceName = @ServiceName)
	AND (  (@Envr = 'PRO' AND CHARINDEX('UAT', SettingName) = 0) 
		OR (@Envr = 'UAT' AND CHARINDEX('UAT', SettingName) > 0))
	AND (@SettingName = '' OR SettingName = @SettingName)
	ORDER BY ServiceName, ID

END