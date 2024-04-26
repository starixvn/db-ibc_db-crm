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
			If UATMode = OFF
			  + @Environment = LIVE => handle all data
			  + @Environment = UAT => return
			If UATMode = ON
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
		,@UATMode VARCHAR(5) = 'OFF'
		,@ErrLogPrefix NVARCHAR(150) = ''
		,@InfLogPrefix NVARCHAR(150) = ''
	
	/*
		Load setting
	*/	
	SELECT @LogUserID = TRY_CONVERT(INT, VValue)
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 2 --ID of StarixIT
	
	SELECT @ProcessID = (
		CASE WHEN @Environment = 'LIVE' THEN 4 --Process_CaptureData
			ELSE 7 END --ProcessUAT_CaptureData
	)
	
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
	
	SELECT @UATMode = VValue
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 10 --UATMode
	
	SELECT @ErrLogPrefix = 'Error - ' + ISNULL(@Environment,'Environment NULL') + ' - '
	SELECT @InfLogPrefix = 'Info - ' + ISNULL(@Environment,'Environment NULL') + ' - '
	SELECT @Environment = ISNULL(@Environment,'UAT')
	
	
	IF @UATMode = 'OFF' AND @Environment = 'UAT' --no action (RETURN)
	BEGIN
		SELECT NULL AS Environment
			,NULL AS FDTime
			,NULL AS SiteDBGroupID
			,NULL AS LinkedServerName
			,NULL AS AGIP
		WHERE 1 = 0
			
		INSERT INTO [Log] (
			LogTime
			,ActionID
			,UserID
			,LogBef
		)
		SELECT GETDATE() AS LogTime
			,@LogActionID
			,@LogUserID
			,@InfLogPrefix + '[Capture process - Initial] - NO Action for UATMode = OFF AND Environment = UAT'
		
		RETURN
	END
	
	--check current status of Capture process
	IF NOT EXISTS (SELECT 1 FROM SystemSetting WHERE VID = @ProcessID AND VValue = 'Done') --ProcessStatus_CaptureData
	BEGIN
		SELECT NULL AS Environment
			,NULL AS FDTime
			,NULL AS SiteDBGroupID
			,NULL AS LinkedServerName
			,NULL AS AGIP
		WHERE 1 = 0
		
		INSERT INTO [Log] (
			LogTime
			,ActionID
			,UserID
			,LogBef
		)
		SELECT GETDATE() AS LogTime
			,@LogActionID
			,@LogUserID
			,@ErrLogPrefix + 'Another [Capture process] - Process(' + ISNULL(CONVERT(VARCHAR,@ProcessID),'NULL') + ') is still active.'
		
		RETURN
	END
	
	--Start [Capture process]
	UPDATE SystemSetting WITH (ROWLOCK,UPDLOCK)
	SET VValue = 'Running'
	WHERE VID = @ProcessID
		AND VValue = 'Done'
	
	INSERT INTO [Log] (
		ActionID
		,UserID
		,LogBef
	)
	SELECT @LogActionID
		,@LogUserID
		,@InfLogPrefix + 'Start [Capture process - Initial] - change ProcessID(' + ISNULL(CONVERT(VARCHAR,@ProcessID),'NULL') + ') to [' + ISNULL(VValue,'NULL') + ']' AS LogBef
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = @ProcessID
	
	--define [FDTime] as timepoint to pull data from SiteDBs
	SET @FDTime = DATEADD(HH, -ISNULL(@ScanBackHour,0) , GETDATE())
	
	--return for web
	SELECT @Environment AS Environment
		,CONVERT(VARCHAR, @FDTime, 120) AS FDTime
		,sc.SiteDBGroupID
		,sc.LinkedServerName
		,sc.AGIP
	FROM bodb02.dbo.SiteDBConfig AS sc WITH (NOLOCK)
	WHERE SiteDBGroupID <> 0
	
	--write more info both PROD/UAT if LogMode = Debug
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
	INSERT INTO [Log] (
		ActionID
		,UserID
		,LogBef
	)
	SELECT @LogActionID
		,@LogUserID
		,@InfLogPrefix + 'Debug - Start [Capture process - Initial] to capture Settlement ResultHistory (' +  LTxt + ')' AS LogBef
	FROM CTE_Log
	WHERE EXISTS (
		SELECT 1
		FROM SystemSetting WITH (NOLOCK)
		WHERE VID = 13 --LogMode
			AND VValue = 'Debug'
	)
END
