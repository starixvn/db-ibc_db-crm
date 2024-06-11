/*<info serverAlias="DBCRM-MessageNotification" isFunction="0" isNested="0"></info>*/
/*
Created by Roy.Du@20240510
Run at DBCRM@MessageNotification
Task: Update Rule#1
*/

USE [MessageNotification]
GO

DECLARE @sqlStm NVARCHAR(MAX)
DECLARE @RuleID INT = 1

SELECT @sqlStm =
'
/*
Created: Roy@20240327
Description:
AlertRule properties
	RuleType: SysErr
	Target: OST/777
	LastScan: compare with LastModifiedTime

Alert rule for [Running] status
	1.For [Capture Data] process, [Retrieving] over 2*Configuration_WaitSec
	2.For [Generate Msg Notification] process, [Generating] over 60s
	3.For [Generate Lap Notification] process, over 60s

-----Steps of Rule-----
1.Define @LastScan
2.Exec Rule and insert into [Error_New] table with Key Columns
	- SessionID
	- SettlementLogID
	- LastModifiedTime
3.Remove EXISTED
	- Load [Error_Old] by @RuleID
	- Remove EXISTED from [Error_New] based on [Error_Old]
4.Return result
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
	- @LastScan
	
--Output Param: 

		--Declaration for Unit Testing
		DECLARE @RuleID INT = 1
			,@LastScan VARCHAR(500)
			,@JSAlertResult NVARCHAR(MAX) = ''''

Revision:
	20240327@Roy: CRM - Implement Message Notifications Center for Result Amendment of Cricket(#197621)
*/
SET NOCOUNT ON
SELECT @JSAlertResult = ''''

DECLARE @WaitSec INT = 0
	,@Sts TINYINT
	,@FromModifiedTime DATETIME
	,@ToModifiedTime DATETIME = GETDATE()

/**************************************************************************************
	1.Define @LastScan
	
	in this Rule, @LastScan IS LastModifiedTime
	
	Define @FromModifiedTime and @ToModifiedTime
*/
SELECT @FromModifiedTime = TRY_CONVERT(DATETIME,@LastScan)

IF @FromModifiedTime IS NULL
BEGIN
	SELECT @FromModifiedTime = MIN(Mi_LastModifiedTime)
	FROM (
		SELECT MIN(LastModifiedTime) AS Mi_LastModifiedTime
		FROM MessageNotification.dbo.SettlementResultHist WITH (NOLOCK)
		
		UNION ALL
		
		SELECT MIN(LastModifiedTime) AS Mi_LastModifiedTime
		FROM MessageNotification.dbo.Notification WITH (NOLOCK)
	) AS t
END

-- NOT EXISTS data in SettlementResultHist => ignore check
IF @FromModifiedTime IS NULL
	OR @FromModifiedTime >= @ToModifiedTime
	OR NOT EXISTS (SELECT 1 FROM MessageNotification.dbo.AlertRule WITH (NOLOCK) WHERE RuleID = @RuleID) --may no need, check @RuleID is null
BEGIN
	SELECT @JSAlertResult = ''''
		,@LastScan = CONVERT(VARCHAR, ISNULL(@FromModifiedTime,DATEADD(ms,3,@ToModifiedTime)), 25) --because condition [LastModifiedTime > @FromModifiedTime] => cover PointTime @ToModifiedTime
	
	RETURN
END

CREATE TABLE #tmpError_New (
	SessionID VARCHAR(50) NOT NULL
	,SettlementLogID INT NOT NULL
	,LastModifiedTime DATETIME NOT NULL
	------------------
	,MatchID INT NOT NULL
	,Content NVARCHAR(4000)
)

CREATE TABLE #tmpError_Old (
	SessionID VARCHAR(50)
	,SettlementLogID INT
	,LastModifiedTime DATETIME
)

CREATE TABLE #tmpNotiNOLap (
	NotificationID INT
	,MatchID INT
	,SettlID INT
)

/**************************************************************************************
	2.Exec Rule and insert into [Error_New] table with Key Columns
*/
---1.For [Capture Data] process, [Retrieving] over 2*Configuration_WaitSec---
SELECT @WaitSec = ISNULL(TRY_CONVERT(INT, VValue),0) * 2
FROM MessageNotification.dbo.SystemSetting WITH (NOLOCK)
WHERE VID = 11 --Retrieving_WaitSec

