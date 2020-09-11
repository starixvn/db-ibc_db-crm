/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_ChatBot_LetstalkMessageLog_Ins] @NotificationId INT
	,@BotId INT
	,@LetstalkId NVARCHAR(200)
	,@Content NVARCHAR(MAX)
	,@IsBlocked BIT = 0
	,@IsSuccess BIT = 0
	,@ErrorMessage NVARCHAR(1000)
	,@IsGroup BIT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) = '' OUTPUT
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
	INSERT INTO dbo.crmLetstalkMessageLog (
		NotificationId
		,BotId
		,LetstalkId
		,Content
		,IsSuccess
		,IsBlocked.ErrorMessage
		,SentTime
		,IsGroup
		)
	VALUES (
		@NotificationId
		,@BotId
		,@LetstalkId
		,@Content
		,@IsSuccess
		,@IsBlocked
		,@ErrorMessage
		,GETDATE()
		,@IsGroup
		)
END
GO