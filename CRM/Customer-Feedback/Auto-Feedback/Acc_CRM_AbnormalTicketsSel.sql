/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_AbnormalTicketsSel]
	@MessageIDs VARCHAR(MAX),
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
		
	Param's Explanation:
		- @MessageIDs: batch msg need to get abnormal tickets
		@MessageIds = '<ROOT>
						<r MsgID="123" ReqID="1" UsernameList="member1,member2,member3" CustIdList=""/>
						<r MsgID="123" ReqID="2" UsernameList="member1,member2,member3" CustIdList=""/>
						<r MsgID="345" ReqID="1" UsernameList="member1,member2,member3" CustIdList=""/>
						</ROOT>'
		- @ConfigUAT: get uus ticket or not
		- @ConfigPRO: get real tickets or not
		- @Environment = 'LIVE'/'UAT' config service for each enviroment 
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @tmpMessage TABLE (MessageId INT, RequestID INT, UsernameList NVARCHAR(MAX), CustIdList VARCHAR(MAX))	
	DECLARE @xml XML = CAST(@MessageIds AS XML)	
	
	INSERT INTO @tmpMessage (MessageId,RequestID, UsernameList, CustIdList)
	SELECT t.c.value('@MsgID[1]','int') MsgID,
		t.c.value('@ReqID[1]','int') ReqID,
		t.c.value('@UsernameList[1]', 'NVARCHAR(MAX)') AS UsernameList,
		t.c.value('@CustIdList[1]', 'VARCHAR(MAX)') AS CustIdList
	FROM @xml.nodes('/ROOT/r') t(c)	

	--event info
	DECLARE @tblEventInfo TABLE (MessageId INT, 
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
		
	-- Abnormal bet
	BEGIN	
		CREATE TABLE #VoidingHistory (VoidingHistoryId INT, RequestId INT, MessageId INT, ReasonId INT, VoidById INT, TransId BIGINT,IssueTypeId TINYINT,DecidedBy NVARCHAR(200),Requestby INT)
			
		INSERT INTO #VoidingHistory (VoidingHistoryId, RequestId, MessageId, ReasonId, VoidById, TransId,IssueTypeId,DecidedBy,Requestby)
		SELECT vh.VoidingHistoryId, vh.RequestId, vh.MessageId, vh.ReasonId, vh.UserId AS VoidById, t.TransId,rq.IssueTypeId, rq.DecidedBy ,rq.UserId AS Requestby
		FROM dbo.TicketVoiding_VoidingHistory vh WITH (NOLOCK)
			INNER JOIN dbo.TicketVoiding_Request rq WITH (NOLOCK) ON rq.RequestId = vh.RequestId AND rq.IssueTypeId IN (11, 15) -- Abnormal Bets, AB
			CROSS APPLY (
				SELECT val AS TransId FROM dbo.strSplit(vh.TransIds, ',')
			) t
		WHERE EXISTS (SELECT 1 FROM @tmpMessage m WHERE vh.MessageId = m.MessageId AND vh.RequestID = m.RequestID)
			AND vh.StatusId = 2 --tickets void successfully
	--	Abnormal bet Single ticket 
		INSERT INTO @tblEventInfo (MessageId, KickOffTime, LeagueName, HomeName, AwayName,SportName,EventDate,IssueTypeId,FilterBy)
		SELECT DISTINCT vh.MessageId, 
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
		
		INSERT INTO @tblEventInfo (MessageId, IssueTypeId, RequestIDList, DecidedBy, Requestby, VoidBy,FilterBy)
		SELECT vh.MessageId, 
			vh.IssueTypeId,
			c.RequestIDList,
			d.DecidedBy,
			e.Requestby,
			f.VoidById,
			rd.FilterBy
		FROM #VoidingHistory vh
			INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK) ON rd.RequestId = vh.RequestId
			OUTER APPLY(
				SELECT STUFF(( SELECT DISTINCT ','+ cast(a.RequestId as VARCHAR(10))  as [text()]
					FROM #VoidingHistory a  
					WHERE vh.MessageId = a.MessageId
					FOR XML PATH('')
					),1,1,'')
			)c (RequestIDList)
			OUTER APPLY(
				SELECT STUFF(( SELECT DISTINCT ','+ cast(a.DecidedBy as VARCHAR(10))  as [text()]
					FROM #VoidingHistory a  
					WHERE vh.MessageId = a.MessageId
					FOR XML PATH('')
					),1,1,'')
			)d (DecidedBy)
			OUTER APPLY(
				SELECT STUFF(( SELECT DISTINCT ','+ cast(c.username as VARCHAR(10))  as [text()]
					FROM #VoidingHistory a  
						INNER JOIN customer c WITH(NOLOCK) ON a.Requestby = c.custid
					WHERE vh.MessageId = a.MessageId
					FOR XML PATH('')
					),1,1,'')
			)e (Requestby)
			OUTER APPLY(
				SELECT STUFF(( SELECT DISTINCT ','+ cast(c.username as VARCHAR(10))  as [text()]
					FROM #VoidingHistory a  
						INNER JOIN customer c WITH(NOLOCK) ON a.VoidById = c.custid
					WHERE vh.MessageId = a.MessageId
					FOR XML PATH('')
					),1,1,'')
			)f (VoidById)
		WHERE rd.FilterBy = 1		
		GROUP BY vh.MessageId,	vh.IssueTypeId,	c.RequestIDList,d.DecidedBy,e.Requestby,f.VoidById,rd.FilterBy
					
		--tickets info	
		DECLARE @tblTrans TABLE (MessageId INT, 
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
		
		INSERT INTO @tblTrans (MessageId, RequestID, transid, custid, username,srecommend,recommend, bettype)
		SELECT vh.MessageId, 
			vh.RequestID,
			vh.transid,
			custid, 
			username, 
			srecommend,
			b.recommend, 
			b.bettype		
		FROM #VoidingHistory vh
			CROSS APPLY (
				SELECT TOP 1 transid, custid, username,srecommend, recommend, b.bettype, b.currency
				FROM dbo.bettrans b WITH (NOLOCK)
				WHERE b.transid = vh.TransId
			) b		
		WHERE 1= CASE WHEN b.currency = 20 AND (@ConfigUAT = 1 OR @Environment = 'UAT') THEN 1
				WHEN b.currency <> 20 AND @ConfigPRO = 1 AND @Environment <> 'UAT' THEN 1
				ELSE 0 END				
		
		--exclude cn88 tickets
		DELETE t
		FROM @tblTrans t
			INNER JOIN customer c WITH(NOLOCK) ON t.custid = c.custid
		WHERE c.site = 'CN88'
	
	END
	
	-- Abnormal Acount
	BEGIN	
		CREATE TABLE #AbnormalAccounts(RequestId INT, MessageId INT, VoidById INT, CustId BIGINT,IssueTypeId TINYINT,DecidedBy NVARCHAR(200),Requestby INT , MinWinlostdate	DATETIME,MaxWinlostdate	DATETIME)
		CREATE TABLE #RelatedAccounts(RequestId INT, MessageId INT, RelatedCustID INT, RelatedUserName VARCHAR(50))
			
		INSERT INTO #AbnormalAccounts ( RequestId, MessageId, VoidById, CustId,IssueTypeId,DecidedBy,Requestby,MinWinlostdate,MaxWinlostdate)
		SELECT vh.RequestId, vh.MessageId, vh.UserId AS VoidById, c.CustId , rq.IssueTypeId , rq.DecidedBy ,rq.UserId AS Requestby , vh.MinWinlostdate,vh.MaxWinlostdate
		FROM dbo.TicketVoiding_VoidingHistory vh WITH (NOLOCK)
			INNER JOIN dbo.TicketVoiding_Request rq WITH (NOLOCK) ON rq.RequestId = vh.RequestId AND rq.IssueTypeId = 13 -- Abnormal Account
			INNER JOIN @tmpMessage m ON m.MessageId = vh.MessageId AND m.RequestId = vh.RequestId
			CROSS APPLY (SELECT val AS CustId FROM dbo.strSplit(m.CustIdList, ',')) c
		WHERE vh.StatusId = 2 --tickets void successfully

		INSERT INTO #RelatedAccounts ( RequestId, MessageId, RelatedUserName)
		SELECT vh.RequestId, vh.MessageId, c.Username
		FROM @tmpMessage vh 
			CROSS APPLY (SELECT val AS Username FROM dbo.strSplit(vh.UsernameList, ',')) c
		
		UPDATE m
		SET m.RelatedCustID = l.custid
		FROM #RelatedAccounts m
		CROSS APPLY
		(
			SELECT TOP 1 c.custid
			FROM Customer c WITH(NOLOCK)
			WHERE c.username = m.RelatedUserName
		) l
		
		INSERT INTO @tblTrans (MessageId, RequestID, custid, username,srecommend,recommend,RelatedCustID,RelatedUserName)
		SELECT vh.MessageId, 
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
	
		INSERT INTO @tblEventInfo (MessageId, IssueTypeId, RequestIDList, DecidedBy, Requestby, VoidBy,MinWinlostdate,MaxWinlostdate)
		SELECT vh.MessageId, 
			vh.IssueTypeId,
			c.RequestIDList,
			d.DecidedBy,
			e.Requestby,
			f.VoidById,
			MIN(MinWinlostdate) AS MinWinlostdate,
			MAX(MaxWinlostdate) AS MaxWinlostdate
		FROM #AbnormalAccounts vh
			OUTER APPLY(
				SELECT STUFF(( SELECT DISTINCT ','+ cast(a.RequestId as VARCHAR(10))  as [text()]
					FROM #AbnormalAccounts a  
					WHERE vh.MessageId = a.MessageId
					FOR XML PATH('')
					),1,1,'')
			)c (RequestIDList)
			OUTER APPLY(
				SELECT STUFF(( SELECT DISTINCT ','+ cast(a.DecidedBy as VARCHAR(10))  as [text()]
					FROM #AbnormalAccounts a  
					WHERE vh.MessageId = a.MessageId
					FOR XML PATH('')
					),1,1,'')
			)d (DecidedBy)
			OUTER APPLY(
				SELECT STUFF(( SELECT DISTINCT ','+ cast(c.username as VARCHAR(10))  as [text()]
					FROM #AbnormalAccounts a  
						INNER JOIN customer c WITH(NOLOCK) ON a.Requestby = c.custid
					WHERE vh.MessageId = a.MessageId
					FOR XML PATH('')
					),1,1,'')
			)e (Requestby)
			OUTER APPLY(
				SELECT STUFF(( SELECT DISTINCT ','+ cast(c.username as VARCHAR(10))  as [text()]
					FROM #AbnormalAccounts a  
						INNER JOIN customer c WITH(NOLOCK) ON a.VoidById = c.custid
					WHERE vh.MessageId = a.MessageId
					FOR XML PATH('')
					),1,1,'')
			)f (VoidById)	
		GROUP BY vh.MessageId,	vh.IssueTypeId,	c.RequestIDList,d.DecidedBy,e.Requestby,f.VoidById
		
				
	END
	
	--return data
	--event info
	SELECT 	*
	FROM @tblEventInfo
	
	--tickets info
	SELECT MessageId, 
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
	
	DROP TABLE #VoidingHistory
END	