SELECT @Sts = StatusID
FROM MessageNotification.dbo.NotiStatus WITH (NOLOCK)
WHERE Status = ''Retrieving''

;WITH CTE_LongSession AS (
	SELECT SessionID
		,MIN(LastModifiedTime) AS Mi_LastModifiedTime
	FROM MessageNotification.dbo.SettlementResultHist WITH (NOLOCK)
	WHERE StatusID = @Sts
		AND LastModifiedTime > @FromModifiedTime
		AND LastModifiedTime <= @ToModifiedTime
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
	,''SessionID ['' + l.SessionID + ''] in [Retrieving] state too long, exceeding ''+ ISNULL(CONVERT(VARCHAR, @WaitSec),''NULL'')+'' seconds. Please double check [Capture Data] process.'' AS Content
FROM CTE_LongSession AS l
	INNER JOIN MessageNotification.dbo.SettlementResultHist AS rh WITH (NOLOCK) ON l.SessionID = rh.SessionID AND rh.StatusID = @Sts
WHERE rh.LastModifiedTime > @FromModifiedTime
	AND rh.LastModifiedTime <= @ToModifiedTime
	AND DATEDIFF(SECOND, rh.LastModifiedTime,GETDATE()) > @WaitSec

---2.For [Generate Msg Notification] process, [Generating] over 60s---
SELECT @WaitSec = 60
SELECT @Sts = StatusID
FROM MessageNotification.dbo.NotiStatus WITH (NOLOCK)
WHERE Status = ''Generating''

;WITH CTE_LongSession AS (
	SELECT SessionID
		,MIN(LastModifiedTime) AS Mi_LastModifiedTime
	FROM MessageNotification.dbo.SettlementResultHist WITH (NOLOCK)
	WHERE StatusID = @Sts
		AND LastModifiedTime > @FromModifiedTime
		AND LastModifiedTime <= @ToModifiedTime
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
	,''SessionID ['' + rh.SessionID + ''] in [Generating] Msg state too long, exceeding ''+ ISNULL(CONVERT(VARCHAR, @WaitSec),''NULL'')+'' seconds. Please double check [Generate Notification] process.'' AS Content
FROM MessageNotification.dbo.SettlementResultHist AS rh WITH (NOLOCK)
WHERE StatusID = @Sts
	AND LastModifiedTime > @FromModifiedTime
	AND LastModifiedTime <= @ToModifiedTime
	AND DATEDIFF(SECOND, LastModifiedTime,GETDATE()) > @WaitSec

---3.For [Generate Lap Notification] process, over 60s---
SELECT @WaitSec = 60

-- Refer to MNC_ResultAmendment_PrepareGenLAP
;WITH CTE_Msg AS (
	SELECT DISTINCT nMsg.NotificationID AS MsgNotiID
		,rh.MatchID
	FROM MessageNotification.dbo.Notification AS nMsg WITH (NOLOCK)
		INNER JOIN MessageNotification.dbo.NotiMapping AS mMsg WITH (NOLOCK) ON nMsg.NotificationID = mMsg.NotificationID
		INNER JOIN MessageNotification.dbo.SettlementResultHist AS rh WITH (NOLOCK) ON mMsg.SettlementLogID = rh.SettlementLogID
	WHERE nMsg.LastModifiedTime > @FromModifiedTime
		AND nMsg.LastModifiedTime <= @ToModifiedTime
		AND nMsg.NotificationType = 1 --1: Result Amendment to Msg
		AND rh.SportType = 50 --Cricket, need modify for others sport
		AND nMsg.StatusID IN (13)--Sent only successful push to DBMSG
		AND nMsg.RefID IS NOT NULL
)
,CTE_Lap AS (
	SELECT DISTINCT nLap.NotificationID AS LapNotiID
		,ext.MsgNotiID
	FROM MessageNotification.dbo.Notification AS nLap WITH (NOLOCK)
		INNER JOIN MessageNotification.dbo.NotificationExtra AS nLapEx WITH (NOLOCK) ON nLap.NotificationID = nLapEx.NotificationID
		OUTER APPLY OPENJSON(nLapEx.ExtraInfo) WITH (
				MsgNotiID VARCHAR(MAX) ''$.MsgNotiID''
			) AS ext--OPENJSON case-sensitive
	WHERE nLap.LastModifiedTime > @FromModifiedTime
		AND nLap.LastModifiedTime <= @ToModifiedTime
		AND nLap.NotificationType = 2 --2: Result Amendment to LAP
)
INSERT INTO #tmpNotiNOLap (
	NotificationID
	,MatchID
)
SELECT m.MsgNotiID
	,m.MatchID
FROM CTE_Msg AS m
	LEFT JOIN CTE_Lap AS l ON m.MsgNotiID = l.MsgNotiID
WHERE l.MsgNotiID IS NULL

CREATE CLUSTERED INDEX CIX_tmpNotiNOLap ON #tmpNotiNOLap(NotificationID)

--validate again with Target => must EXISTS [deposit] Target
;WITH CTE_Valid AS (
	SELECT i.NotificationID
	FROM #tmpNotiNOLap AS i
		INNER JOIN MessageNotification.dbo.NotificationTarget AS nt WITH (NOLOCK) ON i.NotificationID = nt.NotificationID --must EXISTS Target
		INNER JOIN bodb02.dbo.Site AS s WITH (NOLOCK) ON nt.TargetSite = s.site AND s.isDeposit = 1 --deposit user
	GROUP BY i.NotificationID
)
DELETE t
FROM #tmpNotiNOLap AS t
	LEFT JOIN CTE_Valid AS v ON t.NotificationID = v.NotificationID
WHERE v.NotificationID IS NULL

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
	,''LAP Notification of SessionID ['' + rh.SessionID + ''] NOT EXISTS after being approved MessageID ['' + CONVERT(VARCHAR,n.RefID) + ''] for more than ''+ ISNULL(CONVERT(VARCHAR, @WaitSec),''NULL'')+'' seconds. Please double check [Generate LAP Notification] process.'' AS Content
FROM #tmpNotiNOLap AS ck
	INNER JOIN MessageNotification.dbo.Notification AS n WITH (NOLOCK) ON n.NotificationID = ck.NotificationID
	INNER JOIN MessageNotification.dbo.NotiMapping AS nm WITH (NOLOCK) ON n.NotificationID = nm.NotificationID
	INNER JOIN MessageNotification.dbo.SettlementResultHist AS rh WITH (NOLOCK) ON nm.SettlementLogID = rh.SettlementLogID
WHERE DATEDIFF(SECOND, n.LastModifiedTime,GETDATE()) > @WaitSec --[after being approved MessageID] => Use Notification.LastModifiedTime

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
			RefInfo VARCHAR(50) ''$.RefInfo''
			,SettlementLogID INT ''$.SettlementLogID''
			,LastModifiedTime DATETIME ''$.LastModifiedTime''
		) AS ext --OPENJSON case-sensitive
