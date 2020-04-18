/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Acc_CRM_SystemSettingSel] 	
AS
/*
	Created: 20200416@@Johnson
	Task : get system setting for service auto feedback
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20200416@@Johnson: Initial sp [redmine:#130949]
	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @JobStatus VARCHAR(50),
			@BatchSize INT,
			@LastMsgID INT,
			@ConfigUAT BIT,
			@ConfigPRO BIT
	
	SELECT @JobStatus = value 
	FROM crmSystemSetting WITH(NOLOCK)
	WHERE SettingName = 'JobStatus'
	
	SELECT @BatchSize = value
	FROM crmSystemSetting WITH(NOLOCK)
	WHERE SettingName = 'BatchSize'
	
	SELECT @LastMsgID = value
	FROM crmSystemSetting WITH(NOLOCK)
	WHERE SettingName = 'LastMsgID'
	
	SELECT @ConfigUAT = value
	FROM crmSystemSetting WITH(NOLOCK)
	WHERE SettingName = 'ConfigUAT'
	
	SELECT @ConfigPRO = value
	FROM crmSystemSetting WITH(NOLOCK)
	WHERE SettingName = 'ConfigPRO'
	
	SELECT @JobStatus as JobStatus, 
		@BatchSize as BatchSize, 
		@LastMsgID as LastMsgID,
		@ConfigUAT as ConfigUAT,
		@ConfigPRO as ConfigPRO
END