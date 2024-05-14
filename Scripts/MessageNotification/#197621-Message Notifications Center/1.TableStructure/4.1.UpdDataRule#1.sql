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

Alert Output:
	RefID: SessionID or NotificationID
	RefExtraInfo:
		+ For SessionID
			- RefInfo = ''SessionID''
			- SettlementLogID
			- LastModifiedTime
		+ For NotificationID
			- RefInfo = ''NotificationID''
			- LastModifiedTime

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

/*
	in this Rule, @LastScan IS LastModifiedTime
	
	Define @FromModifiedTime and @ToModifiedTime
*/
SELECT @FromModifiedTime = TRY_CONVERT(DATETIME,@LastScan)

IF @FromModifiedTime IS NULL
BEGIN
	SELECT @FromModifiedTime = MIN(Mi_LastModifiedTime)
	FROM (
		SELECT MIN(LastModifiedTime) AS Mi_LastModifiedTime
		FROM SettlementResultHist WITH (NOLOCK)
		
		UNION ALL
		
		SELECT MIN(LastModifiedTime) AS Mi_LastModifiedTime
		FROM Notification WITH (NOLOCK)
	) AS t
END

-- NOT EXISTS data in SettlementResultHist => ignore check
IF @FromModifiedTime IS NULL
	OR @FromModifiedTime >= @ToModifiedTime
	OR NOT EXISTS (SELECT 1 FROM AlertRule WITH (NOLOCK) WHERE RuleID = @RuleID) --may no need, check @RuleID is null
