/*<info serverAlias="DBCRM-MessageNotification" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE MNC_Notification_AdmUpdNoti
	@NotiID INT
	,@NewStatus VARCHAR(50)
	,@NewContentEN NVARCHAR(MAX)
	,@NewContentCH NVARCHAR(MAX)
	,@NewContentCS NVARCHAR(MAX)
	,@UpdaterID INT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(2000) = '' OUTPUT
AS
/*
	Created: 20231213@Roy
	Task: Update noti status
	DB: DBCRM.MessageNotification
	Revisions:
		20231121@Roy: CRM - Implement Message Notifications Center for Result Amendment of Cricket(#197621)
	
	Param's Explanation:
	
	Example:
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @LogUserID INT
		,@LogActionID SMALLINT
		,@NotiType TINYINT
		,@Updater VARCHAR(50)
		,@ErrLogPrefix NVARCHAR(150) = 'Error - '
		,@InfLogPrefix NVARCHAR(150) = 'Info - '
	
	SELECT @LogUserID = TRY_CONVERT(INT, VValue)
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 2 --ID of StarixIT
	
	SELECT @LogActionID = ActionID
	FROM LogAction WITH (NOLOCK)
	WHERE ActName = ISNULL(OBJECT_NAME(@@PROCID),'Unknown')
	
	----------------------------------------------------------------
	INSERT INTO [Log] (
		RefID
		,ActionID
		,UserID
		,LogBef
	)
	SELECT @NotiID
		,@LogActionID
		,@LogUserID
		,@InfLogPrefix + 'Debug log Start UPD Notification with @NotiID = ' + ISNULL(CONVERT(VARCHAR,@NotiID),'NULL')
						+ ', @NewStatus = ' + ISNULL(@NewStatus,'NULL')
						+ ', @UpdaterID = ' + ISNULL(CONVERT(VARCHAR,@UpdaterID),'NULL')
						+ ', @ErrCode = ' + ISNULL(CONVERT(VARCHAR,@ErrCode),'NULL')
						+ ', @NewContentEN (' + ISNULL(@NewContentEN,'NULL') + ')'
						+ ', @NewContentCH (' + ISNULL(@NewContentCH,'NULL') + ')'
						+ ', @NewContentCS (' + ISNULL(@NewContentCS,'NULL') + ')'
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 13 --LogMode
		AND VValue = 'Debug'
	
	-----------------verify before update Content---------------
	IF NOT EXISTS (SELECT 1 FROM Notification WITH (NOLOCK) WHERE NotificationID = @NotiID)
	BEGIN
		SELECT @ErrCode = 50006
			,@ErrMsg = 'INPUT ERROR - NOT EXISTS NotificationID(' + ISNULL(CONVERT(VARCHAR,@NotiID),'NULL') + ')'
		
		INSERT INTO [Log] (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT @NotiID
			,@LogActionID
			,@LogUserID
			,@ErrLogPrefix + 'FAILED while UPD Notification - ' + @ErrMsg
						+ ', @NewStatus = ' + ISNULL(@NewStatus,'NULL')
						+ ', @UpdaterID = ' + ISNULL(CONVERT(VARCHAR,@UpdaterID),'NULL')
		
		RETURN
	END
	
	-----------------load info---------------
	CREATE TABLE #tmpNewNoti (
		NotiID INT
		,Content_en NVARCHAR(MAX)
		,Subject_en NVARCHAR(300)
		,Content_ch NVARCHAR(MAX)
		,Subject_ch NVARCHAR(300)
		,Content_cs NVARCHAR(MAX)
		,Subject_cs NVARCHAR(300)
	)
	
	CREATE TABLE #tmpCurNoti (
		NotiID INT
		,Status VARCHAR(50)
		,Content_en NVARCHAR(MAX)
		,Subject_en NVARCHAR(300)
		,Content_ch NVARCHAR(MAX)
		,Subject_ch NVARCHAR(300)
		,Content_cs NVARCHAR(MAX)
		,Subject_cs NVARCHAR(300)
	)
	
	SELECT @Updater = COALESCE((SELECT username FROM bodb02.dbo.Customer WITH (NOLOCK) WHERE CustID = @UpdaterID),CONVERT(VARCHAR,@UpdaterID),'Updater(NULL)')
	
	SELECT @NotiType = NotificationType
	FROM Notification WITH (NOLOCK)
	WHERE NotificationID = @NotiID
	OPTION (RECOMPILE)
	
	--get current Notification
	INSERT INTO #tmpCurNoti (
		NotiID
		,Status
		
		,Content_en
		,Subject_en
		
		,Content_ch
		,Subject_ch
		
		,Content_cs
		,Subject_cs
	)
	SELECT n.NotificationID
		,s.Status
		
		,n.Content_en
		,(CASE WHEN n.NotificationType = 2 THEN ns.Subject_en END) AS Subject_en
		
		,n.Content_ch
		,(CASE WHEN n.NotificationType = 2 THEN ns.Subject_ch END) AS Subject_ch
		
		,n.Content_cs
		,(CASE WHEN n.NotificationType = 2 THEN ns.Subject_cs END) AS Subject_cs
	FROM Notification AS n WITH (NOLOCK)
		OUTER APPLY OPENJSON(n.Subject) WITH (
							Subject_en NVARCHAR(300) '$.Subject_en'
							,Subject_ch NVARCHAR(300) '$.Subject_ch'
							,Subject_cs NVARCHAR(300) '$.Subject_cs'
						) AS ns --OPENJSON case-sensitive
		LEFT JOIN NotiStatus AS s WITH (NOLOCK) ON n.StatusID = s.StatusID
	WHERE NotificationID = @NotiID
	OPTION (RECOMPILE)
	
	--parse input to new Notification
	INSERT INTO #tmpNewNoti (
		NotiID
		,Content_en
		,Subject_en
		,Content_ch
		,Subject_ch
		,Content_cs
		,Subject_cs
	)
	SELECT @NotiID
		,NULLIF(TRIM(@NewContentEN), '')
		,CASE WHEN NULLIF(TRIM(@NewContentEN), '') IS NOT NULL THEN '' END
		,NULLIF(TRIM(@NewContentCH), '')
		,CASE WHEN NULLIF(TRIM(@NewContentCH), '') IS NOT NULL THEN '' END
		,NULLIF(TRIM(@NewContentCS), '')
		,CASE WHEN NULLIF(TRIM(@NewContentCS), '') IS NOT NULL THEN '' END
		
	IF @NotiType = 2 --LAP
	BEGIN
		/*
			Becasue the LAP Content include [Subject]
				=> Need to parse the [Subject] from input [Content]
			1.[Subject] = Frist [NON BLANK] line of input [Content]
			2.[Content] = input [Content] - [Subject]
			Ex: @NewContentEN = N'<br/> <br/><b>Subject_test</b><br/><br/><b>Dear Valued Customers,</b><br/>...'
				Loop 1: [Subject] = '<br/> ' = TRIM(REPLACE(Subject_en, @NewLine, '')) = ''
						[Content] = '<br/><b>Subject_test</b><br/><br/><b>Dear Valued Customers,</b><br/>...'
				Loop 2: [Subject] = '<br/>' = TRIM(REPLACE(Subject_en, @NewLine, '')) = ''
						[Content] = '<b>Subject_test</b><br/><br/><b>Dear Valued Customers,</b><br/>...'
				Loop 3: [Subject] = '<b>Subject_test</b>' = TRIM(REPLACE(Subject_en, @NewLine, '')) = '<b>Subject_test</b>'
						[Content] = '<br/><br/><b>Dear Valued Customers,</b><br/>...'
				Loop 4: [Subject] = '<b>Subject_test</b>'
						[Content] = '<b>Dear Valued Customers,</b><br/>...'
		*/
		DECLARE @NewLine VARCHAR(5) = '<br/>'
		
		WHILE EXISTS (
			SELECT 1 
			FROM #tmpNewNoti
			WHERE Subject_en = ''
				OR Subject_ch = ''
				OR Subject_cs = ''
				
				OR Content_en LIKE @NewLine + '%'
				OR Content_ch LIKE @NewLine + '%'
				OR Content_cs LIKE @NewLine + '%'
		)
		BEGIN
			;WITH CTE_PreSubject AS (
				SELECT NotiID
					,SUBSTRING(Content_en, 0, CHARINDEX(@NewLine, Content_en, 0) + LEN(@NewLine)) AS Subject_en
					,SUBSTRING(Content_ch, 0, CHARINDEX(@NewLine, Content_ch, 0) + LEN(@NewLine)) AS Subject_ch
					,SUBSTRING(Content_cs, 0, CHARINDEX(@NewLine, Content_cs, 0) + LEN(@NewLine)) AS Subject_cs
				FROM #tmpNewNoti
			)
			UPDATE n
			SET n.Subject_en = CASE WHEN ISNULL(REPLACE(n.Subject_en, @NewLine, ''), '') = '' THEN REPLACE(sj.Subject_en, @NewLine, '') ELSE n.Subject_en END --Remove first @NewLine in Subject
				,n.Content_en = (CASE WHEN ISNULL(REPLACE(n.Subject_en, @NewLine, ''), '') = '' THEN TRIM(RIGHT(n.Content_en, LEN(n.Content_en) - LEN(sj.Subject_en))) --Remove Subject in Content
									WHEN ISNULL(n.Content_en, '') LIKE @NewLine + '%' THEN TRIM(RIGHT(n.Content_en, LEN(n.Content_en) - LEN(@NewLine))) --Remove first @NewLine in Content
									ELSE n.Content_en END)
				
				,n.Subject_ch = CASE WHEN ISNULL(REPLACE(n.Subject_ch, @NewLine, ''), '') = '' THEN REPLACE(sj.Subject_ch, @NewLine, '') ELSE n.Subject_ch END
				,n.Content_ch = (CASE WHEN ISNULL(REPLACE(n.Subject_ch, @NewLine, ''), '') = '' THEN TRIM(RIGHT(n.Content_ch, LEN(n.Content_ch) - LEN(sj.Subject_ch)))
									WHEN ISNULL(n.Content_ch, '') LIKE @NewLine + '%' THEN TRIM(RIGHT(n.Content_ch, LEN(n.Content_ch) - LEN(@NewLine)))
									ELSE n.Content_ch END)
				
				,n.Subject_cs = CASE WHEN ISNULL(REPLACE(n.Subject_cs, @NewLine, ''), '') = '' THEN REPLACE(sj.Subject_cs, @NewLine, '') ELSE n.Subject_cs END
				,n.Content_cs = (CASE WHEN ISNULL(REPLACE(n.Subject_cs, @NewLine, ''), '') = '' THEN TRIM(RIGHT(n.Content_cs, LEN(n.Content_cs) - LEN(sj.Subject_cs)))
									WHEN ISNULL(n.Content_cs, '') LIKE @NewLine + '%' THEN TRIM(RIGHT(n.Content_cs, LEN(n.Content_cs) - LEN(@NewLine)))
									ELSE n.Content_cs END)
			FROM #tmpNewNoti AS n
				INNER JOIN CTE_PreSubject AS sj ON n.NotiID = sj.NotiID
		END
	END
	
	--Subject DIFF
	IF @NotiType = 2 --LAP
		AND EXISTS (
			SELECT 1
			FROM #tmpNewNoti AS n
				INNER JOIN #tmpCurNoti AS c ON n.NotiID = c.NotiID
			WHERE ISNULL(n.Subject_en,'') <> ISNULL(c.Subject_en,'')
				OR ISNULL(n.Subject_ch,'') <> ISNULL(c.Subject_ch,'')
				OR ISNULL(n.Subject_cs,'') <> ISNULL(c.Subject_cs,'')
		)
	BEGIN TRY
		DECLARE @JSCurSub NVARCHAR(MAX)
			,@JSNewSub NVARCHAR(MAX)
			,@NotiUpdCnt INT
		
		SELECT @JSNewSub = TRIM(Subject)
			,@JSCurSub = TRIM(Subject)
		FROM Notification WITH (NOLOCK)
		WHERE NotificationID = @NotiID
		
		IF EXISTS (
			SELECT 1
			FROM #tmpNewNoti AS n
				INNER JOIN #tmpCurNoti AS c ON n.NotiID = c.NotiID
			WHERE ISNULL(n.Subject_en,'') <> ISNULL(c.Subject_en,'')
		)
			SELECT @JSNewSub = JSON_MODIFY(@JSNewSub,'$.Subject_en', Subject_en)
			FROM #tmpNewNoti
		
		IF EXISTS (
			SELECT 1
			FROM #tmpNewNoti AS n
				INNER JOIN #tmpCurNoti AS c ON n.NotiID = c.NotiID
			WHERE ISNULL(n.Subject_ch,'') <> ISNULL(c.Subject_ch,'')
		)
			SELECT @JSNewSub = JSON_MODIFY(@JSNewSub,'$.Subject_ch', Subject_ch)
			FROM #tmpNewNoti
		
		IF EXISTS (
			SELECT 1
			FROM #tmpNewNoti AS n
				INNER JOIN #tmpCurNoti AS c ON n.NotiID = c.NotiID
			WHERE ISNULL(n.Subject_cs,'') <> ISNULL(c.Subject_cs,'')
		)
			SELECT @JSNewSub = JSON_MODIFY(@JSNewSub,'$.Subject_cs', Subject_cs)
			FROM #tmpNewNoti
		
		UPDATE Notification WITH (ROWLOCK,UPDLOCK)
		SET Subject = TRIM(@JSNewSub)
		WHERE NotificationID = @NotiID
			AND TRIM(Subject) <> TRIM(@JSNewSub)
		
		--------------------------
		SELECT @NotiUpdCnt = @@ROWCOUNT
		IF @NotiUpdCnt = 1
		BEGIN
			INSERT INTO [Log] (
				RefID
				,ActionID
				,UserID
				,LogBef
				,LogAft
			)
			SELECT @NotiID
				,@LogActionID
				,@LogUserID
				,@InfLogPrefix + 'UPD NotificationID Subject - Updater (' + ISNULL(CONVERT(VARCHAR,@UpdaterID) + '','NULL') + ') = ' + @Updater
								+ ' - Notification.Subject before (' + ISNULL(@JSCurSub,'NULL') + ')'
				,TRIM(@JSNewSub)
		END
		ELSE
		BEGIN
			SELECT @ErrCode = 50006
				,@ErrMsg = 'UPD Notification Subject - S.T wrong with NO row affected'
			
			INSERT INTO [Log] (
				RefID
				,ActionID
				,UserID
				,LogBef
				,LogAft
			)
			SELECT @NotiID
				,@LogActionID
				,@LogUserID
				,@ErrLogPrefix + @ErrMsg
					+ '- Current Subject(' + ISNULL(@JSCurSub,'NULL') + ')'
				,TRIM(@JSNewSub)
		END
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR
			,@ErrMsg = 'FAILED to UPD Notification Subject - ERROR_MESSAGE(' + ISNULL(ERROR_MESSAGE(),'NULL') + ')'
		
		INSERT INTO [Log] (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT @NotiID
			,@LogActionID
			,@LogUserID
			,@ErrLogPrefix + @ErrMsg
				+ ' - Notification.Subject current(' + ISNULL(@JSCurSub,'NULL') + ')'
				+ '- Input @NewContentEN(' + ISNULL(@NewContentEN,'NULL') + ')'
				+ '- Input @NewContentCH(' + ISNULL(@NewContentCH,'NULL') + ')'
				+ '- Input @NewContentCS(' + ISNULL(@NewContentCS,'NULL') + ')'
				+ '- New Subject (' + ISNULL(@JSNewSub,'NULL') + ')'
	END CATCH
	ELSE
	BEGIN
		INSERT INTO [Log] (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT @NotiID
			,@LogActionID
			,@LogUserID
			,@InfLogPrefix + 'Debug log UPD Notification.Subject - NO Change'
		FROM SystemSetting WITH (NOLOCK)
		WHERE VID = 13 --LogMode
			AND VValue = 'Debug'
	END
	
	--Content DIFF
	IF @ErrCode = 0
		AND EXISTS (
			SELECT 1
			FROM #tmpNewNoti AS n
				INNER JOIN Notification AS c WITH (NOLOCK) ON n.NotiID = c.NotificationID
			WHERE ISNULL(n.Content_en,'') <> ISNULL(c.Content_en,'')
				OR ISNULL(n.Content_ch,'') <> ISNULL(c.Content_ch,'')
				OR ISNULL(n.Content_cs,'') <> ISNULL(c.Content_cs,'')
		)
	BEGIN TRY
		
		UPDATE c
		SET c.Content_en = (CASE WHEN ISNULL(n.Content_en,'') <> ISNULL(c.Content_en,'') THEN ISNULL(n.Content_en,'') ELSE c.Content_en END)
			,c.Content_ch = (CASE WHEN ISNULL(n.Content_ch,'') <> ISNULL(c.Content_ch,'') THEN ISNULL(n.Content_ch,'') ELSE c.Content_ch END)
			,c.Content_cs = (CASE WHEN ISNULL(n.Content_cs,'') <> ISNULL(c.Content_cs,'') THEN ISNULL(n.Content_cs,'') ELSE c.Content_cs END)
		FROM Notification AS c WITH (ROWLOCK,UPDLOCK)
			INNER JOIN #tmpNewNoti AS n ON c.NotificationID = n.NotiID
		
		--------------------------
		INSERT INTO [Log] (
			RefID
			,ActionID
			,UserID
			,LogBef
			,LogAft
		)
		SELECT c.NotiID
			,@LogActionID
			,@LogUserID
			,@InfLogPrefix + 'UPD NotificationID Content - Updater (' + ISNULL(CONVERT(VARCHAR,@UpdaterID) + '','NULL') + ') = ' + @Updater
							+ ' - Notification.Content_en before (' + ISNULL(c.Content_en,'NULL') + ')'
							+ ' - Notification.Content_ch before (' + ISNULL(c.Content_ch,'NULL') + ')'
							+ ' - Notification.Content_cs before (' + ISNULL(c.Content_cs,'NULL') + ')'
			,'Content_en (' + ISNULL(n.Content_en,'NULL') + ')'
				+ ' - Content_ch (' + ISNULL(n.Content_ch,'NULL') + ')'
				+ ' - Content_cs (' + ISNULL(n.Content_cs,'NULL') + ')'
		FROM #tmpCurNoti AS c
			INNER JOIN Notification AS n WITH (NOLOCK) ON c.NotiID = n.NotificationID
		ORDER BY c.NotiID
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR
			,@ErrMsg = 'FAILED to UPD Notification Content - ERROR_MESSAGE(' + ISNULL(ERROR_MESSAGE(),'NULL') + ')'
		
		INSERT INTO [Log] (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT @NotiID
			,@LogActionID
			,@LogUserID
			,@ErrLogPrefix + @ErrMsg
				+ '- @NewContentEN(' + ISNULL(@NewContentEN,'NULL') + ')'
				+ '- @NewContentCH(' + ISNULL(@NewContentCH,'NULL') + ')'
				+ '- @NewContentCS(' + ISNULL(@NewContentCS,'NULL') + ')'
	END CATCH
	ELSE
	BEGIN
		INSERT INTO [Log] (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT @NotiID
			,@LogActionID
			,@LogUserID
			,@InfLogPrefix + 'Debug log UPD Notification.Content(en/ch/cs) - NO Change'
		FROM SystemSetting WITH (NOLOCK)
		WHERE VID = 13 --LogMode
			AND VValue = 'Debug'
	END
	
	-- Status DIFF
	IF @ErrCode = 0
	BEGIN TRY
		EXEC MNC_Notification_AdmUpdNotiSts
			@NotiID = @NotiID
			,@NewStatus = @NewStatus
			,@UpdaterID = @UpdaterID
			,@ErrCode = @ErrCode OUTPUT
			,@ErrMsg = @ErrMsg OUTPUT
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR
			,@ErrMsg = 'FAILED to UPD Notification Status - ERROR_MESSAGE(' + ISNULL(ERROR_MESSAGE(),'NULL') + ')'
		
		INSERT INTO [Log] (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT @NotiID
			,@LogActionID
			,@LogUserID
			,@ErrLogPrefix + @ErrMsg
				+ '- @NewContentEN(' + ISNULL(@NewContentEN,'NULL') + ')'
				+ '- @NewContentCH(' + ISNULL(@NewContentCH,'NULL') + ')'
				+ '- @NewContentCS(' + ISNULL(@NewContentCS,'NULL') + ')'
	END CATCH
	
	--debug log
	INSERT INTO [Log] (
		RefID
		,ActionID
		,UserID
		,LogBef
		,LogAft
	)
	SELECT c.NotiID
		,@LogActionID
		,@LogUserID
		,@InfLogPrefix + 'Debug log DONE UPD Notification'
						+ ', @NewStatus = ' + ISNULL(@NewStatus,'NULL')
						+ ', Content_en (' + ISNULL(c.Content_en,'NULL') + ')'
						+ ', Subject_en (' + ISNULL(c.Subject_en,'NULL') + ')'
						+ ', Content_ch (' + ISNULL(c.Content_ch,'NULL') + ')'
						+ ', Subject_ch (' + ISNULL(c.Subject_ch,'NULL') + ')'
						+ ', Content_cs (' + ISNULL(c.Content_cs,'NULL') + ')'
						+ ', Subject_cs (' + ISNULL(c.Subject_cs,'NULL') + ')'
		,'Status = ' + ISNULL(s.Status,'NULL')
						+ ', Subject (' + ISNULL(n.Subject,'NULL') + ')'
						+ ', Content_en (' + ISNULL(n.Content_en,'NULL') + ')'
						+ ', Content_ch (' + ISNULL(n.Content_ch,'NULL') + ')'
						+ ', Content_cs (' + ISNULL(n.Content_cs,'NULL') + ')'
	FROM #tmpCurNoti AS c
		INNER JOIN Notification AS n WITH (NOLOCK) ON c.NotiID = n.NotificationID
		LEFT JOIN NotiStatus AS s WITH (NOLOCK) ON n.StatusID = s.StatusID
	WHERE 'Debug' = (
		SELECT VValue FROM SystemSetting WITH (NOLOCK) WHERE VID = 13 --LogMode
	)
	ORDER BY c.NotiID
	
	DROP TABLE #tmpNewNoti
	DROP TABLE #tmpCurNoti
END