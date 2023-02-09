/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_VoidingMessageSel]	
	@MaxLogVHCID	INT
AS
/*
	Created: 20200612@Johnson
	Task : Get voiding abnormal tickets message
	DB: DBACC/bodb02
	Original:

	Revisions:
		- 20200612@Johnson: Initial sp [redmine:#135719]
		- 20200810@Johnson: Add requestID to check missing auto void request [redmine:#139158]	
		- 20210414@Johnson: add new issuetype 15 (AB Real member)[redmine:#153341]
		- 20210705@Winfred: Integrate Abnormal Accounts [RedmineId : #157303]
		- 20230131@Winfred: Scale Out for CRM [RedmineId : #181906]
	Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON
		
	DECLARE @MaxLogId INT = 0

	SELECT @MaxLogId = MIN(VoidingHistoryCollectionId) FROM dbo.VoidingHistoryCollection WITH(NOLOCK) 
	WHERE IsProcessing = 1

	DECLARE @Result TABLE (VoidingHistoryCollectionId INT, MessageId INT, RequestId INT, VoidingHistoryId INT, 
							UsernameList NVARCHAR(MAX), IssueTypeId TINYINT)

	;WITH CTE AS
	(
		SELECT VoidingHistoryCollectionId
		FROM dbo.VoidingHistoryCollection WITH(NOLOCK)
		WHERE VoidingHistoryCollectionId > @MaxLogVHCID AND VoidingHistoryCollectionId <= @MaxLogId
	)
	INSERT INTO @Result (VoidingHistoryCollectionId, VoidingHistoryId)
	SELECT d.VoidingHistoryCollectionId, d.VoidingHistoryId
	FROM dbo.VoidingHistoryCollectionDetail d WITH(NOLOCK)
		INNER JOIN CTE e ON e.VoidingHistoryCollectionId = d.VoidingHistoryCollectionId
	ORDER BY VoidingHistoryCollectionId ASC, VoidingHistoryId ASC

	UPDATE r
	SET r.MessageId = vh.MessageId, r.RequestId = vh.RequestId, r.IssueTypeId = rq.IssueTypeId, 
		r.UsernameList = CASE WHEN rq.IssueTypeId = 13 THEN l.Usernames ELSE '' END
	FROM @Result r
		INNER JOIN dbo.TicketVoiding_VoidingHistory vh WITH(NOLOCK) ON vh.VoidingHistoryId = r.VoidingHistoryId
		INNER JOIN dbo.TicketVoiding_Request rq WITH(NOLOCK) ON vh.RequestId = rq.RequestId 
		OUTER APPLY (
			SELECT TOP 1 rd.Usernames
			FROM dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
			WHERE rd.RequestId = r.RequestId
		) l(Usernames)
		
	SELECT DISTINCT VoidingHistoryCollectionId, MessageId, RequestId
	FROM @Result

	SELECT VoidingHistoryCollectionId , MessageId, RequestId, VoidingHistoryId, UsernameList
	FROM @Result
	WHERE IssueTypeId  = 13 -- Abnormal accounts
	
END
GO	