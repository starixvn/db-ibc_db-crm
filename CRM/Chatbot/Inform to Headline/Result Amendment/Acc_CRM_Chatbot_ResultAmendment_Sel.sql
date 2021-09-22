/*<info serverAlias="DBEXT-bodb02" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_Chatbot_ResultAmendment_Sel]
	@BatchSize INT = 3000
	,@SubmitDate DATETIME2(7) 
	,@Seq INT
	,@ServerName NVARCHAR(128) OUTPUT
AS

/*
	Created: 20210731@Malcolm
	DB: DBEXT-bodb02
	Task: CRM - ChatBot - Get ticket

	Revisions:
		- 20210731@Malcolm: Initialize SP [RedmineID: #151509]
		- 20210922@Malcolm: notify for Settled Ticket to Refund/Running and Missing Actual/Wrong Result [RedmineID: #161524]

	Param's Explanation:
		Type = 1: Result Amendment Template - Sportsbook	
		Type = 2: Result Amendment Template - Virtual Sports 2	
		Type = 3: Result Amendment Template - Virtual Sports
		Type = 4: Result Amendment Template - Number Game (Number Game, Turbo Number Game, Happy 5, Happy 5 Linked Game)
		Type = 5: Result Amendment Template - Outright	
		Type = 7: Result Amendment Template - No Result		

*/

