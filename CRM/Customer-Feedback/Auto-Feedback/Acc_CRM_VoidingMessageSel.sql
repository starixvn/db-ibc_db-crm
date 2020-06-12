/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_VoidingMessageSel]	
AS
/*
	Created: 20200612@Johnson
	Task : Get voiding abnormal tickets message
	DB: DBACC/bodb02
	Original:

	Revisions:
		- 20200612@Johnson: Initial sp [redmine:#135719]		
	Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON
		
	SELECT DISTINCT MessageId
	FROM dbo.TicketVoiding_VoidingHistory vh WITH(NOLOCK)
		INNER JOIN TicketVoiding_Request r WITH (NOLOCK) ON vh.RequestId = r.RequestId 
															AND r.IssueTypeId = 11 --abnormal bets
	WHERE CreatedDate >= GETDATE() - 1
		AND vh.StatusId = 2 --tickets void successfully
	ORDER BY MessageId ASC 	
	
END
GO	