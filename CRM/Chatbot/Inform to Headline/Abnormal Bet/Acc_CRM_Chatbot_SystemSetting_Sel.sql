/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_Chatbot_SystemSetting_Sel]
	@ServiceName VARCHAR(50) = 'ChatBot - AbnormalBets'
AS

/*
	Created: 20200811@Percy
	DB: DBCRM-bodb_CRM
	Task: CRM - ChatBot - Get Setting

	Revisions:
		- 20200811@Percy: Initialize SP [RedmineID: #130544]
		- 20201104@Malcolm: Add @@ServiceName to support get setting by Service [RedmineId: #144265]
*/

BEGIN
	SET NOCOUNT ON

	SELECT
		CONVERT(INT, [BatchSize])	AS [BatchSize]
		,CONVERT(BIT, ServiceFlag)	AS ServiceFlag
		,CONVERT(BIGINT, LastLogId)	AS LastLogId
	FROM
	(
		SELECT SettingName, Value
		FROM dbo.SystemSetting WITH (NOLOCK)
		WHERE ServiceName = @ServiceName
	) s
	PIVOT
	(
		MAX(Value)
		FOR SettingName IN (BatchSize, ServiceFlag, LastLogId)
	) p
END
GO