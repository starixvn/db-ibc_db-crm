/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_ChatBot_NotificationTemplate_Upd]
	@UserId						INT
	,@NotificationTemplateId	SMALLINT
	,@NotificationTemplateName	NVARCHAR(1000) = NULL
	,@NotificationTypeId		SMALLINT = NULL
	,@Title						NVARCHAR(2000) = NULL
	,@Contents					NVARCHAR(MAX) = NULL
	,@ErrCode					INT = 0 OUTPUT
	,@ErrMsg					NVARCHAR(2000) = '' OUTPUT
	,@LoginIP					NVARCHAR(20) = ''
AS
/*
Created: 20200810@Malcolm
Task :  Insert a new notification template
DB: DBCRM/bodb_CRM
Original:
	Revisions:
		- 20200810@Malcolm: Initialize SPs [Redmine: #130544]
		- 20201116@Malcolm: Get settings of CWL Service [Redmine: #144265]
		- 20201225@Malcolm: Get settings of TOControl [Redmine: #146735]
	Param's Explanation:
	- @Contents:
		<Contents>
				<Content LanguageId = "1" Value = "A"/>
				<Content LanguageId = "2" Value = "B"/>
		</Contents>
		
*/
BEGIN
	SET NOCOUNT ON

	-- Check permission
	DECLARE @RequiredParameters TABLE(NotificationTemplateId SMALLINT ,[Value] NVARCHAR(300), LanguageId INT, Frenquency INT)

	DECLARE @iDoc INT, @NewValues NVARCHAR(MAX), @OldValues NVARCHAR(MAX), 
			@_Contents XML, @Old_Title NVARCHAR(2000), @Old_NotificationTemplateName NVARCHAR(1000), 
			@Old_NotificationTypeId  SMALLINT, @NotificationTypeXML XML, @ServiceNames NVARCHAR(MAX) = 'ChatBot - AbnormalBets,ChatBot - TOControl,ChatBot - CWL'

	-- Get setting for ChatBot - AbnormalBets,ChatBot - TOControl,ChatBot - CWL
	INSERT INTO @RequiredParameters(NotificationTemplateID, Value, LanguageId, Frenquency)
	SELECT d.NotificationTemplateID, d.Value, d.LanguageId, d.Frequency
	FROM dbo.f_CRM_strSplit(@ServiceNames, ',') f
	CROSS APPLY(SELECT CONVERT(XML, VALUE) AS Setting FROM SystemSetting WITH(NOLOCK) WHERE SettingName = 'NotificationTemplate' AND ServiceName = f.val ) AS i(Setting)
	CROSS APPLY(
		SELECT T.c.value('@NotificationTemplateID', 'INT') AS NotificationTemplateID , h.Value, h.LanguageId, h.Frequency
		FROM i.Setting.nodes('root/r') AS T(c)
		CROSS APPLY(
			SELECT l.k.value('@Value','NVARCHAR(1000)') AS [Value], l.k.value('@LanguageId', 'INT') AS [LanguageId], ISNULL(l.k.value('@Frequency', 'INT'), 1) AS Frequency
			FROM T.c.nodes('TemplateRequiredParam') as l(k)
		) as h
	) as d

	-- Check exists NotificationTemplateId
	IF NOT EXISTS (SELECT 1 FROM dbo.crmNotificationTemplate WITH (NOLOCK) WHERE NotificationTemplateId = @NotificationTemplateId)
	BEGIN
		SELECT @ErrCode = 101, @ErrMsg = 'The Notification Template has been deleted, please check again!'
		RETURN
	END

	CREATE TABLE #Tmp
	(
		NotificationTemplateName	NVARCHAR(1000)
		,NotificationTypeId			SMALLINT
		,Title						NVARCHAR(2000)
		,LanguageId					INT
		,Content					NVARCHAR(MAX)
		,Type						INT
	)

	CREATE TABLE #Contents 
	(
		LanguageId	INT
		,Value	NVARCHAR(MAX)
	)

	BEGIN TRY
		EXEC sp_xml_preparedocument @iDoc OUTPUT, @Contents

		INSERT INTO #Contents
		(
			LanguageId,
			Value
		)
		SELECT
			LanguageId,
			Value
		FROM OPENXML(@iDOC, '/Contents/Content',1) WITH(LanguageId	INT,
														Value		NVARCHAR(MAX))
	EXEC sp_xml_removedocument @iDOC

	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR, @ErrMsg = ERROR_MESSAGE()
		RETURN
	END CATCH

	IF EXISTS (SELECT 1 
			   FROM @RequiredParameters r 
			   CROSS APPLY(
		 	   		SELECT (LEN(c.Value) - LEN(REPLACE(c.Value, r.Value, '')))/LEN(r.Value) AS k FROM #Contents c WHERE c.LanguageId = r.LanguageId 
			   ) d(k)
			   WHERE r.Frenquency > d.k AND r.NotificationTemplateId = @NotificationTemplateId)
	BEGIN
		SELECT @ErrCode = 101, @ErrMsg = 'You cannot remove predefined param(s).'
		RETURN
	END

	-- Check exists NotificationTemplateName
	IF EXISTS (SELECT 1 FROM dbo.crmNotificationTemplate WITH (NOLOCK) WHERE NotificationTemplateId <> @NotificationTemplateId AND NotificationTemplateName = @NotificationTemplateName)
	BEGIN
		SELECT @ErrCode = 101, @ErrMsg = 'The Notification Template Name exists. Please check again!'
		RETURN
	END

	-- Update process
	BEGIN TRY
		UPDATE dbo.crmNotificationTemplate WITH (ROWLOCK)
		SET NotificationTemplateName	= @NotificationTemplateName
			,NotificationTypeId			= @NotificationTypeId
			,Title						= @Title
		OUTPUT deleted.NotificationTemplateName, deleted.NotificationTypeId, deleted.Title, 1
			INTO #Tmp (NotificationTemplateName, NotificationTypeId, Title, Type)
		WHERE NotificationTemplateId = @NotificationTemplateId

		DELETE dbo.crmNotificationTemplateContent WITH(ROWLOCK, UPDLOCK)
		OUTPUT deleted.LanguageId, deleted.Content, 2
			INTO #Tmp(LanguageId, Content, Type)
		WHERE NotificationTemplateId = @NotificationTemplateId

		INSERT INTO dbo.crmNotificationTemplateContent WITH(ROWLOCK)
		(
			NotificationTemplateId,
			LanguageId,
			Content
		)
		SELECT 
			@NotificationTemplateId,
			LanguageId, 
			Value
		FROM #Contents 

	END TRY
	BEGIN CATCH
		SELECT @ErrCode = ERROR_NUMBER(), @ErrMsg = ERROR_MESSAGE()

		IF EXISTS(SELECT 1 FROM #Tmp WHERE Type = 1)
		BEGIN
			UPDATE t
			SET	t.NotificationTemplateId	= tmp.NotificationTemplateName,
				t.NotificationTypeId		= tmp.NotificationTypeId,
				t.Title						= tmp.Title
			FROM crmNotificationTemplate t WITH(ROWLOCK)	
			CROSS APPLY(
				SELECT 
					NotificationTemplateName,
					NotificationTypeId,
					Title
				FROM #Tmp
				WHERE Type = 1
			) AS tmp
			WHERE t.NotificationTemplateId = @NotificationTemplateId
		END		

		IF EXISTS(SELECT 1 FROM #Tmp WHERE Type = 2)
		BEGIN
			INSERT INTO dbo.crmNotificationTemplateContent
			(
				NotificationTemplateId, 
				LanguageId, 
				Content
			)
			SELECT 
				@NotificationTemplateId, 
				LanguageId, 
				Content
			FROM #Tmp
			WHERE Type = 2
		END
		RETURN
	END CATCH

	-- Write log
	--Old Values
	SELECT	
		@Old_NotificationTypeId = t.NotificationTypeId
		,@Old_NotificationTemplateName = t.NotificationTemplateName 
		,@Old_Title = t.Title
	FROM #Tmp t
	WHERE t.Type = 1

	SELECT @NotificationTypeXML	=  (
					SELECT nt.NotificationTypeId AS '@Id', nt.NotificationTypeName AS '@Name'
					FROM dbo.crmNotificationType nt WITH(NOLOCK)
					WHERE nt.NotificationTypeId = @Old_NotificationTypeId
					FOR XML PATH ('NotificationType'))

	SELECT @_Contents = (
					SELECT t.LanguageId AS '@LanguagueId', s.SettingValue AS '@Language', t.Content AS '@Value'
					FROM #Tmp t
						INNER JOIN dbo.crmSetting s WITH(NOLOCK) ON s.SettingID = t.LanguageId
					WHERE t.Type = 2
					FOR XML PATH('Content'), ROOT('Contents'))

	SELECT @OldValues =	CAST((SELECT @NotificationTemplateId	AS '@Id'
									,@Old_NotificationTemplateName	AS '@Name'
									,@NotificationTypeXML
									,@_Contents
							  FOR XML PATH('NotificationTemplate'), ROOT('Acc_CRM_ChatBot_NotificationTemplate_Upd')) AS NVARCHAR(MAX))

	-- New Values
	SELECT @NotificationTypeXML = NULL, @_Contents = NULL

	SELECT @NotificationTypeXML = (
					SELECT nt.NotificationTypeId AS '@Id', nt.NotificationTypeName AS '@Name'
					FROM dbo.crmNotificationType nt WITH(NOLOCK)
					WHERE nt.NotificationTypeId = @NotificationTypeId
					FOR XML PATH('NotificationType'))

	SELECT @_Contents = (
					SELECT c.LanguageId AS '@LanguageId', s.SettingValue AS '@Language', c.Value AS '@Value'
					FROM #Contents c
						INNER JOIN dbo.crmSetting s WITH(NOLOCK) ON s.SettingID = c.LanguageId
					FOR XML PATH('Content'), ROOT('Contents'))

	SELECT @NewValues = CAST((SELECT @NotificationTemplateId	AS '@Id'
									,@NotificationTemplateName	AS '@Name'
									,@NotificationTypeXML
									,@_Contents
							 FOR XML PATH('NotificationTemplate'), ROOT('Acc_CRM_ChatBot_NotificationTemplate_Upd')) AS NVARCHAR(MAX))

	EXEC dbo.WriteLog_UserLog_crmUserLog_RunSP
			@UserID = @UserID,
			@CustID = NULL,
			@ActionID = 1005,
			@IP = @LoginIP,
			@NewValues = @NewValues,
			@OldValues = @OldValues
							 
	DROP TABLE #Contents
	DROP TABLE #Tmp
	
END
GO