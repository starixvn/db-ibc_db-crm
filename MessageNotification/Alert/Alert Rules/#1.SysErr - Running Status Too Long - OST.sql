
/*
Created: Roy@20240327
Description:
AlertRule properties
	RuleType: SysErr
	Target: OST/777
	Scan Range: LastModifiedTime BETWEEN DATEADD(DD, -1, GETDATE()) AND GETDATE()

Alert rule for [Running] status
	1.For [Capture Data Service] process, [Retrieving] over 2*Configuration_WaitSec
	2.For [Generate Notif Service] process, [Generating] over 60s
	3.For [Generate Lap Notification] process, over 60s

-----Steps of Rule-----
1.Exec Rule and insert into [Error_New] table with Key Columns
	- SessionID
	- SettlementLogID
	- LastModifiedTime
2.Remove EXISTED
	- Load [Error_Old] by @RuleID
	- Remove EXISTED from [Error_New] based on [Error_Old]
3.Return result
	- @JSAlertResult
		+ RefID: SessionID
		+ RefExtraInfo
			[{
				"LastModifiedTime": "2024-05-08T05:29:15.870",
				"MatchID": 83150441,
				"RefInfo": "SessionID",
				"SettlementLogID": 1234
			}]
		+ Content
	
--Output Param: 

		--Declaration for Unit Testing
		DECLARE @RuleID INT = 1
			,@JSAlertResult NVARCHAR(MAX) = ''

Revision:
	20240327@Roy: CRM - Implement Message Notifications Center for Result Amendment of Cricket(#197621)
*/
SET NOCOUNT ON
SELECT @JSAlertResult = ''

DECLARE @WaitSec INT = 0
	,@FromModifiedTime DATETIME = DATEADD(DD, -1, GETDATE())
	,@ToModifiedTime DATETIME = GETDATE()

CREATE TABLE #tmpError_New (
	SessionID NVARCHAR(50) NOT NULL
	,SettlementLogID INT NOT NULL
	,LastModifiedTime DATETIME NOT NULL
	------------------
	,MatchID INT NOT NULL
	,Content NVARCHAR(4000)
)

CREATE TABLE #tmpError_Old (
	SessionID NVARCHAR(50)
	,SettlementLogID INT
	,LastModifiedTime DATETIME
)

CREATE TABLE #tmpSettl (
	SessionID NVARCHAR(50) NOT NULL
	,SettlementLogID INT NOT NULL
	,LastModifiedTime DATETIME NOT NULL
	------------------
	,MatchID INT NOT NULL
	,Status VARCHAR(50) NOT NULL
)

CREATE TABLE #tmpMsgNoti (
	MsgNotiID INT NOT NULL
	,LapNotiID INT
	,MessageID INT NOT NULL
	,MatchID INT NOT NULL
	,Status VARCHAR(50) NOT NULL
	,ValidType VARCHAR(50)
)

------------Prepare to check------------
INSERT INTO #tmpSettl (
	SessionID
	,SettlementLogID
	,LastModifiedTime
	,MatchID
	,Status
)
SELECT DISTINCT rh.SessionID
	,rh.SettlementLogID
	,rh.LastModifiedTime
	,rh.MatchID
	,st.Status
FROM MessageNotification.dbo.SettlementResultHist AS rh WITH (NOLOCK)
	LEFT JOIN MessageNotification.dbo.NotiStatus AS st WITH (NOLOCK) ON rh.StatusID = st.StatusID
WHERE rh.LastModifiedTime > @FromModifiedTime
	AND rh.LastModifiedTime <= @ToModifiedTime

CREATE CLUSTERED INDEX CIX_tmpSettl ON #tmpSettl(SessionID)

INSERT INTO #tmpMsgNoti (
	MsgNotiID
	,MessageID
	,MatchID
	,Status
)
SELECT DISTINCT nMsg.NotificationID AS MsgNotiID
	,nMsg.RefID AS MessageID
	,rh.MatchID
	,st.Status
FROM MessageNotification.dbo.Notification AS nMsg WITH (NOLOCK)
	LEFT JOIN MessageNotification.dbo.NotiMapping AS mMsg WITH (NOLOCK) ON nMsg.NotificationID = mMsg.NotificationID
	LEFT JOIN MessageNotification.dbo.SettlementResultHist AS rh WITH (NOLOCK) ON mMsg.SettlementLogID = rh.SettlementLogID
	LEFT JOIN MessageNotification.dbo.NotiStatus AS st WITH (NOLOCK) ON nMsg.StatusID = st.StatusID
