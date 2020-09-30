/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_PicUpdValidation]
	@PicID					INT,
	@CommunicationTools	    NVARCHAR(MAX)
AS
/*
Created: 20200506@Malcolm
Task :  Warn when updating letstalk of Personal
DB: DBCRM/bodb_CRM
Original:

	Revisions:
		- 20200921@Malcolm:	Warn when updating letstalk of Personal [Redmine: #130544]
	Param's Explanation:
	- @CommunicationTools:		
		<ROOT>
				<CommunicationTool SettingID = "" SettingValue = "" 
				/>
		</ROOT>	
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @idoc INT, @SettingId INT, @__Letstalk NVARCHAR(200) = NULL, @New__Letstalk NVARCHAR(200), @Message NVARCHAR(1000) = '' 

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

	SELECT @SettingId = SettingID 
	FROM dbo.crmSetting WITH(NOLOCK)
	WHERE SettingName = 'PICCommunicationTool' AND SettingValue = 'Letstalk'

	SELECT @__Letstalk = cg.ConversationId
	FROM dbo.crmConversationGroup cg WITH(NOLOCK)
		INNER JOIN dbo.crmConversationGroupRecipient cgr WITH(NOLOCK) ON cgr.ConversationGroupId = cg.ConversationGroupId
		INNER JOIN dbo.crmRecipient r WITH(NOLOCK) ON r.RecipientId = cgr.RecipientId
	WHERE cg.ChatTypeId = 2 AND r.SourceId = @PicID AND r.DataSource = 'bodb_CRM.dbo.crmPIC'

	SELECT @New__Letstalk  = i.SettingValue FROM #input i WHERE @SettingId = i.SettingID

	SELECT @Message = ''

	IF ISNULL(@__Letstalk,'') <> ''
	BEGIN
		IF ',' + @New__Letstalk + ',' NOT LIKE '%,' + @__Letstalk + ',%'
		BEGIN
			SELECT @Message = 'This Letstalk ID "' +  @__Letstalk + '" is being used to send notifications personally. If you update/remove the Letstalk ID, the Personal Chat Mapping shall be deactivated. Would you like to proceed?'
		END
	END

	SELECT @Message

	DROP TABLE #input
END