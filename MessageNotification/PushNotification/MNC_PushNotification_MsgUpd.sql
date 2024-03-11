/*<info serverAlias="DBMSG-bodb_Message" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
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
		20230515@Roy: CRM - Implement Message Notifications Center for Result Amendment of Cricket(#197621)
	
	Explanation:
	
	Example:
		EXEC bodb_Message.dbo.MNC_PushNotification_MsgUpd
*/
BEGIN
	SET NOCOUNT ON
	
	CREATE TABLE #tmpMsg (
		MessageID INT NOT NULL
	)
	--------------------------------------------------------
	IF @UpdType = 'AfterUpdNoti'
	BEGIN TRY
		BEGIN TRANSACTION
		
		UPDATE n
		SET n.IsTest = 0
			,n.isDeleted = 0
			,n.LastUpdateTime = GETDATE()
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
	IF NOT EXISTS (SELECT 1 FROM #tmpNoti)
		AND @ErrCode = 0
	BEGIN
		SELECT @ErrCode = 1
			,@ErrMsg = 'NO affected Msg/MsgTarget with param @MessageID = ' + ISNULL(CONVERT(VARCHAR, @MessageID),'NULL')
						+ ', @UpdType = ' + ISNULL(@UpdType,'NULL')
						+ ', ErrCode = ' + ISNULL(CONVERT(VARCHAR, @ErrCode),'NULL')
						+ ', ErrMsg = ' + ISNULL(@ErrMsg,'NULL')
	END
	
	DROP TABLE #tmpNoti
END
