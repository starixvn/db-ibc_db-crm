
/*
Created: Roy@20240327
Description:
AlertRule properties
	RuleType: SysErr
	Target: OST/777
	Scan Range: LastModifiedTime BETWEEN DATEADD(DD, -1, GETDATE()) AND GETDATE()

Alert rule for [Running] status
	1.For [Generate LAP Notif Service] process, over 60s

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
		DECLARE @RuleID INT = 6
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

CREATE TABLE #tmpMsgNoti (
	MsgNotiID INT NOT NULL
	,LapNotiID INT
	,MessageID INT NOT NULL
	,MatchID INT
	,ValidType VARCHAR(50)
)

------------Prepare to check------------
INSERT INTO #tmpMsgNoti (
	MsgNotiID
	,MessageID
)
SELECT DISTINCT nMsg.NotificationID AS MsgNotiID
	,nMsg.RefID AS MessageID
FROM MessageNotification.dbo.Notification AS nMsg WITH (NOLOCK)
	LEFT JOIN MessageNotification.dbo.NotiStatus AS st WITH (NOLOCK) ON nMsg.StatusID = st.StatusID
WHERE nMsg.LastModifiedTime > @FromModifiedTime
	AND nMsg.LastModifiedTime <= @ToModifiedTime
	AND nMsg.NotificationType = 1 --1: Result Amendment to Msg
	AND nMsg.RefID IS NOT NULL
	AND st.Status = 'Sent' --Sent DBMSG

CREATE CLUSTERED INDEX CIX_tmpMsgNoti ON #tmpMsgNoti(MsgNotiID)
/**************************************************************************************
	check before exec rule
*/
IF NOT EXISTS (SELECT 1 FROM MessageNotification.dbo.AlertRule WITH (NOLOCK) WHERE RuleID = @RuleID) --may no need, check @RuleID is null
	OR (NOT EXISTS (SELECT 1 FROM #tmpMsgNoti))
BEGIN
	DROP TABLE #tmpMsgNoti
	DROP TABLE #tmpError_New
	DROP TABLE #tmpError_Old
	--EXIT
	RETURN
END

/**************************************************************************************
	2.Exec Rule and insert into [Error_New] table with Key Columns
*/
---1.For [Generate Lap Notification] process, over 60s---
SELECT @WaitSec = 60

;WITH CTE_Sport AS (
	SELECT DISTINCT i.MsgNotiID
		,rh.MatchID
		,rh.SportType
	FROM #tmpMsgNoti AS i
		LEFT JOIN MessageNotification.dbo.NotiMapping AS nm WITH (NOLOCK) ON i.MsgNotiID = nm.NotificationID
		LEFT JOIN MessageNotification.dbo.SettlementResultHist AS rh WITH (NOLOCK) ON nm.SettlementLogID = rh.SettlementLogID
	WHERE rh.MatchID IS NOT NULL
)
UPDATE i
SET i.MatchID = s.MatchID
	,i.ValidType = (CASE WHEN nLap.NotificationID IS NULL THEN 'NOLAP'
						WHEN st.Status = 'Generating' THEN 'GeneratingLAP'
						ELSE 'CreatedLAP' END) --st.Status = 'Successfully Generated'
	,i.LapNotiID = nLap.NotificationID
FROM #tmpMsgNoti AS i
	LEFT JOIN CTE_Sport AS s ON i.MsgNotiID = s.MsgNotiID
	LEFT JOIN MessageNotification.dbo.Notification AS nLap WITH (NOLOCK) ON i.MessageID = nLap.RefID AND nLap.NotificationType = 2 --2: Result Amendment to LAP
	LEFT JOIN MessageNotification.dbo.NotiStatus AS st WITH (NOLOCK) ON nLap.StatusID = st.StatusID
WHERE s.SportType = 50 --Cricket, need modify for others sport
	
--validate again with Target => must EXISTS [deposit] Target
UPDATE m
SET m.ValidType = 'CreatedLAP'
FROM #tmpMsgNoti AS m
WHERE m.ValidType = 'NOLAP' -- NOT create LAP yet
	AND NOT EXISTS (
		SELECT 1
		FROM MessageNotification.dbo.NotificationTarget AS nt WITH (NOLOCK)
			LEFT JOIN bodb02.dbo.Site AS s WITH (NOLOCK) ON nt.TargetSite = s.site AND s.isDeposit = 1 --deposit user
		WHERE m.MsgNotiID = nt.NotificationID
			AND s.site IS NOT NULL --EXISTS [deposit] Target
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
	,n.LastModifiedTime --[after being approved MessageID]
	,ck.MatchID
	,(CASE WHEN ck.ValidType = 'NOLAP' THEN 'LAP Notification of SessionID [' + rh.SessionID + '] NOT EXISTS after being approved MessageID [' + CONVERT(VARCHAR,n.RefID) + '] for more than '+ ISNULL(CONVERT(VARCHAR, @WaitSec),'NULL')+' seconds. Please double check [Generate LAP Notif Service] process.'
		ELSE 'LAP Notification(' + ISNULL(CONVERT(VARCHAR, ck.LapNotiID),'NULL') + ') of SessionID [' + rh.SessionID + '] in [Generating] state too long, exceeding ' + ISNULL(CONVERT(VARCHAR, @WaitSec),'NULL') + ' seconds. Please double check [Generate LAP Notif Service] process.'
	END) AS Content
FROM #tmpMsgNoti AS ck
	LEFT JOIN MessageNotification.dbo.Notification AS n WITH (NOLOCK) ON ck.MsgNotiID = n.NotificationID
	LEFT JOIN MessageNotification.dbo.NotiMapping AS nm WITH (NOLOCK) ON ck.MsgNotiID = nm.NotificationID
	LEFT JOIN MessageNotification.dbo.SettlementResultHist AS rh WITH (NOLOCK) ON nm.SettlementLogID = rh.SettlementLogID
WHERE ck.ValidType IN ('NOLAP', 'GeneratingLAP')
	AND DATEDIFF(SECOND, n.LastModifiedTime,GETDATE()) > @WaitSec --[after being approved MessageID] => Use Notification.LastModifiedTime

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

DROP TABLE IF EXISTS #tmpMsgNoti
DROP TABLE IF EXISTS #tmpError_New
DROP TABLE IF EXISTS #tmpError_Old

--Return for Unit Testing
 -- SELECT @JSAlertResult AS [@JSAlertResult]