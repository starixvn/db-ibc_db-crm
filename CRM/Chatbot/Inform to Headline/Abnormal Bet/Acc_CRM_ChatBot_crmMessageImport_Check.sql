/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_ChatBot_crmMessageImport_Check]
	@Messages XML
AS

/*
	Created: 20200811@Percy
	DB: DBCRM-bodb_CRM
	Task: CRM - ChatBot - Check what if tickets belong to abnormal accounts type or no
	Revisions:
		- 20210628@Malcolm: Initialize SP [RedmineID: #157303]

	Param's Explanation:
		@Messages:
			<root>
				<r MessageID="1" RequestID="1" IssueTypeId="11"/>
				<r MessageID="1" RequestID="2" IssueTypeId="13"/>
				<r MessageID="3" RequestID="2" IssueTypeId="15"/>
			</root>			   
*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #Messages (MessageId INT, RequestId INT, IssueTypeId TINYINT)
	INSERT INTO  #Messages (MessageId, RequestId, IssueTypeId)
	SELECT DISTINCT
		t.c.value('@MessageID', 'INT') AS MessageId
		,t.c.value('@RequestID', 'INT') AS RequestId
		,t.c.value('@IssueTypeId', 'TINYINT') AS IssueTypeId
	FROM @Messages.nodes('root/r') AS t(c)
	OPTION (OPTIMIZE FOR (@Messages = NULL))

	SELECT me.MessageId, me.RequestId
	FROM #Messages me
	WHERE NOT EXISTS (SELECT 1 FROM dbo.crmMessageImport m WITH (NOLOCK) WHERE m.MessageID = me.MessageId AND m.RequestID = me.RequestId) AND me.IssueTypeId = 13
		
	DROP TABLE #Messages
END
GO