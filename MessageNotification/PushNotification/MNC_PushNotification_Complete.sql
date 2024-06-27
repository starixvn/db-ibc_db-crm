/*<info serverAlias="DBCRM-MessageNotification" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE MNC_PushNotification_Complete
	@Environment VARCHAR(20)
	,@ErrCode INT = 0 OUTPUT
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
	
	DECLARE @ProcessID INT
		,@LogUserID INT
		,@LogActionID SMALLINT
		,@ErrLogPrefix NVARCHAR(150)
		,@InfLogPrefix NVARCHAR(150)
	
	SELECT @LogUserID = TRY_CONVERT(INT, VValue)
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 2 --ID of StarixIT
	
	SELECT @LogActionID = ActionID
	FROM LogAction WITH (NOLOCK)
	WHERE ActName = ISNULL(OBJECT_NAME(@@PROCID),'Unknown')
	
	IF @Environment = 'LIVE'
	BEGIN
		SELECT @ProcessID = 6 --InsertNotifService
		SELECT @ErrLogPrefix = 'Error - [InsertNotifService - Complete] - '
		SELECT @InfLogPrefix = 'Info - [InsertNotifService - Complete] - '
	END
	ELSE
	BEGIN
		SELECT @ProcessID = 12 --UAT_InsertNotifService
		SELECT @ErrLogPrefix = 'Error - [UAT_InsertNotifService - Complete] - '
		SELECT @InfLogPrefix = 'Info - [UAT_InsertNotifService - Complete] - '
		
		SELECT @Environment = ISNULL(@Environment,'UAT')
	END
	
	INSERT INTO UserLog (
		ActionID
		,UserID
		,LogBef
	)
	SELECT @LogActionID
		,@LogUserID
		,COMPRESS((CASE WHEN @ErrCode <> 0 THEN @ErrLogPrefix ELSE @InfLogPrefix END) + '@ErrCode(' + ISNULL(CONVERT(VARCHAR,@ErrCode),'NULL') + ')' + '- @ErrMsg(' + ISNULL(@ErrMsg,'NULL') + ')')
	
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
		,COMPRESS(@InfLogPrefix + 'Change ProcessID(' + ISNULL(CONVERT(VARCHAR,@ProcessID),'NULL') + ') to [' + ISNULL(VValue,'NULL') + ']') AS LogBef
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = @ProcessID
END
