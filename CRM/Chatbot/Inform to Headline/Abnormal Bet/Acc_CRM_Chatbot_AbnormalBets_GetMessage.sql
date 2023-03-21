/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_Chatbot_AbnormalBets_GetMessage]
	@LastVoidingHistoryCollectionId	INT
	,@BatchSize INT = 10
AS

/*
	Created: 20200811@Percy
	DB: DBACC.bodb02
	Task: CRM - ChatBot - Get Message List of Voiding Abnormal Bets from special delete site

	Revisions:
		- 20200811@Percy: Initialize SP [RedmineID: #130544]
		- 20210415@Malcolm: Notify Tickets of AB (Real Member) [RedmineId : #153259]
		- 20210415@Malcolm: Integrate Abnormal Accounts [RedmineId : #157303]
		- 20220112@Malcolm: Scale Out for CRM [RedmineId : #181906]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @MaxVoidingHistoryCollectionId INT = 0

	SELECT @MaxVoidingHistoryCollectionId = MAX(VoidingHistoryCollectionId) FROM dbo.VoidingHistoryCollection WITH(NOLOCK)

	SELECT TOP(1) @MaxVoidingHistoryCollectionId = VoidingHistoryCollectionId - 1
	FROM dbo.VoidingHistoryCollection WITH(NOLOCK) 
	WHERE VoidingHistoryCollectionId <= @MaxVoidingHistoryCollectionId AND IsProcessing = 1
	ORDER BY VoidingHistoryCollectionId ASC

	CREATE TABLE #Result (VoidingHistoryCollectionId INT, VoidingHistoryId INT, UsernameList NVARCHAR(MAX), IssueTypeId TINYINT)

	;WITH CTE AS
	(
		SELECT TOP(@BatchSize) VoidingHistoryCollectionId
		FROM dbo.VoidingHistoryCollection WITH(NOLOCK)
		WHERE VoidingHistoryCollectionId > @LastVoidingHistoryCollectionId AND VoidingHistoryCollectionId <= @MaxVoidingHistoryCollectionId
		ORDER BY VoidingHistoryCollectionId ASC
	)
	INSERT INTO #Result (VoidingHistoryCollectionId, VoidingHistoryId)
	SELECT d.VoidingHistoryCollectionId, d.VoidingHistoryId
	FROM dbo.VoidingHistoryCollectionDetail d WITH(NOLOCK)
		INNER JOIN CTE e ON e.VoidingHistoryCollectionId = d.VoidingHistoryCollectionId
	ORDER BY VoidingHistoryCollectionId ASC, VoidingHistoryId ASC

	UPDATE r
		SET r.IssueTypeId = rq.IssueTypeId, r.UsernameList = CASE WHEN rq.IssueTypeId = 13 THEN l.Usernames ELSE '' END
	FROM #Result r
		INNER JOIN dbo.TicketVoiding_VoidingHistory vh WITH(NOLOCK) ON vh.VoidingHistoryId = r.VoidingHistoryId
		INNER JOIN dbo.TicketVoiding_Request rq WITH(NOLOCK) ON vh.RequestId = rq.RequestId 
		OUTER APPLY (
			SELECT TOP 1 rd.Usernames
			FROM dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
			WHERE rd.RequestId = vh.RequestId
		) l(Usernames)

	SELECT DISTINCT VoidingHistoryCollectionId
	FROM #Result -- Abnormal bets
	WHERE IssueTypeId IN (11, 15)

	SELECT VoidingHistoryCollectionId, VoidingHistoryId, UsernameList
	FROM #Result
	WHERE IssueTypeId = 13 -- Abnormal accounts

	DROP TABLE #Result
END
GO