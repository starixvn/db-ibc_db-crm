/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Acc_CRM_WinLimit_SystemSettingSel] 	
AS
/*
	Created: 20201014@Johnson
	Task : get system setting for service winlimit auto feedback
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20201014@Johnson: Initial sp [redmine:#142194]
		
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @JobStatus 	VARCHAR(50),
			@BatchSize 	INT,			
			@ConfigUAT 	BIT,
			@ConfigPRO 	BIT,
			@ServiceFlag BIT,
			@LastRuntime DATETIME,
			@LastLogID 	BIGINT,
			@IsCredit 	BIT,
			@IsDeposit 	BIT 
	
	SELECT @JobStatus = value 
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'JobStatus'
		AND ServiceName = 'WinLimitFB'
	
	SELECT @BatchSize = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'BatchSize'
		AND ServiceName = 'WinLimitFB'
		
	SELECT @ConfigUAT = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'ConfigUAT'
		AND ServiceName = 'WinLimitFB'
		
	SELECT @ConfigPRO = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'ConfigPRO'
		AND ServiceName = 'WinLimitFB'
		
	SELECT @ServiceFlag = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'ServiceFlag'
		AND ServiceName = 'WinLimitFB'
		
	SELECT @LastRuntime = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'LastRuntime'
		AND ServiceName = 'WinLimitFB'
		
	SELECT @LastLogID = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'LastLogID'
		AND ServiceName = 'WinLimitFB'
	
	SELECT @IsCredit = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'IsCredit'
		AND ServiceName = 'WinLimitFB'
		
	SELECT @IsDeposit = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'IsDeposit'
		AND ServiceName = 'WinLimitFB'	
		
	SELECT @JobStatus as JobStatus, 
		@BatchSize as BatchSize, 
		@ConfigUAT as ConfigUAT,
		@ConfigPRO as ConfigPRO,
		@ServiceFlag as ServiceFlag,
		@LastRuntime as LastRuntime,
		@LastLogID as LastLogID,
		@IsCredit as IsCredit,
		@IsDeposit as IsDeposit
END