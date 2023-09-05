/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_ChatBot_NotificationListValidation]
	@NotificationIds VARCHAR(MAX)
AS
/*
	Created: 20200810@Malcolm
	Task : CRM - Headline Notification - Notification List - Resend (For notification with status as error) 
	DB: DBCRM/bodb_CRM
	Original:
	Revisions:
		- 20200810@Malcolm: Initialize SPs [Redmine: #130544]
		- 20201126@Malcolm: Change bodb02.dbo.f_StringSplit to dbo.f_CRM_strSplit [Redmine: #144265]
		- 20230508@Malcolm: Offer Telegram bot service for Headlines [RedmineId : #179119]
	Param's Explanation:
		
*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #NotificationIds(ID INT PRIMARY KEY)

	INSERT INTO #NotificationIds(ID)
	SELECT DISTINCT value
	FROM STRING_SPLIT(@NotificationIds,',')
	
	SELECT DISTINCT nr.NotificationId
	FROM dbo.crmNotificationGroup nr WITH(NOLOCK)	
		INNER JOIN dbo.crmConversationGroup cg WITH(NOLOCK) ON nr.ConversationGroupId = cg.ConversationGroupId
	WHERE EXISTS(SELECT 1 FROM #NotificationIds n WHERE n.ID = nr.NotificationId) 	
		AND cg.IsActive = 0

	SELECT DISTINCT nr.NotificationId
	FROM dbo.crmNotificationGroup nr WITH(NOLOCK)	
		INNER JOIN dbo.crmConversationGroup cg WITH(NOLOCK) ON nr.ConversationGroupId = cg.ConversationGroupId
	WHERE EXISTS(SELECT 1 FROM #NotificationIds n WHERE n.ID = nr.NotificationId) 	
		AND cg.IsActive = 1
		
	DROP TABLE #NotificationIds
END
GO