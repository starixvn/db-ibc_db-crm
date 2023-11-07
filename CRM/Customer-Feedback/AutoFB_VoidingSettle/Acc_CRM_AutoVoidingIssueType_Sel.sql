/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_AutoVoidingIssueType_Sel]
	@MessageIDs VARCHAR(MAX)
AS
/*
	Created: 20231009@Malcolm
	Task : Get IssueType
	DB: DBACC/bodb02
	Original:

	Revisions:
		- 20231009@Malcolm: Initialize SPs [Redmine: #191355]
	Param's Explanation:
		@MessageIDs = '<ROOT>
						 <r MessageId="1074531543"/> 
						</ROOT>'
*/

BEGIN
	SET NOCOUNT ON
	
	DECLARE @xml XML = CAST(@MessageIds AS XML)	

	DECLARE @Message TABLE (MessageId INT, IssueTypeId TINYINT)

	INSERT INTO @Message (MessageId)
	SELECT t.c.value('@MessageId[1]','int') MessageId
	FROM @xml.nodes('/ROOT/r') t(c)	

	UPDATE m
		SET m.IssueTypeId = ISNULL(r.IssueTypeId, 0) 
	FROM @Message m
		LEFT JOIN dbo.TicketVoiding_VoidingHistory vh WITH(NOLOCK) ON m.MessageId = vh.MessageId
		LEFT JOIN dbo.TicketVoiding_Request r WITH(NOLOCK) ON r.RequestId = vh.RequestId
		
	SELECT DISTINCT MessageId, IssueTypeId
	FROM @Message
	
END	