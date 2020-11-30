/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_TOControl_AutoFeedbackInfoIns] 
	@xml XML	
AS
/*
	Created: 20201127@Johnson
	Task : import list customers reach turnover level into CRM
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20201125@Johnson: Initial sp [redmine:#142194]
	
	Parameter's Explanation:
		- @xml = <ROOT>
					<r custid="1000" matchid="1" hl="101" hlname="XT" related="1000" profileID="1" profileName="HDP&ML" maxTO="1000" houseTO="300" totalTO="800" outstanding="2000" time="2020-11-27 04:06:07" bettype="1" level="80"/>
					<r custid="1001" matchid="2" hl="101" hlname="XT" related="1001" profileID="1" profileName="HDP&ML" maxTO="1000" houseTO="300" totalTO="800" outstanding="3000" time="2020-11-27 04:06:07" bettype="1" level="80"/>
				</ROOT>
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @tmpCust TABLE (
						CustID			INT,
						MatchID			INT,
						ProfileID		INT,
						HeadlineID		INT,
						HeadlineName	VARCHAR(50),
						RelatedCustID	INT,
						ProfileName		NVARCHAR(100),
						MaxTurnover		MONEY,
						HouseTurnover	MONEY,
						TotalTurnover 	MONEY,
						Outstanding		MONEY,
						NotifiedDate	DATETIME,
						Bettype			INT,
						Level			INT,
						EventInfo		VARCHAR(500)
						)
		
	INSERT INTO @tmpCust(CustID,MatchID,ProfileID,HeadlineID,HeadlineName,RelatedCustID,ProfileName,MaxTurnover,
						HouseTurnover,TotalTurnover,Outstanding,NotifiedDate,Bettype,Level)
	SELECT 
		t.c.value('@custid[1]','int') custid,	
		t.c.value('@matchid[1]','int') matchid,	
		t.c.value('@profileID[1]','int') profileID,
		t.c.value('@hl[1]','int') HeadlineID,
		t.c.value('@hlname[1]','varchar(50)') hlname,
		t.c.value('@related[1]','int') RelatedCustID,
		t.c.value('@profile[1]','nvarchar(100)') ProfileName,			
		t.c.value('@maxTO[1]','money') MaxTurnover,
		t.c.value('@houseTO[1]','money') HouseTurnover,
		t.c.value('@totalTO[1]','money') TotalTurnover,
		t.c.value('@outstanding[1]','money') Outstanding,
		t.c.value('@time[1]','datetime') NotifiedDate,				
		t.c.value('@bettype[1]','int') Bettype,
		t.c.value('@level[1]','int') level
	FROM @xml.nodes('/ROOT/r') t(c)	
	
	UPDATE t
	SET t.EventInfo = h.teamname + ' -vs- ' + a.teamname
	FROM @tmpCust t
		INNER JOIN bodb02.dbo.match m WITH(NOLOCK) ON t.matchid = m.matchid
		INNER JOIN bodb02.dbo.team h WITH(NOLOCK) ON m.homeid = h.teamid
		INNER JOIN bodb02.dbo.team a WITH(NOLOCK) ON m.awayid = a.teamid
	
	MERGE crmTOControlFeedbackInfo as Target
	USING @tmpCust as Source ON Target.custid = Source.custid
								AND Target.matchid =Source.matchid
								AND Target.profileID = Source.profileID
	WHEN NOT MATCHED BY Target THEN 							
	INSERT (CustID,MatchID,ProfileID,HeadlineID,HeadlineName,RelatedCustID,ProfileName,MaxTurnover,
						HouseTurnover,TotalTurnover,Outstanding,NotifiedDate,Bettype,EventInfo,Level,Status)
		VALUES(CustID,MatchID,ProfileID,HeadlineID,HeadlineName,RelatedCustID,ProfileName,MaxTurnover,
						HouseTurnover,TotalTurnover,Outstanding,NotifiedDate,Bettype,EventInfo,Level,'Initial')	
	WHEN MATCHED THEN 
	UPDATE SET Target.Level 		= Source.Level,
			Target.TotalTurnover 	= Source.TotalTurnover,
			Target.MaxTurnover 		= Source.MaxTurnover,
			Target.HouseTurnover 	= Source.HouseTurnover,
			Target.Outstanding 		= Source.Outstanding,
			Target.NotifiedDate 	= Source.NotifiedDate,
			Target.Status 			= 'Initial',
			Target.UpdatedTime 		= GETDATE(),
			Target.RetryCount 		= 0;
	
	SELECT CustID,
		MatchID,
		ProfileID,
		HeadlineID,
		HeadlineName,
		RelatedCustID,
		ProfileName,
		Bettype,
		Level,
		TotalTurnover,
		MaxTurnover,
		HouseTurnover,
		Outstanding
	INTO #Result	
	FROM crmTOControlFeedbackInfo WITH(NOLOCK)
	WHERE Status IN ('initial','fail')
		AND retryCount <5
		
	SELECT rs.*,
		HouseTurnover/MaxTurnover as Usage,
		c.username,
		c.roleid,
		e.currency,
		m.homeid,
		m.awayid,
		m.leagueid,
		m.sporttype
	FROM #Result rs
		INNER JOIN bodb02.dbo.match m WITH(NOLOCK) ON rs.matchid = m.matchid
		INNER JOIN bodb02.dbo.customer c WITH(NOLOCK) ON rs.custid = c.custid
		INNER JOIN bodb02.dbo.Exchange e WITH(NOLOCK) ON c.currency = e.ExchangeId
		
	DROP TABLE #Result	
		
END	

