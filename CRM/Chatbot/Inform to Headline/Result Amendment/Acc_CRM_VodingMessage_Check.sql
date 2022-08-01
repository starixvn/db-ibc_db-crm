/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_VodingMessage_Check]
	@Message XML
	,@Environment VARCHAR(50) = ''
AS
/*
Created: 20211105@Malcolm
Task : Check message
DB: DBCRM/bodb_CRM
Original:
	Revisions:
		- 20211105@Malcolm: Initialize SPs [Redmine: #164235]
		- 20220110@Malcolm: Include @Environment parameter [Redmine: #164235]
		- 20210111@Malcolm: If same TransId get the largest messageid [Redmine: #164235]
		- 20220801@Malcolm: Scale OUT [Redmine: #]
	Param's Explanation:
	 @Message:
			<root>
				<r MessageId="1" MsgTargetId="" BetTransId=""/>
			</root>
		
*/
BEGIN
	SET NOCOUNT ON
	CREATE TABLE #Message (MessageId INT, MsgTargetId INT, BetTransId VARCHAR(MAX))

	INSERT INTO #Message (MessageId, MsgTargetId, BetTransId)
	SELECT 
		t.c.value('@MessageId', 'INT') AS MessageId
		,t.c.value('@MsgTargetId', 'INT') AS MsgTargetId
		,t.c.value('@BetTransId', 'VARCHAR(MAX)') AS BetTransId
	FROM @Message.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@Message = NULL))

	SELECT m.MessageId, m.MsgTargetId, m.BetTransId
	FROM #Message m 
	WHERE NOT EXISTS (SELECT 1 FROM dbo.crmVoidingMessage vm WITH(NOLOCK) WHERE vm.MessageId = m.MessageId AND vm.MsgTargetId = m.MsgTargetId)

	DROP TABLE #Message
END
GO

