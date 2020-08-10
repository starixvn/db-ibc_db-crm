USE bodb_CRM
GO

CREATE PROCEDURE [dbo].[Acc_CRM_ChatBot_NotificationTemplate_Sel]
	@NotificationTemplateId		SMALLINT = NULL
	,@NotificationTemplateName	NVARCHAR(1000) = NULL
	,@NotificationTypeId		TINYINT = NULL
AS

BEGIN
	SET NOCOUNT ON

	IF @NotificationTemplateId IS NOT NULL
		SELECT nt.NotificationTemplateId, nt.NotificationTemplateName, n.NotificationTypeName, nt.Title, nt.Content
		FROM dbo.crmNotificationTemplate nt WITH (NOLOCK)
			INNER JOIN dbo.crmNotificationType n WITH (NOLOCK) ON nt.NotificationTypeId = n.NotificationTypeId
		WHERE nt.NotificationTypeId = @NotificationTypeId
	ELSE
		SELECT nt.NotificationTemplateId, nt.NotificationTemplateName, n.NotificationTypeName, nt.Title, nt.Content
		FROM dbo.crmNotificationTemplate nt WITH (NOLOCK)
			INNER JOIN dbo.crmNotificationType n WITH (NOLOCK) ON nt.NotificationTypeId = n.NotificationTypeId
		WHERE (@NotificationTemplateName IS NULL OR nt.NotificationTemplateName = @NotificationTemplateName)
			AND (@NotificationTypeId IS NULL OR nt.NotificationTypeId = @NotificationTypeId)
END
GO