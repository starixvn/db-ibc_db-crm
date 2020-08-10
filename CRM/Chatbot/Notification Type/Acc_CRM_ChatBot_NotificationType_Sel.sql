USE bodb_CRM
GO

CREATE PROCEDURE [dbo].[Acc_CRM_ChatBot_NotificationType_Sel]
	@NotificationTypeId		TINYINT = NULL
	,@NotificationTypeName	NVARCHAR(500) = NULL
	,@RecipientTypeId		TINYINT = NULL
	,@ChatTypeId			TINYINT = NULL
	,@SystemId				TINYINT = NULL
AS

BEGIN
	SET NOCOUNT ON

	IF @NotificationTypeId IS NOT NULL
		SELECT nt.NotificationTypeId, nt.NotificationTypeName, rt.RecipientTypeName, ct.ChatTypeName, s.SystemName
		FROM dbo.crmNotificationType nt WITH (NOLOCK)
			INNER JOIN dbo.crmRecipientType rt WITH (NOLOCK) ON nt.RecipientTypeId = rt.RecipientTypeId
			INNER JOIN dbo.crmChatType ct WITH (NOLOCK) ON nt.ChatTypeId = ct.ChatTypeId
			INNER JOIN dbo.crmSystem s WITH (NOLOCK) ON nt.SystemId = s.SystemId
		WHERE NotificationTypeId = @NotificationTypeId
	ELSE
		SELECT nt.NotificationTypeId, nt.NotificationTypeName, rt.RecipientTypeName, ct.ChatTypeName, s.SystemName
		FROM dbo.crmNotificationType nt WITH (NOLOCK)
			INNER JOIN dbo.crmRecipientType rt WITH (NOLOCK) ON nt.RecipientTypeId = rt.RecipientTypeId
			INNER JOIN dbo.crmChatType ct WITH (NOLOCK) ON nt.ChatTypeId = ct.ChatTypeId
			INNER JOIN dbo.crmSystem s WITH (NOLOCK) ON nt.SystemId = s.SystemId
		WHERE
			(@NotificationTypeName IS NULL OR nt.NotificationTypeName = @NotificationTypeName)
			AND (@RecipientTypeId IS NULL OR nt.RecipientTypeId = @RecipientTypeId)
			AND (@ChatTypeId IS NULL OR nt.ChatTypeId = @ChatTypeId)
			AND (@SystemId IS NULL OR nt.SystemId = @SystemId)
END
GO