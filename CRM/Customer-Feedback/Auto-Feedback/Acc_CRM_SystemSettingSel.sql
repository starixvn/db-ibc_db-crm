/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Acc_CRM_SystemSettingSel] 	
AS
/*
	Created: 20200416@Johnson
	Task : get system setting for service auto feedback
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20200416@Johnson: Initial sp [redmine:#130949]
		- 20200519@Johnson: add setting serviceflag/lastruntime [redmine:#134220]	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @JobStatus VARCHAR(50),
			@BatchSize INT,
			@LastMsgID INT,
			@ConfigUAT BIT,
			@ConfigPRO BIT,
			@ServiceFlag BIT,
			@LastRuntime DATETIME
	
	SELECT @JobStatus = value 
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'JobStatus'
	
	SELECT @BatchSize = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'BatchSize'
	
	SELECT @LastMsgID = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'LastMsgID'
	
	SELECT @ConfigUAT = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'ConfigUAT'
	
	SELECT @ConfigPRO = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'ConfigPRO'
	
	SELECT @ConfigPRO = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'ConfigPRO'
	
	SELECT @ServiceFlag = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'ServiceFlag'
	
	SELECT @LastRuntime = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'LastRuntime'
	
	SELECT @JobStatus as JobStatus, 
		@BatchSize as BatchSize, 
		@LastMsgID as LastMsgID,
		@ConfigUAT as ConfigUAT,
		@ConfigPRO as ConfigPRO,
		@ServiceFlag as @ServiceFlag,
		@LastRuntime as LastRuntime
END