BEGIN
	SELECT @JSAlertResult = ''''
		,@LastScan = CONVERT(VARCHAR, ISNULL(@FromModifiedTime,DATEADD(ms,3,@ToModifiedTime)), 25) --because condition [LastModifiedTime > @FromModifiedTime] => cover PointTime @ToModifiedTime
	
	RETURN
END

/******************************************Start to Check****************************************************/
CREATE TABLE #tmpNotiError_New (
	NotificationID INT
	,MatchID INT
	,Content NVARCHAR(4000)
	,LastModifiedTime DATETIME
)

CREATE TABLE #tmpNotiError_Old (
	NotificationID INT
	,LastModifiedTime DATETIME
)

CREATE TABLE #tmpSettlError_New (
	SessionID VARCHAR(50)
	,MatchID INT
	,SettlementLogID INT
	,Content NVARCHAR(4000)
	,LastModifiedTime DATETIME
)

CREATE TABLE #tmpSettlError_Old (
	SessionID VARCHAR(50)
	,SettlementLogID INT
	,LastModifiedTime DATETIME
)

CREATE TABLE #tmpLapNotiCheck (
	NotificationID INT
	,MatchID INT
	,SettlID INT
)

---1.For [Capture Data] process, [Retrieving] over 2*Configuration_WaitSec---
SELECT @WaitSec = ISNULL(TRY_CONVERT(INT, VValue),0) * 2
FROM SystemSetting WITH (NOLOCK)
WHERE VID = 11 --Retrieving_WaitSec

SELECT @Sts = StatusID
FROM NotiStatus WITH (NOLOCK)
WHERE Status = ''Retrieving''

;WITH CTE_LongSession AS (
	SELECT SessionID
		,MIN(LastModifiedTime) AS Mi_LastModifiedTime
	FROM SettlementResultHist WITH (NOLOCK)
	WHERE StatusID = @Sts
		AND LastModifiedTime > @FromModifiedTime
		AND LastModifiedTime <= @ToModifiedTime
	GROUP BY SessionID
	HAVING DATEDIFF(SECOND, MIN(LastModifiedTime),GETDATE()) > @WaitSec
)
INSERT INTO #tmpSettlError_New (
	SessionID
	,MatchID
	,SettlementLogID
	,Content
	,LastModifiedTime
)
SELECT DISTINCT l.SessionID
	,rh.MatchID
	,rh.SettlementLogID
	,''SessionID ['' + l.SessionID + ''] in [Retrieving] state too long, exceeding ''+ ISNULL(CONVERT(VARCHAR, @WaitSec),''NULL'')+'' seconds. Please double check [Capture Data] process.'' AS Content
	,rh.LastModifiedTime
FROM CTE_LongSession AS l
	INNER JOIN SettlementResultHist AS rh WITH (NOLOCK) ON l.SessionID = rh.SessionID AND rh.StatusID = @Sts
WHERE rh.LastModifiedTime > @FromModifiedTime
	AND rh.LastModifiedTime <= @ToModifiedTime
	AND DATEDIFF(SECOND, rh.LastModifiedTime,GETDATE()) > @WaitSec

---2.For [Generate Msg Notification] process, [Generating] over 60s---
SELECT @WaitSec = 60
SELECT @Sts = StatusID
FROM NotiStatus WITH (NOLOCK)
WHERE Status = ''Generating''

;WITH CTE_LongSession AS (
	SELECT SessionID
		,MIN(LastModifiedTime) AS Mi_LastModifiedTime
	FROM SettlementResultHist WITH (NOLOCK)
	WHERE StatusID = @Sts
		AND LastModifiedTime > @FromModifiedTime
		AND LastModifiedTime <= @ToModifiedTime
	GROUP BY SessionID
	HAVING DATEDIFF(SECOND, MIN(LastModifiedTime),GETDATE()) > @WaitSec
)
INSERT INTO #tmpSettlError_New (
	SessionID
	,MatchID
	,SettlementLogID
	,Content
	,LastModifiedTime
)
SELECT DISTINCT rh.SessionID
	,rh.MatchID
	,rh.SettlementLogID
	,''SessionID ['' + rh.SessionID + ''] in [Generating] Msg state too long, exceeding ''+ ISNULL(CONVERT(VARCHAR, @WaitSec),''NULL'')+'' seconds. Please double check [Generate Notification] process.'' AS Content
	,rh.LastModifiedTime
FROM SettlementResultHist AS rh WITH (NOLOCK)
WHERE StatusID = @Sts
	AND LastModifiedTime > @FromModifiedTime
	AND LastModifiedTime <= @ToModifiedTime
	AND DATEDIFF(SECOND, LastModifiedTime,GETDATE()) > @WaitSec

---3.For [Generate Lap Notification] process, over 60s---
SELECT @WaitSec = 60

-- Refer to MNC_ResultAmendment_PrepareGenLAP
;WITH CTE_Noti AS (
	SELECT DISTINCT nMsg.NotificationID
		,rh.MatchID
		,(CASE WHEN nL.NotificationID IS NOT NULL THEN 1 ELSE 0 END) AS LapCnt
	FROM Notification AS nMsg WITH (NOLOCK)
		INNER JOIN NotiMapping AS mMsg WITH (NOLOCK) ON nMsg.NotificationID = mMsg.NotificationID
		INNER JOIN SettlementResultHist AS rh WITH (NOLOCK) ON mMsg.SettlementLogID = rh.SettlementLogID
		OUTER APPLY (
			SELECT nLap.NotificationID
			FROM NotiMapping AS mLap WITH (NOLOCK)
				INNER JOIN Notification AS nLap WITH (NOLOCK) ON mLap.NotificationID = nLap.NotificationID
			WHERE mLap.SettlementLogID = mMsg.SettlementLogID
				AND nLap.NotificationType = 2 --2: Result Amendment to LAP
		) AS nL
	WHERE nMsg.LastModifiedTime > @FromModifiedTime
		AND nMsg.LastModifiedTime <= @ToModifiedTime
		AND nMsg.NotificationType = 1 --1: Result Amendment to Msg
		AND rh.SportType = 50 --Cricket, need modify for others sport
		AND nMsg.StatusID IN (13)--Sent only successful push to DBMSG
		AND nMsg.RefID IS NOT NULL
)
INSERT INTO #tmpLapNotiCheck (
	NotificationID
	,MatchID
)
SELECT NotificationID
	,MAX(MatchID) AS MatchID
FROM CTE_Noti
GROUP BY NotificationID
HAVING SUM(LapCnt) = 0

CREATE CLUSTERED INDEX CIX_tmpLapNotiCheck ON #tmpLapNotiCheck(NotificationID)

--validate again with Target
;WITH CTE_Valid AS (
	SELECT i.NotificationID
	FROM #tmpLapNotiCheck AS i
		INNER JOIN NotificationTarget AS nt WITH (NOLOCK) ON i.NotificationID = nt.NotificationID --must EXISTS Target
		INNER JOIN bodb02.dbo.Site AS s WITH (NOLOCK) ON nt.TargetSite = s.site AND s.isDeposit = 1 --deposit user
	GROUP BY i.NotificationID
)
DELETE t
FROM #tmpLapNotiCheck AS t
	LEFT JOIN CTE_Valid AS v ON t.NotificationID = v.NotificationID
WHERE v.NotificationID IS NULL

INSERT INTO #tmpNotiError_New (
	NotificationID
	,MatchID
	,Content
	,LastModifiedTime
)
SELECT n.NotificationID
	,ck.MatchID
	,''NOT EXISTS LAP Notification after being approved MessageID ['' + CONVERT(VARCHAR,n.RefID) + ''] for more than ''+ ISNULL(CONVERT(VARCHAR, @WaitSec),''NULL'')+'' seconds. Please double check [Generate LAP Notification] process.'' AS Content
	,n.LastModifiedTime
FROM Notification AS n WITH (NOLOCK)
	INNER JOIN #tmpLapNotiCheck AS ck ON n.NotificationID = ck.NotificationID
WHERE DATEDIFF(SECOND, n.LastModifiedTime,GETDATE()) > @WaitSec

-----------------------Make Sure NOT EXISTS IN Alert--------------------------------------------------
CREATE CLUSTERED INDEX CIX_tmpSettlError_New ON #tmpSettlError_New (SessionID)

INSERT INTO #tmpSettlError_Old (
	SessionID
	,SettlementLogID
	,LastModifiedTime
)
SELECT DISTINCT RefID AS SessionID
	,ext.SettlementLogID
	,ext.LastModifiedTime
FROM Alert AS a WITH (NOLOCK)
	INNER JOIN #tmpSettlError_New AS sn ON a.RefID = sn.SessionID
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
--Delete EXISTED
DELETE n
FROM #tmpSettlError_New AS n
	INNER JOIN #tmpSettlError_Old AS o ON n.SessionID = o.SessionID AND n.SettlementLogID = o.SettlementLogID AND n.LastModifiedTime = o.LastModifiedTime

---------------------------------
CREATE CLUSTERED INDEX CIX_tmpNotiError_New ON #tmpNotiError_New (NotificationID)

INSERT INTO #tmpNotiError_Old (
	NotificationID
	,LastModifiedTime
)
SELECT DISTINCT a.RefID AS NotificationID
	,ext.LastModifiedTime
FROM Alert AS a WITH (NOLOCK)
	INNER JOIN #tmpNotiError_New AS n ON a.RefID = CONVERT(NVARCHAR,n.NotificationID)
	OUTER APPLY OPENJSON(a.RefExtraInfo) WITH (
			RefInfo VARCHAR(50) ''$.RefInfo''
			,LastModifiedTime DATETIME ''$.LastModifiedTime''
		) AS ext --OPENJSON case-sensitive
WHERE a.RuleID = @RuleID
	AND ISJSON(a.RefExtraInfo) = 1
	AND ext.RefInfo = ''NotificationID''
	AND ext.LastModifiedTime IS NOT NULL
--Delete EXISTED
DELETE n
FROM #tmpNotiError_New AS n
	INNER JOIN #tmpNotiError_Old AS o ON n.NotificationID = o.NotificationID AND n.LastModifiedTime = o.LastModifiedTime

--build result
IF NOT EXISTS (SELECT 1 FROM #tmpSettlError_New)
	AND NOT EXISTS (SELECT 1 FROM #tmpNotiError_New )
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
					FROM #tmpSettlError_New AS t
					WHERE t.SessionID = s.SessionID
						AND t.Content = s.Content
					FOR JSON PATH)
				) AS RefExtraInfo
		FROM #tmpSettlError_New AS s
		GROUP BY s.SessionID
			,s.Content
	)
	,CTE_Noti AS (
		SELECT CONVERT(NVARCHAR,s.NotificationID) AS RefID
			,s.Content
			,CONVERT(NVARCHAR(MAX),(
					SELECT DISTINCT ''NotificationID'' AS RefInfo
						,t.MatchID
						,t.LastModifiedTime
					FROM #tmpNotiError_New AS t
					WHERE t.NotificationID = s.NotificationID
						AND t.Content = s.Content
					FOR JSON PATH)
				) AS RefExtraInfo
		FROM #tmpNotiError_New AS s
		GROUP BY s.NotificationID
			,s.Content
	)
	SELECT @JSAlertResult = CONVERT(NVARCHAR(MAX),(
				SELECT *
				FROM (
					SELECT RefID
						,RefExtraInfo
						,Content
					FROM CTE_Sett
					
					UNION ALL
					
					SELECT RefID
						,RefExtraInfo
						,Content
					FROM CTE_Noti
				) AS t
				FOR JSON PATH
			))
		,@LastScan = CONVERT(VARCHAR, @ToModifiedTime, 25)
END

DROP TABLE #tmpNotiError_New
DROP TABLE #tmpNotiError_Old
DROP TABLE #tmpSettlError_New
DROP TABLE #tmpSettlError_Old
DROP TABLE #tmpLapNotiCheck

--Return for Unit Testing
-- SELECT @LastScan AS [@LastScan]
	-- ,@JSAlertResult AS [@JSAlertResult]
'
----------------------------------
UPDATE MessageNotification.dbo.AlertRule
SET SQLStatement = @sqlStm
WHERE RuleID = @RuleID
