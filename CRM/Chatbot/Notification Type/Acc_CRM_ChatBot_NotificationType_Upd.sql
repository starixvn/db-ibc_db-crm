/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_ChatBot_NotificationType_Upd]
	@UserId					INT
	,@NotificationTypeId	SMALLINT
	,@NotificationTypeName	NVARCHAR(500)
	,@RecipientTypeIds	    VARCHAR(200)
	,@ChatTypeIds			VARCHAR(200)
	,@SystemId				TINYINT
	,@ErrCode				INT = 0 OUTPUT
	,@ErrMsg				NVARCHAR(2000) = '' OUTPUT
	,@LoginIP				NVARCHAR(20) = ''
AS
/*
Created: 20200810@Malcolm
Task :  update a notification type
DB: DBCRM/bodb_CRM
Original:
	Revisions:
		- 20200810@Malcolm: Initialize SPs [Redmine: #130544]
	Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @NewValues NVARCHAR(MAX),  @OldValues NVARCHAR(MAX), @RecipientTypeXML XML, @ChatTypeXML XML, @SystemXML XML,
			@Old_SystemId TINYINT, @Old_NotificationTypeName NVARCHAR(500)

	DECLARE @Tmp TABLE 
	(
		NotificationTypeId		SMALLINT
		,NotificationTypeName	NVARCHAR(500)
		,SystemId				TINYINT
		,RecipientTypeId		TINYINT
		,ChatTypeId				TINYINT
		,Type                   TINYINT
	)
	-- Check permission

	-- Check exists NotificationTypeId
	IF NOT EXISTS (SELECT 1 FROM dbo.crmNotificationType WITH (NOLOCK) WHERE NotificationTypeId = @NotificationTypeId)
	BEGIN
		SELECT @ErrCode = 101, @ErrMsg = 'The Notification Type does not exists, please check again!'
		RETURN
	END

	-- Check exists NotificationTypeName
	IF EXISTS (SELECT 1 FROM dbo.crmNotificationType WITH (NOLOCK) WHERE NotificationTypeId <> @NotificationTypeId AND NotificationTypeName = @NotificationTypeName)
	BEGIN
		SELECT @ErrCode = 101, @ErrMsg = 'The Notification Type Name is not available, please check again!'
		RETURN
	END


	SELECT 
		@Old_SystemId = SystemId,
		@Old_NotificationTypeName = NotificationTypeName
	FROM dbo.crmNotificationType t WITH(NOLOCK)

	-- Update process
	BEGIN TRY
		UPDATE dbo.crmNotificationType WITH(ROWLOCK)
			SET NotificationTypeName = @NotificationTypeName,
				SystemId = @SystemId
	    OUTPUT deleted.NotificationTypeId, deleted.NotificationTypeName, deleted.SystemId, 1
			INTO @Tmp(NotificationTypeId, NotificationTypeName, SystemId, Type)
		WHERE NotificationTypeId = @NotificationTypeId

		DELETE dbo.crmNotificationRecipientType WITH(ROWLOCK, UPDLOCK)
		OUTPUT deleted.NotificationTypeId, deleted.RecipientTypeId, 2
			INTO @Tmp(NotificationTypeId, RecipientTypeId, Type)
		WHERE NotificationTypeId = @NotificationTypeId

		DELETE dbo.crmNotificationChatType WITH(ROWLOCK, UPDLOCK)
		OUTPUT deleted.ChatTypeId, deleted.NotificationTypeId, 3
			INTO @Tmp(ChatTypeId, NotificationTypeId, Type)
		WHERE NotificationTypeId = @NotificationTypeId
        
		INSERT INTO dbo.crmNotificationRecipientType
		(
			NotificationTypeId,
			RecipientTypeId
		)
		SELECT @NotificationTypeId,
			   val
		FROM dbo.f_CRM_strSplit(@RecipientTypeIds,',')		

		INSERT INTO dbo.crmNotificationChatType
		(
			NotificationTypeId,
			ChatTypeId
		)
		SELECT 
			@NotificationTypeId,
			val 
		FROM dbo.f_CRM_strSplit(@ChatTypeIds,',')			
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = ERROR_NUMBER(), @ErrMsg = ERROR_MESSAGE()

		IF EXISTS(SELECT 1 FROM @Tmp WHERE Type = 1)
	    BEGIN
			UPDATE nt 
			SET nt.NotificationTypeName = t.NotificationTypeName,
			    nt.SystemId = t.SystemId
			FROM dbo.crmNotificationType nt WITH(ROWLOCK)
				INNER JOIN @Tmp t ON nt.NotificationTypeId = t.NotificationTypeId
			WHERE t.Type = 1
		END

		IF EXISTS(SELECT 1 FROM @Tmp WHERE Type = 2)
		BEGIN
			DELETE dbo.crmNotificationRecipientType WITH(ROWLOCK, UPDLOCK)
			WHERE NotificationTypeId = @NotificationTypeId

			INSERT INTO dbo.crmNotificationRecipientType
			(
				NotificationTypeId,
				RecipientTypeId
			)
			SELECT 
				NotificationTypeId,
				RecipientTypeId
			FROM @Tmp
			WHERE Type = 2			
		END

		IF EXISTS(SELECT 1 FROM @Tmp WHERE Type = 3)
		BEGIN
			DELETE dbo.crmNotificationChatType WITH(ROWLOCK, UPDLOCK)
			WHERE NotificationTypeId = @NotificationTypeId

			INSERT INTO dbo.crmNotificationChatType
			(
				NotificationTypeId,
				ChatTypeId
			)
			SELECT 
				NotificationTypeId,
				ChatTypeId 
			FROM @Tmp
			WHERE Type = 3
		END

		RETURN
	END CATCH

	-- Write log

	--New values
	SELECT @RecipientTypeXML = (
					SELECT f.val AS '@Id', rt.RecipientTypeName AS '@Name'
					FROM bodb02.dbo.f_StringSplit(@RecipientTypeIds,',') f
						INNER JOIN dbo.crmRecipientType rt WITH(NOLOCK) ON rt.RecipientTypeId = f.val
					FOR XML PATH('RecipientType'))

	SELECT @ChatTypeXML	= (
					SELECT f.val AS '@Id', CASE WHEN f.val = 1 THEN 'Group' ELSE 'Personal' END AS '@Name'
					FROM bodb02.dbo.f_StringSplit(@ChatTypeIds, ',') f
					FOR XML PATH('ChatType'))

	SELECT @SystemXML =	(
					SELECT S.SystemId AS '@Id', s.SystemName AS '@Name'
					FROM dbo.crmSystem  s WITH(NOLOCK)
					WHERE s.SystemId = @SystemId
					FOR XML PATH('System'))

	SELECT @NewValues = CAST((SELECT	@NotificationTypeId AS '@Id',	
										@NotificationTypeName AS '@Name',
										@RecipientTypeXML,
										@ChatTypeXML,
										@SystemXML
							 FOR XML PATH('NotificationType'), ROOT('Acc_CRM_ChatBot_NotificationType_Upd')) AS NVARCHAR(MAX))

	--Old values
	SELECT @RecipientTypeXML = NULL, @ChatTypeXML = NULL, @SystemXML = NULL

	SELECT @RecipientTypeXML = (
					SELECT t.RecipientTypeId AS '@Id', rt.RecipientTypeName AS '@Name'
					FROM @Tmp t
						INNER JOIN dbo.crmRecipientType rt WITH(NOLOCK) ON rt.RecipientTypeId = t.RecipientTypeId
					WHERE t.Type = 2
					FOR XML PATH('RecipientType'))

	SELECT @ChatTypeXML	= (
					SELECT t.ChatTypeId AS '@Id', CASE WHEN t.ChatTypeId = 1 THEN 'Group' ELSE 'Personal' END AS '@Name'
					FROM @Tmp t 
					WHERE t.Type = 3
					FOR XML PATH('ChatType'))

	SELECT @SystemXML =	(
					SELECT S.SystemId AS '@Id', s.SystemName AS '@Name'
					FROM dbo.crmSystem  s WITH(NOLOCK)
					WHERE s.SystemId = @Old_SystemId
					FOR XML PATH('System'))

	SELECT @OldValues = CAST((SELECT	@NotificationTypeId AS '@Id',	
										@Old_NotificationTypeName AS '@Name',
										@RecipientTypeXML,
										@ChatTypeXML,
										@SystemXML
							 FOR XML PATH('NotificationType'), ROOT('Acc_CRM_ChatBot_NotificationType_Upd')) AS NVARCHAR(MAX))

	EXEC dbo.WriteLog_UserLog_crmUserLog_RunSP
			@UserID = @UserID,
			@CustID = NULL,
			@ActionID = 1002,
			@IP = @LoginIP,
			@NewValues = @NewValues,
			@OldValues = @OldValues

END
GO