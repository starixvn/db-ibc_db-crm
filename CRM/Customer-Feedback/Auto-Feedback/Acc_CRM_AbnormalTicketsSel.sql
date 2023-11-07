/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_AbnormalTicketsSel]
	@MessageIDs VARCHAR(MAX),
	@TranIDs VARCHAR(MAX) = '' OUTPUT,
	@ConfigUAT BIT = 0,
	@ConfigPRO BIT = 0,
	@Environment	VARCHAR(10) = 'LIVE'
AS
/*
	Created: 20200416@Johnson
	Task : Get abnormal tickets for batch messages
	DB: DBACC/bodb02
	Original:

	Revisions:
		- 20200416@Johnson: Initial sp [redmine:#130949]
		- 20200811@Johnson: Add requestID to check missing auto void request [redmine:#139158]	
		- 20201126@Johnson: add param @Environment [redmine:#145274]
		- 20210705@Winfred: Integrate Abnormal Accounts [RedmineId : #157303]
		- 20211206@Winfred: Integrate Voiding Abnormal Mix Parlay tickets [RedmineId : #163833]
		- 20220803@Winfred: CRM - Scale out DBTRANS [RedmineId : #175877]	
		- 20230131@Winfred: Scale Out for CRM [RedmineId : #181906]
		- 20230731@Malcolm: Incorporate voiding duplicated bet tickets with TVS [RedmineId : #191355]

	Param's Explanation:
		- @MessageIDs: batch msg need to get abnormal tickets
		@MessageIds = '<ROOT>
						<r MsgID="123" ReqID="1" UsernameList="member1,member2,member3" CustIdList="" VoidingHistoryCollectionId="1"/>
						<r MsgID="123" ReqID="2" UsernameList="member1,member2,member3" CustIdList="" VoidingHistoryCollectionId="1"/>
						<r MsgID="345" ReqID="1" UsernameList="member1,member2,member3" CustIdList="" VoidingHistoryCollectionId="1"/>
						</ROOT>'
		- @ConfigUAT: get uus ticket or not
		- @ConfigPRO: get real tickets or not
		- @Environment = 'LIVE'/'UAT' config service for each enviroment 
*/
BEGIN
	SET NOCOUNT ON
	
	SET @TranIDs = ''
	
	DECLARE @tmpMessage TABLE (MessageId INT, RequestID INT, UsernameList NVARCHAR(MAX), CustIdList VARCHAR(MAX),VoidingHistoryCollectionId INT)	
	DECLARE @xml XML = CAST(@MessageIds AS XML)	
	
	INSERT INTO @tmpMessage (MessageId,RequestID, UsernameList, CustIdList,VoidingHistoryCollectionId)
	SELECT t.c.value('@MsgID[1]','int') MsgID,
		t.c.value('@ReqID[1]','int') ReqID,
		t.c.value('@UsernameList[1]', 'NVARCHAR(MAX)') AS UsernameList,
		t.c.value('@CustIdList[1]', 'VARCHAR(MAX)') AS CustIdList,
		t.c.value('@VoidingHistoryCollectionId[1]','int') AS VoidingHistoryCollectionId
	FROM @xml.nodes('/ROOT/r') t(c)	
	--event info
	DECLARE @tblEventInfo TABLE (VoidingHistoryCollectionId INT,
								MessageId NVARCHAR(MAX), 
								KickOffTime VARCHAR(8), 
								LeagueName NVARCHAR(500), 
								HomeName NVARCHAR(100), 
								AwayName NVARCHAR(100), 
								SportName VARCHAR(50), 
								EventDate DATE,
								IssueTypeId TINYINT,
								RequestIDList NVARCHAR(MAX),
								DecidedBy NVARCHAR(MAX),
								Requestby NVARCHAR(MAX),
								VoidBy NVARCHAR(MAX),
								MinWinlostdate	DATETIME,
								MaxWinlostdate	DATETIME,
								FilterBy	TINYINT
								)	
	--tickets info	
	DECLARE @tblTrans TABLE (VoidingHistoryCollectionId INT,
								MessageId INT, 
								RequestID INT,
								TransID BIGINT,
								custid INT, 
								username VARCHAR(50),
								srecommend INT, 
								recommend INT,
								bettype SMALLINT,
								RelatedUserName VARCHAR(50),
								RelatedCustID INT
								)
		
	-- Abnormal bet
	BEGIN	
		CREATE TABLE #VoidingHistory (VoidingHistoryId INT, RequestId INT, MessageId INT, ReasonId INT, VoidById INT, TransId BIGINT,IssueTypeId TINYINT,DecidedBy NVARCHAR(200),Requestby INT,VoidingHistoryCollectionId INT)

		INSERT INTO #VoidingHistory (VoidingHistoryId, RequestId, MessageId, ReasonId, VoidById, TransId,IssueTypeId,DecidedBy,Requestby,VoidingHistoryCollectionId)
		SELECT vh.VoidingHistoryId, vh.RequestId, vh.MessageId, vh.ReasonId, vh.UserId AS VoidById, t.TransId,rq.IssueTypeId, rq.DecidedBy ,rq.UserId AS Requestby , tm.VoidingHistoryCollectionId
		FROM VoidingHistoryCollectionDetail vhc WITH (NOLOCK) 
		INNER JOIN @tmpMessage tm ON vhc.VoidingHistoryCollectionId = tm.VoidingHistoryCollectionId
		INNER JOIN TicketVoiding_VoidingHistory vh WITH (NOLOCK) ON vhc.VoidingHistoryId = vh.VoidingHistoryId
		INNER JOIN dbo.TicketVoiding_Request rq WITH (NOLOCK) ON rq.RequestId = vh.RequestId AND rq.IssueTypeId IN (11, 15) -- Abnormal Bets, AB
			CROSS APPLY (
				SELECT value AS TransId FROM string_split(vh.TransIds, ',') WHERE value <> ''
			) t
		 WHERE vh.MessageId = tm.MessageId AND vh.RequestID = tm.RequestID AND vh.StatusId = 2 --tickets void successfully

		CREATE CLUSTERED INDEX IX_VoidingHistory_MID ON #VoidingHistory(MessageId,RequestId,TransId)

	--	Abnormal bet Single ticket 
		INSERT INTO @tblEventInfo (VoidingHistoryCollectionId, MessageId, KickOffTime, LeagueName, HomeName, AwayName,SportName,EventDate,IssueTypeId,FilterBy)
		SELECT DISTINCT vh.VoidingHistoryCollectionId, b.MessageId, 
			LTRIM(RTRIM(REPLACE(REPLACE(RIGHT(CONVERT(VARCHAR(20), DATEADD(HOUR, 12, m.GlobalShowTime), 100), 7), 'AM', ' AM'), 'PM', ' PM'))) AS KickOffTime, 
			l.LeagueName, 
			h.TeamName AS HomeName, 
			a.TeamName AS AwayName,
			s.sportName, 
			m.eventdate,
			vh.IssueTypeId,
			rd.FilterBy
		FROM #VoidingHistory vh
			INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK) ON rd.RequestId = vh.RequestId
			OUTER APPLY(
				SELECT STUFF(( SELECT DISTINCT ','+ cast(a.MessageId as VARCHAR(50))  as [text()]
					FROM #VoidingHistory a  
					WHERE vh.VoidingHistoryCollectionId = a.VoidingHistoryCollectionId
					FOR XML PATH('')
					),1,1,'')
			)b (MessageId)
			CROSS APPLY (
				SELECT m.hthomescore, m.htawayscore, m.finalhomescore, m.finalawayscore, m.GlobalShowTime, m.eventdate
				FROM dbo.match m WITH(NOLOCK)
				WHERE m.matchid = rd.matchid
				UNION
				SELECT m.hthomescore, m.htawayscore, m.finalhomescore, m.finalawayscore, m.GlobalShowTime, m.eventdate
				FROM dbo.match14 m WITH(NOLOCK)
				WHERE m.matchid = rd.matchid
			) m
			INNER JOIN dbo.League l WITH (NOLOCK) ON rd.LeagueId = l.LeagueID
			INNER JOIN Sports s WITH(NOLOCK) ON l.sporttype = s.SportType
			INNER JOIN dbo.Team h WITH (NOLOCK) ON rd.HomeId = h.TeamId
			INNER JOIN dbo.Team a WITH (NOLOCK) ON rd.AwayId = a.TeamId	
		WHERE rd.FilterBy IS NULL
		--	Abnormal bet Parlay ticket
		
		INSERT INTO @tblEventInfo (VoidingHistoryCollectionId, MessageId, IssueTypeId, RequestIDList, DecidedBy, Requestby, VoidBy,FilterBy)
		SELECT vh.VoidingHistoryCollectionId, b.MessageId, 
			vh.IssueTypeId,
			c.RequestIDList,
			d.DecidedBy,
			e.Requestby,
			f.VoidById,
			rd.FilterBy
		FROM #VoidingHistory vh
			INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK) ON rd.RequestId = vh.RequestId
			OUTER APPLY(
				SELECT STUFF(( SELECT DISTINCT ','+ cast(a.MessageId as VARCHAR(50))  as [text()]
					FROM #VoidingHistory a  
					WHERE vh.VoidingHistoryCollectionId = a.VoidingHistoryCollectionId
					FOR XML PATH('')
					),1,1,'')
			)b (MessageId)
			OUTER APPLY(
				SELECT STUFF(( SELECT DISTINCT ','+ cast(a.RequestId as VARCHAR(50))  as [text()]
					FROM #VoidingHistory a  
					WHERE vh.VoidingHistoryCollectionId = a.VoidingHistoryCollectionId
					FOR XML PATH('')
					),1,1,'')
			)c (RequestIDList)
			OUTER APPLY(
				SELECT STUFF(( SELECT DISTINCT ','+ cast(a.DecidedBy as VARCHAR(50))  as [text()]
					FROM #VoidingHistory a  
					WHERE vh.VoidingHistoryCollectionId = a.VoidingHistoryCollectionId
					FOR XML PATH('')
					),1,1,'')
			)d (DecidedBy)
			OUTER APPLY(
				SELECT STUFF(( SELECT DISTINCT ','+ cast(c.username as VARCHAR(50))  as [text()]
					FROM #VoidingHistory a  
						INNER JOIN customer c WITH(NOLOCK) ON a.Requestby = c.custid
					WHERE vh.VoidingHistoryCollectionId = a.VoidingHistoryCollectionId
					FOR XML PATH('')
					),1,1,'')
			)e (Requestby)
			OUTER APPLY(
				SELECT STUFF(( SELECT DISTINCT ','+ cast(c.username as VARCHAR(50))  as [text()]
					FROM #VoidingHistory a  
						INNER JOIN customer c WITH(NOLOCK) ON a.VoidById = c.custid
					WHERE vh.VoidingHistoryCollectionId = a.VoidingHistoryCollectionId
					FOR XML PATH('')
					),1,1,'')
			)f (VoidById)
		WHERE rd.FilterBy = 1		
		GROUP BY vh.VoidingHistoryCollectionId, b.MessageId, vh.IssueTypeId,	c.RequestIDList,d.DecidedBy,e.Requestby,f.VoidById,rd.FilterBy
				
	END
	
	-- Abnormal Acount
	BEGIN	
		CREATE TABLE #AbnormalAccounts(VoidingHistoryCollectionId INT, RequestId INT, MessageId INT, VoidById INT, CustId BIGINT,IssueTypeId TINYINT,DecidedBy NVARCHAR(200),Requestby INT , MinWinlostdate	DATETIME,MaxWinlostdate	DATETIME)
		CREATE TABLE #RelatedAccounts(VoidingHistoryCollectionId INT, RequestId INT, MessageId INT, RelatedCustID INT, RelatedUserName VARCHAR(50))
				
		INSERT INTO #AbnormalAccounts ( RequestId, MessageId, VoidById, CustId,IssueTypeId,DecidedBy,Requestby,MinWinlostdate,MaxWinlostdate,VoidingHistoryCollectionId)
		SELECT vh.RequestId, vh.MessageId, vh.UserId AS VoidById, c.CustId , rq.IssueTypeId , rq.DecidedBy ,rq.UserId AS Requestby , vh.MinWinlostdate,vh.MaxWinlostdate,tm.VoidingHistoryCollectionId
		FROM VoidingHistoryCollectionDetail vhc WITH (NOLOCK) 
			INNER JOIN @tmpMessage tm ON vhc.VoidingHistoryCollectionId = tm.VoidingHistoryCollectionId
			INNER JOIN dbo.TicketVoiding_VoidingHistory vh WITH (NOLOCK) ON vhc.VoidingHistoryId = vh.VoidingHistoryId
			INNER JOIN dbo.TicketVoiding_Request rq WITH (NOLOCK) ON rq.RequestId = vh.RequestId AND rq.IssueTypeId = 13 -- Abnormal Account
			CROSS APPLY (SELECT value AS CustId FROM string_split(tm.CustIdList, ',') WHERE value <> '') c
		WHERE vh.StatusId = 2 --tickets void successfully

		INSERT INTO #RelatedAccounts ( RequestId, MessageId, RelatedUserName)
		SELECT vh.RequestId, vh.MessageId, c.Username
		FROM @tmpMessage vh 
			CROSS APPLY (SELECT value AS Username FROM string_split(vh.UsernameList, ',') WHERE value <> '') c
		
		UPDATE m
		SET m.RelatedCustID = l.custid
		FROM #RelatedAccounts m
		CROSS APPLY
		(
			SELECT TOP 1 c.custid
			FROM Customer c WITH(NOLOCK)
			WHERE c.username = m.RelatedUserName
		) l
		
		INSERT INTO @tblTrans (VoidingHistoryCollectionId, MessageId, RequestID, custid, username,srecommend,recommend,RelatedCustID,RelatedUserName)
		SELECT vh.VoidingHistoryCollectionId, vh.MessageId, 
			vh.RequestID,
			vh.custid, 
			username, 
			srecommend,
			recommend,
			RelatedCustID,
			RelatedUserName
		FROM #AbnormalAccounts vh
			CROSS APPLY (
				SELECT TOP 1 c.Username, c.Srecommend, c.Mrecommend, c.Recommend , c.currency
				FROM dbo.Customer c WITH(NOLOCK)
				WHERE c.custid = vh.CustId
			) b
			INNER JOIN #RelatedAccounts r ON vh.MessageId = r.MessageId  AND vh.RequestId = r.RequestId AND r.RelatedCustID IN (vh.custid, b.recommend, b.mrecommend, b.srecommend)
		WHERE 1= CASE WHEN b.currency = 20 AND (@ConfigUAT = 1 OR @Environment = 'UAT') THEN 1
				WHEN b.currency <> 20 AND @ConfigPRO = 1 AND @Environment <> 'UAT' THEN 1
				ELSE 0 END	
										
		--exclude cn88 tickets
		DELETE t
		FROM @tblTrans t
			INNER JOIN customer c WITH(NOLOCK) ON t.custid = c.custid
		WHERE c.site = 'CN88'
	
		INSERT INTO @tblEventInfo (VoidingHistoryCollectionId, MessageId, IssueTypeId, RequestIDList, DecidedBy, Requestby, VoidBy,MinWinlostdate,MaxWinlostdate)
		SELECT vh.VoidingHistoryCollectionId, b.MessageId, 
			vh.IssueTypeId,
			c.RequestIDList,
			d.DecidedBy,
			e.Requestby,
			f.VoidById,
			MIN(MinWinlostdate) AS MinWinlostdate,
			MAX(MaxWinlostdate) AS MaxWinlostdate
		FROM #AbnormalAccounts vh
			OUTER APPLY(
				SELECT STUFF(( SELECT DISTINCT ','+ cast(a.MessageId as VARCHAR(50))  as [text()]
					FROM #AbnormalAccounts a  
					WHERE vh.VoidingHistoryCollectionId = a.VoidingHistoryCollectionId
					FOR XML PATH('')
					),1,1,'')
			)b (MessageId)
			OUTER APPLY(
				SELECT STUFF(( SELECT DISTINCT ','+ cast(a.RequestId as VARCHAR(50))  as [text()]
					FROM #AbnormalAccounts a  
					WHERE vh.VoidingHistoryCollectionId = a.VoidingHistoryCollectionId
					FOR XML PATH('')
					),1,1,'')
			)c (RequestIDList)
			OUTER APPLY(
				SELECT STUFF(( SELECT DISTINCT ','+ cast(a.DecidedBy as VARCHAR(50))  as [text()]
					FROM #AbnormalAccounts a  
					WHERE vh.VoidingHistoryCollectionId = a.VoidingHistoryCollectionId
					FOR XML PATH('')
					),1,1,'')
			)d (DecidedBy)
			OUTER APPLY(
				SELECT STUFF(( SELECT DISTINCT ','+ cast(c.username as VARCHAR(50))  as [text()]
					FROM #AbnormalAccounts a  
						INNER JOIN customer c WITH(NOLOCK) ON a.Requestby = c.custid
					WHERE vh.VoidingHistoryCollectionId = a.VoidingHistoryCollectionId
					FOR XML PATH('')
					),1,1,'')
			)e (Requestby)
			OUTER APPLY(
				SELECT STUFF(( SELECT DISTINCT ','+ cast(c.username as VARCHAR(50))  as [text()]
					FROM #AbnormalAccounts a  
						INNER JOIN customer c WITH(NOLOCK) ON a.VoidById = c.custid
					WHERE vh.VoidingHistoryCollectionId = a.VoidingHistoryCollectionId
					FOR XML PATH('')
					),1,1,'')
			)f (VoidById)	
		GROUP BY vh.VoidingHistoryCollectionId, b.MessageId, vh.IssueTypeId, c.RequestIDList, d.DecidedBy, e.Requestby, f.VoidById
				
	END
	
	--Duplicated tickets
	BEGIN	

		;WITH CTE_Duplicated AS
		(
			SELECT m.MessageId, m.RequestID, m.VoidingHistoryCollectionId, vh.UserId AS VoidById, r.IssueTypeId, r.DecidedBy, r.UserId AS Requestby
			FROM @tmpMessage m
				INNER JOIN dbo.VoidingHistoryCollectionDetail vcd WITH(NOLOCK) ON vcd.VoidingHistoryCollectionId = m.VoidingHistoryCollectionId
				INNER JOIN dbo.TicketVoiding_VoidingHistory vh WITH(NOLOCK) ON vh.VoidingHistoryId = vcd.VoidingHistoryId
				INNER JOIN dbo.TicketVoiding_Request r WITH(NOLOCK) ON r.RequestId = vh.RequestId
		WHERE r.IssueTypeId = 20
		),CTE_EventInfo AS
		(
			SELECT d.VoidingHistoryCollectionId, d.IssueTypeId FROM CTE_Duplicated d GROUP BY d.VoidingHistoryCollectionId, d.IssueTypeId
		)
		INSERT INTO @tblEventInfo (VoidingHistoryCollectionId, MessageId, IssueTypeId, RequestIDList, DecidedBy, Requestby, VoidBy)
		SELECT vh.VoidingHistoryCollectionId, b.MessageId, 
			vh.IssueTypeId,
			c.RequestIDList,
			d.DecidedBy,
			e.Requestby,
			f.VoidById
		FROM CTE_EventInfo vh
			OUTER APPLY(
				SELECT STUFF(( SELECT DISTINCT ','+ cast(a.MessageId as VARCHAR(50))  as [text()]
					FROM CTE_Duplicated a  
					WHERE vh.VoidingHistoryCollectionId = a.VoidingHistoryCollectionId
					FOR XML PATH('')
					),1,1,'')
			)b (MessageId)
			OUTER APPLY(
				SELECT STUFF(( SELECT DISTINCT ','+ cast(a.RequestId as VARCHAR(50))  as [text()]
					FROM CTE_Duplicated a  
					WHERE vh.VoidingHistoryCollectionId = a.VoidingHistoryCollectionId
					FOR XML PATH('')
					),1,1,'')
			)c (RequestIDList)
			OUTER APPLY(
				SELECT STUFF(( SELECT DISTINCT ','+ cast(a.DecidedBy as VARCHAR(50))  as [text()]
					FROM CTE_Duplicated a  
					WHERE vh.VoidingHistoryCollectionId = a.VoidingHistoryCollectionId
					FOR XML PATH('')
					),1,1,'')
			)d (DecidedBy)
			OUTER APPLY(
				SELECT STUFF(( SELECT DISTINCT ','+ cast(c.username as VARCHAR(50))  as [text()]
					FROM CTE_Duplicated a  
						INNER JOIN customer c WITH(NOLOCK) ON a.Requestby = c.custid
					WHERE vh.VoidingHistoryCollectionId = a.VoidingHistoryCollectionId
					FOR XML PATH('')
					),1,1,'')
			)e (Requestby)
			OUTER APPLY(
				SELECT STUFF(( SELECT DISTINCT ','+ cast(c.username as VARCHAR(50))  as [text()]
					FROM CTE_Duplicated a  
						INNER JOIN customer c WITH(NOLOCK) ON a.VoidById = c.custid
					WHERE vh.VoidingHistoryCollectionId = a.VoidingHistoryCollectionId
					FOR XML PATH('')
					),1,1,'')
			)f (VoidById)	

		CREATE TABLE #DuplicatedTickets (VoidingHistoryCollectionId INT, MessageId INT, RequestID INT, VoidedTransId BIGINT, OrgTransIds VARCHAR(MAX)
		, Username VARCHAR(30), CustId INT, Site NVARCHAR(10), IsDeposit BIT, IsTest BIT, bettype SMALLINT, SporttypeId TINYINT, MatchId INT, EventType TINYINT, SiteDBGroupID SMALLINT)

		;WITH CTE_DuplicatedTickets AS
		(
			SELECT m.VoidingHistoryCollectionId, m.MessageId, m.RequestID, CONVERT(XML, rd.TransIds) AS TransIds
			FROM @tmpMessage m	
				INNER JOIN dbo.TicketVoiding_Request r WITH(NOLOCK) ON r.RequestId = m.RequestID
				CROSS APPLY (
					SELECT TOP(1) rd.TransIds
					FROM dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
					WHERE rd.RequestId = r.RequestId
				) AS rd
			WHERE r.IssueTypeId = 20
		),CTE_VoidedTickets AS 
		(
			SELECT
				d.VoidingHistoryCollectionId
				,d.MessageId
				,d.RequestID
				,t.OrgTransIds 
				,t.VoidedTransIds
			FROM CTE_DuplicatedTickets d
			CROSS APPLY (
				SELECT 
					t.c.value('@OrgTransIds', 'VARCHAR(MAX)') AS OrgTransIds
					,t.c.value('@VoidedTransIds', 'VARCHAR(MAX)') AS VoidedTransIds
				FROM d.TransIds.nodes('root/r') t(c) 
			) AS t
		)
		INSERT INTO #DuplicatedTickets (VoidingHistoryCollectionId, MessageId, RequestID, OrgTransIds, VoidedTransId)
		SELECT c.VoidingHistoryCollectionId, c.MessageId, c.RequestID, c.OrgTransIds, t.VoidedTransId
		FROM CTE_VoidedTickets c
			CROSS APPLY (SELECT t.value AS VoidedTransId FROM STRING_SPLIT(c.VoidedTransIds, ',') t) AS t

		UPDATE d
			SET d.Username = b.Username, d.CustId = b.custid, d.bettype = b.bettype, d.MatchId = b.matchid, d.SiteDBGroupID = b.SiteDBGroupID
		FROM #DuplicatedTickets d
			INNER JOIN bodb02.dbo.bettrans b WITH(NOLOCK) ON b.TransId = d.VoidedTransId

		UPDATE d
			SET d.Username = b.Username, d.CustId = b.custid, d.bettype = b.bettype, d.MatchId = b.matchid, d.SiteDBGroupID = b.SiteDBGroupID
		FROM #DuplicatedTickets d
			INNER JOIN bodb02.dbo.bettrans14 b WITH(NOLOCK) ON b.TransId = d.VoidedTransId

		UPDATE d
			SET d.IsDeposit = CASE WHEN s.custid IS NULL THEN 0 ELSE 1 END
				,d.Site = ISNULL(s.site, '')
				,d.IsTest = CASE WHEN c.currency = 20 THEN 1 ELSE 0 END
		FROM #DuplicatedTickets d
		CROSS APPLY (
			SELECT TOP(1) c.currency, c.srecommend
			FROM bodb02.dbo.Customer c WITH(NOLOCK)
			WHERE c.custid = d.custId
		) AS c
		LEFT JOIN dbo.Dep_CustSuper s WITH(NOLOCK) ON s.custid = c.srecommend

		;WITH CTE AS
		(
			SELECT DISTINCT d.VoidingHistoryCollectionId, d.MessageId, d.RequestID, vh.SiteDBGroupID
			FROM #DuplicatedTickets d 
				INNER JOIN bodb02.dbo.TicketVoiding_VoidingHistory vh WITH(NOLOCK) 
					ON vh.MessageId = d.MessageId AND vh.RequestId = d.RequestID

		)
		DELETE d	
		FROM #DuplicatedTickets d
			INNER JOIN CTE e 
				ON e.VoidingHistoryCollectionId = d.VoidingHistoryCollectionId 
				AND e.MessageId = d.MessageId 
				AND e.RequestID = d.RequestID
				AND d.SiteDBGroupID <> e.SiteDBGroupID

		DELETE d
		FROM #DuplicatedTickets d
		WHERE 1= CASE WHEN IsTest = 1 AND (@ConfigUAT = 1 OR @Environment = 'UAT') THEN 0
				      WHEN IsTest = 0 AND @ConfigPRO = 1 AND @Environment <> 'UAT' THEN 0
				 ELSE 1 END		

		UPDATE d
			SET d.EventType = l.EventType
		FROM #DuplicatedTickets d
		CROSS APPLY (
			SELECT TOP(1) EventType
			FROM SportBettypeMatrix m WITH(NOLOCK)
			WHERE m.BetType = d.bettype
		) AS l
		
		UPDATE d
			SET d.SporttypeId = d.matchId
		FROM #DuplicatedTickets d
		WHERE d.EventType = 0 AND d.bettype NOT IN (9, 29, 2799)

		UPDATE d
			SET d.SporttypeId = m.sporttype
		FROM #DuplicatedTickets d
			INNER JOIN bodb02.dbo.match m WITH(NOLOCK) ON d.MatchId = m.matchid
		WHERE d.EventType = 1

		UPDATE d
			SET d.SporttypeId = t.sporttype
		FROM #DuplicatedTickets d
			INNER JOIN bodb02.dbo.Outright m WITH(NOLOCK) ON d.MatchId = m.orid
		INNER JOIN bodb02.dbo.League t WITH(NOLOCK) ON t.leagueid = m.leagueid
		WHERE d.EventType = 3

		UPDATE d
			SET d.SporttypeId = m.sporttype
		FROM #DuplicatedTickets d
			INNER JOIN bodb02.dbo.VSRaceInfo m WITH(NOLOCK) ON d.MatchId = m.EventID
		WHERE d.EventType = 2

		-- <root><r OrgTransIds="12321" VoidedTransIds="152574602906697728"/></root>
	END
	--return data
	--event info
	SELECT 	*
	FROM @tblEventInfo
	
	--tickets info
	SELECT VoidingHistoryCollectionId, MessageId, 
		RequestID,
		transid,
		t.custid, 
		t.username, 
		b.typenamee as bettype,
		CASE WHEN s.custid IS NULL THEN 0 ELSE 1 END as isDeposit,
		ISNULL(s.site,'') as site,
		t.RelatedCustID,
		t.RelatedUserName		
	FROM @tblTrans t
		LEFT JOIN bettype b WITH(NOLOCK) ON t.bettype = b.typeid
		LEFT JOIN Dep_CustSuper s WITH(NOLOCK) ON t.srecommend = s.custid
	ORDER BY MessageId,RequestID,isDeposit,custid

	SET @TranIDs = (  SELECT DISTINCT
					  	VoidingHistoryCollectionId AS '@VoidingHistoryCollectionId', 
					  	MessageId AS '@MsgID', 
					  	RequestID AS '@ReqID',
					  	transids AS '@TransID'
					  FROM #VoidingHistory vh 
					  OUTER APPLY(
							SELECT STUFF(( SELECT DISTINCT ','+ cast(a.transid as VARCHAR(20))  as [text()]
								FROM #VoidingHistory a  
								WHERE vh.MessageId = a.MessageId AND vh.RequestID = a.RequestId AND vh.VoidingHistoryCollectionId = a.VoidingHistoryCollectionId
								FOR XML PATH('')
								),1,1,'')
						)c (transids)
					  ORDER BY MessageId, RequestID, VoidingHistoryCollectionId
					  FOR XML PATH ('r'), ROOT ('ROOT'))

	SELECT d.VoidingHistoryCollectionId, d.MessageId, d.RequestID, d.OrgTransIds, d.VoidedTransId, d.Username, d.CustId, d.Site, d.IsDeposit, d.IsTest, b.typenamee AS bettype, d.bettype AS BettypeId, p.ProductId, d.SporttypeId
	FROM #DuplicatedTickets d
		LEFT JOIN bodb02.dbo.bettype b WITH(NOLOCK) ON b.typeid = d.bettype
		OUTER APPLY (
			SELECT TOP(1) S.ProductID
			FROM bodb02.dbo.SportBettypeMatrix s WITH(NOLOCK)
			WHERE d.bettype = s.BetType
		) AS p

	DROP TABLE #VoidingHistory
	DROP TABLE #AbnormalAccounts
	DROP TABLE #DuplicatedTickets
	DROP TABLE #RelatedAccounts
END	

