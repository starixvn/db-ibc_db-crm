/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_ChatBot_Bot_Sel]
AS
/*
	Created: 20200810@Malcolm
	Task :  Get information of bot
	DB: DBCRM/bodb_CRM
	Original:
	Revisions:
		- 20200810@Malcolm: Initialize SPs [Redmine: #130544]
		- 20230508@Malcolm: Add ChannelId [RedmineId : #179119]
	Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	SELECT BotId, BotName, ChannelId
	FROM dbo.crmConversationBot WITH(NOLOCK)
	ORDER BY ChannelId, BotName 
END
GO