BEGIN
	SET NOCOUNT ON

	DECLARE @NRows INT = 0

	SELECT @ServerName = @@SERVERNAME

	CREATE TABLE #TicketDetail (TicketId INT, CustId INT, TicketEventId INT, Seq INT)
	INSERT INTO #TicketDetail (TicketId, CustId, TicketEventId, Seq)
	SELECT TOP(@BatchSize) d.TicketId, d.CustId, d.TicketEventId, d.Seq
	FROM dbo.TicketAmendment_Detail d WITH(NOLOCK) 
		INNER JOIN dbo.TicketAmendment_Event e WITH(NOLOCK) ON e.TicketEventId = d.TicketEventId
	WHERE e.SubmitDate > @SubmitDate OR (e.SubmitDate = @SubmitDate AND d.Seq > @Seq)
	ORDER BY e.SubmitDate ASC, e.TicketEventId ASC, d.Seq ASC

	SELECT @NRows = @@ROWCOUNT

	DECLARE @EventId TABLE (TicketEventId INT PRIMARY KEY CLUSTERED)
	INSERT INTO @EventId (TicketEventId)
	SELECT DISTINCT TicketEventId
	FROM #TicketDetail

	IF EXISTS 
	(
		SELECT 1 
		FROM dbo.TicketAmendment_Event e WITH(NOLOCK)
			INNER JOIN @EventId i ON i.TicketEventId = e.TicketEventId
		WHERE e.Status IS NULL
	) OR @NRows = 0
	BEGIN
		SELECT TOP(0) '' AS TicketId, '' AS TicketEventId,'' AS Seq, '' AS Username, '' AS CustId, '' AS Recommend, '' AS Mrecommend, '' AS Srecommend, '' AS IsTest

		SELECT TOP(0)
			'' AS TicketEventId	
			,'' AS ProductId		
			,'' AS MatchId		
			,'' AS MatchCode		
			,'' AS EventType
			,'' AS SubmitDate
			,'' AS EventDate	
			,'' AS ActualResult	
			,'' AS WrongResult	
			,'' AS Status			
			,'' AS MessageId				
			,'' AS Sporttype	    
			,'' AS HomeId			
			,'' AS AwayId			
			,'' AS LeagueId	
			,'' AS Type

		SELECT TOP(0) '' AS MessageId
		RETURN
	END

	CREATE TABLE #TicketEvent 
	(
		TicketEventId	INT
		,ProductId		TINYINT 
		,MatchId		INT 
		,MatchCode		NVARCHAR(100) 
		,EventType		TINYINT 
		,EventDate		SMALLDATETIME 
		,ActualResult	NVARCHAR(MAX) 
		,WrongResult	NVARCHAR(MAX) 
		,Status			NVARCHAR(20) 
		,MessageId		INT 
		,SubmitDate		DATETIME2(7) 
		,Sporttype	    SMALLINT
		,HomeId			INT
		,AwayId			INT
		,LeagueId		INT
		,Type			TINYINT
	)

	INSERT INTO #TicketEvent 
	(
		TicketEventId	
		,ProductId		
		,MatchId		
		,MatchCode		
		,EventType		
		,EventDate		
		,ActualResult	
		,WrongResult	
		,Status			
		,MessageId		
		,SubmitDate			
	)
	SELECT	 
		e.TicketEventId	
		,e.ProductId		
		,e.MatchId		
		,e.MatchCode		
		,e.EventType		
		,e.EventDate		
		,e.ActualResult	
		,e.WrongResult	
		,e.Status			
		,e.MessageId		
		,e.SubmitDate
	FROM dbo.TicketAmendment_Event e WITH(NOLOCK)
		INNER JOIN @EventId i ON i.TicketEventId = e.TicketEventId

	IF EXISTS (SELECT 1 FROM #TicketEvent WHERE EventType = 1)
	BEGIN
		UPDATE e
			SET e.HomeId = m.Homeid, e.AwayId = m.Awayid, e.LeagueId = m.LeagueId, e.Sporttype = m.Sporttype, e.EventDate = m.eventdate, e.MatchCode = m.matchcode
		FROM #TicketEvent e
			INNER JOIN dbo.match m WITH(NOLOCK) ON m.matchid = e.MatchId
		WHERE e.EventType = 1

		UPDATE e
			SET e.HomeId = m.Homeid, e.AwayId = m.Awayid, e.LeagueId = m.LeagueId, e.Sporttype = m.Sporttype, e.EventDate = m.eventdate, e.MatchCode = m.matchcode
		FROM #TicketEvent e
			INNER JOIN dbo.match14 m WITH(NOLOCK) ON m.matchid = e.MatchId
		WHERE e.EventType = 1
	END
	-- VS
	IF EXISTS (SELECT 1 FROM #TicketEvent WHERE EventType = 3)
	BEGIN
		UPDATE e
			SET e.Sporttype = vs.SportType, e.EventDate = CONVERT(DATE, vs.EventTime)
		FROM #TicketEvent e
			INNER JOIN dbo.VSRaceInfo vs WITH(NOLOCK) ON vs.EventID = e.MatchId
		WHERE e.EventType = 3

		UPDATE e
			SET e.Sporttype = vs.SportType, e.EventDate = CONVERT(DATE, vs.EventTime)
		FROM #TicketEvent e
			INNER JOIN dbo.VSRaceInfo14 vs WITH(NOLOCK) ON vs.EventID = e.MatchId
		WHERE e.EventType = 3
	END

	IF EXISTS (SELECT 1 FROM #TicketEvent WHERE EventType = 0)
	BEGIN
		UPDATE t
			SET t.Sporttype = t.MatchId
		FROM #TicketEvent t
		WHERE EventType = 0
	END

	-- Update template
	UPDATE t
		SET t.Type = CASE WHEN	t.EventType IN (2, 9) THEN 5
						  WHEN  t.ProductId = 1  AND t.MessageId = 0 THEN 1
						  WHEN  t.ProductId = 27 AND t.MessageId = 0 THEN 2
						  WHEN  t.ProductId = 5  THEN 3
						  WHEN  t.ProductId = 3  THEN 4
						  WHEN t.ProductId IN (1, 27) AND t.MessageId <> 0 THEN 7
				     END
	FROM #TicketEvent t

	SELECT t.TicketId, t.TicketEventId, t.Seq, n.Username, t.CustId, n.Recommend, n.Mrecommend, n.Srecommend, n.IsTest
	FROM #TicketDetail t
	CROSS APPLY
	(
		SELECT TOP(1) c.username, c.recommend, c.mrecommend, c.srecommend, CASE WHEN c.currency IN (20, 72) THEN 1 ELSE 0 END AS IsTest
		FROM bodb02.dbo.Customer c WITH(NOLOCK)
		WHERE c.custid = t.CustId
	) AS n

	SELECT 
		TicketEventId	
		,ProductId		
		,MatchId		
		,MatchCode		
		,EventType
		,SubmitDate		
		,EventDate		
		,ActualResult	
		,WrongResult	
		,Status			
		,MessageId				
		,Sporttype	    
		,HomeId			
		,AwayId			
		,LeagueId	
		,Type
	FROM #TicketEvent

	SELECT t.MessageId
	FROM #TicketEvent t
	WHERE t.MessageId <> 0
	
	DROP TABLE #TicketDetail
	DROP TABLE #TicketEvent
END
GO