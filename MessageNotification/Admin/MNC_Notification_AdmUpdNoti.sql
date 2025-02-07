/*<info serverAlias="DBCRM-MessageNotification" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE MNC_Notification_AdmUpdNoti
	@NotiID INT
	,@NewStatus VARCHAR(50)
	,@NewSubject NVARCHAR(1000) = NULL
	,@NewContentEN NVARCHAR(MAX) = NULL
	,@NewContentCH NVARCHAR(MAX) = NULL
	,@NewContentCS NVARCHAR(MAX) = NULL
	,@NewContentZHCN NVARCHAR(MAX) = NULL
	,@Remark NVARCHAR(MAX) = NULL
	,@Filename NVARCHAR(MAX) = NULL
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
		20240910@Roy: CRM - Offer New Chinese Simplify for Result Amendment of Cricket (MNC) (#210317)
		20241204@Virgil: CRM - Add Remark and File attachment section (MNC) [Redmine: #214619]
		20241209@Virgil: CRM - Remove Transaction block and add new log mechanic (MNC) [Redmine: #214619]
	
	Param's Explanation:
	
	Example:
*/
BEGIN
	SET NOCOUNT ON
	
	/*
		Reset OUTPUT
	*/
	SELECT @ErrCode = 0
		,@ErrMsg = ''
	
	DECLARE @LogUserID INT
			,@LogActionID SMALLINT
			,@NotiType TINYINT
			,@NotiUpdCnt INT
			,@Updater VARCHAR(50)
			,@LogMode VARCHAR(500)
			,@LocalErrMsg NVARCHAR(MAX)
			--,@InfLogPrefix NVARCHAR(150) = 'Info - [AdmUpdNoti] - '
			--,@ErrLogPrefix NVARCHAR(150) = 'Error - [AdmUpdNoti] - '
	
	DECLARE @LogSPData TABLE (NewValue NVARCHAR(MAX), OldValue NVARCHAR(MAX));

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
	--INSERT INTO UserLog (
	--	RefID
	--	,ActionID
	--	,UserID
	--	,LogBef
	--)
	--SELECT @NotiID
	--	,@LogActionID
	--	,(CASE WHEN @Updater IS NULL THEN @LogUserID ELSE @UpdaterID END)
	--	,COMPRESS(@InfLogPrefix + 'Start UPD Notification'
	--					+ ' - @NotiID(' + ISNULL(CONVERT(VARCHAR,@NotiID),'NULL') + ')'
	--					+ ' - @NewStatus(' + ISNULL(@NewStatus,'NULL') + ')'
	--					+ ' - @NewSubject(' + ISNULL(@NewSubject,'NULL') + ')'
	--					+ ' - @NewContentEN(' + ISNULL(@NewContentEN,'NULL') + ')'
	--					+ ' - @NewContentCH(' + ISNULL(@NewContentCH,'NULL') + ')'
	--					+ ' - @NewContentCS(' + ISNULL(@NewContentCS,'NULL') + ')'
	--					+ ' - @NewContentZHCN(' + ISNULL(@NewContentZHCN,'NULL') + ')'
	--					+ ' - @Remark(' + ISNULL(@Remark,'NULL') + ')'
	--					+ ' - @Filename(' + ISNULL(@Filename,'NULL') + ')'
	--					+ ' - @UpdaterID(' + ISNULL(CONVERT(VARCHAR,@UpdaterID),'NULL') + ')')
	
	-----------------verify before update---------------
	IF @Updater IS NULL
		OR NOT EXISTS (SELECT 1 FROM Notification WITH (NOLOCK) WHERE NotificationID = @NotiID)
	BEGIN
		SELECT @ErrCode = 50006
			,@ErrMsg = (CASE WHEN @Updater IS NULL THEN 'Invalid Updater' ELSE 'Invalid Input NotiID' END)
					+ '. Please close this page and try again.'
			,@LocalErrMsg = CASE WHEN @Updater IS NULL THEN 'INPUT ERROR - NOT EXISTS UpdaterID(' + ISNULL(CONVERT(VARCHAR,@UpdaterID),'NULL') + ')'
							ELSE 'INPUT ERROR - NOT EXISTS NotificationID(' + ISNULL(CONVERT(VARCHAR,@NotiID),'NULL') + ')' END
		
		--INSERT INTO UserLog (
		--	RefID
		--	,ActionID
		--	,UserID
		--	,LogBef
		--)
		--SELECT @NotiID
		--	,@LogActionID
		--	,(CASE WHEN @Updater IS NULL THEN @LogUserID ELSE @UpdaterID END)
		--	,COMPRESS(@ErrLogPrefix + 'FAILED while UPD Notification - ' + @LocalErrMsg
		--				+ ' - @NotiID(' + ISNULL(CONVERT(VARCHAR,@NotiID),'NULL') + ')'
		--				+ ' - @NewStatus(' + ISNULL(@NewStatus,'NULL') + ')'
		--				+ ' - @NewSubject(' + ISNULL(@NewSubject,'NULL') + ')'
		--				+ ' - @NewContentEN(' + ISNULL(@NewContentEN,'NULL') + ')'
		--				+ ' - @NewContentCH(' + ISNULL(@NewContentCH,'NULL') + ')'
		--				+ ' - @NewContentCS(' + ISNULL(@NewContentCS,'NULL') + ')'
		--				+ ' - @NewContentZHCN(' + ISNULL(@NewContentZHCN,'NULL') + ')'
		--				+ ' - @Remark(' + ISNULL(@Remark,'NULL') + ')'
		--				+ ' - @Filename(' + ISNULL(@Filename,'NULL') + ')'
		--				+ ' - @UpdaterID(' + ISNULL(CONVERT(VARCHAR,@UpdaterID),'NULL') + ')'
		--	)
		
		RETURN
	END
	
	-----------------verify @@ in [General Notification] (OST)---------------
	IF EXISTS (SELECT 1 FROM Notification WITH (NOLOCK) WHERE NotificationID = @NotiID AND NotificationType = 1)
		AND @NewStatus = 'Sending'
		AND (
			ISNULL(CHARINDEX ('@@', @NewContentEN),0) = 0
			OR ISNULL(CHARINDEX ('@@', @NewContentCH),0) = 0
			OR ISNULL(CHARINDEX ('@@', @NewContentCS),0) = 0
			OR ISNULL(CHARINDEX ('@@', @NewContentZHCN),0) = 0
		)
	BEGIN
		SELECT @ErrCode = 50006
			,@ErrMsg = 'Missing ''@@'' in Notification content.'
			,@LocalErrMsg = 'Missing ''@@'' in Notification content.'
		
		--INSERT INTO UserLog (
		--	RefID
		--	,ActionID
		--	,UserID
		--	,LogBef
		--)
		--SELECT @NotiID
		--	,@LogActionID
		--	,(CASE WHEN @Updater IS NULL THEN @LogUserID ELSE @UpdaterID END)
		--	,COMPRESS(@ErrLogPrefix + 'FAILED while UPD Notification - ' + @LocalErrMsg
		--				+ ' - @NotiID(' + ISNULL(CONVERT(VARCHAR,@NotiID),'NULL') + ')'
		--				+ ' - @NewStatus(' + ISNULL(@NewStatus,'NULL') + ')'
		--				+ ' - @NewSubject(' + ISNULL(@NewSubject,'NULL') + ')'
		--				+ ' - @NewContentEN(' + ISNULL(@NewContentEN,'NULL') + ')'
		--				+ ' - @NewContentCH(' + ISNULL(@NewContentCH,'NULL') + ')'
		--				+ ' - @NewContentCS(' + ISNULL(@NewContentCS,'NULL') + ')'
		--				+ ' - @NewContentZHCN(' + ISNULL(@NewContentZHCN,'NULL') + ')'
		--				+ ' - @Remark(' + ISNULL(@Remark,'NULL') + ')'
		--				+ ' - @Filename(' + ISNULL(@Filename,'NULL') + ')'
		--				+ ' - @UpdaterID(' + ISNULL(CONVERT(VARCHAR,@UpdaterID),'NULL') + ')'
		--	)
		
		RETURN
	END
	
	-----------------load info---------------
	CREATE TABLE #tmpNewNoti (
		NotiID INT
		,Subject NVARCHAR(1000)
		,Content_en NVARCHAR(MAX)
		,Content_ch NVARCHAR(MAX)
		,Content_cs NVARCHAR(MAX)
		,Content_zhcn NVARCHAR(MAX)
		,Remark NVARCHAR(MAX)
		,Filename NVARCHAR(MAX)
	)
	
	CREATE TABLE #tmpCurNoti (
		NotiID INT
		,Status VARCHAR(50)
		,Subject NVARCHAR(1000)
		,Content_en NVARCHAR(MAX)
		,Content_ch NVARCHAR(MAX)
		,Content_cs NVARCHAR(MAX)
		,Content_zhcn NVARCHAR(MAX)
		,Remark NVARCHAR(MAX)
		,Filename NVARCHAR(MAX)
	)
	
	/***************************************************************************/
	-- BEGIN TRANSACTION
	/***************************************************************************/
	SELECT @NotiType = NotificationType
	FROM Notification WITH (NOLOCK) 
	WHERE NotificationID = @NotiID
	
	--get current Notification
	INSERT INTO #tmpCurNoti (
		NotiID
		,Status
		,Subject
		,Content_en
		,Content_ch
		,Content_cs
		,Content_zhcn
		,Remark
		,Filename
	)
	SELECT n.NotificationID
		,s.Status
		,CASE WHEN n.NotificationType = 2 THEN n.Subject END --LAP only
		,n.Content_en
		,n.Content_ch
		,n.Content_cs
		,n.Content_zhcn
		,n.Remark
		,n.Filename
	FROM Notification AS n WITH (ROWLOCK,UPDLOCK)
		LEFT JOIN NotiStatus AS s WITH (NOLOCK) ON n.StatusID = s.StatusID
	WHERE n.NotificationID = @NotiID
	
	--parse input to new Notification
	;WITH CTE_NewNoti AS (
		SELECT NULLIF(TRIM(@NewContentEN), '') AS Content_en
			,NULLIF(TRIM(@NewContentCH), '') AS Content_ch
			,NULLIF(TRIM(@NewContentCS), '') AS Content_cs
			,NULLIF(TRIM(@NewContentZHCN), '') AS Content_zhcn			
			,NULLIF(TRIM(@NewSubject), '') AS Subject
			,NULLIF(TRIM(@Remark), '') AS Remark
			,NULLIF(TRIM(@Filename), '') AS Filename
	)
	INSERT INTO #tmpNewNoti (
		NotiID
		,Subject
		,Content_en
		,Content_ch
		,Content_cs
		,Content_zhcn
		,Remark
		,Filename 
	)
	SELECT @NotiID
		,Subject
		,Content_en
		,Content_ch
		,Content_cs
		,Content_zhcn
		,Remark
		,Filename 
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

			INSERT INTO @LogSPData
			SELECT CONVERT(NVARCHAR(MAX),(
						SELECT 'Subject' AS 'AffectedField',
								ISNULL(@NewSubject,'NULL') AS 'Subject'
						FOR JSON PATH, ROOT('MNC_Notification_AdmUpdNoti')
					)) AS NewValue,
					CONVERT(NVARCHAR(MAX),(
						SELECT 'Subject' AS 'AffectedField',
								ISNULL(c.Subject,'NULL') AS 'Subject'
						FOR JSON PATH, ROOT('MNC_Notification_AdmUpdNoti')
					)) AS OldValue
			FROM #tmpCurNoti AS c
				INNER JOIN Notification AS n WITH (NOLOCK) ON c.NotiID = n.NotificationID
			WHERE ISNULL(n.Subject,'') <> ISNULL(c.Subject,'')

		END
		ELSE
		BEGIN
			SELECT @ErrCode = 50006
				,@ErrMsg = 'An error has occurred while updating Subject. Please close this page and try again.'
				,@LocalErrMsg = 'UPD Notification Subject - S.T wrong with NO row affected'
			
			--INSERT INTO @tmpUserLog (
			--	RefID
			--	,ActionID
			--	,UserID
			--	,LogBef
			--	,LogAft
			--)
			--SELECT @NotiID
			--	,@LogActionID
			--	,@UpdaterID
			--	,COMPRESS(@ErrLogPrefix + @LocalErrMsg
			--		+ ' - Current @NotiUpdCnt(' + ISNULL(CONVERT(VARCHAR,@NotiUpdCnt),'NULL') + ')'
			--		+ ' - @NotiID(' + ISNULL(CONVERT(VARCHAR,@NotiID),'NULL') + ')'
			--		+ ' - @UpdaterID(' + ISNULL(CONVERT(VARCHAR,@UpdaterID),'NULL') + ')'
			--		+ ' - @NewSubject(' + ISNULL(@NewSubject,'NULL') + ')'
			--		+ ' - tmpNewNoti('
			--					+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
			--								SELECT *
			--								FROM #tmpNewNoti
			--								FOR JSON PATH
			--							))
			--						),'NO ROW') + ')'
			--		+ ' - tmpCurNoti('
			--						+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
			--									SELECT *
			--									FROM #tmpCurNoti
			--									FOR JSON PATH
			--								))
			--							),'NO ROW') + ')')
			--	,COMPRESS(N'Current Subject(' + ISNULL((SELECT Subject FROM Notification WITH (NOLOCK) WHERE NotificationID = @NotiID),'NULL') + ')')
		END
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR
			,@ErrMsg = 'An error has occurred. Please close this page and try again.'
			,@LocalErrMsg = 'FAILED to UPD Notification Subject - ERROR_MESSAGE(' + ISNULL(ERROR_MESSAGE(),'NULL') + ')'
		
		--INSERT INTO @tmpUserLog (
		--	RefID
		--	,ActionID
		--	,UserID
		--	,LogBef
		--)
		--SELECT @NotiID
		--	,@LogActionID
		--	,@UpdaterID
		--	,COMPRESS(@ErrLogPrefix + @LocalErrMsg
		--		+ ' - @NotiID(' + ISNULL(CONVERT(VARCHAR,@NotiID),'NULL') + ')'
		--		+ ' - @NewStatus(' + ISNULL(@NewStatus,'NULL') + ')'
		--		+ ' - @NewSubject(' + ISNULL(@NewSubject,'NULL') + ')'
		--		+ ' - @NewContentEN(' + ISNULL(@NewContentEN,'NULL') + ')'
		--		+ ' - @NewContentCH(' + ISNULL(@NewContentCH,'NULL') + ')'
		--		+ ' - @NewContentCS(' + ISNULL(@NewContentCS,'NULL') + ')'
		--		+ ' - @NewContentZHCN(' + ISNULL(@NewContentZHCN,'NULL') + ')'
		--		+ ' - @Remark(' + ISNULL(@Remark,'NULL') + ')'
		--		+ ' - @Filename(' + ISNULL(@Filename,'NULL') + ')'
		--		+ ' - @UpdaterID(' + ISNULL(CONVERT(VARCHAR,@UpdaterID),'NULL') + ')'
		--		+ ' - tmpNewNoti('
		--						+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
		--									SELECT *
		--									FROM #tmpNewNoti
		--									FOR JSON PATH
		--								))
		--							),'NO ROW') + ')'
		--		+ ' - tmpCurNoti('
		--						+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
		--									SELECT *
		--									FROM #tmpCurNoti
		--									FOR JSON PATH
		--								))
		--							),'NO ROW') + ')')
	END CATCH
	--ELSE IF @NotiType = 2 
	--BEGIN
	--	INSERT INTO @tmpUserLog (
	--		RefID
	--		,ActionID
	--		,UserID
	--		,LogBef
	--	)
	--	SELECT @NotiID
	--		,@LogActionID
	--		,@UpdaterID
	--		,COMPRESS(@InfLogPrefix + 'Debug - UPD Notification.Subject - NO Change')
	--	WHERE @LogMode = 'Debug'
	--END
	
	-------------------------- Content DIFF --------------------------
	IF @ErrCode = 0
		AND EXISTS (
			SELECT 1
			FROM #tmpNewNoti AS n
				INNER JOIN Notification AS c WITH (NOLOCK) ON n.NotiID = c.NotificationID
			WHERE ISNULL(n.Content_en,'') <> ISNULL(c.Content_en,'')
				OR ISNULL(n.Content_ch,'') <> ISNULL(c.Content_ch,'')
				OR ISNULL(n.Content_cs,'') <> ISNULL(c.Content_cs,'')
				OR ISNULL(n.Content_zhcn,'') <> ISNULL(c.Content_zhcn,'')
				OR ISNULL(n.Content_cs,'') <> ISNULL(c.Content_cs,'')
				OR ISNULL(n.Remark,'') <> ISNULL(c.Remark,'')
				OR ISNULL(n.Filename,'') <> ISNULL(c.Filename,'')
		)
	BEGIN TRY
		
		UPDATE c
		SET c.Content_en = (CASE WHEN ISNULL(n.Content_en,'') <> ISNULL(c.Content_en,'') THEN ISNULL(n.Content_en,'') ELSE c.Content_en END)
			,c.Content_ch = (CASE WHEN ISNULL(n.Content_ch,'') <> ISNULL(c.Content_ch,'') THEN ISNULL(n.Content_ch,'') ELSE c.Content_ch END)
			,c.Content_cs = (CASE WHEN ISNULL(n.Content_cs,'') <> ISNULL(c.Content_cs,'') THEN ISNULL(n.Content_cs,'') ELSE c.Content_cs END)
			,c.Content_zhcn = (CASE WHEN ISNULL(n.Content_zhcn,'') <> ISNULL(c.Content_zhcn,'') THEN ISNULL(n.Content_zhcn,'') ELSE c.Content_zhcn END)
			,c.Remark = (CASE WHEN ISNULL(n.Remark,'') <> ISNULL(c.Remark,'') THEN ISNULL(n.Remark,'') ELSE c.Remark END)
			,c.Filename = (CASE WHEN ISNULL(n.Filename,'') <> ISNULL(c.Filename,'') THEN ISNULL(n.Filename,'') ELSE c.Filename END)
			,c.LastModifiedTime = GETDATE()
		FROM Notification AS c WITH (ROWLOCK,UPDLOCK)
			INNER JOIN #tmpNewNoti AS n ON c.NotificationID = n.NotiID
		WHERE ISNULL(n.Content_en,'') <> ISNULL(c.Content_en,'')
				OR ISNULL(n.Content_ch,'') <> ISNULL(c.Content_ch,'')
				OR ISNULL(n.Content_cs,'') <> ISNULL(c.Content_cs,'')
				OR ISNULL(n.Content_zhcn,'') <> ISNULL(c.Content_zhcn,'')
				OR ISNULL(n.Remark,'') <> ISNULL(c.Remark,'')
				OR ISNULL(n.Filename,'') <> ISNULL(c.Filename,'')
		
		--------------------------
		SELECT @NotiUpdCnt = @@ROWCOUNT

		IF @NotiUpdCnt = 1
		BEGIN
			;WITH 
				CTE_Data AS (
				SELECT c.Content_en		AS 'OldContent_en',
						c.Content_ch	AS 'OldContent_ch',
						c.Content_cs	AS 'OldContent_cs',
						c.Content_zhcn	AS 'OldContent_zhcn',
						c.Remark		AS 'OldRemark',
						c.Filename		AS 'OldFilename',
						n.Content_en	AS 'NewContent_en',
						n.Content_ch	AS 'NewContent_ch',
						n.Content_cs	AS 'NewContent_cs',
						n.Content_zhcn	AS 'NewContent_zhcn',
						n.Remark		AS 'NewRemark',
						n.Filename		AS 'NewFilename'
				FROM #tmpCurNoti AS c
					INNER JOIN Notification AS n WITH (NOLOCK) ON c.NotiID = n.NotificationID
				WHERE ISNULL(n.Content_en,'') <> ISNULL(c.Content_en,'')
					OR ISNULL(n.Content_ch,'') <> ISNULL(c.Content_ch,'')
					OR ISNULL(n.Content_cs,'') <> ISNULL(c.Content_cs,'')
					OR ISNULL(n.Content_zhcn,'') <> ISNULL(c.Content_zhcn,'')
					OR ISNULL(n.Remark,'') <> ISNULL(c.Remark,'')
					OR ISNULL(n.Filename,'') <> ISNULL(c.Filename,'')
			)
			INSERT INTO @LogSPData
			SELECT CONVERT(NVARCHAR(MAX),(
						SELECT 'Content'						AS AffectedField,
								ISNULL(NewContent_en,'NULL')	AS Content_en,
								ISNULL(NewContent_ch,'NULL')	AS Content_ch,
								ISNULL(NewContent_cs,'NULL')	AS Content_cs,
								ISNULL(NewContent_zhcn,'NULL')  AS Content_zhcn,
								ISNULL(NewRemark,'NULL')		AS Remark,
								ISNULL(NewFilename,'NULL')		AS Filename
						FROM CTE_Data
						FOR JSON PATH, ROOT('MNC_Notification_AdmUpdNoti')
					)) AS NewValue,
					CONVERT(NVARCHAR(MAX),(
						SELECT 'Content'						AS AffectedField,
								ISNULL(OldContent_en,'NULL')	AS Content_en,
								ISNULL(OldContent_ch,'NULL')	AS Content_ch,
								ISNULL(OldContent_cs,'NULL')	AS Content_cs,
								ISNULL(OldContent_zhcn,'NULL')  AS Content_zhcn,
								ISNULL(OldRemark,'NULL')		AS Remark,
								ISNULL(OldFilename,'NULL')		AS Filename
						FROM CTE_Data
						FOR JSON PATH, ROOT('MNC_Notification_AdmUpdNoti')
					)) AS OldValue

		END
		ELSE
		BEGIN
			SELECT @ErrCode = 50006
				,@ErrMsg = 'An error has occurred while updating Content. Please close this page and try again.'
				,@LocalErrMsg = 'UPD Notification Content - S.T wrong with NO row affected'
			
			--INSERT INTO @tmpUserLog (
			--	RefID
			--	,ActionID
			--	,UserID
			--	,LogBef
			--)
			--SELECT @NotiID
			--	,@LogActionID
			--	,@UpdaterID
			--	,COMPRESS(@ErrLogPrefix + @LocalErrMsg
			--		+ ' - @NotiUpdCnt(' + ISNULL(CONVERT(VARCHAR,@NotiUpdCnt),'NULL') + ')'
			--		+ ' - @NotiID(' + ISNULL(CONVERT(VARCHAR,@NotiID),'NULL') + ')'
			--		+ ' - @NewStatus(' + ISNULL(@NewStatus,'NULL') + ')'
			--		+ ' - @NewSubject(' + ISNULL(@NewSubject,'NULL') + ')'
			--		+ ' - @NewContentEN(' + ISNULL(@NewContentEN,'NULL') + ')'
			--		+ ' - @NewContentCH(' + ISNULL(@NewContentCH,'NULL') + ')'
			--		+ ' - @NewContentCS(' + ISNULL(@NewContentCS,'NULL') + ')'
			--		+ ' - @NewContentZHCN(' + ISNULL(@NewContentZHCN,'NULL') + ')'
			--		+ ' - @Remark(' + ISNULL(@Remark,'NULL') + ')'
			--		+ ' - @Filename(' + ISNULL(@Filename,'NULL') + ')'
			--		+ ' - @UpdaterID(' + ISNULL(CONVERT(VARCHAR,@UpdaterID),'NULL') + ')'
			--		+ ' - tmpNewNoti('
			--					+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
			--								SELECT *
			--								FROM #tmpNewNoti
			--								FOR JSON PATH
			--							))
			--						),'NO ROW') + ')'
			--		+ ' - tmpCurNoti('
			--						+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
			--									SELECT *
			--									FROM #tmpCurNoti
			--									FOR JSON PATH
			--								))
			--							),'NO ROW') + ')')
		END
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR
			,@ErrMsg = 'An error has occurred. Please close this page and try again.'
			,@LocalErrMsg = 'FAILED to UPD Notification Content - ERROR_MESSAGE(' + ISNULL(ERROR_MESSAGE(),'NULL') + ')'
		
		--INSERT INTO @tmpUserLog (
		--	RefID
		--	,ActionID
		--	,UserID
		--	,LogBef
		--)
		--SELECT @NotiID
		--	,@LogActionID
		--	,@UpdaterID
		--	,COMPRESS(@ErrLogPrefix + @LocalErrMsg
		--		+ ' - @NotiID(' + ISNULL(CONVERT(VARCHAR,@NotiID),'NULL') + ')'
		--		+ ' - @NewStatus(' + ISNULL(@NewStatus,'NULL') + ')'
		--		+ ' - @NewSubject(' + ISNULL(@NewSubject,'NULL') + ')'
		--		+ ' - @NewContentEN(' + ISNULL(@NewContentEN,'NULL') + ')'
		--		+ ' - @NewContentCH(' + ISNULL(@NewContentCH,'NULL') + ')'
		--		+ ' - @NewContentCS(' + ISNULL(@NewContentCS,'NULL') + ')'
		--		+ ' - @NewContentZHCN(' + ISNULL(@NewContentZHCN,'NULL') + ')'
		--		+ ' - @Remark(' + ISNULL(@Remark,'NULL') + ')'
		--		+ ' - @Filename(' + ISNULL(@Filename,'NULL') + ')'
		--		+ ' - @UpdaterID(' + ISNULL(CONVERT(VARCHAR,@UpdaterID),'NULL') + ')'
		--		+ ' - tmpNewNoti('
		--						+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
		--									SELECT *
		--									FROM #tmpNewNoti
		--									FOR JSON PATH
		--								))
		--							),'NO ROW') + ')'
		--		+ ' - tmpCurNoti('
		--						+ ISNULL((SELECT CONVERT(NVARCHAR(MAX),(
		--									SELECT *
		--									FROM #tmpCurNoti
		--									FOR JSON PATH
		--								))
		--							),'NO ROW') + ')')
	END CATCH
	--ELSE
	--BEGIN
	--	INSERT INTO @tmpUserLog (
	--		RefID
	--		,ActionID
	--		,UserID
	--		,LogBef
	--	)
	--	SELECT @NotiID
	--		,@LogActionID
	--		,@UpdaterID
	--		,COMPRESS(@InfLogPrefix + 'Debug - UPD Notification.Content(en/ch/cs) - NO Change')
	--	WHERE @LogMode = 'Debug'
	--END
	
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

				--INSERT INTO @tmpUserLog (
				--	RefID
				--	,ActionID
				--	,UserID
				--	,LogBef
				--)
				--SELECT @NotiID
				--	,@LogActionID
				--	,@UpdaterID
				--	,COMPRESS(@ErrLogPrefix + 'ROLLBACK AFTER Update Noti Status'
				--		+ ' - @ErrMsg(' + ISNULL(@LocalErrMsg,'NULL') + ')'
				--		+ ' - @NotiID(' + ISNULL(CONVERT(VARCHAR,@NotiID),'NULL') + ')'
				--		+ ' - @NewStatus(' + ISNULL(@NewStatus,'NULL') + ')'
				--		+ ' - @NewSubject(' + ISNULL(@NewSubject,'NULL') + ')'
				--		+ ' - @NewContentEN(' + ISNULL(@NewContentEN,'NULL') + ')'
				--		+ ' - @NewContentCH(' + ISNULL(@NewContentCH,'NULL') + ')'
				--		+ ' - @NewContentCS(' + ISNULL(@NewContentCS,'NULL') + ')'
				--		+ ' - @NewContentZHCN(' + ISNULL(@NewContentZHCN,'NULL') + ')'
				--		+ ' - @Remark(' + ISNULL(@Remark,'NULL') + ')'
				--		+ ' - @Filename(' + ISNULL(@Filename,'NULL') + ')'
				--		+ ' - @UpdaterID(' + ISNULL(CONVERT(VARCHAR,@UpdaterID),'NULL') + ')'
				--	)
			END
			ELSE
			BEGIN
				INSERT INTO @LogSPData
				SELECT CONVERT(NVARCHAR(MAX),(
							SELECT 'Status' AS 'AffectedField',
									ISNULL(s.Status,'NULL') AS 'Status'
							FOR JSON PATH, ROOT('MNC_Notification_AdmUpdNoti')
						)) AS NewValue,
						CONVERT(NVARCHAR(MAX),(
							SELECT 'Status' AS 'AffectedField',
									ISNULL(c.Status,'NULL') AS 'Status'
							FOR JSON PATH, ROOT('MNC_Notification_AdmUpdNoti')
						)) AS OldValue
				FROM #tmpCurNoti AS c
					INNER JOIN Notification AS n WITH (NOLOCK) ON c.NotiID = n.NotificationID
					LEFT JOIN NotiStatus AS s WITH (NOLOCK) ON n.StatusID = s.StatusID
				WHERE ISNULL(c.Status,'') <> ISNULL(s.Status,'')
			END
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR
			,@ErrMsg = 'An error has occurred. Please close this page and try again.'
			,@LocalErrMsg = 'FAILED to UPD Notification Status - ERROR_MESSAGE(' + ISNULL(ERROR_MESSAGE(),'NULL') + ')'
		
		--INSERT INTO @tmpUserLog (
		--	RefID
		--	,ActionID
		--	,UserID
		--	,LogBef
		--)
		--SELECT @NotiID
		--	,@LogActionID
		--	,@UpdaterID
		--	,COMPRESS(@ErrLogPrefix + 'ROLLBACK WHILE Update Noti Status'
		--		+ ' - ERROR_MESSAGE(' + ISNULL(@LocalErrMsg,'NULL') + ')'
		--		+ ' - @NotiID(' + ISNULL(CONVERT(VARCHAR,@NotiID),'NULL') + ')'
		--		+ ' - @NewStatus(' + ISNULL(@NewStatus,'NULL') + ')'
		--		+ ' - @NewSubject(' + ISNULL(@NewSubject,'NULL') + ')'
		--		+ ' - @NewContentEN(' + ISNULL(@NewContentEN,'NULL') + ')'
		--		+ ' - @NewContentCH(' + ISNULL(@NewContentCH,'NULL') + ')'
		--		+ ' - @NewContentCS(' + ISNULL(@NewContentCS,'NULL') + ')'
		--		+ ' - @NewContentZHCN(' + ISNULL(@NewContentZHCN,'NULL') + ')'
		--		+ ' - @Remark(' + ISNULL(@Remark,'NULL') + ')'
		--		+ ' - @Filename(' + ISNULL(@Filename,'NULL') + ')'
		--		+ ' - @UpdaterID(' + ISNULL(CONVERT(VARCHAR,@UpdaterID),'NULL') + ')'
		--	)
	END CATCH

	-------------------------- Write UserLog --------------------------
	IF ISNULL(@ErrCode,0) <> 0
	BEGIN
		--roll back transaction
		--ROLLBACK TRANSACTION
		
		--return error message
		SELECT @ErrMsg = ISNULL(@ErrMsg,'An error has occurred. Please close this page and try again.')
		
	END
	--ELSE
	--BEGIN
		/***************************************************************************/
		--COMMIT TRANSACTION
		/***************************************************************************/

		--INSERT INTO UserLog (
		--	RefID
		--	,ActionID
		--	,UserID
		--	,LogBef
		--	,LogAft
		--)
		--SELECT c.NotiID
		--	,@LogActionID
		--	,@UpdaterID
		--	,COMPRESS(@InfLogPrefix + 'Debug - DONE UPD Notification'
		--					+ ' - @NewStatus (' + ISNULL(@NewStatus,'NULL') + ')'
		--					+ ' - Content_en (' + ISNULL(c.Content_en,'NULL') + ')'
		--					+ ' - Subject (' + ISNULL(c.Subject,'NULL') + ')'
		--					+ ' - Content_ch (' + ISNULL(c.Content_ch,'NULL') + ')'
		--					+ ' - Content_cs (' + ISNULL(c.Content_cs,'NULL') + ')'
		--					+ ' - Content_zhcn (' + ISNULL(c.Content_zhcn,'NULL') + ')')
		--					+ ' - Remark (' + ISNULL(c.Remark,'NULL') + ')'
		--					+ ' - Filename (' + ISNULL(c.Filename,'NULL') + ')'
		--	,COMPRESS(N'Status = ' + ISNULL(s.Status,'NULL')
		--					+ ', Subject (' + ISNULL(n.Subject,'NULL') + ')'
		--					+ ', Content_en (' + ISNULL(n.Content_en,'NULL') + ')'
		--					+ ', Content_ch (' + ISNULL(n.Content_ch,'NULL') + ')'
		--					+ ', Content_cs (' + ISNULL(n.Content_cs,'NULL') + ')'
		--					+ ', Content_zhcn (' + ISNULL(n.Content_zhcn,'NULL') + ')')
		--					+ ', Remark (' + ISNULL(n.Remark,'NULL') + ')'
		--					+ ', Filename (' + ISNULL(n.Filename,'NULL') + ')'
		--FROM #tmpCurNoti AS c
		--	INNER JOIN Notification AS n WITH (NOLOCK) ON c.NotiID = n.NotificationID
		--	LEFT JOIN NotiStatus AS s WITH (NOLOCK) ON n.StatusID = s.StatusID
		--WHERE @LogMode = 'Debug'
		--ORDER BY c.NotiID
	--END

	-- Insert log to UserLog
	INSERT INTO UserLog (
		LogTime
		,RefID
		,ActionID
		,UserID
		,NewValue
		,OldValue
	)
	SELECT GETDATE()
		,@NotiID
		,@LogActionID
		,@UpdaterID
		,NewValue
		,OldValue
	FROM @LogSPData
	
	DROP TABLE #tmpNewNoti
	DROP TABLE #tmpCurNoti
END
