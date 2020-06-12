/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_AbnormalTicketsSel]
	@MessageIDs VARCHAR(MAX),
	@ConfigUAT BIT = 0,
	@ConfigPRO BIT = 0
AS
/*
	Created: 20200416@Johnson
	Task : Get abnormal tickets for batch messages
	DB: DBACC/bodb02
	Original:

	Revisions:
		- 20200416@Johnson: Initial sp [redmine:#130949]
	Param's Explanation:
		- @MessageIDs: batch msg need to get abnormal tickets
		'100,101,102'
		- @ConfigUAT: get uus ticket or not
		- @ConfigPRO: get real tickets or not
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @tmpMessage TABLE (MessageId INT, RequestID INT)
	CREATE TABLE #tmpTrans (transid BIGINT)
	
	INSERT INTO @tmpMessage (MessageId)
	SELECT val
	FROM strSplit(@MessageIDs,',')
	
	CREATE TABLE #VoidingHistory (VoidingHistoryId INT, RequestId INT, MessageId INT, ReasonId INT, VoidById INT, TransId BIGINT)
		
	INSERT INTO #VoidingHistory (VoidingHistoryId, RequestId, MessageId, ReasonId, VoidById, TransId)
	SELECT vh.VoidingHistoryId, vh.RequestId, vh.MessageId, vh.ReasonId, vh.UserId AS VoidById, t.TransId
	FROM dbo.TicketVoiding_VoidingHistory vh WITH (NOLOCK)
		CROSS APPLY (
			SELECT val AS TransId FROM dbo.strSplit(vh.TransIds, ',')
		) t
	WHERE EXISTS (SELECT 1 FROM @tmpMessage m WHERE vh.MessageId = m.MessageId)
		AND vh.StatusId = 2 --tickets void successfully
			
	--event info
	DECLARE @tblEventInfo TABLE (MessageId INT, 
								KickOffTime VARCHAR(8), 
								LeagueName NVARCHAR(500), 
								HomeName NVARCHAR(100), 
								AwayName NVARCHAR(100), 
								SportName VARCHAR(50), 
								EventDate DATE)
	
	INSERT INTO @tblEventInfo (MessageId, KickOffTime, LeagueName, HomeName, AwayName,SportName,EventDate)
	SELECT DISTINCT vh.MessageId, 
		LTRIM(RTRIM(REPLACE(REPLACE(RIGHT(CONVERT(VARCHAR(20), DATEADD(HOUR, 12, m.GlobalShowTime), 100), 7), 'AM', ' AM'), 'PM', ' PM'))) AS KickOffTime, 
		l.LeagueName, 
		h.TeamName AS HomeName, 
		a.TeamName AS AwayName,
		s.sportName, 
		m.eventdate
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
				
	--tickets info	
	DECLARE @tblTrans TABLE (MessageId INT, 
							TransID BIGINT,
							custid INT, 
							username VARCHAR(50),
							srecommend INT, 
							recommend INT,
							bettype SMALLINT)
	
	INSERT INTO @tblTrans (MessageId, transid, custid, username,srecommend,recommend, bettype)
	SELECT vh.MessageId, 
		vh.transid,
		custid, 
		username, 
		srecommend,
		b.recommend, 
		b.bettype		
	FROM #VoidingHistory vh
		CROSS APPLY (
			SELECT TOP 1 transid, custid, username,srecommend, recommend, b.bettype, currency
			FROM dbo.bettrans b WITH (NOLOCK)
			WHERE b.transid = vh.TransId
		) b		
	WHERE 1= CASE WHEN b.currency = 20 AND @ConfigUAT = 1 THEN 1
				WHEN b.currency <> 20 AND @ConfigPRO = 1 THEN 1
				ELSE 0 END				
	
	--exclude cn88 tickets
	DELETE t
	FROM @tblTrans t
		INNER JOIN customer c WITH(NOLOCK) ON t.custid = c.custid
	WHERE c.site = 'CN88'
	
	--return data
	--event info
	SELECT 	*
	FROM @tblEventInfo
	
	--tickets info
	SELECT MessageId, 
		transid,
		t.custid, 
		t.username, 
		b.typenamee as bettype,
		CASE WHEN s.custid IS NULL THEN 0 ELSE 1 END as isDeposit,
		ISNULL(s.site,'') as site		
	FROM @tblTrans t
		INNER JOIN bettype b WITH(NOLOCK) ON t.bettype = b.typeid
		LEFT JOIN Dep_CustSuper s WITH(NOLOCK) ON t.srecommend = s.custid
	ORDER BY MessageId,isDeposit,custid
END	