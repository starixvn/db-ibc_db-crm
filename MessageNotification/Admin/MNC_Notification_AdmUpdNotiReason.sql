/*<info serverAlias="DBCRM-MessageNotification" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
USE MessageNotification
GO

CREATE PROCEDURE MNC_Notification_AdmUpdNotiReason
	@NotiID		INT
	,@ReasonID	INT
	,@UpdaterID INT
	,@ErrCode	INT = 0 OUTPUT
	,@ErrMsg	NVARCHAR(2000) = '' OUTPUT
AS
/*
	Created: 20250305@Virgil
	Task: CRM - Message Notifications Center for Result Amendment - Add Reason [Redmine #219040]
	DB: DBCRM-MessageNotification

	Revisions:
		20250305@Virgil: Initial SP [Redmine #219040]
		20250403@Virgil: Hotfix - The Message Notifications Center for Result Amendment has been duplicated [Redmine #222859]
	
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
	
	DECLARE @LogSPData TABLE (NewValue NVARCHAR(MAX), OldValue NVARCHAR(MAX));

	SELECT @LogUserID = TRY_CONVERT(INT, VValue)
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 2 --ID of StarixIT
	
	-- Insert if NOT EXISTS
	INSERT INTO LogAction (ActName)
	SELECT o.[name]
	FROM sys.objects AS o WITH (NOLOCK)
	WHERE o.[is_ms_shipped] = 0 --created by user
		AND o.[type] IN (
			'P', -- stored procedures
			'FN', -- scalar functions 
			'IF', -- inline table-valued functions
			'TF' -- table-valued functions
		)
		AND o.[name] NOT LIKE '_delete%'
		AND o.[name] NOT LIKE '[_delete%'
		AND o.[name] NOT LIKE '_DEL%'
		AND o.[name] NOT LIKE 'DEL_%'
		AND NOT EXISTS (
			SELECT 1
			FROM LogAction AS a
			WHERE a.ActName = o.[name]
		)
	
	SELECT @LogActionID = ActionID
	FROM LogAction WITH (NOLOCK)
	WHERE ActName = ISNULL(OBJECT_NAME(@@PROCID),'Unknown')
	
	SELECT @Updater = username
	FROM bodb02.dbo.Customer WITH (NOLOCK)
	WHERE CustID = @UpdaterID
	
	-----------------verify input before update---------------
	IF @Updater IS NULL
		OR NOT EXISTS (SELECT 1 FROM Notification WITH (NOLOCK) WHERE NotificationID = @NotiID)
	BEGIN
		SELECT @ErrCode = 50006
			,@ErrMsg = (CASE WHEN @Updater IS NULL THEN 'Invalid Updater' ELSE 'Invalid Input NotiID' END)
					+ '. Please close this page and try again.'
		
		RETURN
	END
	
	-----------------load info---------------
	CREATE TABLE #tmpNewNoti (
		NotiID		INT
		,ReasonID	INT
	)
	
	CREATE TABLE #tmpCurNoti (
		NotiID		INT
		,ReasonID	INT
	)
	
	SELECT @NotiType = NotificationType
	FROM Notification WITH (NOLOCK) 
	WHERE NotificationID = @NotiID
	
	-- get current Notification
	INSERT INTO #tmpCurNoti (
		NotiID
		,ReasonID
	)
	SELECT n.NotificationID
		, ReasonID
	FROM Notification AS n WITH (NOLOCK)
	WHERE n.NotificationID = @NotiID
	
	--parse input to new Notification
	INSERT INTO #tmpNewNoti (
		NotiID
		,ReasonID
	)
	SELECT @NotiID AS NotiID
		,NULLIF(@ReasonID, '') AS ReasonID

	
	-------------------------- ReasonID DIFF --------------------------
	IF @ErrCode = 0
		AND EXISTS (
			SELECT 1
			FROM #tmpNewNoti AS n
				INNER JOIN Notification AS c WITH (NOLOCK) ON n.NotiID = c.NotificationID
			WHERE ISNULL(n.ReasonID,'') <> ISNULL(c.ReasonID,'')
		)
	BEGIN TRY
		
		UPDATE c
		SET c.ReasonID = (CASE WHEN ISNULL(n.ReasonID,'') <> ISNULL(c.ReasonID,'') THEN ISNULL(n.ReasonID,'') ELSE c.ReasonID END)
		FROM Notification AS c WITH (ROWLOCK,UPDLOCK)
			INNER JOIN #tmpNewNoti AS n ON c.NotificationID = n.NotiID
		WHERE ISNULL(n.ReasonID,'') <> ISNULL(c.ReasonID,'')
		
		SELECT @NotiUpdCnt = @@ROWCOUNT

		IF @NotiUpdCnt = 1
		BEGIN
			;WITH 
				CTE_Data AS (
					SELECT c.ReasonID	AS 'OldReasonID',
							n.ReasonID	AS 'NewReasonID'
					FROM #tmpCurNoti AS c
						INNER JOIN Notification AS n WITH (NOLOCK) ON c.NotiID = n.NotificationID
					WHERE ISNULL(n.ReasonID,'') <> ISNULL(c.ReasonID,'')
				)
			INSERT INTO @LogSPData
			SELECT CONVERT(NVARCHAR(MAX),(
						SELECT 'ReasonID'					AS AffectedField,
								ISNULL(NewReasonID, 0)		AS ReasonID
						FROM CTE_Data
						FOR JSON PATH, ROOT('MNC_Notification_AdmUpdNotiReason')
					)) AS NewValue,
					CONVERT(NVARCHAR(MAX),(
						SELECT 'ReasonID'					AS AffectedField,
								ISNULL(OldReasonID, 0)		AS ReasonID
						FROM CTE_Data
						FOR JSON PATH, ROOT('MNC_Notification_AdmUpdNotiReason')
					)) AS OldValue

		END
		ELSE
		BEGIN
			SELECT @ErrCode = 50006
				,@ErrMsg = 'An error has occurred while updating Reason. Please close this page and try again.'
			
		END
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR
			,@ErrMsg = 'An error has occurred. Please close this page and try again.'

	END CATCH
	

	-------------------------- Write UserLog --------------------------
	IF ISNULL(@ErrCode,0) <> 0
	BEGIN		
		--return error message
		SELECT @ErrMsg = ISNULL(@ErrMsg,'An error has occurred. Please close this page and try again.')
		
	END

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