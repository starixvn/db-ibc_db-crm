/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_ChatBot_NotificationTemplate_Ins]
	@UserId						INT
	,@NotificationTemplateName	NVARCHAR(1000) = NULL
	,@NotificationTypeId		SMALLINT = NULL
	,@Title						NVARCHAR(2000)
	,@Contents					NVARCHAR(MAX) 
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
	DECLARE @NotificationTemplateId SMALLINT = 0, @iDoc INT, @MsgContentsType XML

	-- Check exists NotificationTemplateName
	IF EXISTS (SELECT 1 FROM dbo.crmNotificationTemplate WITH (NOLOCK) WHERE NotificationTemplateName = @NotificationTemplateName)
	BEGIN
		SELECT @ErrCode = 100, @ErrMsg = 'The Notification Template Name exists. Please check again!'
		RETURN
	END

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

	-- Insert process
	BEGIN TRY
		INSERT INTO dbo.crmNotificationTemplate (NotificationTemplateName, NotificationTypeId, Title)
		VALUES (@NotificationTemplateName, @NotificationTypeId, @Title)

		SELECT @NotificationTemplateId = SCOPE_IDENTITY()

		INSERT INTO dbo.crmNotificationTemplateContent (NotificationTemplateId, LanguageId, Content)
		SELECT @NotificationTemplateId, LanguageId, Value
		FROM #Contents
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = ERROR_NUMBER(), @ErrMsg = ERROR_MESSAGE()

		DELETE dbo.crmNotificationTemplate WITH(ROWLOCK, UPDLOCK)
		WHERE NotificationTemplateId = @NotificationTemplateId

		RETURN
	END CATCH

	DROP TABLE #Contents
	-- Write log
END
GO