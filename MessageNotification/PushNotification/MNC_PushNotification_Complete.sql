/*<info serverAlias="DBCRM-MessageNotification" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE MNC_PushNotification_Complete
	@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(2000) = '' OUTPUT
AS
/*
	Created: 20231213@Roy
	Task: complete Push Notification process
	DB: DBCRM.MessageNotification
	Revisions:
		20231121@Roy: CRM - Implement Message Notifications Center for Result Amendment of Cricket(#197621)
	
	Explanation:
	
	Example:
		EXEC MessageNotification.dbo.MNC_PushNotification_Complete
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @ProcessID INT = 6 --Process_PushNoti
		,@SuccessFlag INT = -1
	
	INSERT INTO [Log] (
		ActionID
		,UserID
		,LogBef
	)
	SELECT (SELECT ActionID FROM LogAction WITH (NOLOCK) WHERE ActName = ISNULL(OBJECT_NAME(@@PROCID),'Unknown')) AS ActionID
		,(SELECT TRY_CONVERT(INT, VValue) FROM SystemSetting WITH (NOLOCK) WHERE VID = 2) AS UserID --ID of StarixIT
		,'Info - Debug log for [Push Notification] - Complete with @ProcessID(' + ISNULL(CONVERT(VARCHAR,@ProcessID),'NULL') + ')'
						+', Current Value(' + ISNULL((SELECT VValue FROM SystemSetting WITH (NOLOCK) WHERE VID = @ProcessID),'NULL') + ')'
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 13 --LogMode
		AND VValue = 'Debug'
	
	--only update if 'Running'
	IF EXISTS (SELECT 1 FROM SystemSetting WITH (NOLOCK) WHERE VID = @ProcessID AND VValue = 'Running')
	BEGIN TRY
		UPDATE SystemSetting WITH (ROWLOCK,UPDLOCK)
		SET VValue = 'Done'
		WHERE VID = @ProcessID
			AND VValue = 'Running'
		
		SELECT @SuccessFlag = @@ROWCOUNT
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR --output for web
			,@ErrMsg = ERROR_MESSAGE() --output for web
		
		SET @SuccessFlag = 0
	END CATCH
	
	INSERT INTO [Log] (
		ActionID
		,UserID
		,LogBef
	)
	SELECT (SELECT ActionID FROM LogAction WITH (NOLOCK) WHERE ActName = ISNULL(OBJECT_NAME(@@PROCID),'Unknown')) AS ActionID
		,(SELECT TRY_CONVERT(INT, VValue) FROM SystemSetting WITH (NOLOCK) WHERE VID = 2) AS UserID --ID of StarixIT
		,'Error - FAILED UPD [Push Notification] Process with @ProcessID(' + ISNULL(CONVERT(VARCHAR,@ProcessID),'NULL') + ') to DONE'
			+ ISNULL(' - @ErrCode (' + CONVERT(VARCHAR,@ErrCode) + ')','')
			+ ISNULL(' - @ErrMsg (' + @ErrMsg + ')','')
	WHERE @SuccessFlag = 0
END
