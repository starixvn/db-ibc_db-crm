/*<info serverAlias="DBMSG-bodb_Message" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE MNC_PushNotification_MsgUpd
	@MessageID INT
	,@UpdType VARCHAR(50) = 'AfterUpdNoti'
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(2000) = '' OUTPUT
AS
/*
	Created: 20231213@Roy
	Task: update Msg/MsgTarget after update Noti.MessageID from respone
	DB: DBMSG.bodb_Message
	Revisions:
		20231121@Roy: CRM - Implement Message Notifications Center for Result Amendment of Cricket(#197621)
	
	Explanation:
		@ErrCode: respone @ErrCode from MNC_PushNotification_NotiUpd with @UpdType = 'AfterInsMsg'
		@ErrMsg: respone @ErrMsg from MNC_PushNotification_NotiUpd  with @UpdType = 'AfterInsMsg'
	
	Example:
		EXEC bodb_Message.dbo.MNC_PushNotification_MsgUpd
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @iErrCode INT = @ErrCode
		,@iErrMsg NVARCHAR(2000) = @ErrMsg
	
	CREATE TABLE #tmpUpdMsg (
		MessageID INT NOT NULL
	)
	----------------Error from MNC_PushNotification_NotiUpd----------------------------------------
	IF @ErrCode <> 0
	BEGIN TRY
		---DELETE Msg
		DELETE FROM dbo.Msg
		OUTPUT DELETED.MessageID
		INTO #tmpUpdMsg (
			MessageID
		) --Get Updated MessageID
		WHERE MessageId = @MessageID
			AND Remark LIKE 'MNC%'
		---DELETE MsgTarget
		
		DELETE mt
		FROM dbo.MsgTarget AS mt
			INNER JOIN #tmpUpdMsg AS d ON d.MessageId = mt.MessageId
		
		/*
			at this state, ErrCode from MNC_PushNotification_NotiUpd is handled
			=> reset @ErrCode
		*/
		SELECT @ErrCode = 0
			,@ErrMsg = ''
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR --output for web
			,@ErrMsg = 'Error - [Push Notification Msg process - MsgUpd] - FAILED to DELETE MessageID due to ERROR from NotiUpd'
						+ ' - @MessageID(' + ISNULL(CONVERT(VARCHAR,@MessageID),'NULL') + ')'
						+ ' - @UpdType(' + ISNULL(@UpdType,'NULL') + ')'
						+ ' - @ErrCode(' + ISNULL(CONVERT(VARCHAR,@iErrCode),'NULL') + ')'
						+ ' - @ErrMsg(' + ISNULL(@iErrMsg,'NULL') + ')'
						+ ' - ERROR_MESSAGE(' + ISNULL(ERROR_MESSAGE(),'NULL') + ')' --output for web
		ROLLBACK TRANSACTION
	END CATCH
	ELSE IF @UpdType = 'AfterUpdNoti'
	BEGIN TRY
		BEGIN TRANSACTION
		
		UPDATE m
		SET m.IsTest = 0
			,m.isDeleted = 0
			,m.LastUpdateTime = GETDATE()
		OUTPUT INSERTED.MessageID
		INTO #tmpUpdMsg (
			MessageID
		) --Get Updated MessageID
		FROM dbo.Msg AS m WITH (ROWLOCK,UPDLOCK)
		WHERE m.MessageID = @MessageID
			AND m.Remark LIKE 'MNC%'
		
		UPDATE t
		SET t.isDeleted = 0
		FROM dbo.MsgTarget AS t WITH (ROWLOCK,UPDLOCK)
			INNER JOIN #tmpUpdMsg AS m ON t.MessageID = m.MessageID
		
		COMMIT TRANSACTION
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR --output for web
			,@ErrMsg = 'Error - [Push Notification Msg process - MsgUpd] - FAILED to mark MessageID completed'
						+ ' - @MessageID(' + ISNULL(CONVERT(VARCHAR,@MessageID),'NULL') + ')'
						+ ' - @UpdType(' + ISNULL(@UpdType,'NULL') + ')'
						+ ' - @ErrCode(' + ISNULL(CONVERT(VARCHAR,@iErrCode),'NULL') + ')'
						+ ' - @ErrMsg(' + ISNULL(@iErrMsg,'NULL') + ')'
						+ ' - ERROR_MESSAGE(' + ISNULL(ERROR_MESSAGE(),'NULL') + ')' --output for web
		ROLLBACK TRANSACTION
	END CATCH
	
	------------------------------
	IF NOT EXISTS (SELECT 1 FROM #tmpUpdMsg)
		AND @ErrCode = 0
	BEGIN
		SELECT @ErrCode = 50004
			,@ErrMsg = '[Push Notification Msg process - MsgUpd] - NO affected Msg/MsgTarget'
						+ ' - @MessageID(' + ISNULL(CONVERT(VARCHAR,@MessageID),'NULL') + ')'
						+ ' - @UpdType(' + ISNULL(@UpdType,'NULL') + ')'
	END
	
	DROP TABLE #tmpUpdMsg
END