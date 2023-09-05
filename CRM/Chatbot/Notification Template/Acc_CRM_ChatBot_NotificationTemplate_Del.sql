/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_ChatBot_NotificationTemplate_Del]
	@UserId						INT
	,@NotificationTemplateId	SMALLINT
	,@NotificationTemplateName  NVARCHAR(1000)
	,@ErrCode					INT = 0 OUTPUT
	,@ErrMsg					NVARCHAR(2000) = '' OUTPUT
	,@LoginIP					VARCHAR(45) = ''
AS
/*
	Created: 20200810@Malcolm
	Task : CRM - Headline Notification - Notification Template - Action - Delete (Delete a notification template)
	DB: DBCRM/bodb_CRM
	Original:
		Revisions:
			- 20200810@Malcolm: Initialize SPs [Redmine: #130544]
			- 20201116@Malcolm: Get settings of CWL Service [Redmine: #144265]
			- 20201225@Malcolm: Get settings of TOControl [Redmine: #146735]
			- 20210428@Malcolm: Get settings of Problem Accounts [Redmine: #153119]
			- 20210801@Malcolm: Get settings of Result Amendment [RedmineID: #151509]
			- 20221121@Malcolm: Get settings of Archiving Dormant Accounts [RedmineID: #158258]
			- 20230223@Malcolm: Do not delete the template that created the announcement [RedmineID: #179118]
			- 20230508@Malcolm: Offer Telegram bot service for Headlines [RedmineId : #179119]
		Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #NotificationTemplate(NotificationTemplateId INT)

	DECLARE  @Setting_AbnormalBets XML, @Setting_CWL XML , @__Title NVARCHAR(200), @__NotificationTypeId SMALLINT, @__ContentXML XML, @__NotificationTypeXML XML,
			 @NewValues NVARCHAR(MAX), @ServiceNames NVARCHAR(MAX) = ''

	-- Get setting for CWL, AbnormalBets Services, ChatBot - TOControl
	SELECT @ServiceNames = s.Value FROM dbo.SystemSetting s WITH(NOLOCK) WHERE s.ServiceName = 'ChatBot - Settings' AND s.SettingName = 'Services'

	INSERT INTO #NotificationTemplate(NotificationTemplateId)
	SELECT DISTINCT s.NotificationTemplateID
	FROM STRING_SPLIT(@ServiceNames, ',') f
	CROSS APPLY(SELECT CONVERT(XML, VALUE) AS Setting FROM SystemSetting WITH(NOLOCK) WHERE SettingName = 'NotificationTemplate' AND ServiceName = f.value ) AS i(Setting)
	CROSS APPLY(SELECT DISTINCT T.c.value('@NotificationTemplateID', 'INT') AS NotificationTemplateID FROM i.Setting.nodes('/root/r') T(c)) s(NotificationTemplateID)
	-- Check permission

	-- Check exists NotificationTemplateId
	IF NOT EXISTS (SELECT 1 FROM dbo.crmNotificationTemplate WITH (NOLOCK) WHERE NotificationTemplateId = @NotificationTemplateId)
	BEGIN
		SELECT @ErrCode = 101, @ErrMsg = @NotificationTemplateName + ' has been deleted, please check!'
		RETURN
	END

	IF EXISTS(SELECT 1 FROM #NotificationTemplate WHERE NotificationTemplateId = @NotificationTemplateId)
		OR EXISTS(SELECT 1 FROM dbo.crmAnnouncement WITH(NOLOCK) WHERE NotificationTemplateId = @NotificationTemplateId)
	BEGIN
		SELECT @ErrCode = 102, @ErrMsg = 'This is the system template, so you cannot delete it.'
		RETURN
	END


	SELECT @__Title = Title, @__NotificationTypeId = NotificationTypeId
	FROM dbo.crmNotificationTemplate nt WITH(NOLOCK)
	WHERE nt.NotificationTemplateId = @NotificationTemplateId

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

	SELECT @__NotificationTypeXML = (
					SELECT nt.NotificationTypeId AS '@Id', nt.NotificationTypeName AS '@Name'
					FROM dbo.crmNotificationType nt WITH(NOLOCK)
					WHERE nt.NotificationTypeId = @__NotificationTypeId 
					FOR XML PATH('NotificationType'))

	SELECT @__ContentXML = (
					SELECT t.LanguageId AS '@LanguageId', s.SettingValue AS '@Language', t.Content AS '@Value'
					FROM #Tmp t
						 INNER JOIN dbo.crmSetting s WITH(NOLOCK) ON s.SettingID = t.LanguageId
					FOR XML PATH('Content'), ROOT('Contents'))

	SELECT @NewValues = (
					SELECT @NotificationTemplateId AS '@Id',
						   @NotificationTemplateName AS '@Name',
						   @__Title AS '@Title',
						   @__NotificationTypeXML,
						   @__ContentXML
					FOR XML PATH ('NotificationTemplate'), ROOT('Acc_CRM_ChatBot_NotificationTemplate_Del'))

	EXEC dbo.WriteLog_UserLog_crmUserLog_RunSP
			@UserID = @UserID,
			@CustID = NULL,
			@ActionID = 1006,
			@IP = @LoginIP,
			@NewValues = @NewValues

	-- Drop temp tables
	DROP TABLE #Tmp
	DROP TABLE #NotificationTemplate
END
GO