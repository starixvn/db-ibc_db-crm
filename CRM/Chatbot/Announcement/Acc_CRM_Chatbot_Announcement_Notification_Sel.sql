/*<info serverAlias="DBCRM-bodb_CRM" executers="wsv_nap" isFunction="0" isNested="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE dbo.Acc_CRM_Chatbot_Announcement_Notification_Sel
AS

/*
    Created: 20230607@Malcolm
    DB: DBCRM-bodb_CRM
    Task: CRM - ChatBot - Send Notification of Announcement

    Revisions:
        - 20230607@Malcolm: Initialize SP [RedmineID: #189408]
        - 20230712@Malcolm: Add ChannelId [RedmineID: #179119]
        - 20240327@Ned.Le: CRM - Headline Announcement - Enhancement - Allow to attach separate screenshots for a specific language AND Allow to push Notifications with empty content [Redmine: #201042]
*/

BEGIN

    SET NOCOUNT ON


    ---------------------
    -- Create temp tables

    -- #tmpSendNotifications
    CREATE TABLE #tmpSendNotifications (
        NotificationId      INT,
        Content             NVARCHAR(MAX),
        ConversationGroupId SMALLINT,
        ChatTypeId          TINYINT,
        BotId               BIGINT,
        ConversationId      VARCHAR(200),
        IsOnlyRetryImage    BIT,
        ErrImages           NVARCHAR(2000),
        ChannelId           TINYINT,
        LanguageId          INT
    )

    -- #tmpNotifications
    CREATE TABLE #tmpNotifications (
        NotificationId      INT,
        ConversationGroupId SMALLINT
    )


    --------------------------------------------------------
    -- Get list of notification of announcement need to send

    -- Get data from crmNotification|crmNotificationGroup|crmAnnouncementNotification
    -- + Get data
    INSERT INTO #tmpNotifications (NotificationId, ConversationGroupId)
    SELECT n.NotificationId, ng.ConversationGroupId
    FROM bodb_CRM.dbo.crmNotification n WITH (NOLOCK)
         INNER JOIN bodb_CRM.dbo.crmNotificationGroup ng WITH (NOLOCK) ON n.NotificationId = ng.NotificationId
         INNER JOIN bodb_CRM.dbo.crmAnnouncementNotification an WITH (NOLOCK) ON an.NotificationId = n.NotificationId
    WHERE n.Status IN ('Planned', 'Sending')
          AND ng.Status IN ('Planned', 'Retrying')
    -- + If not have any record need to get --> go to Result
    IF (@@ROWCOUNT = 0) GOTO Result

    -- Update status table crmNotificationGroup
    -- + Update data
    UPDATE ng WITH (ROWLOCK)
    SET ng.Status = 'Sending'
    OUTPUT DELETED.NotificationId, DELETED.ConversationGroupId INTO #tmpSendNotifications (NotificationId, ConversationGroupId)
    FROM bodb_CRM.dbo.crmNotificationGroup ng
         INNER JOIN #tmpNotifications n ON n.NotificationId = ng.NotificationId AND n.ConversationGroupId = ng.ConversationGroupId
    WHERE ng.Status IN ('Planned', 'Retrying')
    -- + If not have any record need to update --> go to Result
    IF (@@ROWCOUNT = 0) GOTO Result

    -- Update status table crmNotification
    UPDATE n WITH (ROWLOCK)
    SET n.Status = 'Sending'
    FROM bodb_CRM.dbo.crmNotification n
    WHERE EXISTS (SELECT 1 FROM #tmpNotifications t WHERE n.NotificationId = t.NotificationId)
          AND n.Status IN ('Planned', 'Sending')

    -- Update value for all necessary information
    UPDATE sn
    SET sn.Content          = n.Content,
        sn.ChatTypeId       = ng.ChatTypeId,
        sn.BotId            = ng.BotId,
        sn.ConversationId   = ng.ConversationId,
        sn.IsOnlyRetryImage = n.IsOnlyRetryImage,
        sn.ErrImages        = n.ErrImages,
        sn.ChannelId        = ng.ChannelId,
        sn.LanguageId       = ng.LanguageId
    FROM #tmpSendNotifications sn
         CROSS APPLY (
             SELECT n.Content,
                    t.c.value('@IsOnlyRetryImage', 'BIT') AS IsOnlyRetryImage,
                    t.c.value('@ErrImages', 'NVARCHAR(2000)') AS ErrImages
             FROM bodb_CRM.dbo.crmNotification n WITH (NOLOCK)
                  INNER JOIN bodb_CRM.dbo.crmNotificationGroup ng WITH(NOLOCK) ON ng.NotificationId = n.NotificationId
                  OUTER APPLY ng.FailInfo.nodes('root/r') t(c)
             WHERE n.NotificationId = sn.NotificationId
         ) n
         CROSS APPLY
         (
             SELECT cg.ChatTypeId,
                    cgb.BotId,
                    cg.ConversationId,
                    cg.ChannelId,
                    cg.LanguageId
             FROM bodb_CRM.dbo.crmConversationGroup cg WITH (NOLOCK)
                  LEFT JOIN bodb_CRM.dbo.crmConversationGroupBot cgb WITH (NOLOCK) ON cg.ConversationGroupId = cgb.ConversationGroupId
             WHERE cg.ConversationGroupId = sn.ConversationGroupId
         ) ng


    ---------------------------
    -- Return final information

    Result:
        SELECT s.NotificationId,
               s.Content,
               s.ConversationGroupId,
               s.ChatTypeId,
               s.BotId,
               s.ConversationId,
               ISNULL(ac.FileName, '') FileName,
               a.AnnouncementId,
               s.IsOnlyRetryImage,
               s.ErrImages,
               s.ChannelId
        FROM #tmpSendNotifications s
             LEFT JOIN bodb_CRM.dbo.crmAnnouncementNotification an WITH (NOLOCK) ON an.NotificationId = s.NotificationId
             LEFT JOIN bodb_CRM.dbo.crmAnnouncement a WITH (NOLOCK) ON a.AnnouncementId = an.AnnouncementId
             LEFT JOIN bodb_CRM.dbo.crmAnnouncementContent ac WITH (NOLOCK) ON a.AnnouncementId = ac.AnnouncementId AND s.LanguageId = ac.LanguageId
END
GO