/*<info serverAlias="DBACC-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/

USE bodb02
GO

ALTER PROCEDURE [dbo].[Acc_CRM_AutoFB_AbnormalBets_GetVoidedInfo]	
	@LastVoidingHistoryCollectionId	INT
	,@MaxVoidingHistoryCollectionId INT OUTPUT
	,@BatchSize INT = 10
AS
/*
	Created: 20240109@Malcolm
	Task : Get voiding abnormal tickets
	DB: DBACC/bodb02
	Original:

	Revisions:
		- 20240109@Malcolm: Initial SPs [redmine:#198905]
        - 20240327@Ned.Le: CRM - Support Auto Feedback for voiding System Parlay tickets of Abnormal bet from TVS [RedmineId : #201913]
		
	Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON
		
	DECLARE @MaxLogId INT = 0

	SELECT @MaxLogId = MAX(VoidingHistoryCollectionId) FROM dbo.VoidingHistoryCollection WITH(NOLOCK) 
	
	SELECT TOP(1) @MaxLogId = VoidingHistoryCollectionId - 1
	FROM dbo.VoidingHistoryCollection WITH(NOLOCK) 
	WHERE VoidingHistoryCollectionId <= @MaxLogId AND IsProcessing = 1
	ORDER BY VoidingHistoryCollectionId ASC

	CREATE TABLE #VoidedCollectionInfo 
	(
		VoidingHistoryCollectionId	INT
		,VoidingHistoryId			INT
		,RequestId					INT
		,MessageId					INT
		,SiteDBGroupID				SMALLINT
		,IssueTypeId				TINYINT
		,RequestBy					NVARCHAR(200)
		,DecidedBy					NVARCHAR(200)
		,VoidBy						NVARCHAR(200)
		,MatchId					INT
		,TransIdList				VARCHAR(MAX)
		,UsernameList				NVARCHAR(MAX)
		,ReasonList					NVARCHAR(MAX)
		,OriginalTransId			VARCHAR(MAX)
		,FilterBy					TINYINT
		,MinWinlostdate				DATETIME
		,MaxWinlostdate				DATETIME
	)

	;WITH CTE_BatchSize AS (
		SELECT TOP(@BatchSize) VoidingHistoryCollectionId	
		FROM dbo.VoidingHistoryCollection d WITH(NOLOCK)
		WHERE VoidingHistoryCollectionId > @LastVoidingHistoryCollectionId AND VoidingHistoryCollectionId <= @MaxLogId
		ORDER BY VoidingHistoryCollectionId ASC
	)
	INSERT INTO #VoidedCollectionInfo 
	(
		VoidingHistoryCollectionId	
		,VoidingHistoryId			
		,RequestId					
		,MessageId					
		,SiteDBGroupID				
		,IssueTypeId				
		,RequestBy					
		,DecidedBy					
		,VoidBy						
		,MatchId					
		,TransIdList				
		,UsernameList				
		,ReasonList					
		,OriginalTransId			
		,FilterBy					
		,MinWinlostdate				
		,MaxWinlostdate				
	)
	SELECT 
		d.VoidingHistoryCollectionId	
		,d.VoidingHistoryId			
		,d.RequestId					
		,d.MessageId					
		,d.SiteDBGroupID				
		,d.IssueTypeId				
		,d.RequestBy					
		,d.DecidedBy					
		,d.VoidBy						
		,d.MatchId					
		,d.TransIdList				
		,d.UsernameList				
		,d.ReasonList					
		,d.OriginalTransId			
		,d.FilterBy					
		,d.MinWinlostdate				
		,d.MaxWinlostdate	
	FROM dbo.VoidingHistoryCollectionDetail d WITH(NOLOCK)
		INNER JOIN CTE_BatchSize b ON b.VoidingHistoryCollectionId = d.VoidingHistoryCollectionId
	ORDER BY d.VoidingHistoryCollectionId ASC

	DECLARE @Result TABLE 
	(
		VoidingHistoryCollectionId	INT
		,RequestId					INT
		,MessageId					INT
		,IssueTypeId				TINYINT
		,IsParlay					BIT
		,RequestBy					NVARCHAR(200)
		,DecidedBy					NVARCHAR(200)
		,VoidBy						NVARCHAR(200)
		,MatchId					INT
		,TransIdList				VARCHAR(MAX)
		,UsernameList				NVARCHAR(MAX)
		,OriginalTransId			VARCHAR(MAX)
	)
	
	INSERT INTO @Result 
	(
		VoidingHistoryCollectionId
		,RequestId
		,MessageId
		,IssueTypeId				
		,IsParlay
		,RequestBy
		,DecidedBy
		,VoidBy
		,MatchId
		,TransIdList
		,OriginalTransId
	)
	SELECT 
		VoidingHistoryCollectionId
		,RequestId
		,MessageId
		,IssueTypeId				
		,CASE WHEN IssueTypeId IN (11, 20) AND ISNULL(FilterBy, 0) IN (1, 2) THEN 1 ELSE 0 END AS IsParlay
		,RequestBy
		,DecidedBy
		,VoidBy
		,MatchId
		,TransIdList
		,OriginalTransId
	FROM #VoidedCollectionInfo
	WHERE IssueTypeId IN (11, 15, 20)
	ORDER BY VoidingHistoryCollectionId, MessageId

	-- Abnormal Accounts
	;WITH CTE_UsernameList AS (
		SELECT VoidingHistoryCollectionId, MessageId, RequestId, RequestBy, DecidedBy, ReasonList, VoidBy, UsernameList, IssueTypeId, 0 AS IsParlay
		FROM #VoidedCollectionInfo
		WHERE IssueTypeId = 13
	)
	INSERT INTO @Result 
	(
		VoidingHistoryCollectionId
		,RequestId
		,MessageId
		,IssueTypeId				
		,IsParlay
		,RequestBy
		,DecidedBy
		,VoidBy
		,MatchId
		,TransIdList
		,OriginalTransId
		,UsernameList
	)
	SELECT 
		VoidingHistoryCollectionId
		,RequestId
		,MessageId
		,IssueTypeId
		,IsParlay
		,RequestBy
		,DecidedBy
		,VoidBy
		,0 AS MatchId
		,TransIdList
		,'' AS OriginalTransId
		,UsernameList
	FROM CTE_UsernameList u
	CROSS APPLY (
		SELECT STRING_AGG(CONVERT(VARCHAR(MAX), TransId), ',') WITHIN GROUP (ORDER BY TransId) AS TransIdList
		FROM bodb02.dbo.TicketVoiding_VoidedTransaction vt WITH(NOLOCK) 
		WHERE vt.MessageId = u.MessageId
	) AS n	

	SELECT @MaxVoidingHistoryCollectionId = ISNULL(MAX(VoidingHistoryCollectionId), 0) FROM @Result
	
	SELECT 
		VoidingHistoryCollectionId
		,RequestId
		,MessageId
		,IssueTypeId				
		,IsParlay
		,RequestBy
		,DecidedBy
		,VoidBy
		,MatchId
		,TransIdList
		,OriginalTransId
		,UsernameList
	FROM @Result
	ORDER BY VoidingHistoryCollectionId, RequestId, MessageId

	SELECT VoidingHistoryCollectionId, MIN(MessageId) AS MessageId	
	FROM #VoidedCollectionInfo
	GROUP BY VoidingHistoryCollectionId

	DROP TABLE #VoidedCollectionInfo
END
GO	