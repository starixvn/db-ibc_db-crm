/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_ChatBot_Channel_Sel]
	@ChannelId TINYINT = NULL
AS
/*
	Created: 20230524@Malcolm
	Task :  Get information of Channel
	DB: DBCRM/bodb_CRM
	Original:
	Revisions:
		- 20230524@Malcolm: Initialize SPs [Redmine: #179119]
	Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	SELECT ChannelId, ChannelName
	FROM dbo.crmChannel WITH(NOLOCK)
	WHERE ChannelId = @ChannelId OR @ChannelId IS NULL
END
GO