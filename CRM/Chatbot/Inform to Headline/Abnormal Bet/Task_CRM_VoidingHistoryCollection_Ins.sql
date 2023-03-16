/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Task_CRM_VoidingHistoryCollection_Ins]
AS
/*
	Created: 20230104@Malcolm
	Task : Collect message 
	DB: DBACC/bodb02
	Original:
		Revisions:
			- 20230104@Malcolm: Initialize SPs [Redmine: #181906]
	Param's Explanation:
		
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @Id INT, @VoidingHistoryCollectionId INT, @CurrentDate DATETIME = GETDATE(), @Time DATETIME, @ErrMsg NVARCHAR(2000) = '', @CollectionId INT = 0

	CREATE TABLE #Result (Id INT, BroadcastSessionId VARCHAR(100), VoidingHistoryId INT, ModifiedDate DATETIME, CreatedDate DATETIME, MatchId INT, StatusId INT, IsCollect BIT DEFAULT(1))

	CREATE CLUSTERED INDEX CIX_BroadcastSessionId_MatchId ON #Result (BroadcastSessionId, MatchId)

	IF EXISTS (SELECT 1 FROM dbo.VoidingHistoryCollection WITH(NOLOCK) WHERE IsProcessing = 1)
	BEGIN
		SELECT @Time = MIN(CreatedDate) FROM dbo.VoidingHistoryCollection WITH(NOLOCK) WHERE IsProcessing = 1

		IF DATEDIFF(MINUTE, @Time, @CurrentDate) >= 5
		BEGIN
			UPDATE dbo.VoidingHistoryCollection WITH(ROWLOCK, UPDLOCK)
				SET IsProcessing = 0
			WHERE IsProcessing = 1

			SELECT @ErrMsg = 'SQL Server Job System: ''bodb02: Collect Ticketvoiding_VoidingHistory for CRM-ChatBot'' failed on ' + @@SERVERNAME
			RAISERROR(@ErrMsg, 16, 1)
		END
		RETURN
	END

	INSERT INTO #Result (BroadcastSessionId, VoidingHistoryId, MatchId, StatusId, ModifiedDate, CreatedDate)
	SELECT 
		DISTINCT vh.BroadcastSessionId
		,vh.VoidingHistoryId
		,CASE WHEN r.ActionId = 1 THEN ISNULL(rq.MatchId, 0) ELSE 0 END AS MatchId
		,CASE WHEN vh.StatusId = 2 AND r.IssueTypeId = 13 AND vh.MinWinlostdate IS NULL THEN 1 ELSE vh.StatusId END
		,DATEADD(MINUTE, 1, vh.ModifiedDate) AS ModifiedDate
		,vh.CreatedDate
	FROM dbo.TicketVoiding_VoidingHistory vh WITH (NOLOCK)
		INNER JOIN dbo.TicketVoiding_Request r WITH (NOLOCK) ON vh.RequestId = r.RequestId AND (r.IssueTypeId IN (11,15) OR r.IssueTypeId = 13)-- abnormal bet(11), Abnormal Accounts(13), AB (real member)(15)
		CROSS APPLY (
			SELECT TOP(1) MatchId
			FROM dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
			WHERE rd.RequestId = r.RequestId
			ORDER BY Id ASC
		) AS rq (MatchId)
	WHERE vh.CreatedDate >= @CurrentDate - 1
		AND NOT EXISTS (SELECT 1 FROM dbo.VoidingHistoryCollectionDetail d WITH(NOLOCK) WHERE d.VoidingHistoryId = vh.VoidingHistoryId)
	ORDER BY BroadcastSessionId, VoidingHistoryId

	--Delete Broadcast Session Id created 5 seconds from the current time to remove sessions that have not yet been voided
	;WITH CTE_Session AS
	(
		SELECT BroadcastSessionId, MIN(CreatedDate) AS CreatedDate
		FROM #Result r
		GROUP BY BroadcastSessionId
		HAVING MIN(CreatedDate) > DATEADD(SECOND, -5, @CurrentDate)
	)
	DELETE r
	FROM #Result r
		INNER JOIN CTE_Session s ON s.BroadcastSessionId = r.BroadcastSessionId

	;WITH CTE_Session AS
	(
		SELECT  
			BroadcastSessionId
			,MatchId
			,MAX(CASE WHEN StatusId <> 2 THEN 1 ELSE 0 END) + MAX(CASE WHEN StatusId = 2 THEN 2 ELSE 0 END) AS StatusSum
			,MIN(CASE WHEN StatusId = 2 THEN ModifiedDate ELSE NULL END) AS ModifiedDate
		FROM #Result
		GROUP BY BroadcastSessionId, MatchId
	),CTE_SessionCollection AS
	(
		SELECT BroadcastSessionId, MatchId
		FROM CTE_Session s
		WHERE StatusSum = 2 OR (StatusSum = 3 AND @CurrentDate >= ModifiedDate)
	)
	UPDATE r
		SET r.IsCollect = 0 
	FROM #Result r
		LEFT JOIN CTE_SessionCollection e ON e.BroadcastSessionId = r.BroadcastSessionId AND e.MatchId = r.MatchId 
	WHERE e.BroadcastSessionId IS NULL

	DELETE FROM #Result WHERE StatusId <> 2 OR IsCollect = 0

	UPDATE r
		SET r.Id = r.rn
	FROM (
		SELECT Id, DENSE_RANK() OVER(ORDER BY r.BroadcastSessionId, r.MatchId) AS rn
		FROM #Result r
	) r

	SET @Id = 1
	WHILE EXISTS (SELECT 1 FROM #Result r WHERE r.Id = @Id) 
	BEGIN
		INSERT INTO dbo.VoidingHistoryCollection (IsProcessing) VALUES (1)

		SELECT @VoidingHistoryCollectionId = SCOPE_IDENTITY()

		INSERT INTO dbo.VoidingHistoryCollectionDetail (VoidingHistoryCollectionId, VoidingHistoryId)
		SELECT @VoidingHistoryCollectionId, r.VoidingHistoryId
		FROM #Result r
		WHERE r.Id = @Id

		UPDATE dbo.VoidingHistoryCollection WITH(ROWLOCK, UPDLOCK)
			SET IsProcessing = 0
		WHERE VoidingHistoryCollectionId = @VoidingHistoryCollectionId

		SET @Id += 1
	END
	
	--keep data for 2 months

	SELECT @CollectionId = MAX(VoidingHistoryCollectionId) FROM dbo.VoidingHistoryCollection WITH(NOLOCK) WHERE CreatedDate <= DATEADD(MONTH, -2 , @CurrentDate)

	IF ISNULL(@CollectionId, 0) <> 0
	BEGIN
		DELETE dbo.VoidingHistoryCollectionDetail WITH(ROWLOCK, UPDLOCK)
		WHERE VoidingHistoryCollectionId <= @CollectionId

		DELETE dbo.VoidingHistoryCollection WITH(ROWLOCK, UPDLOCK)
		WHERE VoidingHistoryCollectionId <= @CollectionId
	END
	
	DROP TABLE #Result
END
GO