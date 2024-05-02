/*<info serverAlias="DBCRM-bodb_CRM" executers="wsv_nap" isFunction="0" isNested="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE dbo.Acc_CRM_NewAccDetail_PicUpdValidation @PicID              INT,
                                                          @CommunicationTools NVARCHAR(MAX)
AS

/*
    Created: 20240403@Ned.Le
    Task: CRM - Account Details - Headline Communication Info - Update Communication Tool for PIC
    DB: DBCRM/bodb_CRM
    Original: Acc_CRM_PicUpdValidation

    Revisions:
        20240403@Ned.Le: CRM - Manage Headline/PIC/Staff authority and Company services (#193385)

    Param's Explanation:
        @CommunicationTools: '<ROOT>
                                <CommunicationTool SettingID="49001" SettingValue="abc,def" />
                              </ROOT>'
*/

BEGIN

    SET NOCOUNT ON


    -------------
    -- Parse data

    DECLARE @idoc INT
    EXEC sp_xml_preparedocument @iDoc OUTPUT, @CommunicationTools
    CREATE TABLE #tmpCommunicationTools (SettingID INT, SettingValue NVARCHAR(200))
    INSERT INTO  #tmpCommunicationTools (SettingID, SettingValue)
    SELECT SettingID, SettingValue
    FROM OPENXML(@iDoc, '/ROOT/CommunicationTool', 1) WITH (SettingID INT, SettingValue NVARCHAR(200))
    EXEC sp_xml_removedocument @iDoc


    ---------------
    -- Process data

    -- Get New Conversation
    CREATE TABLE #tmpNewConversation (ConversationId VARCHAR(200), Username VARCHAR(200), ChannelId TINYINT)
    INSERT INTO  #tmpNewConversation (ConversationId, Username, ChannelId)
    SELECT DISTINCT CASE WHEN s.SettingValue = 'Letstalk' THEN TRIM(f.value) ELSE '' END ConversationId,
                    CASE WHEN s.SettingValue = 'Telegram' THEN TRIM(f.value) ELSE '' END Username,
                    CASE WHEN s.SettingValue = 'Letstalk' THEN 1 ELSE 2 END              ChannelId
    FROM #tmpCommunicationTools i
         CROSS APPLY STRING_SPLIT(i.SettingValue, ',') f
         INNER JOIN bodb_CRM.dbo.crmSetting s WITH (NOLOCK) ON s.SettingID = i.SettingID
    WHERE s.SettingName = 'PICCommunicationTool'
          AND s.SettingValue IN ('Letstalk', 'Telegram')

    -- Get Used Conversation
    CREATE TABLE #tmpUsedConversation (ConversationId VARCHAR(200), Username VARCHAR(200), ChannelId TINYINT)
    INSERT INTO  #tmpUsedConversation (ConversationId, Username, ChannelId)
    SELECT CASE WHEN cg.ChannelId = 1 THEN cg.ConversationId ELSE '' END ConversationId,
           ISNULL(cg.Username, '')                                       Username,
           cg.ChannelId                                                  ChannelId
    FROM bodb_CRM.dbo.crmConversationGroup cg WITH (NOLOCK)
         INNER JOIN bodb_CRM.dbo.crmConversationGroupRecipient cgr WITH (NOLOCK) ON cgr.ConversationGroupId = cg.ConversationGroupId
         INNER JOIN bodb_CRM.dbo.crmRecipient r WITH (NOLOCK) ON r.RecipientId = cgr.RecipientId
    WHERE cg.ChatTypeId = 2
          AND r.SourceId = @PicId
          AND r.DataSource = 'bodb_CRM.dbo.crmPIC'
          AND cg.IsDeleted = 0

    -- Cross check between Used and New
    DELETE u
    FROM #tmpUsedConversation u
         INNER JOIN #tmpNewConversation n ON u.ConversationId = n.ConversationId
                                             AND u.Username = n.Username
                                             AND u.ChannelId = n.ChannelId

    --------------
    -- Return data

    IF EXISTS (SELECT 1 FROM #tmpUsedConversation)
    BEGIN
        ;WITH CTE_Communication AS (
            SELECT 'Letstalk' CommunicationTool, STRING_AGG(CAST(ConversationId AS VARCHAR(MAX)), ',') CommunicationValue
            FROM #tmpUsedConversation
            WHERE ChannelId = 1 AND ISNULL(ConversationId, '') <> ''
            UNION ALL
            SELECT 'Telegram' CommunicationTool, STRING_AGG(CAST(Username AS VARCHAR(MAX)), ',') CommunicationValue
            FROM #tmpUsedConversation
            WHERE ChannelId = 2 AND ISNULL(Username, '') <> ''
        )
        SELECT p.PicID,
               (p.Username + ' (' + sr.SettingValue + ')') PicInfo,
               cte.CommunicationTool,
               cte.CommunicationValue
        FROM bodb_CRM.dbo.crmPIC p WITH (NOLOCK)
             INNER JOIN bodb_CRM.dbo.crmSetting sr WITH (NOLOCK) ON sr.SettingName = 'PICRole' AND p.Role = sr.SettingID
             CROSS JOIN CTE_Communication cte
        WHERE p.PicID = @PicID
              AND ISNULL(cte.CommunicationValue, '') <> ''
    END
    ELSE
    BEGIN
        SELECT NULL AS PicID,
               NULL AS PicInfo,
               NULL AS CommunicationTool,
               NULL AS CommunicationValue
    END


    ------------
    -- Drop data

    DROP TABLE #tmpCommunicationTools
    DROP TABLE #tmpNewConversation
    DROP TABLE #tmpUsedConversation

END
GO