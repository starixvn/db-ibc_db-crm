/*<info serverAlias="DBMSG-bodb_Message" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE MNC_PushNotification_MsgIns
	@NotificationID INT
	,@JSNotification NVARCHAR(MAX)
	,@MessageID INT OUTPUT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(2000) = '' OUTPUT
AS
/*
	Created: 20231213@Roy
	Task: Insert Notification to Msg/MsgTarget
	DB: DBMSG.bodb_Message
	Revisions:
		20231121@Roy: CRM - Implement Message Notifications Center for Result Amendment of Cricket(#197621)
		20240910@Roy: CRM - Offer New Chinese Simplify for Result Amendment of Cricket (MNC) (#210317)
	
	Explanation:
		Steps
			- Parse JSON data
			- Insert Msg
			- Insert MsgTarget
		
		Output
			@MessageID of new Msg message
			@ErrCode
			@ErrMsg
	
	Example:
		EXEC bodb_Message.dbo.MNC_PushNotification_MsgIns
*/
BEGIN
	SET NOCOUNT ON
	
	/*
		Reset OUTPUT
	*/
	SELECT @ErrCode = 0
		,@ErrMsg = ''
		,@MessageID = NULL
	
	DECLARE @DefaultDateTime DATETIME = GETDATE()
	
	CREATE TABLE #tmpJSData (
		ObjectName NVARCHAR(150)
		,JSONData NVARCHAR(MAX)
	)
	
	CREATE TABLE #tmpMsg (
		NotificationID INT
		,Content_en NVARCHAR(4000)
		,Content_ch NVARCHAR(4000)
		,Content_cs NVARCHAR(4000)
		,Content_zhcn NVARCHAR(4000)
		,MsgType TINYINT
		,MsgContentsType TINYINT NOT NULL
		,IsSticky BIT
		,IsBatch BIT
		,IsTest BIT NOT NULL
		,isDeleted BIT NOT NULL
		,MatchID INT
		,LeagueGroupID SMALLINT
		,PostTime DATETIME
		,Creator INT
		,CreatorName NVARCHAR(50)
		,CreateTime DATETIME
		,LastUpdator INT
		,LastUpdateName VARCHAR(50)
		,LastUpdateTime DATETIME
	)
	
	CREATE TABLE #tmpMsgTarget (
		TargetID INT NOT NULL
		,TargetName NVARCHAR(30)
		,BetTransID VARCHAR(MAX) NULL
		,isDeleted BIT NOT NULL
		,PostTime DATETIME
	)
	
	CREATE TABLE #tmpNewMessage (
		MessageID INT NOT NULL
	)
	
	--parse JSON data
	BEGIN TRY
		INSERT INTO #tmpJSData(
			ObjectName
			,JSONData
		)
		SELECT ObjectName
			,JSONData
		FROM OPENJSON(@JSNotification) WITH (
				ObjectName NVARCHAR(150) '$.ObjectName'
				,JSONData NVARCHAR(MAX) '$.JSONData'
			)--OPENJSON case-sensitive
		WHERE ISJSON(@JSNotification) = 1
		
		INSERT INTO #tmpMsg (
			NotificationID
			,Content_en
			,Content_ch
			,Content_cs
			,Content_zhcn
			,MsgContentsType
			,IsTest
			,isDeleted
			,MsgType
			,IsSticky
			,IsBatch
			,MatchID
			,LeagueGroupID
			,Creator
			,CreatorName
			,LastUpdator
			,LastUpdateName
			,PostTime
			,CreateTime
			,LastUpdateTime
		)
		SELECT NotificationID
			,Content_en
			,Content_ch
			,Content_cs
			,Content_zhcn
			,111 AS MsgContentsType --MsgContentsType of Result amendment
			,1 AS IsTest --tmp value, will update = 0 after everything complete
			,1 AS isDeleted --tmp value, will update = 0 after everything complete
			,1 AS MsgType --message to customer (personal)
			,0 AS IsSticky --Is special Message or not
			,1 AS IsBatch --special message (need to replace the symbol @@ by transid when display)
			,MatchID
			,LeagueGroupID
			,Creator
			,CreatorName
			,Creator AS LastUpdator
			,CreatorName AS LastUpdateName
			,@DefaultDateTime AS PostTime
			,@DefaultDateTime AS CreateTime
			,@DefaultDateTime AS LastUpdateTime
		FROM OPENJSON((SELECT JSONData FROM #tmpJSData WHERE ObjectName = 'Notification' AND ISJSON(JSONData) = 1)) WITH (
				NotificationID INT '$.NotificationID'
				,Content_en NVARCHAR(4000) '$.Content_en'
				,Content_ch NVARCHAR(4000) '$.Content_ch'
				,Content_cs NVARCHAR(4000) '$.Content_cs'
				,Content_zhcn NVARCHAR(4000) '$.Content_zhcn'
				,MatchID INT '$.MatchID'
				,LeagueGroupID SMALLINT '$.LeagueGroupID'
				,Creator INT '$.Creator'
				,CreatorName NVARCHAR(50) '$.CreatorName'
			)--OPENJSON case-sensitive
		
		INSERT INTO #tmpMsgTarget (
			TargetID
			,TargetName
			,BetTransID
			,isDeleted
			,PostTime
		)
		SELECT TargetID
			,TargetName
			,BetTransID
			,1 AS isDeleted --tmp value, will update = 0 after everything complete
			,@DefaultDateTime AS PostTime
		FROM OPENJSON((SELECT JSONData FROM #tmpJSData WHERE ObjectName = 'NotificationTarget' AND ISJSON(JSONData) = 1)) WITH (
				TargetID INT '$.TargetID'
				,TargetName NVARCHAR(30) '$.TargetName'
				,BetTransID VARCHAR(MAX) '$.BetTransID'
			)--OPENJSON case-sensitive
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR --output for web
			,@ErrMsg = 'Error - [UAT/PRO] - [InsertMessageService - MsgIns] - FAILED parse input JSON'
						+ ' - ERROR_MESSAGE(' + ISNULL(ERROR_MESSAGE(),'NULL') + ')' --output for web
	END CATCH
	
	--insert Msg and get @MessageID
	IF @ErrCode = 0
		AND EXISTS (SELECT 1 FROM #tmpMsg WHERE NotificationID = @NotificationID)
	BEGIN TRY
		BEGIN TRANSACTION
			INSERT dbo.Msg (
				Content_en
				,Content_ch
				,Content_cs
				,Content_zhcn
				,MsgType
				,MsgContentsType
				,IsSticky
				,IsBatch
				,IsTest
				,isDeleted
				,MatchID
				,LeagueGroupID
				,PostTime
				,Creator
				,CreatorName
				,CreateTime
				,LastUpdator
				,LastUpdateName
				,LastUpdateTime
			)
			OUTPUT INSERTED.MessageID
			INTO #tmpNewMessage(MessageID)
			SELECT Content_en
				,Content_ch
				,Content_cs
				,Content_zhcn
				,MsgType
				,MsgContentsType
				,IsSticky
				,IsBatch
				,IsTest
				,isDeleted
				,MatchID
				,LeagueGroupID
				,PostTime
				,Creator
				,CreatorName
				,CreateTime
				,LastUpdator
				,LastUpdateName
				,LastUpdateTime
			FROM #tmpMsg
		COMMIT TRANSACTION
		
		SELECT @MessageID = MessageID
		FROM #tmpNewMessage
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR --output for web
			,@ErrMsg = 'Error - [UAT/PRO] - [InsertMessageService - MsgIns] - FAILED Insert Msg'
						+ ' - ERROR_MESSAGE(' + ISNULL(ERROR_MESSAGE(),'NULL') + ')' --output for web
		ROLLBACK TRANSACTION
	END CATCH
	
	--insert MsgTarget
	IF @ErrCode = 0
		AND @MessageID IS NOT NULL
		AND EXISTS (SELECT 1 FROM dbo.Msg WHERE MessageId = @MessageID)
	BEGIN TRY
		BEGIN TRANSACTION
			INSERT dbo.MsgTarget (
				MessageId
				,TargetID
				,TargetName
				,BetTransID
				,isDeleted
				,PostTime
			)
			SELECT @MessageID AS MessageId
				,TargetID
				,TargetName
				,BetTransID
				,isDeleted
				,PostTime
			FROM #tmpMsgTarget
		COMMIT TRANSACTION
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR --output for web
			,@ErrMsg = 'Error - [UAT/PRO] - [InsertMessageService - MsgIns] - FAILED Insert MsgTarget'
						+ ' - ERROR_MESSAGE(' + ISNULL(ERROR_MESSAGE(),'NULL') + ')' --output for web
		
		ROLLBACK TRANSACTION
	END CATCH
	
	---NO error but invalid @MessageID--
	IF @ErrCode = 0
		AND (@MessageID IS NULL
				OR NOT EXISTS (SELECT 1 FROM dbo.Msg WITH (NOLOCK) WHERE MessageId = @MessageID)
				OR NOT EXISTS (SELECT 1 FROM dbo.MsgTarget WITH (NOLOCK) WHERE MessageId = @MessageID)
		)
	BEGIN
		SELECT @ErrMsg = ISNULL(@ErrMsg,'Error - [UAT/PRO] - [InsertMessageService - MsgIns] - ') + 'Invalid @MessageID(' + ISNULL(CONVERT(VARCHAR,@MessageID),'NULL') + ')'
							+ ' - @NotificationID(' + ISNULL(CONVERT(VARCHAR,@NotificationID),'NULL') + ')'
							+ ' - @JSNotification(' + ISNULL(@JSNotification,'NULL') + ')'
		
		SELECT @ErrCode = 50002 --user-defined
		
		SELECT @MessageID = NULL
	END
	ELSE IF @ErrCode <> 0
	BEGIN
		---DELETE Msg
		DELETE FROM dbo.Msg
		WHERE MessageId = @MessageID
		---DELETE MsgTarget
		DELETE FROM dbo.MsgTarget
		WHERE MessageId = @MessageID
		
		SELECT @ErrMsg = ISNULL(@ErrMsg,'Error - [UAT/PRO] - [InsertMessageService - MsgIns] - ') + 'Deleted Msg/MsgTarget with @MessageID(' + ISNULL(CONVERT(VARCHAR,@MessageID),'NULL') + ')'
						+ ' - @NotificationID(' + ISNULL(CONVERT(VARCHAR,@NotificationID),'NULL') + ')'
						+ ' - @JSNotification(' + ISNULL(@JSNotification,'NULL') + ')'
		
		SELECT @MessageID = NULL
	END
	
	DROP TABLE #tmpNewMessage
	DROP TABLE #tmpJSData
	DROP TABLE #tmpMsg
	DROP TABLE #tmpMsgTarget
END
