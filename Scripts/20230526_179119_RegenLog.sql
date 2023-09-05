/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
/*
	Created: 20200810@Malcolm
	Task : Create new table to Offer Telegram bot service [RedmineID : #179119]
	DB: DBCRM/bodb_CRM
	
*/

INSERT INTO crmLogActionType (ActionTypeID, ActionTypeName)
VALUES (7, 'Bot Service')

INSERT INTO dbo.crmLogAction (ActionID, SPName, ActionNameEN, IsInternal, ExcludedForCn88, ActionTypeID)
VALUES (1018, 'Acc_CRM_ChatBot_AddBotToGroup_Ins', 'Add Bot To Group', 0, 0, 7)
	,(1019, 'Acc_CRM_ChatBot_ChangeGroupName_Upd', 'Update Group Name', 0, 0, 7)
	,(1020, 'Acc_CRM_ChatBot_KickOutBotFromGroup_Del', 'Kick out Bot From Group', 0, 0, 7)
	,(1021, 'Acc_CRM_ChatBot_AddBotToPersonal_Ins', 'Add Bot To Personal', 0, 0, 7)

DECLARE @TOControl_NotificationType SMALLINT, @CWL_NotificationType SMALLINT

SELECT @CWL_NotificationType = CASE WHEN NotificationTypeName = 'Company Win Loss Limit Announcement' THEN NotificationTypeId ELSE @CWL_NotificationType END
, @TOControl_NotificationType = CASE WHEN NotificationTypeName = 'Turnover Control Announcement' THEN NotificationTypeId ELSE @TOControl_NotificationType END
FROM dbo.crmNotificationType WITH(NOLOCK)
WHERE NotificationTypeName IN ('Company Win Loss Limit Announcement', 'Turnover Control Announcement')

CREATE TABLE #crmNotificationLog
(
	NotificationId INT
	,ReferenceId BIGINT
	,DataSource NVARCHAR(256)
)
INSERT INTO #crmNotificationLog (NotificationId, ReferenceId, DataSource)
SELECT DISTINCT 
	NotificationId
	,ReferenceId
	,CASE WHEN NotificationTypeId = @CWL_NotificationType THEN 'DBCUST.CustDB.dbo.WinLimit_CustGameMonitoring_History' ELSE 'DBCUST.CustDB.dbo.TOControl_Setting_History' END
FROM dbo.crmNotification WITH(NOLOCK)
WHERE NotificationTypeId IN (@CWL_NotificationType, @TOControl_NotificationType) AND ReferenceId IS NOT NULL

CREATE CLUSTERED INDEX CIX_NotificationId ON #crmNotificationLog (NotificationId)

INSERT INTO dbo.crmNotificationRefDetail
(
	NotificationId, ReferenceId, DataSource
)
SELECT NotificationId, ReferenceId, DataSource
FROM #crmNotificationLog l
WHERE NOT EXISTS (
	SELECT 1 FROM dbo.crmNotificationRefDetail g WITH(NOLOCK) WHERE g.NotificationId = l.NotificationId
)

DROP TABLE #crmNotificationLog
