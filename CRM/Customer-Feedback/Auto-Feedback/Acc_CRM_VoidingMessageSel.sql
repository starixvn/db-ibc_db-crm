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
		- 20200810@Johnson: Add requestID to check missing auto void request [redmine:#139158]	
		- 20210414@Johnson: add new issuetype 15 (AB Real member)[redmine:#153341]
		- 20210705@Winfred: Integrate Abnormal Accounts [RedmineId : #157303]
	Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON
		
	DECLARE @Result TABLE (MessageId INT, RequestId INT, VoidingHistoryId INT, UsernameList NVARCHAR(MAX))

	INSERT INTO @Result (MessageId, RequestId, VoidingHistoryId)
	SELECT DISTINCT vh.MessageId, vh.RequestId, CASE WHEN r.IssueTypeId = 13 THEN vh.VoidingHistoryId ELSE 0 END AS VoidingHistoryId
	FROM dbo.TicketVoiding_VoidingHistory vh WITH (NOLOCK)
		INNER JOIN TicketVoiding_Request r WITH (NOLOCK) ON vh.RequestId = r.RequestId AND (r.IssueTypeId IN (11,15) OR (r.IssueTypeId = 13 
		AND vh.MinWinlostdate IS NOT NULL))-- abnormal bet(11), Abnormal Accounts(13), AB (real member)(15)
	WHERE vh.CreatedDate >= GETDATE() - 1
		AND vh.StatusId = 2 -- tickets void successfully
	ORDER BY MessageId

	IF EXISTS (SELECT 1 FROM @Result WHERE VoidingHistoryId <> 0)
	BEGIN
		UPDATE r
			SET r.UsernameList = l.Usernames
		FROM @Result r
		CROSS APPLY (
			SELECT TOP 1 rd.Usernames
			FROM dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
			WHERE rd.RequestId = r.RequestId
		) l(Usernames)
		WHERE r.VoidingHistoryId <> 0
	END

	SELECT DISTINCT MessageId, RequestId
	FROM @Result

	SELECT MessageId, RequestId, VoidingHistoryId, UsernameList
	FROM @Result
	WHERE VoidingHistoryId <> 0
	
END
GO	