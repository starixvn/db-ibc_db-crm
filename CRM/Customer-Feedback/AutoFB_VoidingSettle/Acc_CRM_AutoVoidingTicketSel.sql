/*<info serverAlias="DBACC-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/

USE bodb02
GO

ALTER PROCEDURE [dbo].[Acc_CRM_AutoVoidingTicketSel]
	@MessageIDs VARCHAR(MAX),
	@ConfigUAT BIT = 0,
	@ConfigPRO BIT = 0,
	@Environment	VARCHAR(10) = 'LIVE'
AS
/*
	Created: 20210908@Winfred
	Task : get list messageid creating fb and fail for creating fb
	DB: DBACC/bodb02
	Original:

	Revisions:
		- 20210908@Winfred: Integrate Auto generate Feedbacks for Voiding Settled Tickets [RedmineId : #157481]
		- 20220207@Elodie: Enhance SP [RedmineId: #168524]
		- 20231030@Malcolm: Add Virtual Sports 3 [RedmineId: #191355]
        - 20240126@Ned.Le: CRM - Support auto Feedback and Notification to headlines/ Accounting PIC when having Refund and Result Amendment for VS4 product [RedmineId: #200080]
		- 20240719@Luke: CRM - Incorporate new product - Virtual Sports 5 [Redmine: #207712]
		- 20250418@Virgil: CRM - Integrate new product - Virtual Sports 7 [RedmineId: #219592]

	Param's Explanation:
		- @MessageIDs: batch msg need to get Voiding Settled Tickets
		@MessageIds = '<ROOT>
						 <r MessageId="1074531543" MsgTargetId="1076587375" BetTransId="111882178359"/> 
						<r MessageId="1074531543" MsgTargetId="1076587376" BetTransId="111882178359"/> 
						<r MessageId="1074531543" MsgTargetId="1076587377" BetTransId="111882178359"/> 
						<r MessageId="1074531543" MsgTargetId="1076587378" BetTransId="111882178359"/> 
						<r MessageId="1074531543" MsgTargetId="1076587379" BetTransId="111882178359"/> 
						<r MessageId="74531666" MsgTargetId="14234611" BetTransId="111882172360"/> 
						<r MessageId="74531666" MsgTargetId="15911863" BetTransId="111882172361"/> 
						<r MessageId="74531667" MsgTargetId="16086285" BetTransId="111882172362"/> 
						</ROOT>'
		- @ConfigUAT: get uus ticket or not
		- @ConfigPRO: get real tickets or not
		- @Environment = 'LIVE'/'UAT' config service for each enviroment 
*/

