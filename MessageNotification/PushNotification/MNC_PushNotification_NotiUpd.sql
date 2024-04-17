/*<info serverAlias="DBCRM-MessageNotification" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE MNC_PushNotification_NotiUpd
	@NotificationID INT
	,@MessageID INT
	,@UpdType VARCHAR(50) = 'AfterInsMsg'
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(2000) = '' OUTPUT
AS
/*
	Created: 20231213@Roy
	Task: update Notification staus
	DB: DBCRM.MessageNotification
	Revisions:
		20231121@Roy: CRM - Implement Message Notifications Center for Result Amendment of Cricket(#197621)
	
	Explanation:
		@MessageID: respond after insert DBMSG@Msg
		@ErrCode: respond @ErrCode from MNC_PushNotification_MsgIns
		@ErrMsg: respond @ErrMsg from MNC_PushNotification_MsgIns
	
	Example:
		EXEC MessageNotification.dbo.MNC_PushNotification_NotiUpd
			@NotificationID = 1
			,@MessageID = 1
			,@ErrCode = @ErrC OUTPUT
			,@ErrMsg = @ErrM OUTPUT
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @LogUserID INT
		,@LogActionID SMALLINT
		,@StsFailedSend TINYINT
		,@StsSucceedSend TINYINT
		,@StsSending TINYINT
		,@ErrLogPrefix NVARCHAR(150) = ''
		,@InfLogPrefix NVARCHAR(150) = ''
	
	/*
		Load setting
	*/
	SELECT @LogUserID = TRY_CONVERT(INT, VValue)
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 2 --ID of StarixIT
	
	SELECT @StsFailedSend = StatusID
	FROM NotiStatus WITH (NOLOCK)
	WHERE Status = 'Failed to Send'
	
	SELECT @StsSucceedSend = StatusID
	FROM NotiStatus WITH (NOLOCK)
	WHERE Status = 'Sent'
	
	SELECT @StsSending = StatusID
	FROM NotiStatus WITH (NOLOCK)
	WHERE Status = 'Sending'
	
	SELECT @LogActionID = ActionID
	FROM LogAction WITH (NOLOCK)
	WHERE ActName = ISNULL(OBJECT_NAME(@@PROCID),'Unknown')
	
	SELECT @ErrLogPrefix = 'Error - '
	SELECT @InfLogPrefix = 'Info - '
	
	INSERT INTO [Log] (
		RefID
		,ActionID
		,UserID
		,LogBef
	)
	SELECT @NotificationID AS RefID
		,@LogActionID
		,@LogUserID
		,@InfLogPrefix + 'Debug log for [Push Notification] - UPD RefID with @NotificationID(' + ISNULL(CONVERT(VARCHAR,@NotificationID),'NULL') + ')'
						+', @MessageID(' + ISNULL(CONVERT(VARCHAR,@MessageID),'NULL') + ')'
						+', @UpdType(' + ISNULL(@UpdType,'NULL') + ')'
						+', @ErrCode(' + ISNULL(CONVERT(VARCHAR,@ErrCode),'NULL') + ')'
						+', @ErrMsg(' + ISNULL(@ErrMsg,'NULL') + ')'
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 13 --LogMode
		AND VValue = 'Debug'
	
	CREATE TABLE #tmpNoti (
		NotificationID INT NOT NULL
		,StatusID TINYINT NOT NULL
	)
	
	----------------return error from MNC_PushNotification_MsgIns----------------------------------------
	IF @ErrCode <> 0
	BEGIN
		INSERT INTO [Log] (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT @NotificationID
			,@LogActionID
			,@LogUserID
			,@ErrLogPrefix + 'Error from MNC_PushNotification_MsgIns - @NotificationID = '+ ISNULL(CONVERT(VARCHAR, @NotificationID),'NULL')
				+ ', @MessageID = ' + ISNULL(CONVERT(VARCHAR, @MessageID),'NULL')
				+ ', @UpdType = ' + ISNULL(@UpdType,'NULL')
				+ ', ErrCode = ' + ISNULL(CONVERT(VARCHAR, @ErrCode),'NULL')
				+ ', ErrMsg = ' + ISNULL(@ErrMsg,'NULL')
	END
	
	IF @UpdType = 'AfterInsMsg'
	BEGIN TRY
		BEGIN TRANSACTION
		
		UPDATE n
		SET n.StatusID = (CASE WHEN @ErrCode = 0 AND @MessageID IS NOT NULL THEN @StsSucceedSend ELSE @StsFailedSend END)
			,n.RefID = (CASE WHEN @ErrCode = 0 AND @MessageID IS NOT NULL THEN @MessageID ELSE NULL END)
			,n.LastModifiedTime = GETDATE()
		OUTPUT INSERTED.NotificationID
			,INSERTED.StatusID
		INTO #tmpNoti (
			NotificationID
			,StatusID
		) --Get Updated NotificationID
		FROM Notification AS n WITH (ROWLOCK,UPDLOCK)
		WHERE n.StatusID = @StsSending --Sending
			AND n.NotificationType = 1 --Result Amendment to Msg
			AND n.NotificationID = @NotificationID
		
		INSERT INTO [Log] (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT NotificationID
			,@LogActionID
			,@LogUserID
			,@InfLogPrefix + 'Changed Notification Status from [Sending] to ['+ (CASE WHEN StatusID = @StsSucceedSend THEN 'Sent' ELSE 'Failed to Send' END) +']'
							+ ' - @MessageID(' + ISNULL(CONVERT(VARCHAR,@MessageID),'NULL') + ')'
		FROM #tmpNoti
		ORDER BY NotificationID
		
		UPDATE nt
		SET nt.StatusID = n.StatusID
		FROM NotificationTarget AS nt WITH (ROWLOCK,UPDLOCK)
			INNER JOIN #tmpNoti AS n ON nt.NotificationID = n.NotificationID
		
		COMMIT TRANSACTION
		
		/*
			at this state, ErrCode from MNC_PushNotification_MsgIns is handled
			=> reset @ErrCode
		*/
		SELECT @ErrCode = 0
			,@ErrMsg = ''
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR --output for web
			,@ErrMsg = ERROR_MESSAGE() --output for web
		
		ROLLBACK TRANSACTION
	END CATCH
	
	--------------check Error in this SP----------------
	IF NOT EXISTS (SELECT 1 FROM #tmpNoti)
	BEGIN
		IF @ErrCode = 0
		BEGIN
			SELECT @ErrCode = 50003 --user-defined
				,@ErrMsg = 'NO affected Notification with param @NotificationID = '+ ISNULL(CONVERT(VARCHAR, @NotificationID),'NULL')
							+ ', @MessageID = ' + ISNULL(CONVERT(VARCHAR, @MessageID),'NULL')
							+ ', @UpdType = ' + ISNULL(@UpdType,'NULL')
							+ ', ErrCode = ' + ISNULL(CONVERT(VARCHAR, @ErrCode),'NULL')
							+ ', ErrMsg = ' + ISNULL(@ErrMsg,'NULL')
		END
		
		INSERT INTO [Log] (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT @NotificationID
			,@LogActionID
			,@LogUserID
			,@ErrLogPrefix + 'NO affected Notification with param @NotificationID = '+ ISNULL(CONVERT(VARCHAR, @NotificationID),'NULL')
				+ ', @MessageID = ' + ISNULL(CONVERT(VARCHAR, @MessageID),'NULL')
				+ ', @UpdType = ' + ISNULL(@UpdType,'NULL')
				+ ', ErrCode = ' + ISNULL(CONVERT(VARCHAR, @ErrCode),'NULL')
				+ ', ErrMsg = ' + ISNULL(@ErrMsg,'NULL')
	END
	DROP TABLE IF EXISTS #tmpNoti
END
