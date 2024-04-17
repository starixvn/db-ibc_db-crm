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
		,@ErrLogPrefix NVARCHAR(150) = 'Error - '
		,@InfLogPrefix NVARCHAR(150) = 'Info - '
	
	SELECT @LogUserID = TRY_CONVERT(INT, VValue)
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 2 --ID of StarixIT
	
	SELECT @LogActionID = ActionID
	FROM LogAction WITH (NOLOCK)
	WHERE ActName = ISNULL(OBJECT_NAME(@@PROCID),'Unknown')
	
	SELECT @NewStatusID = StatusID
	FROM NotiStatus WITH (NOLOCK)
	WHERE Status = @NewStatus
	
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
		,@InfLogPrefix + 'Debug log Start UPD Notification Status with @NotiID = ' + ISNULL(CONVERT(VARCHAR,@NotiID),'NULL')
						+ ', @NewStatus = ' + ISNULL(@NewStatus,'NULL')
						+ ', @UpdaterID = ' + ISNULL(CONVERT(VARCHAR,@UpdaterID),'NULL')
						+ ', @ErrCode = ' + ISNULL(CONVERT(VARCHAR,@ErrCode),'NULL')
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 13 --LogMode
		AND VValue = 'Debug'
	
	--current Status = New Status
	IF EXISTS (SELECT 1 FROM Notification WITH (NOLOCK) WHERE NotificationID = @NotiID AND StatusID = @NewStatusID)
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
			,@InfLogPrefix + 'UPD Notification status - NO Change because current Status = New Status(' + ISNULL(@NewStatus,'NULL') + ')'
		RETURN
	END
	
	-----------------load info---------------
	SELECT @NotiType = n.NotificationType
		,@CurStatus = s.Status
	FROM Notification AS n WITH (NOLOCK)
		INNER JOIN NotiStatus AS s WITH (NOLOCK) ON n.StatusID = s.StatusID
	WHERE n.NotificationID = @NotiID
	
	SELECT @Updater = COALESCE((SELECT username FROM bodb02.dbo.Customer WITH (NOLOCK) WHERE CustID = @UpdaterID),CONVERT(VARCHAR,@UpdaterID),'Updater(NULL)')
	
	-----------------verify before update Noti status---------------
	IF @NewStatusID IS NULL
		OR NOT EXISTS (SELECT 1 FROM Notification WITH (NOLOCK) WHERE NotificationID = @NotiID)
	BEGIN
		SELECT @ErrCode = 50005
			,@ErrMsg = 'INPUT ERROR - NOT EXISTS NotificationID(' + ISNULL(CONVERT(VARCHAR,@NotiID),'NULL') + ') OR NOT EXISTS Status(' + ISNULL(@NewStatus,'NULL') + ')'
		
		INSERT INTO [Log] (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT @NotiID
			,@LogActionID
			,@LogUserID
			,@ErrLogPrefix + 'FAILED while UPD Notification Status - @NotiID = ' + ISNULL(CONVERT(VARCHAR,@NotiID),'NULL')
						+ ', @NewStatus = ' + ISNULL(@NewStatus,'NULL')
						+ ', @UpdaterID = ' + ISNULL(CONVERT(VARCHAR,@UpdaterID),'NULL')
						+ ', @ErrCode = ' + ISNULL(CONVERT(VARCHAR,@ErrCode),'NULL')
						+ ', @ErrMsg = ' + ISNULL(@ErrMsg,'NULL')
		
		RETURN
	END
	
	CREATE TABLE #tmpValidSts (
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
	INSERT INTO #tmpValidSts (
		StatusID
		,Status
	)
	SELECT DISTINCT s.StatusID
		,s.Status
	FROM CTE_Sts AS s
	WHERE s.NotiType = @NotiType
	
	IF NOT EXISTS (SELECT 1 FROM #tmpValidSts WHERE StatusID = @NewStatusID)
	BEGIN
		SELECT @ErrCode = 50005
			,@ErrMsg = 'NotificationID(' + ISNULL(CONVERT(VARCHAR,@NotiID),'NULL') + ') can NOT change status to [' + ISNULL(@NewStatus,'NULL') + ']'
						+ ' due to inconsistent with NotificationType(' + ISNULL(CONVERT(VARCHAR,@NotiType) + '','NULL') + ')'
		
		INSERT INTO [Log] (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT @NotiID
			,@LogActionID
			,@LogUserID
			,@ErrLogPrefix + 'FAILED while UPD Notification Status - ' + @ErrMsg
						+ ', @NewStatus = ' + ISNULL(@NewStatus,'NULL')
						+ ', @UpdaterID = ' + ISNULL(CONVERT(VARCHAR,@UpdaterID),'NULL')
		
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
			
			--special handle for changed Msg Notification status from [New] -> [Sending]
			IF @NotiUpdCnt = 1
				AND @NotiType = 1
				AND @CurStatus = 'New' AND @NewStatus = 'Sending'
			BEGIN
				SELECT @CExtraInfo = ISNULL(ExtraInfo,'')
				FROM NotificationExtra WITH (NOLOCK)
				WHERE NotificationID = @NotiID
				
				--update MsgSender
				SELECT @NExtraInfo = JSON_MODIFY(@CExtraInfo,'$.MsgSender', @Updater)
				SELECT @NExtraInfo = JSON_MODIFY(@NExtraInfo,'$.MsgSendDate', CONVERT(VARCHAR,@CurrTime,127))
				
				UPDATE NotificationExtra WITH (ROWLOCK,UPDLOCK)
				SET ExtraInfo = @NExtraInfo
				WHERE NotificationID = @NotiID
			END
			
			--special handle for changed LAP Notification status from [New] -> [Active]
			IF @NotiUpdCnt = 1
				AND @NotiType = 2
				AND @CurStatus = 'New' AND @NewStatus = 'Active'
			BEGIN
				SELECT @CExtraInfo = ISNULL(ExtraInfo,'')
				FROM NotificationExtra WITH (NOLOCK)
				WHERE NotificationID = @NotiID
				
				--update LapSender
				SELECT @NExtraInfo = JSON_MODIFY(@CExtraInfo,'$.LapSender', @Updater)
				SELECT @NExtraInfo = JSON_MODIFY(@NExtraInfo,'$.LapSendDate', CONVERT(VARCHAR,@CurrTime,127))
				
				UPDATE NotificationExtra WITH (ROWLOCK,UPDLOCK)
				SET ExtraInfo = @NExtraInfo
				WHERE NotificationID = @NotiID
			END
		COMMIT TRANSACTION
		
		--------------------------
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
			,@InfLogPrefix + 'Changed NotificationID Status from [' + ISNULL(@CurStatus,'NULL') + '] to [' + ISNULL(@NewStatus,'NULL') + '] - Updater (' + ISNULL(CONVERT(VARCHAR,@UpdaterID) + '','NULL') + ') = ' + @Updater
							+ ' - NotificationExtra.ExtraInfo '
							+ CASE WHEN @CExtraInfo IS NULL THEN 'NO Change' ELSE 'before (' + ISNULL(@CExtraInfo,'NULL') + ')' END
			,CASE WHEN @CExtraInfo IS NOT NULL THEN ISNULL(@NExtraInfo,'NULL') END
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR --output for web
			,@ErrMsg = 'FAILED to UPD Notification status - ERROR_MESSAGE(' + ISNULL(ERROR_MESSAGE(),'NULL') + ')' --output for web
		
		ROLLBACK TRANSACTION
		
		--------------------------
		INSERT INTO [Log] (
			RefID
			,ActionID
			,UserID
			,LogBef
		)
		SELECT @NotiID
			,@LogActionID
			,@LogUserID
			,@ErrLogPrefix + 'ROLLBACK UPD Notification Status - @NewStatus' + ISNULL(@NewStatus,'NULL') + ')'
				+ '- @UpdaterID(' + ISNULL(CONVERT(VARCHAR,@UpdaterID),'NULL') + ')'
				+ ' - ERROR_MESSAGE(' + @ErrMsg + ')'
	END CATCH
	
	DROP TABLE IF EXISTS #tmpValidSts
END