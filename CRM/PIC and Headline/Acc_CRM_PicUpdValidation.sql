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

	DECLARE @idoc INT, @Message NVARCHAR(1000)

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

	DECLARE @SettingLetstalkId INT
	SELECT  @SettingLetstalkId = SettingId
	FROM dbo.crmSetting WITH(NOLOCK)
	WHERE SettingName = 'PICCommunicationTool' AND SettingValue = 'Letstalk'

	DECLARE @Used__Letstalk TABLE (LetstalkId VARCHAR(200))
	DECLARE @New__Letstalk TABLE (LetstalkId VARCHAR(200))

	INSERT INTO @New__Letstalk (LetstalkId)
	SELECT DISTINCT LTRIM(RTRIM(f.val))
	FROM #input i
		CROSS APPLY dbo.f_CRM_strSplit(i.SettingValue, ',') f
	WHERE i.SettingId = @SettingLetstalkId AND ISNULL(LTRIM(RTRIM(f.val)), '') <> ''
	
	INSERT INTO @Used__Letstalk (LetstalkId)
	SELECT DISTINCT cg.ConversationId
	FROM dbo.crmConversationGroup cg WITH(NOLOCK)
		INNER JOIN dbo.crmConversationGroupRecipient cgr WITH(NOLOCK) ON cgr.ConversationGroupId = cg.ConversationGroupId
		INNER JOIN dbo.crmRecipient r WITH(NOLOCK) ON r.RecipientId = cgr.RecipientId
	WHERE cg.ChatTypeId = 2 AND r.SourceId = @PicId AND r.DataSource = 'bodb_CRM.dbo.crmPIC'
		AND ISNULL(cg.ConversationId, '') <> ''

	IF EXISTS (SELECT 1 FROM @Used__Letstalk)
	BEGIN
		SELECT @Message = COALESCE(@Message + ', ', '') + u.LetstalkId
		FROM @Used__Letstalk u
			LEFT JOIN @New__Letstalk n ON u.LetstalkId = n.LetstalkId
		WHERE n.LetstalkId IS NULL

		IF ISNULL(@Message, '') <> ''
			SELECT @Message = 'The Letstalk ID(s) "' + @Message + '" is/are being used to send notifications personally. If you update/remove the Letstalk ID(s), the Personal Chat Mapping shall be deactivated. Would you like to proceed?'
	END

	SELECT @Message

	DROP TABLE #input
END