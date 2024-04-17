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
	
	CREATE TABLE #tmpMsg (
		MessageID INT NOT NULL
	)
	----------------Error from MNC_PushNotification_NotiUpd----------------------------------------
	IF @ErrCode <> 0
	BEGIN TRY
		---DELETE Msg
		DELETE FROM dbo.Msg
		OUTPUT DELETED.MessageID
		INTO #tmpMsg (
			MessageID
		) --Get Updated MessageID
		WHERE MessageId = @MessageID
			AND m.Remark LIKE 'MNC%'
		---DELETE MsgTarget
		
		DELETE mt
		FROM dbo.MsgTarget AS mt
			INNER JOIN #tmpMsg AS d ON d.MessageId = mt.MessageId
		
		/*
			at this state, ErrCode from MNC_PushNotification_NotiUpd is handled
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
	ELSE IF @UpdType = 'AfterUpdNoti'
	BEGIN TRY
		BEGIN TRANSACTION
		
		UPDATE m
		SET m.IsTest = 0
			,m.isDeleted = 0
			,m.LastUpdateTime = GETDATE()
		OUTPUT INSERTED.MessageID
		INTO #tmpMsg (
			MessageID
		) --Get Updated MessageID
		FROM dbo.Msg AS m WITH (ROWLOCK,UPDLOCK)
		WHERE m.MessageID = @MessageID
			AND m.Remark LIKE 'MNC%'
		
		UPDATE t
		SET t.isDeleted = 0
		FROM dbo.MsgTarget AS t WITH (ROWLOCK,UPDLOCK)
			INNER JOIN #tmpMsg AS m ON t.MessageID = m.MessageID
		
		COMMIT TRANSACTION
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR --output for web
			,@ErrMsg = ERROR_MESSAGE() --output for web
		
		ROLLBACK TRANSACTION
	END CATCH
	
	------------------------------
	IF NOT EXISTS (SELECT 1 FROM #tmpMsg)
		AND @ErrCode = 0
	BEGIN
		SELECT @ErrCode = 50004
			,@ErrMsg = 'NO affected Msg/MsgTarget with param @MessageID = ' + ISNULL(CONVERT(VARCHAR, @MessageID),'NULL')
						+ ', @UpdType = ' + ISNULL(@UpdType,'NULL')
						+ ', ErrCode = ' + ISNULL(CONVERT(VARCHAR, @ErrCode),'NULL')
						+ ', ErrMsg = ' + ISNULL(@ErrMsg,'NULL')
	END
	
	DROP TABLE #tmpMsg
END