WHERE nMsg.LastModifiedTime > @FromModifiedTime
	AND nMsg.LastModifiedTime <= @ToModifiedTime
	AND nMsg.NotificationType = 1 --1: Result Amendment to Msg
	AND rh.SportType = 50 --Cricket, need modify for others sport
	AND st.Status IN ( 'Generating', 'Sending')
	AND nMsg.RefID IS NOT NULL

CREATE CLUSTERED INDEX CIX_tmpMsgNoti ON #tmpMsgNoti(MsgNotiID)
/**************************************************************************************
	check before exec rule
*/
IF NOT EXISTS (SELECT 1 FROM MessageNotification.dbo.AlertRule WITH (NOLOCK) WHERE RuleID = @RuleID) --may no need, check @RuleID is null
	OR (NOT EXISTS (SELECT 1 FROM #tmpSettl) AND NOT EXISTS (SELECT 1 FROM #tmpMsgNoti))
BEGIN
	DROP TABLE #tmpSettl
	DROP TABLE #tmpMsgNoti
	DROP TABLE #tmpError_New
	DROP TABLE #tmpError_Old
	--EXIT
	RETURN
END

/**************************************************************************************
	2.Exec Rule and insert into [Error_New] table with Key Columns
*/
---1.For [Capture Data Service] process, [Retrieving] over 2*Configuration_WaitSec---
SELECT @WaitSec = ISNULL(TRY_CONVERT(INT, VValue),0) * 2
FROM MessageNotification.dbo.SystemSetting WITH (NOLOCK)
WHERE VID = 11 --Retrieving_WaitSec

;WITH CTE_LongSession AS (
	SELECT SessionID
		,MIN(LastModifiedTime) AS Mi_LastModifiedTime
	FROM #tmpSettl
	WHERE Status = 'Retrieving'
	GROUP BY SessionID
	HAVING DATEDIFF(SECOND, MIN(LastModifiedTime),GETDATE()) > @WaitSec
)
INSERT INTO #tmpError_New (
	SessionID
	,SettlementLogID
	,LastModifiedTime
	,MatchID
	--------------
	,Content
)
SELECT DISTINCT l.SessionID
	,rh.SettlementLogID
	,rh.LastModifiedTime
	,rh.MatchID
	,'SessionID [' + l.SessionID + '] in [Retrieving] state too long, exceeding '+ ISNULL(CONVERT(VARCHAR, @WaitSec),'NULL')+' seconds. Please double check [Capture Data Service] process.' AS Content
FROM CTE_LongSession AS l
	LEFT JOIN #tmpSettl AS rh ON l.SessionID = rh.SessionID AND rh.Status = 'Retrieving'

---2.For [Generate Notif Service] process, [Generating] over 60s---
SELECT @WaitSec = 60

;WITH CTE_LongSession AS (
	SELECT SessionID
		,MIN(LastModifiedTime) AS Mi_LastModifiedTime
	FROM #tmpSettl
	WHERE Status = 'Generating'
	GROUP BY SessionID
	HAVING DATEDIFF(SECOND, MIN(LastModifiedTime),GETDATE()) > @WaitSec
)
INSERT INTO #tmpError_New (
	SessionID
	,SettlementLogID
	,LastModifiedTime
	,MatchID
	--------------
	,Content
)
SELECT DISTINCT rh.SessionID
	,rh.SettlementLogID
	,rh.LastModifiedTime
	,rh.MatchID
	,'SessionID [' + rh.SessionID + '] in [Generating] Msg state too long, exceeding '+ ISNULL(CONVERT(VARCHAR, @WaitSec),'NULL')+' seconds. Please double check [Generate Notif Service] process.' AS Content
FROM CTE_LongSession AS l
	LEFT JOIN #tmpSettl AS rh ON l.SessionID = rh.SessionID AND rh.Status = 'Generating'

