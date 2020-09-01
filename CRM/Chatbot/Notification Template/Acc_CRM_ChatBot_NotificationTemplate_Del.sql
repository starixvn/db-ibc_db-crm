/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_ChatBot_NotificationTemplate_Del]
	@UserId						INT
	,@NotificationTemplateId	SMALLINT
	,@ErrCode					INT = 0 OUTPUT
	,@ErrMsg					NVARCHAR(2000) = '' OUTPUT
AS
/*
Created: 20200810@Malcolm
Task :  Delete a new notification template
DB: DBCRM/bodb_CRM
Original:
	Revisions:
		- 20200810@Malcolm: Initialize SPs [Redmine: #130544]
	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #NotificationTemplate(NotificationTemplateId INT)

	DECLARE @MsgContentsType XML

	SELECT @MsgContentsType = CAST(Value AS XML)
	FROM SystemSetting WITH(NOLOCK)
	WHERE SettingName = 'NotificationTemplate'

	INSERT INTO #NotificationTemplate(NotificationTemplateId)
	SELECT  T.c.value('@NotificationTemplateID', 'INT')
	FROM @MsgContentsType.nodes('/root/r') T(c)
	-- Check permission

	-- Check exists NotificationTemplateId
	IF NOT EXISTS (SELECT 1 FROM dbo.crmNotificationTemplate WITH (NOLOCK) WHERE NotificationTemplateId = @NotificationTemplateId)
	BEGIN
		SELECT @ErrCode = 101, @ErrMsg = 'The Notification Template has been deleted, please check again!'
		RETURN
	END

	IF EXISTS(SELECT 1 FROM #NotificationTemplate WHERE NotificationTemplateId = @NotificationTemplateId)
	BEGIN
		SELECT @ErrCode = 102, @ErrMsg = 'This is the system template, so you cannot delete it.'
		RETURN
	END

	CREATE TABLE #Tmp (NotificationTemplateId SMALLINT, LanguageId INT, Content NVARCHAR(MAX))
	-- Delete process
	BEGIN TRY
	    DELETE dbo.crmNotificationTemplateContent WITH(ROWLOCK, UPDLOCK)
		OUTPUT deleted.NotificationTemplateId, deleted.LanguageId, deleted.Content
			INTO #Tmp (NotificationTemplateId, LanguageId, Content)
		WHERE NotificationTemplateId = @NotificationTemplateId

		DELETE dbo.crmNotificationTemplate WITH (ROWLOCK, UPDLOCK)
		WHERE NotificationTemplateId = @NotificationTemplateId
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = ERROR_NUMBER(), @ErrMsg = ERROR_MESSAGE()

		IF EXISTS(SELECT 1 FROM #Tmp)
			INSERT INTO dbo.crmNotificationTemplateContent 
			(
				NotificationTemplateId,
				LanguageId,
				Content
			)
			SELECT 
				NotificationTemplateId,
				LanguageId,
				Content
			FROM #Tmp
		RETURN
	END CATCH

	-- Write log

	-- Drop temp tables
	DROP TABLE #Tmp
	DROP TABLE #NotificationTemplate
END
GO