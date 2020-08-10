USE bodb_CRM
GO

CREATE PROCEDURE [dbo].[Acc_CRM_ChatBot_ChatTypeMapping_Sel]
	@ConversationGroupId	SMALLINT = NULL
	,@ChatTypeId			TINYINT = NULL
	,@ConversationGroupName	NVARCHAR(1000) = NULL
	,@Healine				VARCHAR(50) = NULL
	,@RecipientName			VARCHAR(50) = NULL
	,@LetstalkID			VARCHAR(50) = NULL
	,@MappingStatus			VARCHAR(50) = NULL
	,@LanguageId			TINYINT = NULL
	,@IsActive				BIT = NULL
	,@ConversationBotId		TINYINT = NULL
AS

BEGIN
	SET NOCOUNT ON

	DECLARE @PICCommunicationLetStalkId INT
	SELECT  @PICCommunicationLetStalkId = SettingId FROM dbo.crmSetting WITH (NOLOCK)
	WHERE	SettingName = 'PICCommunicationTool' AND SettingValue = 'LetsTalk'

	SELECT cg.ConversationGroupId, cg.ConversationGroupName
			,ct.ChatTypeName, cb.ConversationBotName
			,p.Username AS RecipientName
			,pc.CommunicationValue AS LetstalkId
	FROM dbo.crmConversationGroup cg WITH (NOLOCK)
		INNER JOIN dbo.crmConversationGroupBot cgb WITH (NOLOCK) ON cg.ConversationGroupId = cgb.ConversationBotId
		INNER JOIN dbo.crmConversationBot cb WITH (NOLOCK) ON cgb.ConversationBotId = cb.ConversationBotId
		INNER JOIN dbo.crmChatType ct WITH (NOLOCK) ON cg.ChatTypeId = ct.ChatTypeId
		INNER JOIN dbo.crmConversationGroupPIC cgp WITH (NOLOCK) ON cg.ConversationGroupId = cgp.ConversationGroupId
		INNER JOIN dbo.crmPIC p WITH (NOLOCK) ON cgp.PicId = p.PicId
		INNER JOIN dbo.crmPICCommunication pc WITH (NOLOCK) ON p.PicId = pc.PicId AND pc.CommunicationID = @PICCommunicationLetStalkId
END
GO

