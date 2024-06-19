/*<info serverAlias="DBCRM-MessageNotification" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE MNC_Notification_AdmUpdNotiSts
	@NotiID INT
	,@NewStatus VARCHAR(50)
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
		,@NewStatusID TINYINT
		,@CurStatus VARCHAR(50)
		,@Updater VARCHAR(50)
		,@ErrLogPrefix NVARCHAR(150) = 'Error - Adm - '
		,@InfLogPrefix NVARCHAR(150) = 'Info - Adm - '
	
	SELECT @LogUserID = TRY_CONVERT(INT, VValue)
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 2 --ID of StarixIT
	
	SELECT @LogActionID = ActionID
	FROM LogAction WITH (NOLOCK)
	WHERE ActName = ISNULL(OBJECT_NAME(@@PROCID),'Unknown')
	
	----------------------------------------------------------------
	INSERT INTO UserLog (
		RefID
		,ActionID
		,UserID
		,LogBef
	)
	SELECT @NotiID
		,@LogActionID
		,@LogUserID
		,COMPRESS(@InfLogPrefix + 'Debug - Start UPD Notification Status'
						+ ' - @NotiID(' + ISNULL(CONVERT(VARCHAR,@NotiID),'NULL') + ')'
						+ ' - @NewStatus(' + ISNULL(@NewStatus,'NULL') + ')'
						+ ' - @UpdaterID(' + ISNULL(CONVERT(VARCHAR,@UpdaterID),'NULL') + ')')
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 13 --LogMode
		AND VValue = 'Debug'
	
	-----------------load info---------------
	SELECT @NewStatus = (CASE WHEN TRIM(@NewStatus) = 'Failed' THEN 'Failed to Send' ELSE TRIM(@NewStatus) END)
	
	SELECT @NewStatusID = StatusID
	FROM NotiStatus WITH (NOLOCK)
	WHERE Status = @NewStatus
	
	SELECT @NotiType = n.NotificationType
		,@CurStatus = s.Status
	FROM Notification AS n WITH (NOLOCK)
		INNER JOIN NotiStatus AS s WITH (NOLOCK) ON n.StatusID = s.StatusID
	WHERE n.NotificationID = @NotiID
	
	SELECT @Updater = COALESCE((SELECT username FROM bodb02.dbo.Customer WITH (NOLOCK) WHERE CustID = @UpdaterID),CONVERT(VARCHAR,@UpdaterID),'Updater(NULL)')
	
	DROP TABLE IF EXISTS #tmpConsisSts
	CREATE TABLE #tmpConsisSts (
		StatusID TINYINT
		,Status VARCHAR(50)
	)
	
	--hard code status based on NotiType - follow MNC_Notification_AdmSelNoti
	;WITH CTE_Sts AS (
		SELECT 1 AS NotiType--Msg
			,s.StatusID
			,s.Status
		FROM STRING_SPLIT('New,Draft,Cancelled,Sending,Sent,Failed to Send', ',') AS m
			INNER JOIN NotiStatus AS s WITH (NOLOCK) ON m.value = s.Status
		
		UNION ALL
		
		SELECT 2 AS NotiType--LAP
			,s.StatusID
			,s.Status
		FROM STRING_SPLIT('New,Active,Inactive', ',') AS l
			INNER JOIN NotiStatus AS s WITH (NOLOCK) ON l.value = s.Status
	)
	INSERT INTO #tmpConsisSts (
		StatusID
		,Status
	)
	SELECT DISTINCT s.StatusID
		,s.Status
	FROM CTE_Sts AS s
	WHERE s.NotiType = @NotiType
	
	/* start verify before update status */
	IF @NewStatusID IS NULL
		OR NOT EXISTS (SELECT 1 FROM Notification WITH (NOLOCK) WHERE NotificationID = @NotiID)
	BEGIN
		SELECT @ErrCode = 50005
			,@ErrMsg = 'INPUT ERROR - NOT EXISTS NotificationID(' + ISNULL(CONVERT(VARCHAR,@NotiID),'NULL') + ') OR NOT EXISTS Status(' + ISNULL(@NewStatus,'NULL') + ')'
		
		INSERT INTO UserLog (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT @NotiID
			,@LogActionID
			,@LogUserID
			,COMPRESS(@ErrLogPrefix + 'FAILED while UPD Notification Status'
						+ ' - @NotiID(' + ISNULL(CONVERT(VARCHAR,@NotiID),'NULL') + ')'
						+ ' - @NewStatus(' + ISNULL(@NewStatus,'NULL') + ')'
						+ ' - @UpdaterID(' + ISNULL(CONVERT(VARCHAR,@UpdaterID),'NULL') + ')'
						+ ' - ERROR_MESSAGE(' + ISNULL(@ErrMsg,'NULL') + ')')
		
		RETURN
	END
	
	--current Status = New Status
	IF @CurStatus = @NewStatus
	BEGIN
		INSERT INTO UserLog (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT @NotiID
			,@LogActionID
			,@LogUserID
			,COMPRESS(@InfLogPrefix + 'UPD Notification status - NO Change because current Status = New Status(' + ISNULL(@NewStatus,'NULL') + ')'
							+ ' - @NotiID(' + ISNULL(CONVERT(VARCHAR,@NotiID),'NULL') + ')'
							+ ' - @UpdaterID(' + ISNULL(CONVERT(VARCHAR,@UpdaterID),'NULL') + ')')
		RETURN
	END
	
	--consistency between NotiType and @NewStatus
	IF NOT EXISTS (SELECT 1 FROM #tmpConsisSts WHERE StatusID = @NewStatusID)
	BEGIN
		SELECT @ErrCode = 50005
			,@ErrMsg = 'Unable to modify NotificationID(' + ISNULL(CONVERT(VARCHAR,@NotiID),'NULL') + ') status to [' + ISNULL(@NewStatus,'NULL') + ']'
						+ ' due to inconsistent with NotificationType(' + ISNULL(CONVERT(VARCHAR,@NotiType),'NULL') + ')'
		
		INSERT INTO UserLog (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT @NotiID
			,@LogActionID
			,@LogUserID
			,COMPRESS(@ErrLogPrefix + 'FAILED while UPD Notification Status'
						+ ' - @NewStatus(' + ISNULL(@NewStatus,'NULL') + ')'
						+ ' - @UpdaterID(' + ISNULL(CONVERT(VARCHAR,@UpdaterID),'NULL') + ')'
						+ ' - ERROR_MESSAGE(' + ISNULL(@ErrMsg,'NULL') + ')')
		
		RETURN
	END
	
	--Sending Check
	IF @NewStatus = 'Sending'
		AND EXISTS (SELECT 1 FROM Notification WITH (NOLOCK) WHERE NotificationID = @NotiID AND RefID IS NOT NULL)
	BEGIN
		SELECT @ErrCode = 50005
			,@ErrMsg = 'Unable to modify NotificationID(' + ISNULL(CONVERT(VARCHAR,@NotiID),'NULL') + ') status to [Sending]'
						+ ' due to an existing MessageID(' + CONVERT(VARCHAR,RefID) + ')'
		FROM Notification WITH (NOLOCK)
		WHERE NotificationID = @NotiID
			AND RefID IS NOT NULL
		
		INSERT INTO UserLog (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT @NotiID
			,@LogActionID
			,@LogUserID
			,COMPRESS(@ErrLogPrefix + 'FAILED while UPD Notification Status'
						+ ' - @NewStatus(' + ISNULL(@NewStatus,'NULL') + ')'
						+ ' - @UpdaterID(' + ISNULL(CONVERT(VARCHAR,@UpdaterID),'NULL') + ')'
						+ ' - ERROR_MESSAGE(' + ISNULL(@ErrMsg,'NULL') + ')')
		
		RETURN
	END
	
	--Sent Check
	IF @NewStatus = 'Sent'
		AND EXISTS (SELECT 1 FROM Notification WITH (NOLOCK) WHERE NotificationID = @NotiID AND RefID IS NULL)
	BEGIN
		SELECT @ErrCode = 50005
			,@ErrMsg = 'Unable to modify NotificationID(' + ISNULL(CONVERT(VARCHAR,@NotiID),'NULL') + ') status to [Sent]'
						+ ' due to an NOT EXISTS REFID'
		
		INSERT INTO UserLog (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT @NotiID
			,@LogActionID
			,@LogUserID
			,COMPRESS(@ErrLogPrefix + 'FAILED while UPD Notification Status'
						+ ' - @NewStatus(' + ISNULL(@NewStatus,'NULL') + ')'
						+ ' - @UpdaterID(' + ISNULL(CONVERT(VARCHAR,@UpdaterID),'NULL') + ')'
						+ ' - ERROR_MESSAGE(' + ISNULL(@ErrMsg,'NULL') + ')')
		
		RETURN
	END
	
	-------------------------------update Noti status------------------------------------
	BEGIN TRY
		BEGIN TRANSACTION
			DECLARE @NotiUpdCnt INT
				,@CExtraInfo NVARCHAR(MAX)
				,@NExtraInfo NVARCHAR(MAX)
				,@CurrTime DATETIME = GETDATE()
			
			UPDATE Notification WITH (ROWLOCK,UPDLOCK)
			SET StatusID = @NewStatusID
				,LastModifiedTime = @CurrTime
			WHERE NotificationID = @NotiID
				AND StatusID <> @NewStatusID
			
			SELECT @NotiUpdCnt = @@ROWCOUNT
			
			--special handle for changed Msg Notification status -> [Sending]
			IF @NotiUpdCnt = 1
				AND @NotiType = 1
				AND @NewStatus = 'Sending'
			BEGIN
				SELECT @CExtraInfo = ISNULL(ExtraInfo,'')
				FROM NotificationExtra WITH (NOLOCK)
				WHERE NotificationID = @NotiID
				
				--update MsgSender
				SELECT @NExtraInfo = JSON_MODIFY(@CExtraInfo,'$[0].MsgSender', @Updater)
				SELECT @NExtraInfo = JSON_MODIFY(@NExtraInfo,'$[0].MsgSendDate', CONVERT(VARCHAR,@CurrTime,127))
				
				UPDATE NotificationExtra WITH (ROWLOCK,UPDLOCK)
				SET ExtraInfo = @NExtraInfo
				WHERE NotificationID = @NotiID
			END
			
			--special handle for changed LAP Notification status -> [Active]
			IF @NotiUpdCnt = 1
				AND @NotiType = 2
				AND @NewStatus = 'Active'
			BEGIN
				SELECT @CExtraInfo = ISNULL(ExtraInfo,'')
				FROM NotificationExtra WITH (NOLOCK)
				WHERE NotificationID = @NotiID
				
				--update LapSender
				SELECT @NExtraInfo = JSON_MODIFY(@CExtraInfo,'$[0].LapSender', @Updater)
				SELECT @NExtraInfo = JSON_MODIFY(@NExtraInfo,'$[0].LapSendDate', CONVERT(VARCHAR,@CurrTime,127))
				
				UPDATE NotificationExtra WITH (ROWLOCK,UPDLOCK)
				SET ExtraInfo = @NExtraInfo
				WHERE NotificationID = @NotiID
			END
		COMMIT TRANSACTION
		
		--------------------------
		INSERT INTO UserLog (
			RefID
			,ActionID
			,UserID
			,LogBef
			,LogAft
		)
		SELECT @NotiID
			,@LogActionID
			,@LogUserID
			,COMPRESS(@InfLogPrefix + 'Changed NotificationID Status from [' + ISNULL(@CurStatus,'NULL') + '] to [' + ISNULL(@NewStatus,'NULL') + ']'
							+ ' - Updater (' + ISNULL(CONVERT(VARCHAR,@UpdaterID),'NULL') + ') = ' + @Updater
							+ ' - NotificationExtra.ExtraInfo '
								+ CASE WHEN @CExtraInfo IS NULL THEN 'NO Change' ELSE 'before (' + ISNULL(@CExtraInfo,'NULL') + ')' END)
			,COMPRESS(CASE WHEN @CExtraInfo IS NOT NULL THEN ISNULL(@NExtraInfo,'NULL') END)
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR --output for web
			,@ErrMsg = 'FAILED to UPD Notification status'
						+ ' - @NotiID(' + ISNULL(CONVERT(VARCHAR,@NotiID),'NULL') + ')'
						+ ' - @NewStatus(' + ISNULL(@NewStatus,'NULL') + ')'
						+ ' - @UpdaterID(' + ISNULL(CONVERT(VARCHAR,@UpdaterID),'NULL') + ')'
						+ ' - ERROR_MESSAGE(' + ISNULL(ERROR_MESSAGE(),'NULL') + ')' --output for web
		
		ROLLBACK TRANSACTION
		
		--------------------------
		INSERT INTO UserLog (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT @NotiID
			,@LogActionID
			,@LogUserID
			,COMPRESS(@ErrLogPrefix + @ErrMsg)
	END CATCH
	
	DROP TABLE #tmpConsisSts
END