/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_AmendmentNoti_SystemSettingSel] 	
AS
/*
	Created: Winfred
	Task : Get system setting for service Amendment Notification auto feedback
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 202010303@Winfred: Initial sp [redmine:#147470]
		
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @JobStatus 	VARCHAR(50),
			@BatchSize 	INT,			
			@ConfigUAT 	BIT,
			@ConfigPRO 	BIT,
			@ServiceFlag BIT,
			@LastRuntime DATETIME,
			@LastSubmitDate DATETIME2,
			@LastSeq 	INT,
			@IsCredit 	BIT,
			@IsDeposit 	BIT ,
			@BatchSizeTicket INT ,
			@LastRuntimeUAT DATETIME,
			@LastSubmitDateUAT DATETIME2,
			@LastSeqUAT 	INT,
			@JobStatusUAT 	VARCHAR(50)
			
	SELECT @JobStatus = value 
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'JobStatus'
		AND ServiceName = 'AmendmentNotiFB'
	
	SELECT @BatchSize = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'BatchSize'
		AND ServiceName = 'AmendmentNotiFB'
		
	SELECT @ConfigUAT = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'ConfigUAT'
		AND ServiceName = 'AmendmentNotiFB'
		
	SELECT @ConfigPRO = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'ConfigPRO'
		AND ServiceName = 'AmendmentNotiFB'
		
	SELECT @ServiceFlag = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'ServiceFlag'
		AND ServiceName = 'AmendmentNotiFB'
		
	SELECT @LastRuntime = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'LastRuntime'
		AND ServiceName = 'AmendmentNotiFB'
		
	SELECT @LastSubmitDate = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'LastSubmitDate'
		AND ServiceName = 'AmendmentNotiFB'
	
	SELECT @IsCredit = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'IsCredit'
		AND ServiceName = 'AmendmentNotiFB'
		
	SELECT @IsDeposit = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'IsDeposit'
		AND ServiceName = 'AmendmentNotiFB'	
	
	SELECT @BatchSizeTicket = value 
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'BatchSizeTicket'
		AND ServiceName = 'AmendmentNotiFB'	

	SELECT @JobStatusUAT = value 
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'JobStatusUAT'
		AND ServiceName = 'AmendmentNotiFB'
		
	SELECT @LastRuntimeUAT = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'LastRuntimeUAT'
		AND ServiceName = 'AmendmentNotiFB'
		
	SELECT @LastSubmitDateUAT = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'LastSubmitDateUAT'
		AND ServiceName = 'AmendmentNotiFB'	

	SELECT @LastSeq = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'LastSeq'
		AND ServiceName = 'AmendmentNotiFB'	
		
	SELECT @LastSeqUAT = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'LastSeqUAT'
		AND ServiceName = 'AmendmentNotiFB'					
		
	SELECT @JobStatus as JobStatus, 
		@BatchSize as BatchSize, 
		@ConfigUAT as ConfigUAT,
		@ConfigPRO as ConfigPRO,
		@ServiceFlag as ServiceFlag,
		@LastRuntime as LastRuntime,
		@LastSubmitDate as LastSubmitDate,
		@IsCredit as IsCredit,
		@IsDeposit as IsDeposit,
		@BatchSizeTicket as BatchSizeTicket,
		@JobStatusUAT as JobStatusUAT,
		@LastRuntimeUAT as LastRuntimeUAT,
		@LastSubmitDateUAT as LastSubmitDateUAT,
		@LastSeq as LastSeq,
		@LastSeqUAT as LastSeqUAT
END