BEGIN
	SET NOCOUNT ON
	
	DECLARE @tmpMessage TABLE (MessageId INT, MsgTargetId INT, ListBetTransId NVARCHAR(MAX))	
	DECLARE @xml XML = CAST(@MessageIds AS XML)	
	DECLARE @AffectedList VARCHAR(MAX) = ''
	
	CREATE TABLE #CustHeadline (
				CustID			INT,
				HeadlineID		INT,					
				HeadlineName	VARCHAR(50)
				)
	--Messageid non create fb
	DECLARE @tblMessageNoFB TABLE (MessageId INT, MsgTargetId INT, TransId BIGINT, IsCreatedFB BIT DEFAULT(0))
	CREATE TABLE #tmpMsg (MessageId INT, MsgTargetId INT)
	CREATE CLUSTERED INDEX CIX_MessageId ON #tmpMsg (MessageId)

	--event info
	CREATE TABLE #tblEventInfo (MessageId INT, 
								TransId BIGINT,
								CustID INT,
								UserName VARCHAR(50), 
								HeadlineID INT, 
								HeadlineName NVARCHAR(50), 
								MatchId	INT,
								MatchCode	NVARCHAR(100),
								EventDate DATE,
								Bettype INT,
								ProductID INT,
								ListMsgTargetId NVARCHAR(MAX),
								EventType	TINYINT,
								RefTable	TINYINT)	
		
	
	
	INSERT INTO @tmpMessage (MessageId,MsgTargetId, ListBetTransId)
	SELECT t.c.value('@MessageId[1]','int') MessageId,
		t.c.value('@MsgTargetId[1]','BIGINT') MsgTargetId,
		t.c.value('@BetTransId[1]', 'NVARCHAR(MAX)') AS ListBetTransId
	FROM @xml.nodes('/ROOT/r') t(c)	

	INSERT INTO @tblMessageNoFB	(MessageId,MsgTargetId,TransId)
	SELECT 	MessageId,MsgTargetId , t.TransId
	FROM @tmpMessage a	
	CROSS APPLY (
				SELECT val AS TransId FROM dbo.strSplit(a.ListBetTransId, ',')
			) t 		

	-- Get info ticket bettrans
	UPDATE t 
	SET t.IsCreatedFB = 1
	OUTPUT deleted.MessageId,b.transid,b.custid,b.UserName,b.matchid , b.betcheck,b.winlostdate, b.bettype,sb.RefTable,
	CASE WHEN b.bettype IN (9, 29, 2799, 10449, 11099) THEN 1 ELSE sb.EventType END  ,sb.ProductID
	INTO #tblEventInfo (MessageId,TransId,CustID,UserName,MatchId,MatchCode,EventDate,Bettype,RefTable,EventType , ProductID
	)
	FROM @tblMessageNoFB t
	INNER JOIN dbo.bettrans b  WITH(NOLOCK) ON b.transid = t.TransId
	INNER JOIN customer c WITH(NOLOCK) ON b.custid = c.custid 
	LEFT JOIN Dep_CustSuper s WITH(NOLOCK) ON c.srecommend = s.custid 
	CROSS APPLY ( SELECT TOP(1) EventType,RefTable,ProductID
				 FROM dbo.SportBettypeMatrix  WITH(NOLOCK) 
				 WHERE BetType = b.bettype  ) sb
	WHERE t.IsCreatedFB = 0 AND sb.ProductID in (1,3,5,27, 77, 83, 88, 106) --NumberGame,Sportbook,
		 AND s.custid IS NULL
		 AND b.statusID = 102 AND b.status  = 'VOID'  AND c.site <> 'CN88'
		 AND 1= CASE WHEN b.currency = 20 AND (@ConfigUAT = 1 OR @Environment = 'UAT') THEN 1
				WHEN b.currency <> 20 AND @ConfigPRO = 1 AND @Environment <> 'UAT' THEN 1
				ELSE 0 END
	-- Get info ticket bettrans14
	UPDATE t
	SET t.IsCreatedFB = 1
	OUTPUT deleted.MessageId,b.transid,b.custid,b.UserName,	b.matchid, b.betcheck,b.winlostdate, b.bettype,sb.RefTable,
	CASE WHEN b.bettype IN (9, 29, 2799, 10449, 11099) THEN 1 ELSE sb.EventType END  ,sb.ProductID
	INTO #tblEventInfo (MessageId,TransId,CustID,UserName,MatchId,MatchCode,EventDate,Bettype,RefTable,EventType, ProductID )
	FROM @tblMessageNoFB t
	INNER JOIN dbo.bettrans14 b  WITH(NOLOCK) ON b.transid = t.TransId
	INNER JOIN customer c WITH(NOLOCK) ON b.custid = c.custid 
	LEFT JOIN Dep_CustSuper s WITH(NOLOCK) ON c.srecommend = s.custid 
	CROSS APPLY ( SELECT TOP(1) EventType,RefTable,ProductID
				 FROM dbo.SportBettypeMatrix  WITH(NOLOCK) 
				 WHERE BetType = b.bettype  ) sb
	WHERE t.IsCreatedFB = 0 AND sb.ProductID in (1,3,5,27, 77, 83, 88, 106) --NumberGame,Sportbook,
		 AND s.custid IS NULL
		 AND b.statusID = 102 AND b.status  = 'VOID' AND c.site <> 'CN88'
		 AND 1= CASE WHEN b.currency = 20 AND (@ConfigUAT = 1 OR @Environment = 'UAT') THEN 1
				WHEN b.currency <> 20 AND @ConfigPRO = 1 AND @Environment <> 'UAT' THEN 1
				ELSE 0 END	
		
	-- Get list cust 
	SELECT @AffectedList =  STUFF((SELECT DISTINCT ',' + cast(custid AS VARCHAR(10))
									FROM #tblEventInfo
									FOR XML PATH('')), 1, 1, '')

	-- Get headline list customer
	INSERT INTO #CustHeadline(CustID,HeadlineID,HeadlineName)
	EXEC dbo.Acc_CRM_GroupHeadlineSel @custids = @AffectedList	
	
	UPDATE a
	SET a.HeadlineID = c.HeadlineID,a.HeadlineName = c.HeadlineName 
	FROM #tblEventInfo a
		INNER JOIN #CustHeadline c WITH(NOLOCK) ON a.custid = c.custid														
	
	--Update info product and main ticket
	
	UPDATE r
	SET r.MatchCode = CASE WHEN EventType = 0 AND RefTable =3 THEN  SUBSTRING(r.MatchCode, CHARINDEX('-', r.MatchCode, CHARINDEX('-', r.MatchCode, 0) + 1) + 1, CHARINDEX(';', r.MatchCode + ';', 1) - CHARINDEX('-', r.MatchCode, CHARINDEX('-', r.MatchCode, 0) + 1) -1) 
						ELSE MatchId END
	FROM #tblEventInfo r

	UPDATE r
	SET r.ListMsgTargetId = c.MsgTargetId
	FROM #tblEventInfo r
	OUTER APPLY(
				SELECT STUFF(( SELECT DISTINCT ','+ cast(ms.MsgTargetId as VARCHAR(15))  as [text()]
					FROM @tblMessageNoFB ms  
					WHERE r.TransId = ms.TransId 
					FOR XML PATH('')
					),1,1,'')
			)c (MsgTargetId)
	-- remove ticket create fb 
	DELETE r FROM @tblMessageNoFB r INNER JOIN 	#tblEventInfo b ON r.TransId = b.TransId
	
	SELECT 
		t.MessageId,t.TransId,t.CustID,t.UserName,
		t.HeadlineID,t.HeadlineName,t.MatchId,t.MatchCode,
		t.EventDate, t.Bettype,t.EventType,t.ProductID,t.ListMsgTargetId	
	FROM #tblEventInfo t
		
	INSERT INTO #tmpMsg (MessageId, MsgTargetId)
	SELECT DISTINCT MessageId, MsgTargetId 
	FROM @tblMessageNoFB

	SELECT DISTINCT f.MessageId, c.MsgTargetId
	FROM #tmpMsg f
	OUTER APPLY(
				SELECT STUFF(( SELECT DISTINCT ','+ cast(ms.MsgTargetId as VARCHAR(15))  as [text()]
					FROM #tmpMsg ms  
					WHERE f.MessageId = ms.MessageId 
					FOR XML PATH('')
					),1,1,'')
			)c (MsgTargetId)

	DROP TABLE #tblEventInfo
		
END	