WHERE a.RuleID = @RuleID
	AND ISJSON(a.RefExtraInfo) = 1
	AND ext.RefInfo = ''SessionID''
	AND ext.SettlementLogID IS NOT NULL
	AND ext.LastModifiedTime IS NOT NULL

DELETE n
FROM #tmpError_New AS n
	INNER JOIN #tmpError_Old AS o ON n.SessionID = o.SessionID AND n.SettlementLogID = o.SettlementLogID AND n.LastModifiedTime = o.LastModifiedTime

/**************************************************************************************
	4.Return result
*/
IF NOT EXISTS (SELECT 1 FROM #tmpError_New)
BEGIN
	SELECT @JSAlertResult = ''''
		,@LastScan = CONVERT(VARCHAR, @ToModifiedTime, 25)
END
ELSE
BEGIN
	;WITH CTE_Sett AS (
		SELECT s.SessionID AS RefID
			,s.Content
			,CONVERT(NVARCHAR(MAX),(
					SELECT DISTINCT ''SessionID'' AS RefInfo
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
		,@LastScan = CONVERT(VARCHAR, @ToModifiedTime, 25)
END

DROP TABLE #tmpError_New
DROP TABLE #tmpError_Old
DROP TABLE #tmpNotiNOLap

--Return for Unit Testing
-- SELECT @LastScan AS [@LastScan]
	-- ,@JSAlertResult AS [@JSAlertResult]
'
----------------------------------
UPDATE MessageNotification.dbo.AlertRule
SET SQLStatement = @sqlStm
WHERE RuleID = @RuleID
