/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_Chatbot_AbnormalBets_GetMessage]
AS

/*
	Created: 20200811@Percy
	DB: DBACC.bodb02
	Task: CRM - ChatBot - Get Message List of Voiding Abnormal Bets from special delete site

	Revisions:
		- 20200811@Percy: Initialize SP [RedmineID: #130544]
		- 20210415@Malcolm: Notify Tickets of AB (Real Member) [RedmineId : #153259]
		- 20210415@Malcolm: Integrate Abnormal Accounts [RedmineId : #157303]
*/

BEGIN
	SET NOCOUNT ON

	SELECT DISTINCT vh.MessageId, vh.RequestId, r.IssueTypeId
	FROM dbo.TicketVoiding_VoidingHistory vh WITH (NOLOCK)
		INNER JOIN TicketVoiding_Request r WITH (NOLOCK) ON vh.RequestId = r.RequestId AND (r.IssueTypeId IN (11,15) OR r.IssueTypeId = 13 AND vh.MinWinlostdate IS NOT NULL)-- abnormal bet(11), Abnormal Accounts(13), AB (real member)(15)
	WHERE vh.CreatedDate >= GETDATE() - 1
		AND vh.StatusId = 2 -- tickets void successfully
	ORDER BY MessageId
END
GO