/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_ChatBot_NotificationMsgLog_Ins] @NotificationId INT
	,@BotId INT
	,@ConversationId VARCHAR(200)
	,@Content NVARCHAR(MAX)
	,@IsBotBlocked BIT = 0
	,@IsSuccess BIT = 0
	,@ErrMsg NVARCHAR(4000)
AS
/*
Created: 20200911@Oliver.Dang
Task :  Write log after send message to Letstalk
DB: DBCRM/bodb_CRM
Original:
	Revisions:
		- 20200911@Oliver: Initialize SPs [Redmine: #130544]
	Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	INSERT INTO dbo.crmNotificationMsgLog(
		NotificationId
		,BotId
		,ConversationId
		,Content
		,SentTime
		,IsSuccess
		,IsBotBlocked
		,ErrMsg
		)
	VALUES (
		@NotificationId
		,@BotId
		,@ConversationId
		,@Content
		,GETDATE()
		,@IsSuccess
		,@IsBotBlocked
		,@ErrMsg
		)
END
GO