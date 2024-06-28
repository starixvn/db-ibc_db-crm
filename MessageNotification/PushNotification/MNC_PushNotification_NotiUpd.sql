/*<info serverAlias="DBCRM-MessageNotification" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE MNC_PushNotification_NotiUpd
	@Environment VARCHAR(20)
	,@NotificationID INT
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
		,@PRODIncludeTest BIT
		,@IsTestFlag BIT
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
	
	SELECT @PRODIncludeTest = VValue
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 10 --IncludeTestMatch
	
	IF @Environment = 'LIVE'
	BEGIN
		SELECT @ErrLogPrefix = 'Error - [InsertNotifService - Prepare] - '
		SELECT @InfLogPrefix = 'Info - [InsertNotifService - Prepare] - '
	END
	ELSE
	BEGIN
		SELECT @ErrLogPrefix = 'Error - [UAT_InsertNotifService - Prepare] - '
		SELECT @InfLogPrefix = 'Info - [UAT_InsertNotifService - Prepare] - '
		
		SELECT @Environment = ISNULL(@Environment,'UAT')
	END
	
	/*
		Filter data by IncludeTestMatch
			If IncludeTestMatch = ON
			  + @Environment = LIVE => handle all data
			  + @Environment = UAT => return
			If IncludeTestMatch = OFF
			  + @Environment = LIVE => handle REAL data
			  + @Environment = UAT => handle TEST data
	*/
	IF @PRODIncludeTest = 1 AND @Environment = 'UAT' --no action (RETURN)
	BEGIN
		SELECT @ErrCode = 50001 --user-defined error code
			,@ErrMsg = 'NO Action for IncludeTestMatch = ON AND Environment = UAT'
		
		INSERT INTO UserLog (
			ActionID
			,UserID
			,LogBef
		)
		SELECT @LogActionID
			,@LogUserID
			,COMPRESS(@InfLogPrefix + 'NO Action for IncludeTestMatch = ON AND Environment = UAT')
		
		RETURN
	END
	ELSE IF @PRODIncludeTest = 0 AND @Environment = 'LIVE' --REAL data only
	BEGIN
		SET @IsTestFlag = 0
	END
	ELSE IF @PRODIncludeTest = 0 AND @Environment = 'UAT' --TEST data only
	BEGIN
		SET @IsTestFlag = 1
	END
	ELSE --both REAL & TEST
	BEGIN
		SET @IsTestFlag = NULL
	END
	
	--write input log
	INSERT INTO UserLog (
		RefID
		,ActionID
		,UserID
		,LogBef
	)
	SELECT @NotificationID AS RefID
		,@LogActionID
		,@LogUserID
		,COMPRESS((CASE WHEN ISNULL(@ErrCode,0) <> 0 THEN @InfLogPrefix + 'Start NotiUpd' ELSE @ErrLogPrefix + 'FROM [MsgIns]' END)
					+' - @NotificationID(' + ISNULL(CONVERT(VARCHAR,@NotificationID),'NULL') + ')'
					+' - @MessageID(' + ISNULL(CONVERT(VARCHAR,@MessageID),'NULL') + ')'
					+' - @UpdType(' + ISNULL(@UpdType,'NULL') + ')'
					+' - @ErrCode(' + ISNULL(CONVERT(VARCHAR,@ErrCode),'NULL') + ')'
					+' - @ErrMsg(' + ISNULL(@ErrMsg,'NULL') + ')')
	
	CREATE TABLE #tmpUpdNoti (
		NotificationID INT NOT NULL
		,StatusID TINYINT NOT NULL
	)
	
	IF @UpdType = 'AfterInsMsg'
	BEGIN TRY
		BEGIN TRANSACTION
		
		UPDATE n
		SET n.StatusID = (CASE WHEN @ErrCode = 0 AND @MessageID IS NOT NULL THEN @StsSucceedSend ELSE @StsFailedSend END)
			,n.RefID = (CASE WHEN @ErrCode = 0 AND @MessageID IS NOT NULL THEN @MessageID ELSE n.RefID END)
			,n.LastModifiedTime = GETDATE()
		OUTPUT INSERTED.NotificationID
			,INSERTED.StatusID
		INTO #tmpUpdNoti (
			NotificationID
			,StatusID
		) --Get Updated NotificationID
		FROM Notification AS n WITH (ROWLOCK,UPDLOCK)
		WHERE n.StatusID = @StsSending --Sending
			AND n.NotificationType = 1 --Result Amendment to Msg
			AND n.NotificationID = @NotificationID
			AND (
				@IsTestFlag IS NULL
				OR EXISTS (
					SELECT 1
					FROM NotiMapping AS nm WITH (NOLOCK)
						INNER JOIN SettlementResultHist AS rh WITH (NOLOCK) ON nm.SettlementLogID = rh.SettlementLogID
					WHERE nm.NotificationID = @NotificationID
						AND rh.IsTest = @IsTestFlag
				)
			) --filter by Environment/IncludeTestMatch
		
		IF EXISTS (SELECT 1 FROM #tmpUpdNoti)
		BEGIN
			INSERT INTO UserLog (
				RefID
				,ActionID
				,UserID
				,LogBef
			)
			SELECT u.NotificationID
				,@LogActionID
				,@LogUserID
				,COMPRESS(@InfLogPrefix + 'Changed NotificationID Status from [Sending] to [' + s.Status + ']' 
								+ ' - @MessageID(' + ISNULL(CONVERT(VARCHAR,@MessageID),'NULL') + ')')
			FROM #tmpUpdNoti AS u
				INNER JOIN NotiStatus AS s WITH (NOLOCK) ON u.StatusID = s.StatusID
			ORDER BY u.NotificationID
			
			UPDATE nt
			SET nt.StatusID = n.StatusID
			FROM NotificationTarget AS nt WITH (ROWLOCK,UPDLOCK)
				INNER JOIN #tmpUpdNoti AS n ON nt.NotificationID = n.NotificationID
			
			/*
				at this state, ErrCode from MNC_PushNotification_MsgIns is handled
				=> reset @ErrCode
			*/
			SELECT @ErrCode = 0
				,@ErrMsg = ''
		END
		ELSE
		BEGIN
			INSERT INTO UserLog (
				RefID
				,ActionID
				,UserID
				,LogBef
			)
			SELECT @NotificationID
				,@LogActionID
				,@LogUserID
				,COMPRESS(@ErrLogPrefix + 'CAN NOT Change NotificationID Status'
							+ ' - Current StatusID(' + ISNULL(CONVERT(VARCHAR,(SELECT StatusID FROM Notification WITH(NOLOCK) WHERE NotificationID = @NotificationID)),'NULL') + ')'
							+ ' - Current SettlementResultHist.IsTest(' + ISNULL((
																		SELECT STRING_AGG(CONVERT(NVARCHAR(MAX),rh.IsTest),',')
																		FROM NotiMapping AS nm WITH (NOLOCK)
																			INNER JOIN SettlementResultHist AS rh WITH (NOLOCK) ON nm.SettlementLogID = rh.SettlementLogID
																		WHERE nm.NotificationID = @NotificationID
																	),'NULL') + ')'
							+ ' - @Environment(' + ISNULL(@Environment,'NULL') + ')'
							+ ' - IncludeTestMatch(' + ISNULL(CONVERT(VARCHAR,@PRODIncludeTest),'NULL') + ')'
							+ ' - @IsTestFlag(' + ISNULL(CONVERT(VARCHAR,@IsTestFlag),'both REAL & TEST') + ')'
				)
			
			SELECT @ErrCode = 50003 --user-defined
				,@ErrMsg = 'NO affected Notification'
		END
		
		COMMIT TRANSACTION
		
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR --output for web
			,@ErrMsg = 'FAILED while Updated NotificationID - ERROR_MESSAGE(' + ISNULL(ERROR_MESSAGE(),'NULL') + ')' --output for web
		
		ROLLBACK TRANSACTION
	END CATCH
	
	--------------check Error in this SP----------------
	IF @ErrCode = 0
		AND NOT EXISTS (SELECT 1 FROM #tmpUpdNoti)
	BEGIN
		SELECT @ErrCode = 50003 --user-defined
			,@ErrMsg = 'NO affected Notification'
	END
	
	INSERT INTO UserLog (
		RefID
		,ActionID
		,UserID
		,LogBef
	)
	SELECT @NotificationID
		,@LogActionID
		,@LogUserID
		,COMPRESS(@ErrLogPrefix + ISNULL(@ErrMsg,'NULL')
						+ ' - @NotificationID(' + ISNULL(CONVERT(VARCHAR,@NotificationID),'NULL') + ')'
						+ ' - @MessageID(' + ISNULL(CONVERT(VARCHAR,@MessageID),'NULL') + ')'
						+ ' - @UpdType(' + ISNULL(@UpdType,'NULL') + ')')
	WHERE @ErrCode <> 0
	
	DROP TABLE #tmpUpdNoti
END
