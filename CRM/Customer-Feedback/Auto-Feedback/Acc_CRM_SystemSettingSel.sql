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
		- 20200612@Johnson: remove LastMsgID [redmine:#135719]
		- 20200812@Johnson: Filter by serviceName = 'AutoFB' [redmine:#139158]
		- 20210705@Winfred: Integrate Abnormal Accounts [RedmineId : #157303]
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @JobStatus VARCHAR(50),
			@BatchSize INT,			
			@ConfigUAT BIT,
			@ConfigPRO BIT,
			@ServiceFlag BIT,
			@LastRuntime DATETIME,
			@JobStatusUAT VARCHAR(50),
			@LastRuntimeUAT DATETIME,
			@LastDateUAT DATETIME
	
	SELECT @JobStatus = value 
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'JobStatus'
		AND ServiceName = 'AutoFB'
	
	SELECT @BatchSize = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'BatchSize'
		AND ServiceName = 'AutoFB'
		
	SELECT @ConfigUAT = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'ConfigUAT'
		AND ServiceName = 'AutoFB'
		
	SELECT @ConfigPRO = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'ConfigPRO'
		AND ServiceName = 'AutoFB'
		
	SELECT @ServiceFlag = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'ServiceFlag'
		AND ServiceName = 'AutoFB'
		
	SELECT @LastRuntime = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'LastRuntime'
		AND ServiceName = 'AutoFB'
	
	SELECT @JobStatusUAT = value 
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'JobStatusUAT'
		AND ServiceName = 'AutoFB'
		
	SELECT @LastRuntimeUAT = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'LastRuntimeUAT'
		AND ServiceName = 'AutoFB'	
	
	SELECT @LastDateUAT = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'LastDateUAT'
		AND ServiceName = 'AutoFB'	
			
	SELECT @JobStatus as JobStatus, 
		@BatchSize as BatchSize, 
		@ConfigUAT as ConfigUAT,
		@ConfigPRO as ConfigPRO,
		@ServiceFlag as ServiceFlag,
		@LastRuntime as LastRuntime,
		@JobStatusUAT as JobStatusUAT,
		@LastRuntimeUAT as LastRuntimeUAT,
		@LastDateUAT as LastDateUAT
END