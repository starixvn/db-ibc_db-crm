/*<info serverAlias="DBCRM-MessageNotification" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE MNC_Notification_AdmUpdNoti
	@NotiID INT
	,@NewStatus VARCHAR(50)
	,@NewSubject NVARCHAR(1000) = NULL
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
		,@NotiUpdCnt INT
		,@Updater VARCHAR(50)
		,@ErrLogPrefix NVARCHAR(150) = 'Error - Adm - '
		,@InfLogPrefix NVARCHAR(150) = 'Info - Adm - '
		,@LogMode VARCHAR(500)
		,@LocalErrMsg NVARCHAR(MAX)
	
	DECLARE @tmpUserLog TABLE (
		LogTime DATETIME DEFAULT GETDATE()
		,RefID INT
		,ActionID SMALLINT
		,UserID INT
		,LogBef VARBINARY(MAX)
		,LogAft VARBINARY(MAX)
	)
	SELECT @LogUserID = TRY_CONVERT(INT, VValue)
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 2 --ID of StarixIT
	
	SELECT @LogActionID = ActionID
	FROM LogAction WITH (NOLOCK)
	WHERE ActName = ISNULL(OBJECT_NAME(@@PROCID),'Unknown')
	
	SELECT @LogMode = VValue
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 13 --LogMode
	
	SELECT @Updater = username
	FROM bodb02.dbo.Customer WITH (NOLOCK)
	WHERE CustID = @UpdaterID
	
	----------------------------------------------------------------
	INSERT INTO UserLog (
		RefID
		,ActionID
		,UserID
		,LogBef
	)
	SELECT @NotiID
		,@LogActionID
		,(CASE WHEN @Updater IS NULL THEN @LogUserID ELSE @UpdaterID END)
		,COMPRESS(@InfLogPrefix + 'Start UPD Notification'
						+ ' - @NotiID(' + ISNULL(CONVERT(VARCHAR,@NotiID),'NULL') + ')'
						+ ' - @NewStatus(' + ISNULL(@NewStatus,'NULL') + ')'
						+ ' - @NewSubject(' + ISNULL(@NewSubject,'NULL') + ')'
						+ ' - @NewContentEN(' + ISNULL(@NewContentEN,'NULL') + ')'
						+ ' - @NewContentCH(' + ISNULL(@NewContentCH,'NULL') + ')'
						+ ' - @NewContentCS(' + ISNULL(@NewContentCS,'NULL') + ')'
						+ ' - @UpdaterID(' + ISNULL(CONVERT(VARCHAR,@UpdaterID),'NULL') + ')')
	
	-----------------verify before update---------------
	IF @Updater IS NULL
		OR NOT EXISTS (SELECT 1 FROM Notification WITH (NOLOCK) WHERE NotificationID = @NotiID)
	BEGIN
		SELECT @ErrCode = 50006
			,@ErrMsg = (CASE WHEN @Updater IS NULL THEN 'Invalid Updater' ELSE 'Invalid Input NotiID' END)
					+ '. Please close this page and try again.'
			,@LocalErrMsg = CASE WHEN @Updater IS NULL THEN 'INPUT ERROR - NOT EXISTS UpdaterID(' + ISNULL(CONVERT(VARCHAR,@UpdaterID),'NULL') + ')'
							ELSE 'INPUT ERROR - NOT EXISTS NotificationID(' + ISNULL(CONVERT(VARCHAR,@NotiID),'NULL') + ')' END
		
		INSERT INTO UserLog (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT @NotiID
			,@LogActionID
			,(CASE WHEN @Updater IS NULL THEN @LogUserID ELSE @UpdaterID END)
			,COMPRESS(@ErrLogPrefix + 'FAILED while UPD Notification - ' + @LocalErrMsg
						+ ' - @NotiID(' + ISNULL(CONVERT(VARCHAR,@NotiID),'NULL') + ')'
						+ ' - @NewStatus(' + ISNULL(@NewStatus,'NULL') + ')'
						+ ' - @NewSubject(' + ISNULL(@NewSubject,'NULL') + ')'
						+ ' - @NewContentEN(' + ISNULL(@NewContentEN,'NULL') + ')'
						+ ' - @NewContentCH(' + ISNULL(@NewContentCH,'NULL') + ')'
						+ ' - @NewContentCS(' + ISNULL(@NewContentCS,'NULL') + ')'
						+ ' - @UpdaterID(' + ISNULL(CONVERT(VARCHAR,@UpdaterID),'NULL') + ')'
			)
		
		RETURN
	END
	
	-----------------verify @@ in [General Notification] (OST)---------------
	IF EXISTS (SELECT 1 FROM Notification WITH (NOLOCK) WHERE NotificationID = @NotiID AND NotificationType = 1)
		AND @NewStatus = 'Sending'
		AND (
			ISNULL(CHARINDEX ('@@', @NewContentEN),0) = 0
			OR ISNULL(CHARINDEX ('@@', @NewContentCH),0) = 0
			OR ISNULL(CHARINDEX ('@@', @NewContentCS),0) = 0
		)
	BEGIN
		SELECT @ErrCode = 50006
			,@ErrMsg = 'Missing ''@@'' in Notification content.'
			,@LocalErrMsg = 'Missing ''@@'' in Notification content.'
		
		INSERT INTO UserLog (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT @NotiID
			,@LogActionID
			,(CASE WHEN @Updater IS NULL THEN @LogUserID ELSE @UpdaterID END)
			,COMPRESS(@ErrLogPrefix + 'FAILED while UPD Notification - ' + @LocalErrMsg
						+ ' - @NotiID(' + ISNULL(CONVERT(VARCHAR,@NotiID),'NULL') + ')'
						+ ' - @NewStatus(' + ISNULL(@NewStatus,'NULL') + ')'
						+ ' - @NewSubject(' + ISNULL(@NewSubject,'NULL') + ')'
						+ ' - @NewContentEN(' + ISNULL(@NewContentEN,'NULL') + ')'
						+ ' - @NewContentCH(' + ISNULL(@NewContentCH,'NULL') + ')'
						+ ' - @NewContentCS(' + ISNULL(@NewContentCS,'NULL') + ')'
						+ ' - @UpdaterID(' + ISNULL(CONVERT(VARCHAR,@UpdaterID),'NULL') + ')'
			)
		
		RETURN
	END
	
	-----------------load info---------------
	CREATE TABLE #tmpNewNoti (
		NotiID INT
		,Subject NVARCHAR(1000)
		,Content_en NVARCHAR(MAX)
		,Content_ch NVARCHAR(MAX)
		,Content_cs NVARCHAR(MAX)
	)
	
	CREATE TABLE #tmpCurNoti (
		NotiID INT
		,Status VARCHAR(50)
		,Subject NVARCHAR(1000)
		,Content_en NVARCHAR(MAX)
		,Content_ch NVARCHAR(MAX)
		,Content_cs NVARCHAR(MAX)
	)
	
	/*
		Lock NotiID while UPDATE
	*/
	/***************************************************************************/
	BEGIN TRANSACTION
	/***************************************************************************/
	SELECT @NotiType = NotificationType
	FROM Notification WITH (ROWLOCK,UPDLOCK) --Lock NotiID while UPDATE
	WHERE NotificationID = @NotiID
	OPTION (RECOMPILE)
	
	--get current Notification
	INSERT INTO #tmpCurNoti (
		NotiID
		,Status
		,Subject
		,Content_en
		,Content_ch
		,Content_cs
	)
	SELECT n.NotificationID
		,s.Status
		,CASE WHEN n.NotificationType = 2 THEN n.Subject END --LAP only
		,n.Content_en
		,n.Content_ch
		,n.Content_cs
	FROM Notification AS n WITH (ROWLOCK,UPDLOCK)
		LEFT JOIN NotiStatus AS s WITH (NOLOCK) ON n.StatusID = s.StatusID
	WHERE n.NotificationID = @NotiID
	OPTION (RECOMPILE)
	
	--parse input to new Notification
	;WITH CTE_NewNoti AS (
		SELECT NULLIF(TRIM(@NewContentEN), '') AS Content_en
			,NULLIF(TRIM(@NewContentCH), '') AS Content_ch
			,NULLIF(TRIM(@NewContentCS), '') AS Content_cs
			
			,NULLIF(TRIM(@NewSubject), '') AS Subject
	)
	INSERT INTO #tmpNewNoti (
		NotiID
		,Subject
		,Content_en
		,Content_ch
		,Content_cs
	)
	SELECT @NotiID
		,Subject
		,Content_en
		,Content_ch
		,Content_cs
	FROM CTE_NewNoti
	
	-------------------------- Subject DIFF - Only for LAP --------------------------
	IF @NotiType = 2 --LAP
		AND EXISTS (
			SELECT 1
			FROM #tmpNewNoti AS n
				INNER JOIN #tmpCurNoti AS c ON n.NotiID = c.NotiID
			WHERE ISNULL(n.Subject,'') <> ISNULL(c.Subject,'')
		)
	BEGIN TRY
		UPDATE c
		SET c.Subject = n.Subject
			,c.LastModifiedTime = GETDATE()
		FROM Notification AS c WITH (ROWLOCK,UPDLOCK)
			INNER JOIN #tmpNewNoti AS n ON c.NotificationID = n.NotiID
		WHERE ISNULL(n.Subject,'') <> ISNULL(c.Subject,'')
		
		--------------------------
		SELECT @NotiUpdCnt = @@ROWCOUNT
		IF @NotiUpdCnt = 1
		BEGIN
			INSERT INTO @tmpUserLog (
				RefID
				,ActionID
				,UserID
				,LogBef
				,LogAft
			)
			SELECT NotiID
				,@LogActionID
				,@UpdaterID
				,COMPRESS(@InfLogPrefix + 'UPD NotificationID Subject - Updater (' + ISNULL(CONVERT(VARCHAR,@UpdaterID) + '','NULL') + ') = ' + @Updater
								+ ' - @NewSubject(' + ISNULL(@NewSubject,'NULL') + ')'
								+ ' - @UpdaterID(' + ISNULL(CONVERT(VARCHAR,@UpdaterID),'NULL') + ')'
								+ ' - Notification.Subject before (' + ISNULL(c.Subject,'NULL') + ')')
				,COMPRESS(N'New Subject(' + ISNULL(n.Subject,'NULL') + ')')
			FROM #tmpCurNoti AS c
				INNER JOIN Notification AS n WITH (NOLOCK) ON c.NotiID = n.NotificationID
			WHERE ISNULL(n.Subject,'') <> ISNULL(c.Subject,'')
		END
		ELSE
		BEGIN
			SELECT @ErrCode = 50006
				,@ErrMsg = 'An error has occurred while updating Subject. Please close this page and try again.'
				,@LocalErrMsg = 'UPD Notification Subject - S.T wrong with NO row affected'
			
			INSERT INTO @tmpUserLog (
				RefID
				,ActionID
				,UserID
				,LogBef
				,LogAft
			)
			SELECT @NotiID
				,@LogActionID
				,@UpdaterID
				,COMPRESS(@ErrLogPrefix + @LocalErrMsg
					+ ' - Current @NotiUpdCnt(' + ISNULL(CONVERT(VARCHAR,@NotiUpdCnt),'NULL') + ')'
					+ ' - @NotiID(' + ISNULL(CONVERT(VARCHAR,@NotiID),'NULL') + ')'
					+ ' - @UpdaterID(' + ISNULL(CONVERT(VARCHAR,@UpdaterID),'NULL') + ')'
					+ ' - @NewSubject(' + ISNULL(@NewSubject,'NULL') + ')'
					+ ' - tmpNewNoti('
								+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
											SELECT *
											FROM #tmpNewNoti
											FOR JSON PATH
										))
									),'NO ROW') + ')'
					+ ' - tmpCurNoti('
									+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
												SELECT *
												FROM #tmpCurNoti
												FOR JSON PATH
											))
										),'NO ROW') + ')')
				,COMPRESS(N'Current Subject(' + ISNULL((SELECT Subject FROM Notification WITH (NOLOCK) WHERE NotificationID = @NotiID),'NULL') + ')')
		END
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR
			,@ErrMsg = 'An error has occurred. Please close this page and try again.'
			,@LocalErrMsg = 'FAILED to UPD Notification Subject - ERROR_MESSAGE(' + ISNULL(ERROR_MESSAGE(),'NULL') + ')'
		
		INSERT INTO @tmpUserLog (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT @NotiID
			,@LogActionID
			,@UpdaterID
			,COMPRESS(@ErrLogPrefix + @LocalErrMsg
				+ ' - @NotiID(' + ISNULL(CONVERT(VARCHAR,@NotiID),'NULL') + ')'
				+ ' - @NewStatus(' + ISNULL(@NewStatus,'NULL') + ')'
				+ ' - @NewSubject(' + ISNULL(@NewSubject,'NULL') + ')'
				+ ' - @NewContentEN(' + ISNULL(@NewContentEN,'NULL') + ')'
				+ ' - @NewContentCH(' + ISNULL(@NewContentCH,'NULL') + ')'
				+ ' - @NewContentCS(' + ISNULL(@NewContentCS,'NULL') + ')'
				+ ' - @UpdaterID(' + ISNULL(CONVERT(VARCHAR,@UpdaterID),'NULL') + ')'
				+ ' - tmpNewNoti('
								+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
											SELECT *
											FROM #tmpNewNoti
											FOR JSON PATH
										))
									),'NO ROW') + ')'
				+ ' - tmpCurNoti('
								+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
											SELECT *
											FROM #tmpCurNoti
											FOR JSON PATH
										))
									),'NO ROW') + ')')
	END CATCH
	ELSE IF @NotiType = 2
	BEGIN
		INSERT INTO @tmpUserLog (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT @NotiID
			,@LogActionID
			,@UpdaterID
			,COMPRESS(@InfLogPrefix + 'Debug - UPD Notification.Subject - NO Change')
		WHERE @LogMode = 'Debug'
	END
	
	-------------------------- Content DIFF --------------------------
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
			,c.LastModifiedTime = (CASE WHEN (ISNULL(n.Content_en,'') + ISNULL(n.Content_ch,'') + ISNULL(n.Content_cs,'')) <> (ISNULL(c.Content_en,'') + ISNULL(c.Content_ch,'') + ISNULL(c.Content_cs,''))
										THEN GETDATE() ELSE c.LastModifiedTime END)
		FROM Notification AS c WITH (ROWLOCK,UPDLOCK)
			INNER JOIN #tmpNewNoti AS n ON c.NotificationID = n.NotiID
		
		--------------------------
		SELECT @NotiUpdCnt = @@ROWCOUNT
		IF @NotiUpdCnt = 1
		BEGIN
			INSERT INTO @tmpUserLog (
				RefID
				,ActionID
				,UserID
				,LogBef
				,LogAft
			)
			SELECT c.NotiID
				,@LogActionID
				,@UpdaterID
				,COMPRESS(@InfLogPrefix + 'UPD NotificationID Content - Updater (' + ISNULL(CONVERT(VARCHAR,@UpdaterID) + '','NULL') + ') = ' + @Updater
								+ ' - @UpdaterID(' + ISNULL(CONVERT(VARCHAR,@UpdaterID),'NULL') + ')'
								+ ' - Notification.Content_en before (' + ISNULL(c.Content_en,'NULL') + ')'
								+ ' - Notification.Content_ch before (' + ISNULL(c.Content_ch,'NULL') + ')'
								+ ' - Notification.Content_cs before (' + ISNULL(c.Content_cs,'NULL') + ')')
				,COMPRESS(N'New Content_en (' + ISNULL(n.Content_en,'NULL') + ')'
					+ ' - New Content_ch (' + ISNULL(n.Content_ch,'NULL') + ')'
					+ ' - New Content_cs (' + ISNULL(n.Content_cs,'NULL') + ')')
			FROM #tmpCurNoti AS c
				INNER JOIN Notification AS n WITH (NOLOCK) ON c.NotiID = n.NotificationID
			WHERE ISNULL(n.Content_en,'') <> ISNULL(c.Content_en,'')
				OR ISNULL(n.Content_ch,'') <> ISNULL(c.Content_ch,'')
				OR ISNULL(n.Content_cs,'') <> ISNULL(c.Content_cs,'')
		END
		ELSE
		BEGIN
			SELECT @ErrCode = 50006
				,@ErrMsg = 'An error has occurred while updating Content. Please close this page and try again.'
				,@LocalErrMsg = 'UPD Notification Content - S.T wrong with NO row affected'
			
			INSERT INTO @tmpUserLog (
				RefID
				,ActionID
				,UserID
				,LogBef
			)
			SELECT @NotiID
				,@LogActionID
				,@UpdaterID
				,COMPRESS(@ErrLogPrefix + @LocalErrMsg
					+ ' - @NotiUpdCnt(' + ISNULL(CONVERT(VARCHAR,@NotiUpdCnt),'NULL') + ')'
					+ ' - @NotiID(' + ISNULL(CONVERT(VARCHAR,@NotiID),'NULL') + ')'
					+ ' - @NewStatus(' + ISNULL(@NewStatus,'NULL') + ')'
					+ ' - @NewSubject(' + ISNULL(@NewSubject,'NULL') + ')'
					+ ' - @NewContentEN(' + ISNULL(@NewContentEN,'NULL') + ')'
					+ ' - @NewContentCH(' + ISNULL(@NewContentCH,'NULL') + ')'
					+ ' - @NewContentCS(' + ISNULL(@NewContentCS,'NULL') + ')'
					+ ' - @UpdaterID(' + ISNULL(CONVERT(VARCHAR,@UpdaterID),'NULL') + ')'
					+ ' - tmpNewNoti('
								+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
											SELECT *
											FROM #tmpNewNoti
											FOR JSON PATH
										))
									),'NO ROW') + ')'
					+ ' - tmpCurNoti('
									+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
												SELECT *
												FROM #tmpCurNoti
												FOR JSON PATH
											))
										),'NO ROW') + ')')
		END
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR
			,@ErrMsg = 'An error has occurred. Please close this page and try again.'
			,@LocalErrMsg = 'FAILED to UPD Notification Content - ERROR_MESSAGE(' + ISNULL(ERROR_MESSAGE(),'NULL') + ')'
		
		INSERT INTO @tmpUserLog (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT @NotiID
			,@LogActionID
			,@UpdaterID
			,COMPRESS(@ErrLogPrefix + @LocalErrMsg
				+ ' - @NotiID(' + ISNULL(CONVERT(VARCHAR,@NotiID),'NULL') + ')'
				+ ' - @NewStatus(' + ISNULL(@NewStatus,'NULL') + ')'
				+ ' - @NewSubject(' + ISNULL(@NewSubject,'NULL') + ')'
				+ ' - @NewContentEN(' + ISNULL(@NewContentEN,'NULL') + ')'
				+ ' - @NewContentCH(' + ISNULL(@NewContentCH,'NULL') + ')'
				+ ' - @NewContentCS(' + ISNULL(@NewContentCS,'NULL') + ')'
				+ ' - @UpdaterID(' + ISNULL(CONVERT(VARCHAR,@UpdaterID),'NULL') + ')'
				+ ' - tmpNewNoti('
								+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
											SELECT *
											FROM #tmpNewNoti
											FOR JSON PATH
										))
									),'NO ROW') + ')'
				+ ' - tmpCurNoti('
								+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
											SELECT *
											FROM #tmpCurNoti
											FOR JSON PATH
										))
									),'NO ROW') + ')')
	END CATCH
	ELSE
	BEGIN
		INSERT INTO @tmpUserLog (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT @NotiID
			,@LogActionID
			,@UpdaterID
			,COMPRESS(@InfLogPrefix + 'Debug - UPD Notification.Content(en/ch/cs) - NO Change')
		WHERE @LogMode = 'Debug'
	END
	
	-------------------------- Status DIFF --------------------------
	IF @ErrCode = 0
	BEGIN TRY
		EXEC MessageNotification.dbo.MNC_Notification_AdmUpdNotiSts
			@NotiID = @NotiID
			,@NewStatus = @NewStatus
			,@UpdaterID = @UpdaterID
			,@ErrCode = @ErrCode OUTPUT
			,@ErrMsg = @LocalErrMsg OUTPUT
			
			IF ISNULL(@ErrCode,0) <> 0
			BEGIN
				SELECT @ErrMsg = 'An error has occurred while updating Status. Please close this page and try again.'
				INSERT INTO @tmpUserLog (
					RefID
					,ActionID
					,UserID
					,LogBef
				)
				SELECT @NotiID
					,@LogActionID
					,@UpdaterID
					,COMPRESS(@ErrLogPrefix + 'ROLLBACK AFTER Update Noti Status'
						+ ' - @ErrMsg(' + ISNULL(@LocalErrMsg,'NULL') + ')'
						+ ' - @NotiID(' + ISNULL(CONVERT(VARCHAR,@NotiID),'NULL') + ')'
						+ ' - @NewStatus(' + ISNULL(@NewStatus,'NULL') + ')'
						+ ' - @NewSubject(' + ISNULL(@NewSubject,'NULL') + ')'
						+ ' - @NewContentEN(' + ISNULL(@NewContentEN,'NULL') + ')'
						+ ' - @NewContentCH(' + ISNULL(@NewContentCH,'NULL') + ')'
						+ ' - @NewContentCS(' + ISNULL(@NewContentCS,'NULL') + ')'
						+ ' - @UpdaterID(' + ISNULL(CONVERT(VARCHAR,@UpdaterID),'NULL') + ')'
					)
			END
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR
			,@ErrMsg = 'An error has occurred. Please close this page and try again.'
			,@LocalErrMsg = 'FAILED to UPD Notification Status - ERROR_MESSAGE(' + ISNULL(ERROR_MESSAGE(),'NULL') + ')'
		
		INSERT INTO @tmpUserLog (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT @NotiID
			,@LogActionID
			,@UpdaterID
			,COMPRESS(@ErrLogPrefix + 'ROLLBACK WHILE Update Noti Status'
				+ ' - ERROR_MESSAGE(' + ISNULL(@LocalErrMsg,'NULL') + ')'
				+ ' - @NotiID(' + ISNULL(CONVERT(VARCHAR,@NotiID),'NULL') + ')'
				+ ' - @NewStatus(' + ISNULL(@NewStatus,'NULL') + ')'
				+ ' - @NewSubject(' + ISNULL(@NewSubject,'NULL') + ')'
				+ ' - @NewContentEN(' + ISNULL(@NewContentEN,'NULL') + ')'
				+ ' - @NewContentCH(' + ISNULL(@NewContentCH,'NULL') + ')'
				+ ' - @NewContentCS(' + ISNULL(@NewContentCS,'NULL') + ')'
				+ ' - @UpdaterID(' + ISNULL(CONVERT(VARCHAR,@UpdaterID),'NULL') + ')'
			)
	END CATCH
	
	IF ISNULL(@ErrCode,0) <> 0
	BEGIN
		--roll back transaction
		ROLLBACK TRANSACTION
		
		--return error message
		SELECT @ErrMsg = ISNULL(@ErrMsg,'An error has occurred. Please close this page and try again.')
		
		--write log
		INSERT INTO UserLog (
			LogTime
			,RefID
			,ActionID
			,UserID
			,LogBef
			,LogAft
		)
		SELECT LogTime
			,RefID
			,ActionID
			,UserID
			,LogBef
			,LogAft
		FROM @tmpUserLog
		ORDER BY LogTime
	END
	ELSE
	BEGIN
		/***************************************************************************/
		COMMIT TRANSACTION
		/***************************************************************************/
		--debug log
		INSERT INTO UserLog (
			RefID
			,ActionID
			,UserID
			,LogBef
			,LogAft
		)
		SELECT c.NotiID
			,@LogActionID
			,@UpdaterID
			,COMPRESS(@InfLogPrefix + 'Debug - DONE UPD Notification'
							+ ' - @NewStatus (' + ISNULL(@NewStatus,'NULL') + ')'
							+ ' - Content_en (' + ISNULL(c.Content_en,'NULL') + ')'
							+ ' - Subject (' + ISNULL(c.Subject,'NULL') + ')'
							+ ' - Content_ch (' + ISNULL(c.Content_ch,'NULL') + ')'
							+ ' - Content_cs (' + ISNULL(c.Content_cs,'NULL') + ')')
			,COMPRESS(N'Status = ' + ISNULL(s.Status,'NULL')
							+ ', Subject (' + ISNULL(n.Subject,'NULL') + ')'
							+ ', Content_en (' + ISNULL(n.Content_en,'NULL') + ')'
							+ ', Content_ch (' + ISNULL(n.Content_ch,'NULL') + ')'
							+ ', Content_cs (' + ISNULL(n.Content_cs,'NULL') + ')')
		FROM #tmpCurNoti AS c
			INNER JOIN Notification AS n WITH (NOLOCK) ON c.NotiID = n.NotificationID
			LEFT JOIN NotiStatus AS s WITH (NOLOCK) ON n.StatusID = s.StatusID
		WHERE @LogMode = 'Debug'
		ORDER BY c.NotiID
	END
	
	DROP TABLE #tmpNewNoti
	DROP TABLE #tmpCurNoti
END
