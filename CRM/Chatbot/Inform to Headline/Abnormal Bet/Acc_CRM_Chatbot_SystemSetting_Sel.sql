/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_Chatbot_SystemSetting_Sel]
AS

/*
	Created: 20200811@Percy
	DB: DBCRM-bodb_CRM
	Task: CRM - ChatBot - Get Setting

	Revisions:
		- 20200811@Percy: Initialize SP [RedmineID: #130544]
*/

BEGIN
	SET NOCOUNT ON

	SELECT CONVERT(INT, [BatchSize]) AS [BatchSize], CONVERT(BIT, ServiceFlag) AS ServiceFlag
	FROM
	(
		SELECT SettingName, Value
		FROM dbo.SystemSetting WITH (NOLOCK)
		WHERE ServiceName = 'ChatBot - AbnormalBets'
	) s
	PIVOT
	(
		MAX(Value)
		FOR SettingName IN (BatchSize, ServiceFlag)
	) p
END
GO