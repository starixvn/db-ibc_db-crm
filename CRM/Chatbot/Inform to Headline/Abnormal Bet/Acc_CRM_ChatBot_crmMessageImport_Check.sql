/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_ChatBot_crmMessageImport_Check]
	@Messages XML
AS

/*
	Created: 20210628@Malcolm
	DB: DBCRM-bodb_CRM
	Task: CRM - ChatBot - Check what if tickets belong to abnormal accounts type or no
	Revisions:
		- 20210628@Malcolm: Initialize SP [RedmineID: #157303]

	Param's Explanation:
		@Messages:
			<root>
				<r MessageID="1" RequestID="1" VoidingHistoryID="0" UsernameList="a,b"/>
				<r MessageID="1" RequestID="2" VoidingHistoryID="0" UsernameList=""/>
				<r MessageID="3" RequestID="2" VoidingHistoryID="15" UsernameList=""/>
			</root>			                                  
*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #Messages (MessageId INT, RequestId INT, VoidingHistoryId INT, UsernameList NVARCHAR(MAX))
	INSERT INTO  #Messages (MessageId, RequestId, VoidingHistoryId, UsernameList)
	SELECT DISTINCT
		t.c.value('@MessageID', 'INT') AS MessageId
		,t.c.value('@RequestID', 'INT') AS RequestId
		,t.c.value('@VoidingHistoryID', 'INT') AS VoidingHistoryId
		,t.c.value('@UsernameList', 'NVARCHAR(MAX)') AS UsernameList
	FROM @Messages.nodes('root/r') AS t(c)
	OPTION (OPTIMIZE FOR (@Messages = NULL))

	SELECT me.MessageId, me.RequestId, me.VoidingHistoryId, me.UsernameList
	FROM #Messages me
	WHERE NOT EXISTS (SELECT 1 FROM dbo.crmMessageImport m WITH (NOLOCK) WHERE m.MessageID = me.MessageId AND m.RequestID = me.RequestId) 
		
	DROP TABLE #Messages
END
GO