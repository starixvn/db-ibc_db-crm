/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_ChatBot_NotificationTemplate_Upd]
	@UserId						INT
	,@NotificationTemplateId	SMALLINT
	,@NotificationTemplateName	NVARCHAR(1000) = NULL
	,@NotificationTypeId		TINYINT = NULL
	,@Title						NVARCHAR(2000) = NULL
	,@Contents					NVARCHAR(MAX) = NULL
	,@ErrCode					INT = 0 OUTPUT
	,@ErrMsg					NVARCHAR(2000) = '' OUTPUT
AS
/*
Created: 20200810@Malcolm
Task :  Insert a new notification template
DB: DBCRM/bodb_CRM
Original:
	Revisions:
		- 20200810@Malcolm: Initialize SPs [Redmine: #130544]
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
	CREATE TABLE #RequiredParameters(Value NVARCHAR(300), LanguageId INT)
	DECLARE @iDoc INT, @MsgContentsType XML

	SELECT @MsgContentsType = CAST(Value AS XML)
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'MsgContentsType'

	INSERT INTO #RequiredParameters(Value, LanguageId)
	SELECT 
		T.c.value('@Value', 'NVARCHAR(200)') AS [Value],
		T.c.value('@LanguageId', 'INT')		
	FROM @MsgContentsType.nodes('root/r/TemplateRequiredParam') AS T(c)

	-- Check exists NotificationTemplateId
	IF NOT EXISTS (SELECT 1 FROM dbo.crmNotificationTemplate WITH (NOLOCK) WHERE NotificationTemplateId = @NotificationTemplateId)
	BEGIN
		SELECT @ErrCode = 101, @ErrMsg = 'The Notification Template has been deleted, please check again!'
		RETURN
	END

	CREATE TABLE #Tmp
	(
		NotificationTemplateName	NVARCHAR(1000)
		,NotificationTypeId			TINYINT
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

	IF EXISTS(SELECT 1
			  FROM #Contents c 
				  INNER JOIN #RequiredParameters r ON r.LanguageId = c.LanguageId
			  WHERE c.Value NOT LIKE '%' + r.Value + '%')
	BEGIN
		SELECT @ErrCode = 101, @ErrMsg = 'You cannot remove predefined param(s).'
		RETURN
	END

	-- Check exists NotificationTemplateName
	IF EXISTS (SELECT 1 FROM dbo.crmNotificationTemplate WITH (NOLOCK) WHERE NotificationTemplateId <> @NotificationTemplateId AND NotificationTemplateName = @NotificationTemplateName)
	BEGIN
		SELECT @ErrCode = 101, @ErrMsg = 'The Notification Template Name is not available, please check again'
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


	DROP TABLE #Contents
	DROP TABLE #Tmp
	DROP TABLE #RequiredParameters

	-- Write log
END
GO