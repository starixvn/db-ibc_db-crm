/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_Chatbot_AbnormalBets_GetMessage]
AS

/*
	Created: 20200811@Percy
	DB: DBACC.bodb02
	Task: CRM - ChatBot - Get Message List of Voiding Abnormal Bets from special delete site

	Revisions:
		- 20200811@Percy: Initialize SP [RedmineID: #130544]
*/

BEGIN
	SET NOCOUNT ON

	SELECT DISTINCT vh.MessageId, vh.RequestId
	FROM dbo.TicketVoiding_VoidingHistory vh WITH (NOLOCK)
		INNER JOIN dbo.TicketVoiding_Request r WITH (NOLOCK) ON vh.RequestId = r.RequestId AND r.IssueTypeId = 11 -- abnormal bets
	WHERE vh.CreatedDate >= GETDATE() - 1
END
GO