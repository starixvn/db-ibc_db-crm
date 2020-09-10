/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_Chatbot_SendNotification_Status_Upd]
	@XmlData	XML
	,@ErrCode	INT = 0 OUTPUT
	,@ErrMsg	NVARCHAR(4000) = '' OUTPUT
AS

/*
	Created: 20200811@Percy
	DB: DBCRM-bodb_CRM
	Task: CRM - ChatBot - Send Notification - Update status

	Revisions:
		- 20200811@Percy: Initialize SP [RedmineID: #130544]

	Param's Explanation:
		. @XmlData
			<root>
				<r NotificationId="1" ConversationGroupId="1" Status="Planned" ErrMsg="" />
				<r NotificationId="2" ConversationGroupId="1" Status="Sending" ErrMsg="" />
				<r NotificationId="3" ConversationGroupId="2" Status="Error" ErrMsg="Letstalk ID has been changed" />
			</root>
*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #tmpNotificationGroup (NotificationId INT, ConversationGroupId SMALLINT, Status VARCHAR(20), ErrMsg NVARCHAR(MAX))
	INSERT INTO #tmpNotificationGroup (NotificationId, ConversationGroupId, Status, ErrMsg)
	SELECT
		t.c.value('@NotificationId', 'INT') AS NotificationId
		,t.c.value('@ConversationGroupId', 'SMALLINT') AS ConversationGroupId
		,t.c.value('@Status', 'VARCHAR(20)') AS Status
		,t.c.value('@ErrMsg', 'NVARCHAR(MAX)') AS ErrMsg
	FROM @XmlData.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@XmlData = NULL))

	IF @@ROWCOUNT = 0
		RETURN

	CREATE TABLE #tmpNotification (NotificationId INT, Status VARCHAR(20))
	INSERT INTO #tmpNotification (NotificationId, Status)
	SELECT NotificationId, Status
	FROM (
		SELECT NotificationId
			,CASE WHEN Status = 'Retrying' THEN 'Sending' ELSE Status END AS Status
			,ROW_NUMBER() OVER(PARTITION BY NotificationId ORDER BY CASE WHEN Status = 'Planned' THEN 1 ELSE 0 END) AS RowNum
		FROM #tmpNotificationGroup
	) t
	WHERE RowNum = 1

	UPDATE ng WITH (ROWLOCK)
	SET ng.Status = CASE WHEN t.Status = 'Retrying' AND ng.RetryTime = 4 THEN 'Error' ELSE t.Status END
		,ng.Reason = t.ErrMsg
		,ng.RetryTime = ng.RetryTime + CASE WHEN t.Status = 'Retrying' THEN 1 ELSE 0 END
	FROM dbo.crmNotificationGroup ng
		INNER JOIN #tmpNotificationGroup t
			ON		ng.NotificationId = t.NotificationId
				AND ng.ConversationGroupId = t.ConversationGroupId
	
	UPDATE n WITH (ROWLOCK)
	SET n.Status = t.Status
	FROM dbo.crmNotification n
		INNER JOIN #tmpNotification t ON n.NotificationId = t.NotificationId
END
GO