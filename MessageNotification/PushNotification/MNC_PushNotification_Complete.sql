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
		,@LogUserID INT
		,@LogActionID SMALLINT
	
	SELECT @LogUserID = TRY_CONVERT(INT, VValue)
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 2 --ID of StarixIT
	
	SELECT @LogActionID = ActionID
	FROM LogAction WITH (NOLOCK)
	WHERE ActName = ISNULL(OBJECT_NAME(@@PROCID),'Unknown')
	
	INSERT INTO UserLog (
		ActionID
		,UserID
		,LogBef
	)
	SELECT @LogActionID
		,@LogUserID
		,COMPRESS(N'Info - Start [Push Notification Msg process - Completed]'
			+ '- @ErrCode(' + ISNULL(CONVERT(VARCHAR,@ErrCode),'NULL') + ')'
			+ '- @ErrMsg(' + ISNULL(@ErrMsg,'NULL') + ')')
	
	IF @ErrCode <> 0
	BEGIN
		INSERT INTO UserLog (
			ActionID
			,UserID
			,LogBef
		)
		SELECT @LogActionID
			,@LogUserID
			,COMPRESS(N'Error - [Push Notification Msg process - Completed]'
				+ ' - @ErrCode(' + ISNULL(CONVERT(VARCHAR,@ErrCode),'NULL') + ')'
				+ ' - @ErrMsg(' + ISNULL(@ErrMsg,'NULL') + ')')
	END
	
	UPDATE SystemSetting WITH (ROWLOCK,UPDLOCK)
	SET VValue = 'Done'
	WHERE VID = @ProcessID
		AND VValue = 'Running'
	
	INSERT INTO UserLog (
		ActionID
		,UserID
		,LogBef
	)
	SELECT @LogActionID
		,@LogUserID
		,COMPRESS(N'Info - Completed [Push Notification Msg process - Completed] - change ProcessID(' + ISNULL(CONVERT(VARCHAR,@ProcessID),'NULL') + ') to [' + ISNULL(VValue,'NULL') + ']') AS LogBef
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = @ProcessID
END
