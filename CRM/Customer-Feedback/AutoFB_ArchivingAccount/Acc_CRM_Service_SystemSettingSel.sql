/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_Service_SystemSettingSel] 
	@ServiceName varchar(100)
AS
/*
	Created: Winfred
	Task : CRM -Auto-generated FB to Headline for Archiving Dormant Accounts
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20221121@Winfred: CRM -Auto-generated FB to Headline for Archiving Dormant Accounts [redmine:#158258]
		- 20230131@Winfred: Scale Out for CRM [RedmineId : #181906]
	
	Parameter's Explanation:
		@ServiceName : 'ArchivedAccountFB'
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @JobStatus 	VARCHAR(50),
			@BatchSize 	INT,
			@BatchSizeAccount 	INT,		
			@IsSyncArchivedAccount 	BIT,			
			@ConfigUAT 	BIT,
			@ConfigPRO 	BIT,
			@IsCredit 	BIT,
			@IsDeposit 	BIT ,
			@JobStatusUAT 	VARCHAR(50),
			@LastRuntime DATETIME,
			@LastRuntimeUAT DATETIME,
			@ServiceFlag BIT,
			@ServiceID 	INT,
			@MaxLogFBId INT ,
			@MaxVoidingHistoryCollectionId INT ,
			@MaxVoidingHistoryCollectionIdUAT INT 
			
	SELECT @JobStatus = value 
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'JobStatus'
		AND ServiceName = @ServiceName
	
	SELECT @BatchSize = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'BatchSize'
		AND ServiceName = @ServiceName
		
	SELECT @ConfigUAT = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'ConfigUAT'
		AND ServiceName = @ServiceName
		
	SELECT @ConfigPRO = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'ConfigPRO'
		AND ServiceName = @ServiceName
		
	SELECT @ServiceFlag = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'ServiceFlag'
		AND ServiceName = @ServiceName
		
	SELECT @LastRuntime = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'LastRuntime'
		AND ServiceName = @ServiceName
		
	SELECT @BatchSizeAccount = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'BatchSizeAccount'
		AND ServiceName = @ServiceName
	
	SELECT @IsCredit = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'IsCredit'
		AND ServiceName = @ServiceName
		
	SELECT @IsDeposit = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'IsDeposit'
		AND ServiceName = @ServiceName	
	
	SELECT @IsSyncArchivedAccount = value 
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'IsSyncArchivedAccount'
		AND ServiceName = @ServiceName	

	SELECT @JobStatusUAT = value 
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'JobStatusUAT'
		AND ServiceName = @ServiceName
		
	SELECT @LastRuntimeUAT = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'LastRuntimeUAT'
		AND ServiceName = @ServiceName
		
	SELECT @ServiceID = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'ServiceID'
		AND ServiceName = @ServiceName	

	SELECT @MaxLogFBId = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'MaxLogFBId'
		AND ServiceName = @ServiceName	
	
	SELECT @MaxVoidingHistoryCollectionId = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'MaxVoidingHistoryCollectionId'
		AND ServiceName = @ServiceName	
	
	SELECT @MaxVoidingHistoryCollectionIdUAT = value
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'MaxVoidingHistoryCollectionIdUAT'
		AND ServiceName = @ServiceName					
		
	SELECT @JobStatus as JobStatus, 
		@BatchSize as BatchSize, 
		@ConfigUAT as ConfigUAT,
		@ConfigPRO as ConfigPRO,
		@ServiceFlag as ServiceFlag,
		@LastRuntime as LastRuntime,
		@BatchSizeAccount as BatchSizeAccount,
		@IsCredit as IsCredit,
		@IsDeposit as IsDeposit,
		@IsSyncArchivedAccount as IsSyncArchivedAccount,
		@JobStatusUAT as JobStatusUAT,
		@LastRuntimeUAT as LastRuntimeUAT,
		@ServiceID as ServiceID,
		@MaxLogFBId as MaxLogFBId,
		@MaxVoidingHistoryCollectionId AS MaxVoidingHistoryCollectionId,
		@MaxVoidingHistoryCollectionIdUAT AS MaxVoidingHistoryCollectionIdUAT
END	