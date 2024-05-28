/*<info serverAlias="DBCRM-MessageNotification" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE MNC_Notification_AdmUpdNoti
	@NotiID INT
	,@NewStatus VARCHAR(50)
	,@NewContentEN NVARCHAR(MAX) = NULL
	,@NewContentCH NVARCHAR(MAX) = NULL
	,@NewContentCS NVARCHAR(MAX) = NULL
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
		,@LogMode VARCHAR(500)
	
	SELECT @LogUserID = TRY_CONVERT(INT, VValue)
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 2 --ID of StarixIT
	
	SELECT @LogActionID = ActionID
	FROM LogAction WITH (NOLOCK)
	WHERE ActName = ISNULL(OBJECT_NAME(@@PROCID),'Unknown')
	
	SELECT @LogMode = VValue
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 13 --LogMode
	
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
		,@InfLogPrefix + 'Debug - Start UPD Notification'
						+ ' - @NotiID(' + ISNULL(CONVERT(VARCHAR,@NotiID),'NULL') + ')'
						+ ' - @NewStatus(' + ISNULL(@NewStatus,'NULL') + ')'
						+ ' - @UpdaterID(' + ISNULL(CONVERT(VARCHAR,@UpdaterID),'NULL') + ')'
						+ ' - @NewContentEN(' + ISNULL(@NewContentEN,'NULL') + ')'
						+ ' - @NewContentCH(' + ISNULL(@NewContentCH,'NULL') + ')'
						+ ' - @NewContentCS(' + ISNULL(@NewContentCS,'NULL') + ')'
	WHERE @LogMode = 'Debug'
	
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
						+ ' - @NotiID(' + ISNULL(CONVERT(VARCHAR,@NotiID),'NULL') + ')'
						+ ' - @NewStatus(' + ISNULL(@NewStatus,'NULL') + ')'
						+ ' - @UpdaterID(' + ISNULL(CONVERT(VARCHAR,@UpdaterID),'NULL') + ')'
						+ ' - @NewContentEN(' + ISNULL(@NewContentEN,'NULL') + ')'
						+ ' - @NewContentCH(' + ISNULL(@NewContentCH,'NULL') + ')'
						+ ' - @NewContentCS(' + ISNULL(@NewContentCS,'NULL') + ')'
		
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
		AND ISJSON(n.Subject) = 1
	OPTION (RECOMPILE)
	
	--parse input to new Notification
	;WITH CTE_NewNoti AS (
		SELECT NULLIF(TRIM(@NewContentEN), '') AS Content_en
			,NULLIF(TRIM(@NewContentCH), '') AS Content_ch
			,NULLIF(TRIM(@NewContentCS), '') AS Content_cs
	)
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
		,Content_en
		,CASE WHEN Content_en IS NOT NULL THEN '' END --blank if Content IS NOT NULL (for Loop below)
		,Content_ch
		,CASE WHEN Content_ch IS NOT NULL THEN '' END
		,Content_cs
		,CASE WHEN Content_cs IS NOT NULL THEN '' END
	FROM CTE_NewNoti
		
	IF @NotiType = 2 --LAP
	BEGIN
		/*
			Becasue the LAP Content include [Subject]
				=> Need to parse the [Subject] from input [Content]
			
			1.[Subject] = Frist [NON BLANK] line of input [Content]
			2.[Content] = input [Content] - [Subject]
			Ex: @NewContentEN = N'<br/> <br/><b>Subject_test</b><br/><br/><b>Dear Valued Customers,</b><br/>...'
				Loop 1: [Subject] = '<br/>' = TRIM(REPLACE(Subject_en, @NewLine, '')) = ''
						[Content] = '<br/><b>Subject_test</b><br/><br/><b>Dear Valued Customers,</b><br/>...' --removed SPACE
				Loop 2: [Subject] = ' <br/>' = TRIM(REPLACE(Subject_en, @NewLine, '')) = ''
						[Content] = '<b>Subject_test</b><br/><br/><b>Dear Valued Customers,</b><br/>...'
				Loop 3: [Subject] = '<b>Subject_test</b>' = TRIM(REPLACE(Subject_en, @NewLine, '')) = '<b>Subject_test</b>'
						[Content] = '<br/><br/><b>Dear Valued Customers,</b><br/>...'
				Loop 4: [Subject] = '<b>Subject_test</b>'
						[Content] = '<b>Dear Valued Customers,</b><br/>...'
		*/
		DECLARE @NewLine VARCHAR(5) = '<br/>'
			,@iCnt INT
		
		--Ensure that the WHILE loop does NOT run indefinitely--
		;WITH CTE_NewLineCnt AS (
			SELECT LEN(Content_en) - LEN(REPLACE(Content_en, @NewLine, '')) AS en_Cnt
				,LEN(Content_ch) - LEN(REPLACE(Content_ch, @NewLine, '')) AS ch_Cnt
				,LEN(Content_cs) - LEN(REPLACE(Content_cs, @NewLine, '')) AS cs_Cnt
			FROM #tmpNewNoti
		)
		SELECT @iCnt = (SELECT MAX(v) FROM (VALUES (en_Cnt), (ch_Cnt), (cs_Cnt)) AS value(v)) / LEN(@NewLine)
		FROM CTE_NewLineCnt --count number of times appears @NewLine
		
		WHILE ISNULL(@iCnt,0) >= 0
			AND EXISTS (
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
					--get [temp Subject] => from [start] to [First @NewLine] (include @NewLine)
					,SUBSTRING(Content_en, 0, CHARINDEX(@NewLine, Content_en, 0) + LEN(@NewLine)) AS Subject_en
					,SUBSTRING(Content_ch, 0, CHARINDEX(@NewLine, Content_ch, 0) + LEN(@NewLine)) AS Subject_ch
					,SUBSTRING(Content_cs, 0, CHARINDEX(@NewLine, Content_cs, 0) + LEN(@NewLine)) AS Subject_cs
				FROM #tmpNewNoti
			)
			UPDATE n
			SET n.Subject_en = (CASE WHEN n.Subject_en = '' 							--IF current Subject BLANK
										THEN TRIM(REPLACE(sj.Subject_en, @NewLine, '')) --get [temp Subject] (remove @NewLine)
									ELSE n.Subject_en 									--keep current
								END)
				,n.Content_en = (CASE WHEN n.Subject_en = '' 													--IF current Subject BLANK
										THEN TRIM(RIGHT(n.Content_en, LEN(n.Content_en) - LEN(sj.Subject_en))) 	--Remove [temp Subject] in Content
									WHEN ISNULL(n.Content_en, '') LIKE @NewLine + '%' 							--IF current Content [start with @NewLine]
										THEN TRIM(RIGHT(n.Content_en, LEN(n.Content_en) - LEN(@NewLine))) 		--Remove [first @NewLine] in Content
									ELSE n.Content_en
								END)
				
				,n.Subject_ch = (CASE WHEN n.Subject_ch = ''
										THEN TRIM(REPLACE(sj.Subject_ch, @NewLine, ''))
									ELSE n.Subject_ch
								END)
				,n.Content_ch = (CASE WHEN n.Subject_ch = ''
										THEN TRIM(RIGHT(n.Content_ch, LEN(n.Content_ch) - LEN(sj.Subject_ch)))
									WHEN ISNULL(n.Content_ch, '') LIKE @NewLine + '%'
										THEN TRIM(RIGHT(n.Content_ch, LEN(n.Content_ch) - LEN(@NewLine)))
									ELSE n.Content_ch
								END)
				
				,n.Subject_cs = (CASE WHEN n.Subject_cs = ''
										THEN TRIM(REPLACE(sj.Subject_cs, @NewLine, ''))
									ELSE n.Subject_cs
								END)
				,n.Content_cs = (CASE WHEN n.Subject_cs = ''
										THEN TRIM(RIGHT(n.Content_cs, LEN(n.Content_cs) - LEN(sj.Subject_cs)))
									WHEN ISNULL(n.Content_cs, '') LIKE @NewLine + '%'
										THEN TRIM(RIGHT(n.Content_cs, LEN(n.Content_cs) - LEN(@NewLine)))
									ELSE n.Content_cs
								END)
			FROM #tmpNewNoti AS n
				INNER JOIN CTE_PreSubject AS sj ON n.NotiID = sj.NotiID
			
			----reset for loop
			SELECT @iCnt = @iCnt - 1
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
			SELECT @JSNewSub = JSON_MODIFY(@JSNewSub,'$[0].Subject_en', Subject_en)
			FROM #tmpNewNoti
		
		IF EXISTS (
			SELECT 1
			FROM #tmpNewNoti AS n
				INNER JOIN #tmpCurNoti AS c ON n.NotiID = c.NotiID
			WHERE ISNULL(n.Subject_ch,'') <> ISNULL(c.Subject_ch,'')
		)
			SELECT @JSNewSub = JSON_MODIFY(@JSNewSub,'$[0].Subject_ch', Subject_ch)
			FROM #tmpNewNoti
		
		IF EXISTS (
			SELECT 1
			FROM #tmpNewNoti AS n
				INNER JOIN #tmpCurNoti AS c ON n.NotiID = c.NotiID
			WHERE ISNULL(n.Subject_cs,'') <> ISNULL(c.Subject_cs,'')
		)
			SELECT @JSNewSub = JSON_MODIFY(@JSNewSub,'$[0].Subject_cs', Subject_cs)
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
				,'New Subject(' + ISNULL(@JSNewSub,'NULL') + ')'
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
					+ ' - Current Subject(' + ISNULL(@JSCurSub,'NULL') + ')'
					+ ' - @NotiID(' + ISNULL(CONVERT(VARCHAR,@NotiID),'NULL') + ')'
					+ ' - @NewStatus(' + ISNULL(@NewStatus,'NULL') + ')'
					+ ' - @UpdaterID(' + ISNULL(CONVERT(VARCHAR,@UpdaterID),'NULL') + ')'
					+ ' - @NewContentEN(' + ISNULL(@NewContentEN,'NULL') + ')'
					+ ' - @NewContentCH(' + ISNULL(@NewContentCH,'NULL') + ')'
					+ ' - @NewContentCS(' + ISNULL(@NewContentCS,'NULL') + ')'
				,'New Subject(' + ISNULL(@JSNewSub,'NULL') + ')'
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
			,LogAft
		)
		SELECT @NotiID
			,@LogActionID
			,@LogUserID
			,@ErrLogPrefix + @ErrMsg
				+ ' - Current Subject(' + ISNULL(@JSCurSub,'NULL') + ')'
				+ ' - @NotiID(' + ISNULL(CONVERT(VARCHAR,@NotiID),'NULL') + ')'
				+ ' - @NewStatus(' + ISNULL(@NewStatus,'NULL') + ')'
				+ ' - @UpdaterID(' + ISNULL(CONVERT(VARCHAR,@UpdaterID),'NULL') + ')'
				+ ' - @NewContentEN(' + ISNULL(@NewContentEN,'NULL') + ')'
				+ ' - @NewContentCH(' + ISNULL(@NewContentCH,'NULL') + ')'
				+ ' - @NewContentCS(' + ISNULL(@NewContentCS,'NULL') + ')'
			,'New Subject(' + ISNULL(@JSNewSub,'NULL') + ')'
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
			,@InfLogPrefix + 'Debug - UPD Notification.Subject - NO Change'
		WHERE @LogMode = 'Debug'
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
			,'New Content_en (' + ISNULL(n.Content_en,'NULL') + ')'
				+ ' - New Content_ch (' + ISNULL(n.Content_ch,'NULL') + ')'
				+ ' - New Content_cs (' + ISNULL(n.Content_cs,'NULL') + ')'
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
				+ ' - @NotiID(' + ISNULL(CONVERT(VARCHAR,@NotiID),'NULL') + ')'
				+ ' - @NewStatus(' + ISNULL(@NewStatus,'NULL') + ')'
				+ ' - @UpdaterID(' + ISNULL(CONVERT(VARCHAR,@UpdaterID),'NULL') + ')'
				+ ' - @NewContentEN(' + ISNULL(@NewContentEN,'NULL') + ')'
				+ ' - @NewContentCH(' + ISNULL(@NewContentCH,'NULL') + ')'
				+ ' - @NewContentCS(' + ISNULL(@NewContentCS,'NULL') + ')'
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
			,@InfLogPrefix + 'Debug - UPD Notification.Content(en/ch/cs) - NO Change'
		WHERE @LogMode = 'Debug'
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
				+ ' - @NotiID(' + ISNULL(CONVERT(VARCHAR,@NotiID),'NULL') + ')'
				+ ' - @NewStatus(' + ISNULL(@NewStatus,'NULL') + ')'
				+ ' - @UpdaterID(' + ISNULL(CONVERT(VARCHAR,@UpdaterID),'NULL') + ')'
				+ ' - @NewContentEN(' + ISNULL(@NewContentEN,'NULL') + ')'
				+ ' - @NewContentCH(' + ISNULL(@NewContentCH,'NULL') + ')'
				+ ' - @NewContentCS(' + ISNULL(@NewContentCS,'NULL') + ')'
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
		,@InfLogPrefix + 'Debug - DONE UPD Notification'
						+ ' - @NewStatus (' + ISNULL(@NewStatus,'NULL') + ')'
						+ ' - Content_en (' + ISNULL(c.Content_en,'NULL') + ')'
						+ ' - Subject_en (' + ISNULL(c.Subject_en,'NULL') + ')'
						+ ' - Content_ch (' + ISNULL(c.Content_ch,'NULL') + ')'
						+ ' - Subject_ch (' + ISNULL(c.Subject_ch,'NULL') + ')'
						+ ' - Content_cs (' + ISNULL(c.Content_cs,'NULL') + ')'
						+ ' - Subject_cs (' + ISNULL(c.Subject_cs,'NULL') + ')'
		,'Status = ' + ISNULL(s.Status,'NULL')
						+ ', Subject (' + ISNULL(n.Subject,'NULL') + ')'
						+ ', Content_en (' + ISNULL(n.Content_en,'NULL') + ')'
						+ ', Content_ch (' + ISNULL(n.Content_ch,'NULL') + ')'
						+ ', Content_cs (' + ISNULL(n.Content_cs,'NULL') + ')'
	FROM #tmpCurNoti AS c
		INNER JOIN Notification AS n WITH (NOLOCK) ON c.NotiID = n.NotificationID
		LEFT JOIN NotiStatus AS s WITH (NOLOCK) ON n.StatusID = s.StatusID
	WHERE @LogMode = 'Debug'
	ORDER BY c.NotiID
	
	DROP TABLE #tmpNewNoti
	DROP TABLE #tmpCurNoti
END