/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/

USE bodb_CRM
GO

CREATE PROCEDURE [dbo].[Acc_CRM_PicUpdValidation]
	@PicID					INT,
	@CommunicationTools	    NVARCHAR(MAX)
AS
/*
	Created: 20200506@Malcolm
	Task : CRM - PIC and Headline - PIC Management - Edit PIC - Save
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20200921@Malcolm:	Warn when updating letstalk of Personal [Redmine: #130544]
		- 20230508@Malcolm: Offer Telegram bot service for Headlines [RedmineId : #179119]
        - 20240305@Ned.Le: [CRM] Updating PIC and Headline > PIC management got error (HotFix #201830)

	Param's Explanation:
	- @CommunicationTools:		
		<ROOT>
				<CommunicationTool SettingID = "" SettingValue = "" 
				/>
		</ROOT>	
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @idoc INT, @Message NVARCHAR(1000) = ''

	CREATE TABLE #input
	(	
		SettingID		INT,
		SettingValue	NVARCHAR(200)
	)

	EXEC sp_xml_preparedocument @iDoc OUTPUT, @CommunicationTools
	 
	INSERT INTO #input (SettingID,
						SettingValue)

	SELECT				SettingID,
						SettingValue
	FROM OPENXML(@iDoc, '/ROOT/CommunicationTool',1) WITH (SettingID		INT,
											  SettingValue	NVARCHAR(200))
	EXEC sp_xml_removedocument @iDoc

	DECLARE @UsedConversation TABLE (ConversationId VARCHAR(200), Username VARCHAR(200), ChannelId TINYINT)
	DECLARE @NewConversation TABLE (ConversationId VARCHAR(200), Username VARCHAR(200), ChannelId TINYINT)

	INSERT INTO @NewConversation (ConversationId, Username, ChannelId)
	SELECT 
		DISTINCT CASE WHEN s.SettingValue = 'Letstalk' THEN TRIM(f.value) ELSE '' END AS ConversationId
		,CASE WHEN s.SettingValue = 'Telegram' THEN TRIM(f.value) ELSE '' END AS Username
		,CASE WHEN s.SettingValue = 'Letstalk' THEN 1 ELSE 2 END AS ChannelId
	FROM #input i
		CROSS APPLY STRING_SPLIT(i.SettingValue, ',') f
		INNER JOIN dbo.crmSetting s WITH(NOLOCK) ON s.SettingID = i.SettingID
	WHERE s.SettingName = 'PICCommunicationTool' AND s.SettingValue IN ('Letstalk', 'Telegram')
	
	INSERT INTO @UsedConversation (ConversationId, ChannelId, Username)
	SELECT CASE WHEN cg.ChannelId = 1 THEN cg.ConversationId ELSE '' END, cg.ChannelId, ISNULL(cg.Username, '')
	FROM dbo.crmConversationGroup cg WITH(NOLOCK)
		INNER JOIN dbo.crmConversationGroupRecipient cgr WITH(NOLOCK) ON cgr.ConversationGroupId = cg.ConversationGroupId
		INNER JOIN dbo.crmRecipient r WITH(NOLOCK) ON r.RecipientId = cgr.RecipientId
	WHERE cg.ChatTypeId = 2 AND r.SourceId = @PicId AND r.DataSource = 'bodb_CRM.dbo.crmPIC'
		AND cg.IsDeleted = 0

	DELETE u
	FROM @UsedConversation u
		INNER JOIN @NewConversation n ON u.ChannelId = n.ChannelId AND u.ConversationId = n.ConversationId AND u.Username = n.Username

	IF EXISTS (SELECT 1 FROM @UsedConversation)
	BEGIN

		SELECT @Message = STRING_AGG(CONCAT(ConversationId, Username), ',') WITHIN GROUP (ORDER BY ChannelId)  FROM @UsedConversation 

		IF ISNULL(@Message, '') <> ''
			SELECT @Message = 'The Letstalk ID(s) or Telegram Username(s) ' + @Message + ' is/are being used to send notifications personally. If you update/remove the Letstalk ID or Telegram Username, the Personal Chat Mapping shall be deactivated. Would you like to proceed?'
	END

	SELECT @Message

	DROP TABLE #input
END