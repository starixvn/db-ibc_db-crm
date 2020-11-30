/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Acc_CRM_TOControl_SystemSettingSel] 	
AS
/*
	Created: 20201125@Johnson
	Task : get system setting for service TO Control auto feedback
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20201125@Johnson: Initial sp [redmine:#145274]
		
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @JobStatus 	VARCHAR(50),
			@BatchSize 	INT,			
			@ConfigUAT 	BIT,
			@ConfigPRO 	BIT,
			@ServiceFlag BIT,
			@LastRuntime DATETIME,
			@LastNotifiedDate DATETIME,
			@IsCredit 	BIT,
			@IsDeposit 	BIT 
	
	SELECT @JobStatus = value 
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'JobStatus'
		AND ServiceName = 'TOControlFB'
	
	SELECT @BatchSize = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'BatchSize'
		AND ServiceName = 'TOControlFB'
		
	SELECT @ConfigUAT = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'ConfigUAT'
		AND ServiceName = 'TOControlFB'
		
	SELECT @ConfigPRO = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'ConfigPRO'
		AND ServiceName = 'TOControlFB'
		
	SELECT @ServiceFlag = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'ServiceFlag'
		AND ServiceName = 'TOControlFB'
		
	SELECT @LastRuntime = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'LastRuntime'
		AND ServiceName = 'TOControlFB'
		
	SELECT @LastNotifiedDate = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'LastNotifiedDate'
		AND ServiceName = 'TOControlFB'
	
	SELECT @IsCredit = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'IsCredit'
		AND ServiceName = 'TOControlFB'
		
	SELECT @IsDeposit = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'IsDeposit'
		AND ServiceName = 'TOControlFB'	
		
	SELECT @JobStatus as JobStatus, 
		@BatchSize as BatchSize, 
		@ConfigUAT as ConfigUAT,
		@ConfigPRO as ConfigPRO,
		@ServiceFlag as ServiceFlag,
		@LastRuntime as LastRuntime,
		@LastNotifiedDate as LastNotifiedDate,
		@IsCredit as IsCredit,
		@IsDeposit as IsDeposit
END