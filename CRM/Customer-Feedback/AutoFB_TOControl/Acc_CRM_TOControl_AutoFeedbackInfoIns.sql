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
		- @xml = '<ROOT>
					<r custid="14521681" matchid="31757960" profileID="16" hl="14521687" hlname="SuperTest91" related="14521687" profileName="Non Live - HDP &amp; ML" maxTO="1000" houseTO="302" totalTO="1010" outstanding="2000" time="2020-12-02 3:16:32" bettype="1" level="100"/>
					<r custid="14521681" matchid="31757960" profileID="16" hl="14521687" hlname="SuperTest91" related="14521687" profileName="Non Live - HDP &amp; ML" maxTO="1000" houseTO="302" totalTO="1010" outstanding="2000" time="2020-12-02 3:16:32" bettype="20" level="100"/>
				</ROOT>'
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
						BettypeList		VARCHAR(100),
						Level			INT,
						EventInfo		VARCHAR(500)
						)
		
	INSERT INTO @tmpCust(CustID,MatchID,ProfileID,HeadlineID,HeadlineName,RelatedCustID,ProfileName,MaxTurnover,
						HouseTurnover,TotalTurnover,Outstanding,NotifiedDate,BettypeList,Level)
	SELECT 
		t.c.value('@custid[1]','int') custid,	
		t.c.value('@matchid[1]','int') matchid,	
		t.c.value('@profileID[1]','int') profileID,
		t.c.value('@hl[1]','int') HeadlineID,
		t.c.value('@hlname[1]','varchar(50)') hlname,
		t.c.value('@related[1]','int') RelatedCustID,
		t.c.value('@profileName[1]','nvarchar(100)') ProfileName,			
		t.c.value('@maxTO[1]','money') MaxTurnover,
		t.c.value('@houseTO[1]','money') HouseTurnover,
		t.c.value('@totalTO[1]','money') TotalTurnover,
		t.c.value('@outstanding[1]','money') Outstanding,
		t.c.value('@time[1]','datetime') NotifiedDate,				
		t.c.value('@bettype[1]','varchar(100)') BettypeList,
		t.c.value('@level[1]','int') level
	FROM @xml.nodes('/ROOT/r') t(c)	
	
	UPDATE t
	SET t.EventInfo = h.teamname + ' -vs- ' + a.teamname
	FROM @tmpCust t
		INNER JOIN bodb02.dbo.match m WITH(NOLOCK) ON t.matchid = m.matchid
		INNER JOIN bodb02.dbo.team h WITH(NOLOCK) ON m.homeid = h.teamid
		INNER JOIN bodb02.dbo.team a WITH(NOLOCK) ON m.awayid = a.teamid
	
	INSERT INTO [dbo].[crmTOControlFeedbackInfo]
           ([CustID]
           ,[MatchID]
           ,[ProfileID]
           ,[HeadlineID]
           ,[HeadlineName]
           ,[RelatedCustID]
           ,[ProfileName]
           ,[BettypeList]
           ,[EventInfo]
           ,[Level]
           ,[TotalTurnover]
           ,[MaxTurnover]
           ,[HouseTurnover]
           ,[Outstanding]
           ,[NotifiedDate]
           ,[Status]
           ,[CreatedDate]          
           ,[RetryCount])
	SELECT CustID,
		MatchID,
		ProfileID,
		HeadlineID,
		HeadlineName,
		RelatedCustID,
		ProfileName,
		BettypeList,
		EventInfo,
		Level,
		TotalTurnover,
		MaxTurnover,
		HouseTurnover,
		Outstanding,
		NotifiedDate,
		'initial' as status,
		GETDATE() as CreatedDate,
		0 as RetryCount
	FROM @tmpCust t
	WHERE NOT EXISTS (SELECT 1 FROM crmTOControlFeedbackInfo fb WITH(NOLOCK) 
					WHERE fb.custid = t.custid
						AND fb.matchid = t.matchid
						AND fb.profileID = t.profileID
						AND fb.Level = t.Level
					)
	
	SELECT LogID,
		CustID,
		MatchID,
		ProfileID,
		HeadlineID,
		HeadlineName,
		RelatedCustID,
		ProfileName,
		BettypeList,
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
		HouseTurnover/MaxTurnover*100 as Usage,
		c.username,
		c.roleid,
		c.site,
		ISNULL(hl.IsVip,0) as IsVip,
		e.currency,
		m.homeid,
		m.awayid,
		m.leagueid,
		m.sporttype
	FROM #Result rs
		INNER JOIN bodb02.dbo.match m WITH(NOLOCK) ON rs.matchid = m.matchid
		INNER JOIN bodb02.dbo.customer c WITH(NOLOCK) ON rs.custid = c.custid
		INNER JOIN bodb02.dbo.Exchange e WITH(NOLOCK) ON c.currency = e.ExchangeId
		LEFT JOIN crmCustomer hl WITH(NOLOCK) ON rs.HeadlineID = hl.custid
		
	DROP TABLE #Result	
		
END	

