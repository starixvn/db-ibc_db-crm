/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_AmendmentNoti_AutoFeedbackInfoSel] 
	@BatchSize INT = 10
AS
/*
	Created: Winfred
	Task : import list customers reach Amendment Notification into CRM
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 202010303@Winfred: Initial sp [redmine:#147470]
		- 20220817@Winfred: Don't generate feedback for those ignored accounts [redmine:#173914]
	
	Parameter's Explanation:

*/
BEGIN
	SET NOCOUNT ON
	CREATE TABLE #Result (LogID INT,
							TicketEventId INT ,
							HeadlineID INT ,
							HeadlineName VARCHAR(50),
							ProductID INT, 
							affectedId VARCHAR(MAX),
							affectedName VARCHAR(MAX), 
							MatchId	INT,
							MatchCode	NVARCHAR(100),
							EventType	TINYINT,
							MessageId INT,
							ActualResult	NVARCHAR(MAX),
							WrongResult	NVARCHAR(MAX),	
							Listbettype VARCHAR(MAX) ,
							currency  NVARCHAR(50),
							site VARCHAR(10),
							Sporttype TINYINT,
							leagueid	INT,
							leaguenametc NVARCHAR(100),
							homeid	INT,
							awayid	INT,
							KO_time DATETIME,
							eventdate DATETIME,
							race_time DATETIME
							)
	UPDATE fb 
	SET status = 'ignore',UpdatedTime = GETDATE()
	FROM crmAmendmentNotiFeedbackInfo fb  WITH(UPDLOCK,ROWLOCK)
		LEFT JOIN crmCustomer c WITH(NOLOCK) ON fb.HeadlineID = c.custid
	WHERE status IN ('initial','fail') AND retryCount < 5  AND c.CustID IS NOT NULL AND c.Ignored = 1

	INSERT INTO #Result (LogID,TicketEventId, HeadlineID,HeadlineName,ProductID,affectedId,affectedName,MatchId,MatchCode,EventType,MessageId,ActualResult,WrongResult,Listbettype,currency,site)
	SELECT TOP (@BatchSize) 
		an.LogID
		,an.TicketEventId
		,an.HeadlineID
		,an.HeadlineName
		,an.ProductID
		,an.affectedId
		,an.affectedName
		,an.MatchId
		,an.MatchCode
		,an.EventType
		,an.MessageId
		,an.ActualResult
		,an.WrongResult
		,an.Listbettype
		,e.currency
		,c.site
	FROM crmAmendmentNotiFeedbackInfo an with(nolock)
		INNER JOIN bodb02.dbo.customer c WITH(NOLOCK) ON an.HeadlineID = c.custid
		INNER JOIN bodb02.dbo.Exchange e WITH(NOLOCK) ON c.currency = e.ExchangeId
	WHERE an.Status IN ('initial','fail')	AND an.retryCount < 5
	ORDER BY an.LogID
	
	-- Don't get FB Duplicate 
	;WITH Temp AS( 
		SELECT LogID, ROW_NUMBER() OVER( PARTITION BY TicketEventId,HeadlineID,ActualResult,WrongResult,MessageId,affectedId ORDER BY LogID) AS RowNum
		FROM #Result
	)
	DELETE del 
	FROM #Result del
		INNER JOIN Temp rCheck ON del.LogID = rCheck.LogID
	WHERE rCheck.RowNum > 1
	
	-- Update FB Duplicate 	
	UPDATE Upd 
	SET Upd.Status = 'duplicated'
	FROM crmAmendmentNotiFeedbackInfo Upd WITH(UPDLOCK,ROWLOCK)
	INNER JOIN #Result rCheck ON Upd.TicketEventId = rCheck.TicketEventId AND Upd.HeadlineID = rCheck.HeadlineID 
								AND Upd.affectedId = rCheck.affectedId AND ISNULL(Upd.ActualResult,'') = ISNULL(rCheck.ActualResult,'') 
								AND ISNULL(Upd.WrongResult,'') = ISNULL(rCheck.WrongResult,'')
								AND ISNULL(Upd.MessageId,0) = ISNULL(rCheck.MessageId,0)
	WHERE Upd.Status IN ('initial','fail')  AND Upd.LogID <> rCheck.LogID AND Upd.retryCount < 5
	--Delete record from temp table and mark dupliceted if processed before
	DECLARE @ProcessedRecord TABLE (LogID INT)

	DELETE r
	OUTPUT deleted.LogID INTO @ProcessedRecord(LogID)
	FROM crmAmendmentNotiFeedbackInfo c WITH(NOLOCK)
		INNER JOIN #Result r ON c.HeadlineID = r.HeadlineID AND c.TicketEventId = r.TicketEventId
								AND c.affectedId = r.affectedId AND ISNULL(c.ActualResult,'') = ISNULL(r.ActualResult,'') 
								AND ISNULL(c.WrongResult,'') = ISNULL(r.WrongResult,'') AND ISNULL(c.MessageId,0) = ISNULL(r.MessageId,0)
	WHERE c.Status = 'completed'  AND c.LogID <> r.LogID 

	UPDATE c
	SET c.Status = 'duplicated'
	FROM crmAmendmentNotiFeedbackInfo c WITH(ROWLOCK,UPDLOCK)
		INNER JOIN @ProcessedRecord r ON c.LogID = r.LogID
	
	-- Get data from Match when EventType = 1
	Update r
	SET r.sporttype = m.Sporttype
		,r.homeid = m.homeid
		,r.awayid = m.awayid
		,r.leagueid = m.leagueid
		,r.KO_time = m.GlobalShowTime
		,r.eventdate = m.eventdate
		,r.MatchCode = m.MatchCode
	FROM #Result r
		INNER JOIN bodb02.dbo.match m WITH(NOLOCK) ON r.MatchId = m.matchid
	WHERE 	r.EventType = 1
	
	Update r
	SET r.sporttype = m.Sporttype
		,r.homeid = m.homeid
		,r.awayid = m.awayid
		,r.leagueid = m.leagueid
		,r.KO_time = m.GlobalShowTime
		,r.eventdate = m.eventdate
		,r.MatchCode = m.MatchCode
	FROM #Result r
		INNER JOIN bodb02.dbo.match14 m WITH(NOLOCK) ON r.MatchId = m.matchid
	WHERE 	r.EventType = 1 AND r.Sporttype IS NULL
	
	-- Get data from Match when EventType = 3
	Update r
	SET r.sporttype = vi.sporttype
		,r.leagueid = vi.leagueid
		,r.eventdate = vi.EventTime
		,r.race_time = vi.EventTime
	FROM #Result r
		INNER JOIN bodb02.dbo.VSRaceInfo vi WITH(NOLOCK) ON r.MatchId = vi.EventID
	WHERE 	r.EventType = 3
	
	Update r
	SET r.sporttype = vi.sporttype
		,r.leagueid = vi.leagueid
		,r.eventdate = vi.EventTime
		,r.race_time = vi.EventTime
	FROM #Result r
		INNER JOIN bodb02.dbo.VSRaceInfo14 vi WITH(NOLOCK) ON r.MatchId = vi.EventID
	WHERE 	r.EventType = 3  AND r.Sporttype IS NULL

	-- Get data from Match when EventType = 0
	Update r
	SET r.sporttype = ev.MatchId
		,r.eventdate = ev.EventDate
	FROM #Result r
		INNER JOIN bodb02.dbo.TicketAmendment_Event ev WITH(NOLOCK) ON r.TicketEventId = ev.TicketEventId
	WHERE 	r.EventType = 0
	-- Get data from Match when EventType = Outright
	Update r
	SET r.homeid = m.teamid
		,r.leagueid = m.leagueid
		,r.leaguenametc = t.leaguenametc
		,r.KO_time = m.kickofftime
	FROM #Result r
		INNER JOIN bodb02.dbo.Outright m WITH(NOLOCK) ON r.MatchId = m.orid
		INNER JOIN bodb02.dbo.League t WITH(NOLOCK) ON t.leagueid = m.leagueid
	WHERE 	r.EventType = 2 
	
	Update r
	SET r.sporttype = t.SportType
		,r.leagueid = t.leagueid
		,r.leaguenametc = t.leaguenametc
		,r.KO_time = m.kickofftime
	FROM #Result r
		INNER JOIN bodb02.dbo.League t WITH(NOLOCK) ON t.leagueid = r.MatchId
		CROSS APPLY ( SELECT TOP 1 kickofftime FROM bodb02.dbo.Outright m WITH(NOLOCK) WHERE m.leagueid = r.MatchId   ) AS m
	WHERE 	r.EventType = 9
	
	
	SELECT 
		LogID,
		TicketEventId, 
		HeadlineID,
		HeadlineName,
		ProductID,
		affectedId,
		affectedName,
		MatchId,
		MatchCode,
		EventType,
		ActualResult,
		WrongResult,
		Listbettype,
		currency,
		MessageId,
		site,
		ISNULL(hl.IsVip,0) as IsVip,
		Sporttype ,
		leagueid ,
		leaguenametc,
		homeid	,
		awayid	,
		KO_time ,
		eventdate ,
		race_time 
	FROM #Result f
	LEFT JOIN crmCustomer hl WITH(NOLOCK) ON f.HeadlineID = hl.custid
	ORDER BY TicketEventId
		
	DROP TABLE #Result	
END	