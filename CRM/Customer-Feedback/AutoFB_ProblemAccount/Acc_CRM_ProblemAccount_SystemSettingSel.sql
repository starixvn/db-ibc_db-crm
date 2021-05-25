/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Acc_CRM_ProblemAccount_SystemSettingSel] 	
AS
/*
	Created: 20210505@Johnson
	Task : get system setting for service ProblemAccount auto feedback
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20210505@Johnson: Initial sp [redmine:#153119]
		
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @JobStatus 	VARCHAR(50),
			@JobStatusUAT 	VARCHAR(50),
			@BatchSize 	INT,			
			@ConfigUAT 	BIT,
			@ConfigPRO 	BIT,
			@ServiceFlag BIT,
			@LastRuntime DATETIME,
			@LastRuntimeUAT DATETIME,
			@LastLogID 	INT,
			@LastLogIdUAT 	INT
	
	SELECT @JobStatus = value 
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'JobStatus'
		AND ServiceName = 'ProblemAccountFB'
	
	SELECT @JobStatusUAT = value 
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'JobStatusUAT'
		AND ServiceName = 'ProblemAccountFB'
		
	SELECT @BatchSize = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'BatchSize'
		AND ServiceName = 'ProblemAccountFB'
		
	SELECT @ConfigUAT = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'ConfigUAT'
		AND ServiceName = 'ProblemAccountFB'
		
	SELECT @ConfigPRO = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'ConfigPRO'
		AND ServiceName = 'ProblemAccountFB'
		
	SELECT @ServiceFlag = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'ServiceFlag'
		AND ServiceName = 'ProblemAccountFB'
		
	SELECT @LastRuntime = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'LastRuntime'
		AND ServiceName = 'ProblemAccountFB'
	
	SELECT @LastRuntimeUAT = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'LastRuntimeUAT'
		AND ServiceName = 'ProblemAccountFB'
		
	SELECT @LastLogID = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'LastLogID'
		AND ServiceName = 'ProblemAccountFB'
	
	SELECT @LastLogIdUAT = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'LastLogIdUAT'
		AND ServiceName = 'ProblemAccountFB'
	
	SELECT @JobStatus as JobStatus, 
		@JobStatusUAT as JobStatusUAT, 
		@BatchSize as BatchSize, 
		@ConfigUAT as ConfigUAT,
		@ConfigPRO as ConfigPRO,
		@ServiceFlag as ServiceFlag,		
		@LastRuntime as LastRuntime,
		@LastRuntimeUAT as LastRuntimeUAT,
		@LastLogID as LastLogID,
		@LastLogIdUAT as LastLogIdUAT
END