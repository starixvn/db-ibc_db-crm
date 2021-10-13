/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_Voiding_SystemSettingSel] 	
AS
/*
	Created: 20210908@Winfred
	Task : Get system setting for service Amendment Notification voiding settle auto feedback
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20210908@Winfred: Initial sp [redmine:#157481]
		
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @JobStatus 	VARCHAR(50),
			@BatchSize 	INT,			
			@ConfigUAT 	BIT,
			@ConfigPRO 	BIT,
			@ServiceFlag BIT,
			@LastRuntime DATETIME,
			@LastLogID 	INT,
			@IsCredit 	BIT,
			@IsDeposit 	BIT ,
			@LastRuntimeUAT DATETIME,
			@LastDateUAT DATETIME,
			@LastLogIDUAT 	INT,
			@JobStatusUAT 	VARCHAR(50)
			
	SELECT @JobStatus = value 
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'JobStatus'
		AND ServiceName = 'AutoVoidFB'
	
	SELECT @BatchSize = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'BatchSize'
		AND ServiceName = 'AutoVoidFB'
		
	SELECT @ConfigUAT = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'ConfigUAT'
		AND ServiceName = 'AutoVoidFB'
		
	SELECT @ConfigPRO = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'ConfigPRO'
		AND ServiceName = 'AutoVoidFB'
		
	SELECT @ServiceFlag = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'ServiceFlag'
		AND ServiceName = 'AutoVoidFB'
		
	SELECT @LastRuntime = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'LastRuntime'
		AND ServiceName = 'AutoVoidFB'
		
	SELECT @LastDateUAT = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'LastDateUAT'
		AND ServiceName = 'AutoVoidFB'
	
	SELECT @IsCredit = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'IsCredit'
		AND ServiceName = 'AutoVoidFB'
		
	SELECT @IsDeposit = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'IsDeposit'
		AND ServiceName = 'AutoVoidFB'	

	SELECT @JobStatusUAT = value 
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'JobStatusUAT'
		AND ServiceName = 'AutoVoidFB'
		
	SELECT @LastRuntimeUAT = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'LastRuntimeUAT'
		AND ServiceName = 'AutoVoidFB'
	
	SELECT @LastLogID = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'LastLogID'
		AND ServiceName = 'AutoVoidFB'	
		
	SELECT @LastLogIDUAT = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'LastLogIDUAT'
		AND ServiceName = 'AutoVoidFB'					
		
	SELECT @JobStatus as JobStatus, 
		@BatchSize as BatchSize, 
		@ConfigUAT as ConfigUAT,
		@ConfigPRO as ConfigPRO,
		@ServiceFlag as ServiceFlag,
		@LastRuntime as LastRuntime,
		@LastDateUAT as LastDateUAT,
		@IsCredit as IsCredit,
		@IsDeposit as IsDeposit,
		@JobStatusUAT as JobStatusUAT,
		@LastRuntimeUAT as LastRuntimeUAT,
		@LastLogID as LastLogID,
		@LastLogIDUAT as LastLogIDUAT
END