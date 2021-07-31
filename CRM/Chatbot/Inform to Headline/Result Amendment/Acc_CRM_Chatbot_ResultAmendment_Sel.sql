/*<info serverAlias="DBMSG-bodb_Message" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_Chatbot_ResultAmendment_Sel]
	@BatchSize INT = 3000
	,@SubmitDate DATETIME2 
	,@Seq INT
AS

/*
	Created: 20200811@Percy
	DB: DBMSG-bodb_Message
	Task: CRM - ChatBot - Get ticket

	Revisions:
		- 20210728@Malcolm: Initialize SP [RedmineID: #130544]

	Param's Explanation:
		Type = 1: Result Amendment Template - Sportsbook	
		Type = 2: Result Amendment Template - Virtual Sports 2	
		Type = 3: Result Amendment Template - Virtual Sports
		Type = 4: Result Amendment Template - Number Game (Number Game, Turbo Number Game, Happy 5, Happy 5 Linked Game)
		Type = 5: Result Amendment Template - Outright	

*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #TicketDetail (TicketId INT, CustId INT, TicketEventId INT)
	INSERT INTO #TicketDetail (TicketId, CustId, TicketEventId)
	SELECT TOP(@BatchSize) d.TicketId, d.CustId, d.TicketEventId
	FROM dbo.TicketAmendment_Detail d WITH(NOLOCK)
		INNER JOIN dbo.TicketAmendment_Event e WITH(NOLOCK) ON e.TicketEventId = d.TicketEventId
	WHERE e.SubmitDate > @SubmitDate OR (e.SubmitDate = @SubmitDate AND d.Seq > @Seq)

	DECLARE @EventId TABLE (TicketEventId INT)
	INSERT INTO @EventId (TicketEventId)
	SELECT DISTINCT TicketEventId
	FROM #TicketDetail

	IF EXISTS (
		SELECT 1 
		FROM dbo.TicketAmendment_Event e WITH(NOLOCK)
			INNER JOIN @EventId i ON i.TicketEventId = e.TicketEventId
		WHERE e.Status IS NULL
	) 
	BEGIN
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
		,Sporttype	    
		,HomeId			
		,AwayId			
		,LeagueId		
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
			SET e.HomeId = m.Homeid, e.AwayId = m.Awayid, e.LeagueId = m.LeagueId, e.Sporttype = m.Sporttype, e.MatchCode = m.matchcode
		FROM #TicketEvent e
			INNER JOIN dbo.match14 m WITH(NOLOCK) ON m.matchid = e.MatchId
		WHERE e.EventType = 1
	END
	-- VS
	IF EXISTS (SELECT 1 FROM #TicketEvent WHERE EventType = 3)
	BEGIN
		UPDATE e
			SET e.Sporttype = vs.SportType
		FROM #TicketEvent e
			INNER JOIN dbo.VSRaceInfo vs WITH(NOLOCK) ON vs.EventID = e.MatchId
		WHERE e.EventType = 1

		UPDATE e
			SET e.Sporttype = vs.SportType
		FROM #TicketEvent e
			INNER JOIN dbo.VSRaceInfo14 vs WITH(NOLOCK) ON vs.EventID = e.MatchId
		WHERE e.EventType = 1
	END

	-- Update template
	UPDATE t
		SET t.Type = CASE WHEN	t.EventType = 9  THEN 5
						  WHEN  t.ProductId = 1  THEN 1
						  WHEN  t.ProductId = 27 THEN 2
						  WHEN  t.ProductId = 5  THEN 3
						  WHEN  t.ProductId = 3  THEN 4
				     END
	FROM #TicketEvent t

	SELECT t.TicketId, t.TicketEventId, n.Username, t.CustId, n.Recommend, n.Mrecommend, n.Srecommend, n.IsTest
	FROM #TicketDetail t
	CROSS APPLY
	(
		SELECT TOP(1) c.username, c.recommend, c.mrecommend, c.srecommend, CASE WHEN c.currency = 20 THEN 1 ELSE 0 END AS IsTest
		FROM dbo.Customer c WITH(NOLOCK)
		WHERE c.custid = t.CustId
	) AS n

	SELECT 
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
		,Sporttype	    
		,HomeId			
		,AwayId			
		,LeagueId	
		,Type
	FROM #TicketEvent

	SELECT TicketEventId, MessageId
	FROM #TicketEvent
	WHERE EventType = 9
	 
END
GO