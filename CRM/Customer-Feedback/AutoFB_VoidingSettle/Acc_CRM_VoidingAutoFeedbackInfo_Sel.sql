/*<info serverAlias="DBCRM-bodb_CRM" executers="wsv_nap" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

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
		- 20230223@Tacy: CRM - Split 789y site [redmineID: #182438]
        - 20240207@Ned.Le: CRM/Chatbot - Message Notifications for Voiding Tickets of Special Sites (ChinaView, JollySports) [RedmineId : #198905]
		- 20240718@Luke: CRM - Incorporate new product - Virtual Sports 5 [Redmine: #207712]
        - 20240924@Ned.Le: CRM - Integrate two new sports Virtual Horses and Virtual Dogs of Product Betradar VS2 (#210788)
        - 20251016@Helios: Updated Sporttype datatype from TINYINT to SMALLINT for migration [RedmineId: #241501]
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
							Sporttype SMALLINT,
							leagueid	INT,
                            leaguegroupid INT,
							leaguenametc NVARCHAR(100),
							homeid	INT,
							awayid	INT,
							KO_time DATETIME,
							race_time DATETIME,
							Product_Sort INT,
							SportName_Sort NVARCHAR(150),
                            VendorMatchId VARCHAR(50)
							)
	DECLARE @Message  TABLE (LogVoidingID INT )
	DECLARE @tmpIgnoreCust TABLE (MessageID INT, ListMsgTargetId VARCHAR(MAX))
	
	UPDATE fb 
	SET status = 'ignore',UpdatedTime = GETDATE()
	OUTPUT DELETED.MessageID,DELETED.ListMsgTargetId INTO @tmpIgnoreCust(MessageID,ListMsgTargetId)
	FROM crmAutoFBVoiding fb  WITH(UPDLOCK,ROWLOCK)
		INNER JOIN crmCustomer c WITH(NOLOCK) ON fb.HeadlineID = c.custid
	WHERE status IN ('initial','fail') AND retryCount < 5  AND c.Ignored = 1
		
	UPDATE mi 
	SET mi.IsProcessed = 1,
		mi.IsProcessedUAT = 1
	FROM crmVoidingMessage mi  WITH(UPDLOCK,ROWLOCK)
	INNER JOIN @tmpIgnoreCust t ON mi.MessageID = t.MessageID 
	CROSS APPLY (
				SELECT value AS MsgTargetId FROM STRING_SPLIT(t.ListMsgTargetId, ',') WHERE value <> ''
			) c
	WHERE mi.MsgTargetId = c.MsgTargetId AND (IsProcessed = 0 OR IsProcessedUAT = 0)

	INSERT INTO @Message (LogVoidingID)
	SELECT TOP (@BatchSize) 
		LogVoidingID
	FROM crmAutoFBVoiding an WITH(NOLOCK)
	WHERE an.Status IN ('initial','fail')	AND an.retryCount < 5
	ORDER BY an.LogVoidingID ASC
	
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
        ,r.leaguegroupid = l.LeagueGroupID
		,r.KO_time = m.GlobalShowTime
		,r.eventdate = m.eventdate
		,r.MatchCode = m.MatchCode
	FROM #ResultDetail r
		INNER JOIN bodb02.dbo.match m WITH(NOLOCK) ON r.MatchId = m.matchid
        INNER JOIN bodb02.dbo.League l WITH(NOLOCK) ON m.leagueid = l.leagueid
	WHERE 	r.EventType = 1
	
	Update r
	SET r.sporttype = m.Sporttype
		,r.homeid = m.homeid
		,r.awayid = m.awayid
		,r.leagueid = m.leagueid
        ,r.leaguegroupid = l.LeagueGroupID
		,r.KO_time = m.GlobalShowTime
		,r.eventdate = m.eventdate
		,r.MatchCode = m.MatchCode
	FROM #ResultDetail r
		INNER JOIN bodb02.dbo.match14 m WITH(NOLOCK) ON r.MatchId = m.matchid
        INNER JOIN bodb02.dbo.League l WITH(NOLOCK) ON m.leagueid = l.leagueid
	WHERE 	r.EventType = 1 AND r.Sporttype IS NULL
	
	-- Get data from Match when EventType = 3
	Update r
	SET r.sporttype = vi.sporttype
		,r.leagueid = vi.leagueid
		,r.eventdate = vi.EventTime
		,r.race_time = vi.EventTime
        ,r.VendorMatchId = vi.VendorMatchId
        ,r.KO_time = vi.EventTime
	FROM #ResultDetail r
		INNER JOIN bodb02.dbo.VSRaceInfo vi WITH(NOLOCK) ON r.MatchId = vi.EventID
        INNER JOIN bodb02.dbo.League3rd l WITH(NOLOCK) ON vi.leagueid = l.League3rdId
	WHERE 	r.EventType = 3
	
	Update r
	SET r.sporttype = vi.sporttype
		,r.leagueid = vi.leagueid
		,r.eventdate = vi.EventTime
		,r.race_time = vi.EventTime
        ,r.VendorMatchId = vi.VendorMatchId
        ,r.KO_time = vi.EventTime
	FROM #ResultDetail r
		INNER JOIN bodb02.dbo.VSRaceInfo14 vi WITH(NOLOCK) ON r.MatchId = vi.EventID
        INNER JOIN bodb02.dbo.League3rd l WITH(NOLOCK) ON vi.leagueid = l.League3rdId
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
        ,r.leaguegroupid = t.LeagueGroupID
		,r.leaguenametc = t.leaguenametc
		,r.KO_time = m.kickofftime
	FROM #ResultDetail r
		INNER JOIN bodb02.dbo.Outright m WITH(NOLOCK) ON r.MatchId = m.orid
		INNER JOIN bodb02.dbo.League t WITH(NOLOCK) ON t.leagueid = m.leagueid
	WHERE 	r.EventType = 2 

	-- Get data from Match when EventType = 5
	Update r
	SET r.sporttype = m.Sporttype
		,r.homeid = m.homeid
		,r.awayid = m.awayid
		,r.leagueid = m.League3rdId
		,r.KO_time = m.StartTime
		,r.eventdate = m.eventdate
		,r.MatchCode = m.MatchCode
	FROM #ResultDetail r
		INNER JOIN bodb02.dbo.Match3rd m WITH(NOLOCK) ON r.MatchId = m.Match3rdId
	WHERE 	r.EventType = 5

	Update r
	SET r.sporttype = m.Sporttype
		,r.homeid = m.homeid
		,r.awayid = m.awayid
		,r.leagueid = m.League3rdId
		,r.KO_time = m.StartTime
		,r.eventdate = m.eventdate
		,r.MatchCode = m.MatchCode
	FROM #ResultDetail r
		INNER JOIN bodb02.dbo.Match3rd14 m WITH(NOLOCK) ON r.MatchId = m.Match3rdId
	WHERE 	r.EventType = 5 AND r.Sporttype IS NULL
	
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
			,s.SiteLabel
	FROM [dbo].[crmAutoFBVoiding] fb WITH(NOLOCK) 
	INNER JOIN @Message m ON FB.LogVoidingID =  m.LogVoidingID
	INNER JOIN bodb02.dbo.customer c WITH(NOLOCK) ON fb.HeadlineID = c.custid
	INNER JOIN bodb02.dbo.Site s WITH (NOLOCK) ON s.site=c.site
	LEFT JOIN crmCustomer hl WITH(NOLOCK) ON fb.HeadlineID = hl.custid
	
	SELECT 
		LogVoidingID,
		MatchId,
		MatchCode,
		EventType,
		Sporttype ,
		leagueid ,
        leaguegroupid,
		leaguenametc,
		homeid	,
		awayid	,
		KO_time ,
		eventdate ,
		race_time ,
		ProductID,
        VendorMatchId
	FROM #ResultDetail
	order by Product_Sort ASC , EventDate DESC, SportName_Sort ASC, KO_time DESC, leaguenametc ASC
	
			
END	