--For Notification.StatusID = Generating / Sending
INSERT INTO #tmpError_New (
	SessionID
	,SettlementLogID
	,LastModifiedTime
	,MatchID
	--------------
	,Content
)
SELECT DISTINCT rh.SessionID
	,rh.SettlementLogID
	,n.LastModifiedTime
	,rh.MatchID
	,(CASE WHEN m.Status = 'Generating' THEN 'Notification(' + ISNULL(CONVERT(VARCHAR, m.MsgNotiID),'NULL') + ') of SessionID [' + rh.SessionID + '] in [Generating] Msg state too long, exceeding '+ ISNULL(CONVERT(VARCHAR, @WaitSec),'NULL')+' seconds. Please double check [Generate Notification] process.'
		ELSE 'Notification(' + ISNULL(CONVERT(VARCHAR, m.MsgNotiID),'NULL') + ') of SessionID [' + rh.SessionID + '] in [Sending] state too long, exceeding '+ ISNULL(CONVERT(VARCHAR, @WaitSec),'NULL')+' seconds. Please double check [Insert Message Service] process.'
	END) AS Content
FROM #tmpMsgNoti AS m
	LEFT JOIN MessageNotification.dbo.Notification AS n WITH (NOLOCK) ON m.MsgNotiID = n.NotificationID
	LEFT JOIN MessageNotification.dbo.NotiMapping AS nm WITH (NOLOCK) ON m.MsgNotiID = nm.NotificationID
	LEFT JOIN MessageNotification.dbo.SettlementResultHist AS rh WITH (NOLOCK) ON nm.SettlementLogID = rh.SettlementLogID
WHERE m.Status IN ('Generating', 'Sending')
	AND DATEDIFF(SECOND, n.LastModifiedTime, GETDATE()) > @WaitSec

/**************************************************************************************
	3.Remove EXISTED
	
	Key to remove EXISTED
	- SessionID
	- SettlementLogID
	- LastModifiedTime

*/
CREATE CLUSTERED INDEX CIX_tmpError_New ON #tmpError_New (SessionID)

INSERT INTO #tmpError_Old (
	SessionID
	,SettlementLogID
	,LastModifiedTime
)
SELECT DISTINCT a.RefID AS SessionID
	,ext.SettlementLogID
	,ext.LastModifiedTime
FROM MessageNotification.dbo.Alert AS a WITH (NOLOCK)
	INNER JOIN #tmpError_New AS sn ON a.RefID = sn.SessionID
	OUTER APPLY OPENJSON(a.RefExtraInfo) WITH (
			RefInfo VARCHAR(50) '$.RefInfo'
			,SettlementLogID INT '$.SettlementLogID'
			,LastModifiedTime DATETIME '$.LastModifiedTime'
		) AS ext --OPENJSON case-sensitive
WHERE a.RuleID = @RuleID
	AND ISJSON(a.RefExtraInfo) = 1
	AND ext.RefInfo = 'SessionID'
	AND ext.SettlementLogID IS NOT NULL
	AND ext.LastModifiedTime IS NOT NULL

DELETE n
FROM #tmpError_New AS n
	INNER JOIN #tmpError_Old AS o ON n.SessionID = o.SessionID AND n.SettlementLogID = o.SettlementLogID AND n.LastModifiedTime = o.LastModifiedTime

/**************************************************************************************
	4.Return result
*/
IF EXISTS (SELECT 1 FROM #tmpError_New)
BEGIN
	;WITH CTE_Sett AS (
		SELECT DISTINCT s.SessionID AS RefID
			,s.Content
			,CONVERT(NVARCHAR(MAX),(
					SELECT DISTINCT 'SessionID' AS RefInfo
						,t.SettlementLogID
						,t.MatchID
						,t.LastModifiedTime
					FROM #tmpError_New AS t
					WHERE t.SessionID = s.SessionID
						AND t.Content = s.Content
					FOR JSON PATH)
				) AS RefExtraInfo
		FROM #tmpError_New AS s
		GROUP BY s.SessionID
			,s.Content
	)
	SELECT @JSAlertResult = CONVERT(NVARCHAR(MAX),(
				SELECT RefID
					,RefExtraInfo
					,Content
				FROM CTE_Sett
				FOR JSON PATH
			))
END

DROP TABLE IF EXISTS #tmpSettl
DROP TABLE IF EXISTS #tmpMsgNoti
DROP TABLE IF EXISTS #tmpError_New
DROP TABLE IF EXISTS #tmpError_Old

--Return for Unit Testing
 -- SELECT @JSAlertResult AS [@JSAlertResult]