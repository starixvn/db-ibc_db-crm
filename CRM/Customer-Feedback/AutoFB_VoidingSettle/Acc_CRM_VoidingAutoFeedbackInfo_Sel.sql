/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_VoidingAutoFeedbackInfo_Sel] 
	@BatchSize INT = 10
AS
/*
	Created: 20210908@Winfred
	Task : Get list Create FB into CRM
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20210908@Winfred: Integrate Auto generate Feedbacks for Voiding Settled Tickets [RedmineId : #157481]
		- 20211124@Winfred: fix site column for Voiding Settled Tickets [RedmineId : #164235]
		- 20220817@Winfred: Don't generate feedback for those ignored accounts [redmine:#173914]
	Parameter's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON
		
	CREATE TABLE #ResultDetail (LogEventID INT,
							LogVoidingID INT ,
							MatchId INT ,
							MatchCode NVARCHAR(MAX),
							ProductID INT, 
							EventType	TINYINT,
							EventDate DATETIME,
							Sporttype TINYINT,
							leagueid	INT,
							leaguenametc NVARCHAR(100),
							homeid	INT,
							awayid	INT,
							KO_time DATETIME,
							race_time DATETIME,
							Product_Sort INT,
							SportName_Sort NVARCHAR(150)
							)
	DECLARE @Message  TABLE (LogVoidingID INT )
	
	UPDATE fb 
	SET status = 'ignore',UpdatedTime = GETDATE()
	FROM crmAutoFBVoiding fb  WITH(UPDLOCK,ROWLOCK)
		LEFT JOIN crmCustomer c WITH(NOLOCK) ON fb.HeadlineID = c.custid
	WHERE status IN ('initial','fail') AND retryCount < 5  AND c.CustID IS NOT NULL AND c.Ignored = 1

	INSERT INTO @Message (LogVoidingID)
	SELECT TOP (@BatchSize) 
		LogVoidingID
	FROM crmAutoFBVoiding an WITH(NOLOCK)
	WHERE an.Status IN ('initial','fail')	AND an.retryCount < 5
	ORDER BY an.LogVoidingID	
	
	INSERT INTO #ResultDetail(LogEventID,LogVoidingID,MatchId,MatchCode,ProductID,EventType,EventDate,Product_Sort)
	SELECT LogEventID,LogVoidingID,MatchId,MatchCode,ProductID,EventType,EventDate,
		 CASE WHEN ProductID  =  1 AND EventType NOT IN (2,9) THEN 1
			  WHEN ProductID  = 27 THEN 2
			  WHEN ProductID  =  5 THEN 3
			  WHEN ProductID  = 3  THEN 4
			  WHEN EventType IN (2,9)  THEN 5 ELSE 1 END AS Product_Sort
	FROM crmAutoEventVoiding an WITH(NOLOCK)
	WHERE LogVoidingID IN (SELECT LogVoidingID FROM @Message)
	-- Get data from Match when EventType = 1
	Update r
	SET r.sporttype = m.Sporttype
		,r.homeid = m.homeid
		,r.awayid = m.awayid
		,r.leagueid = m.leagueid
		,r.KO_time = m.GlobalShowTime
		,r.eventdate = m.eventdate
		,r.MatchCode = m.MatchCode
	FROM #ResultDetail r
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
	FROM #ResultDetail r
		INNER JOIN bodb02.dbo.match14 m WITH(NOLOCK) ON r.MatchId = m.matchid
	WHERE 	r.EventType = 1 AND r.Sporttype IS NULL
	
	-- Get data from Match when EventType = 3
	Update r
	SET r.sporttype = vi.sporttype
		,r.leagueid = vi.leagueid
		,r.eventdate = vi.EventTime
		,r.race_time = vi.EventTime
	FROM #ResultDetail r
		INNER JOIN bodb02.dbo.VSRaceInfo vi WITH(NOLOCK) ON r.MatchId = vi.EventID
	WHERE 	r.EventType = 3
	
	Update r
	SET r.sporttype = vi.sporttype
		,r.leagueid = vi.leagueid
		,r.eventdate = vi.EventTime
		,r.race_time = vi.EventTime
	FROM #ResultDetail r
		INNER JOIN bodb02.dbo.VSRaceInfo14 vi WITH(NOLOCK) ON r.MatchId = vi.EventID
	WHERE 	r.EventType = 3  AND r.Sporttype IS NULL

	-- Get data from Match when EventType = 0
	Update r
	SET r.sporttype = r.MatchId
	FROM #ResultDetail r
	WHERE 	r.EventType = 0
	-- Get data from Match when EventType = Outright
	Update r
	SET r.homeid = m.teamid
		,r.leagueid = m.leagueid
		,r.leaguenametc = t.leaguenametc
		,r.KO_time = m.kickofftime
	FROM #ResultDetail r
		INNER JOIN bodb02.dbo.Outright m WITH(NOLOCK) ON r.MatchId = m.orid
		INNER JOIN bodb02.dbo.League t WITH(NOLOCK) ON t.leagueid = m.leagueid
	WHERE 	r.EventType = 2 
	
	Update r
	SET r.SportName_Sort = CAST(CASE WHEN r.Sporttype = 1 THEN 1 WHEN r.Sporttype = 2 THEN 2 ELSE 3 END AS VARCHAR(5)) + '_' + ISNULL(c.SportName,'')
	FROM #ResultDetail r
	left join bodb02.dbo.Sports c  WITH(NOLOCK)  on r.Sporttype = c.SportType
	
	SELECT fb.LogVoidingID
			,fb.MessageId
			,fb.HeadlineID
			,fb.HeadlineName
			,ISNULL(hl.IsVip,0) as IsVip
			,fb.ProductID
			,fb.RetryCount
			,fb.affectedId
			,fb.affectedName
			,fb.ListMsgTargetId
			,fb.Listbettype
			,fb.CreatedDate
			,c.site
	FROM [dbo].[crmAutoFBVoiding] fb WITH(NOLOCK) 
	INNER JOIN @Message m ON FB.LogVoidingID =  m.LogVoidingID
	INNER JOIN bodb02.dbo.customer c WITH(NOLOCK) ON fb.HeadlineID = c.custid
	LEFT JOIN crmCustomer hl WITH(NOLOCK) ON fb.HeadlineID = hl.custid
	
	SELECT 
		LogVoidingID,
		MatchId,
		MatchCode,
		EventType,
		Sporttype ,
		leagueid ,
		leaguenametc,
		homeid	,
		awayid	,
		KO_time ,
		eventdate ,
		race_time ,
		ProductID
	FROM #ResultDetail
	order by Product_Sort , EventDate DESC, SportName_Sort , KO_time DESC, leaguenametc
	
			
END	