/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="1"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_ChatBot_CWL_LastLog_Udp]
	@LogIds		XML
	,@ErrCode	INT = 0 OUTPUT
	,@ErrMsg	NVARCHAR(4000) = '' OUTPUT
AS

/*
	Created: 20201105@Malcolm
	DB: DBCRM-bodb_CRM
	Task: CRM - CWL - Update last logid 

	Revisions:
		- 20201105@Malcolm: Initialize SP [RedmineID: #144841]

	Param's Explanation:

*/

BEGIN
	SET NOCOUNT ON

	IF @LogIds IS NULL
		RETURN

	DECLARE @LastLogId BIGINT

	CREATE TABLE #LogId (LogId BIGINT)

	INSERT INTO #LogId (LogId)
	SELECT T.c.value('@LogId', 'BIGINT')
	FROM @LogIds.nodes('/root/r') T(c)

	SELECT @LastLogId = MAX(LogId)
	FROM #LogId

	UPDATE s
		SET s.Value = CONVERT(NVARCHAR(MAX), @LastLogId)
	FROM SystemSetting s WITH(ROWLOCK)
	WHERE s.ServiceName = 'ChatBot - CWL' AND SettingName = 'LastLogID' 

	IF @@ROWCOUNT = 0
	BEGIN
		SELECT @ErrCode = 100, @ErrMsg = 'Invalid SystemSetting!'
	END
END
GO