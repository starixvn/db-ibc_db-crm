/*<info serverAlias="DBCRM-bodb_CRM" executers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_Chatbot_ClearLog]
AS

/*
	Created: 20221109@Malcolm
	DB: DBCRM-bodb_CRM
	Task: CRM - ChatBot - Delete log

	Revisions:
		- 20221109@Malcolm: Initialize SP [RedmineID: #180493]

	Param's Explanation:	
*/

BEGIN
	SET NOCOUNT ON

	WHILE 1 = 1
	BEGIN
		DELETE TOP(3000) dbo.crmNotificationReference WITH(ROWLOCK, UPDLOCK)
		WHERE CreatedDate < DATEADD(MONTH, -1, GETDATE())

		IF @@ROWCOUNT = 0
			BREAK
	END

	WHILE 1 = 1
	BEGIN
		DELETE TOP(3000) dbo.crmChatBot_UserLog_RunSP WITH(ROWLOCK, UPDLOCK)
		WHERE LogDate < DATEADD(DAY, -7, GETDATE())

		IF @@ROWCOUNT = 0
			BREAK
	END
END
GO