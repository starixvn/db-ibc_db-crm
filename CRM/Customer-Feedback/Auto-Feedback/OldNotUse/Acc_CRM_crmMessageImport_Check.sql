ALTER PROCEDURE [dbo].[Acc_CRM_crmMessageImport_Check]
	@Messages XML
AS

/*
	Created: 20210628@Malcolm
	DB: DBCRM-bodb_CRM
	Task: CRM - ChatBot - Check what if tickets belong to abnormal accounts type or no
	Revisions:
		- 20210628@Malcolm: Initialize SP [RedmineID: #157303]
		- 20230131@Winfred: Scale Out for CRM [RedmineId : #181906]

	Param's Explanation:
		@Messages:
			<root>
				<r VoidingHistoryCollectionId="1" MessageID="1" RequestID="1" VoidingHistoryID="0" UsernameList="a,b"/>
				<r VoidingHistoryCollectionId="1" MessageID="1" RequestID="2" VoidingHistoryID="0" UsernameList=""/>
				<r VoidingHistoryCollectionId="1" MessageID="3" RequestID="2" VoidingHistoryID="15" UsernameList=""/>
			</root>			                                  
*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #Messages (VoidingHistoryCollectionId INT, MessageId INT, RequestId INT, VoidingHistoryId INT, UsernameList NVARCHAR(MAX))
	INSERT INTO  #Messages (VoidingHistoryCollectionId, MessageId, RequestId, VoidingHistoryId, UsernameList)
	SELECT DISTINCT
		t.c.value('@VoidingHistoryCollectionId', 'INT') AS VoidingHistoryCollectionId
		,t.c.value('@MessageID', 'INT') AS MessageId
		,t.c.value('@RequestID', 'INT') AS RequestId
		,t.c.value('@VoidingHistoryID', 'INT') AS VoidingHistoryId
		,t.c.value('@UsernameList', 'NVARCHAR(MAX)') AS UsernameList
	FROM @Messages.nodes('root/r') AS t(c)
	OPTION (OPTIMIZE FOR (@Messages = NULL))

	SELECT me.VoidingHistoryCollectionId, me.MessageId, me.RequestId, me.VoidingHistoryId, me.UsernameList
	FROM #Messages me
	WHERE NOT EXISTS (SELECT 1 FROM dbo.crmMessageImport m WITH (NOLOCK) WHERE m.MessageID = me.MessageId AND m.RequestID = me.RequestId AND m.VoidingHistoryCollectionId = me.VoidingHistoryCollectionId) 
		
	DROP TABLE #Messages
END
GO