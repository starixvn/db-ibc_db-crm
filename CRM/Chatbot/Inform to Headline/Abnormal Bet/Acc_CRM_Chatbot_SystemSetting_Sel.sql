/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_Chatbot_SystemSetting_Sel]
	@ServiceName VARCHAR(50) = 'ChatBot - AbnormalBets'
	,@Environment VARCHAR(50) = ''
AS

/*
	Created: 20200811@Percy
	DB: DBCRM-bodb_CRM
	Task: CRM - ChatBot - Get Setting

	Revisions:
		- 20200811@Percy: Initialize SP [RedmineID: #130544]
		- 20201104@Malcolm: Add @@ServiceName to support get setting by Service [RedmineId: #144265]
		- 20210801@Malcolm: Get SubmitDate, Seq [RedmineId: #151509]
*/

BEGIN
	SET NOCOUNT ON

	SELECT @Environment = ISNULL(@Environment, '')

	SELECT -- BatchSizeGetMsg
		CONVERT(INT, [BatchSize])	AS [BatchSize]
		,CONVERT(INT, [BatchSizeGetMsg]) AS [BatchSizeGetMsg]
		,CONVERT(BIT, ServiceFlag)	AS ServiceFlag
		,CASE WHEN @Environment = 'UAT' THEN CONVERT(BIGINT, LastLogIdUAT) ELSE CONVERT(BIGINT, LastLogId) END AS LastLogId
		,CASE WHEN @Environment = 'UAT' THEN CONVERT(DATETIME2(7), SubmitDateUAT) ELSE CONVERT(DATETIME2(7), SubmitDate) END AS SubmitDate
		,CASE WHEN @Environment = 'UAT' THEN CONVERT(INT, SeqUAT) ELSE CONVERT(INT, Seq) END AS Seq
		,CONVERT(BIT, IncludeUUSCurrency) AS IncludeUUSCurrency
	FROM
	(
		SELECT SettingName, Value
		FROM dbo.SystemSetting WITH (NOLOCK)
		WHERE ServiceName = @ServiceName 
	) s
	PIVOT
	(
		MAX(Value)
		FOR SettingName IN (BatchSize, BatchSizeGetMsg, ServiceFlag,  LastLogIdUAT, LastLogId, SubmitDateUAT, SubmitDate, SeqUAT, Seq, IncludeUUSCurrency)
	) p
END
GO