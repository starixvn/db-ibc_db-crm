/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_ChatBot_Announcement_Notification_UpdStatus]
	@XmlData	XML
	,@ErrCode	INT = 0 OUTPUT
	,@ErrMsg	NVARCHAR(4000) = '' OUTPUT
AS

/*
	Created: 20230607@Malcolm
	DB: DBCRM-bodb_CRM
	Task: CRM - ChatBot - Send Notification of Announcement - Update status

	Revisions:
		- 20230607@Malcolm: Initialize SP [RedmineID: #189408]

	Param's Explanation:
		. @XmlData
			<root>
				<r NotificationId="1" ConversationGroupId="1" Status="Planned" ErrMsg="" IsOnlyRetryImage="" ErrImages=""/>
				<r NotificationId="2" ConversationGroupId="1" Status="Sending" ErrMsg="" IsOnlyRetryImage="" ErrImages=""/>
				<r NotificationId="3" ConversationGroupId="2" Status="Error" ErrMsg="Letstalk ID has been changed" IsOnlyRetryImage="" ErrImages=""/>
			</root>
*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #tmpNotificationGroup (NotificationId INT, ConversationGroupId SMALLINT, Status VARCHAR(20), ErrMsg NVARCHAR(MAX), FailInfo XML)
	CREATE TABLE #tmpNotification (NotificationId INT, Status VARCHAR(20))

	INSERT INTO #tmpNotificationGroup (NotificationId, ConversationGroupId, Status, ErrMsg, FailInfo)
	SELECT
		t.c.value('@NotificationId', 'INT') AS NotificationId
		,t.c.value('@ConversationGroupId', 'SMALLINT') AS ConversationGroupId
		,t.c.value('@Status', 'VARCHAR(20)') AS Status
		,t.c.value('@ErrMsg', 'NVARCHAR(MAX)') AS ErrMsg
		,n.FailInfo
	FROM @XmlData.nodes('root/r') t(c)
	CROSS APPLY (
		SELECT 
			t.c.value('@IsOnlyRetryImage', 'BIT') AS '@IsOnlyRetryImage'
			,t.c.value('@ErrImages', 'NVARCHAR(2000)') AS '@ErrImages' 
		FOR XML PATH ('r'), ROOT('root')  
	) AS n(FailInfo)
	OPTION (OPTIMIZE FOR (@XmlData = NULL))

	IF @@ROWCOUNT = 0
		RETURN

	-- Update NotificationGroup
	UPDATE ng WITH (ROWLOCK)
	SET ng.Status = CASE WHEN t.Status = 'Retrying' AND ng.RetryTime = 4 THEN 'Error' ELSE t.Status END
		,ng.Reason = t.ErrMsg
		,ng.RetryTime = ng.RetryTime + CASE WHEN t.Status = 'Retrying' THEN 1 ELSE 0 END
		,ng.FailInfo = t.FailInfo
	OUTPUT INSERTED.NotificationId, INSERTED.Status INTO #tmpNotification (NotificationId, Status)
	FROM dbo.crmNotificationGroup ng
		INNER JOIN #tmpNotificationGroup t
			ON		ng.NotificationId = t.NotificationId
				AND ng.ConversationGroupId = t.ConversationGroupId

	-- Update Notification
	UPDATE #tmpNotification SET Status = 'Sending' WHERE Status = 'Retrying'

	UPDATE n WITH (ROWLOCK)
	SET n.Status = t.Status
	FROM dbo.crmNotification n
		INNER JOIN #tmpNotification t ON n.NotificationId = t.NotificationId
END
GO