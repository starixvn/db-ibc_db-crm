/*<info serverAlias="DBCRM-MessageNotification" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE MNC_SettlResultHist_Initial
	@Environment VARCHAR(20)
AS
/*
	Created: 20231213@Roy
	Task: Initial load setting
	DB: DBCRM.MessageNotification
	Revisions:
		20231121@Roy: CRM - Implement Message Notifications Center for Result Amendment of Cricket(#197621)
	
	Explanation:
		@Environment
			If IncludeTestMatch = ON
			  + @Environment = LIVE => handle all data
			  + @Environment = UAT => return
			If IncludeTestMatch = OFF
			  + @Environment = LIVE => handle REAL data
			  + @Environment = UAT => handle TEST data
		
		Steps
			- Based on @Environment => turn on PRD / UAT.. service
			- Based on SiteDBConfig => define how many SiteDB need to pull data
			- Based on SystemSetting.ScanBackHour => define timepoint to pull data from SiteDBs
	
	Example:
		EXEC MessageNotification.dbo.MNC_SettlResultHist_Initial
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @FDTime DATETIME
		,@LogUserID INT
		,@LogActionID SMALLINT
		,@ProcessID INT
		,@ScanBackHour INT
		,@PRODIncludeTest BIT = 0
		,@ErrLogPrefix NVARCHAR(150) = ''
		,@InfLogPrefix NVARCHAR(150) = ''
	
	/*
		Load setting
	*/	
	SELECT @LogUserID = TRY_CONVERT(INT, VValue)
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 2 --ID of StarixIT
	
	--Insert if NOT EXISTS
	INSERT INTO LogAction (ActName)
	SELECT o.[name]
	FROM sys.objects AS o WITH (NOLOCK)
	WHERE o.[is_ms_shipped] = 0 --created by user
		AND o.[type] IN (
			'P', -- stored procedures
			'FN', -- scalar functions 
			'IF', -- inline table-valued functions
			'TF' -- table-valued functions
		)
		AND o.[name] NOT LIKE '_delete%'
		AND o.[name] NOT LIKE '[_delete%'
		AND o.[name] NOT LIKE '_DEL%'
		AND NOT EXISTS (
			SELECT 1
			FROM LogAction AS a
			WHERE a.ActName = o.[name]
		)
	
	SELECT @LogActionID = ActionID
	FROM LogAction WITH (NOLOCK)
	WHERE ActName = ISNULL(OBJECT_NAME(@@PROCID),'Unknown')
	
	SELECT @ScanBackHour = TRY_CONVERT(INT, VValue)
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 1 --ScanBackHour
	
	SELECT @PRODIncludeTest = VValue
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 10 --IncludeTestMatch
	
	IF @Environment = 'LIVE'
	BEGIN
		SELECT @ProcessID = 4 --CaptureDataService
		SELECT @ErrLogPrefix = 'Error - [CaptureDataService - Initial] - '
		SELECT @InfLogPrefix = 'Info - [CaptureDataService - Initial] - '
	END
	ELSE
	BEGIN
		SELECT @ProcessID = 7 --UAT_CaptureDataService
		SELECT @ErrLogPrefix = 'Error - [UAT_CaptureDataService - Initial] - '
		SELECT @InfLogPrefix = 'Info - [UAT_CaptureDataService - Initial] - '
		
		SELECT @Environment = ISNULL(@Environment,'UAT')
	END
	
	
	IF @PRODIncludeTest = 1 AND @Environment = 'UAT'
	BEGIN
		SELECT NULL AS Environment
			,NULL AS FDTime
			,NULL AS SiteDBGroupID
			,NULL AS LinkedServerName
			,NULL AS AGIP
		WHERE 1 = 0
			
		INSERT INTO UserLog (
			ActionID
			,UserID
			,LogBef
		)
		SELECT @LogActionID
			,@LogUserID
			,COMPRESS(@ErrLogPrefix + 'NO Action for IncludeTestMatch = ON AND Environment = UAT')
		
		RETURN
	END
	
	--define [FDTime] as timepoint to pull data from SiteDBs
	SET @FDTime = DATEADD(HH, - ISNULL(@ScanBackHour, 24) , GETDATE())
	
	--return for web
	SELECT @Environment AS Environment
		,CONVERT(VARCHAR, @FDTime, 120) AS FDTime
		,sc.SiteDBGroupID
		,sc.LinkedServerName
		,sc.AGIP
	FROM bodb02.dbo.SiteDBConfig AS sc WITH (NOLOCK)
	WHERE SiteDBGroupID <> 0
	
	--write log
	;WITH CTE_Log AS (
		SELECT CONVERT(NVARCHAR(MAX),(
					SELECT @Environment AS Environment
						,CONVERT(VARCHAR, @FDTime, 120) AS FDTime
						,sc.SiteDBGroupID
						,sc.LinkedServerName
						,sc.AGIP
					FROM bodb02.dbo.SiteDBConfig AS sc WITH (NOLOCK)
					WHERE SiteDBGroupID <> 0
					FOR JSON AUTO
				)) AS LTxt
	)
	INSERT INTO UserLog (
		ActionID
		,UserID
		,LogBef
	)
	SELECT @LogActionID
		,@LogUserID
		,COMPRESS(@InfLogPrefix + 'Completed - Return(' +  LTxt + ')') AS LogBef
	FROM CTE_Log
	
	/*
		Handle LastRunTime
	*/
	IF @Environment = 'LIVE'
	BEGIN
		UPDATE SystemSetting WITH (ROWLOCK,UPDLOCK)
		SET VValue = CONVERT(VARCHAR, GETDATE(), 120)
		WHERE VID = 18 --LastRunTime
	END
	ELSE
	BEGIN
		UPDATE SystemSetting WITH (ROWLOCK,UPDLOCK)
		SET VValue = CONVERT(VARCHAR, GETDATE(), 120)
		WHERE VID = 20 --UAT_LastRunTime
	END
	
	INSERT INTO UserLog (
		ActionID
		,UserID
		,LogBef
	)
	SELECT @LogActionID
		,@LogUserID
		,COMPRESS(@InfLogPrefix + 'Debug - UPDATE SystemSetting.LastRunTime(' + ISNULL(CONVERT(VARCHAR, GETDATE()),'NULL') + ')')
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 13 --LogMode
		AND VValue = 'Debug'
END
