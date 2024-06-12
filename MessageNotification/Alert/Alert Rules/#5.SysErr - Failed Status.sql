
/*
Created: Roy@20240327
Description: Alert rule for [Insert DBMSG]

AlertRule properties
	RuleType: PushErr
	Target: IT Group
	Scan Range: LastModifiedTime BETWEEN DATEADD(DD, -1, GETDATE()) AND GETDATE()

Alert rule
	1.Any [Failed] Status

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
		DECLARE @RuleID INT = 5
			,@LastScan VARCHAR(500)
			,@JSAlertResult NVARCHAR(MAX) = ''

Revision:
	20240327@Roy: CRM - Implement Message Notifications Center for Result Amendment of Cricket(#197621)
*/

DECLARE @FromSettlID INT
	,@ToSettlID INT

/**************************************************************************************
	1.Define @LastScan
	
	in this Rule, @LastScan IS SettlementLogID
	
	Define @FromSettlID and @ToSettlID
*/
;WITH CTE_FromSettl AS (
	SELECT ISNULL(TRY_CONVERT(INT,@LastScan),0) AS FromSettlID
	
	UNION ALL
	
	SELECT MIN(SettlementLogID) AS FromSettlID
	FROM MessageNotification.dbo.SettlementResultHist WITH (NOLOCK)
	WHERE LastModifiedTime > DATEADD(DD, -1, GETDATE())
		AND LastModifiedTime <= GETDATE()
		AND IsTest = 0
)
SELECT @FromSettlID = MIN(FromSettlID)
FROM CTE_FromSettl

SELECT @ToSettlID = ISNULL((SELECT MAX(SettlementLogID) FROM MessageNotification.dbo.SettlementResultHist WITH (NOLOCK) WHERE SettlementLogID > @FromSettlID), @FromSettlID)

CREATE TABLE #tmpFailed_New (
	SessionID NVARCHAR(50) NOT NULL
	,SettlementLogID INT NOT NULL
	,LastModifiedTime DATETIME NOT NULL
	------------------
	,MatchID INT NOT NULL
	,DeleteReason TINYINT
	,Content NVARCHAR(4000)
)

CREATE TABLE #tmpFailed_Old (
	SessionID NVARCHAR(50)
	,SettlementLogID INT
	,LastModifiedTime DATETIME
)

/**************************************************************************************
	2.Exec Rule and insert into [Error_New] table with Key Columns
*/
---1.For [Capture Data] process, [Failed to Retrieve]---
-- SELECT @StsFailed = StatusID
-- FROM MessageNotification.dbo.NotiStatus WITH (NOLOCK)
-- WHERE Status = 'Failed to Retrieve'

---2.For [Generate Msg Notification] process, [Failed to Generate]---
-- SELECT @StsFailed = StatusID
-- FROM MessageNotification.dbo.NotiStatus WITH (NOLOCK)
-- WHERE Status = 'Failed to Generate'

INSERT INTO #tmpFailed_New (
	SessionID
	,SettlementLogID
	,LastModifiedTime
	------------------
	,MatchID
	,Content
)
SELECT DISTINCT rh.SessionID
	,rh.SettlementLogID
	,rh.LastModifiedTime
	,rh.MatchID
	,'Result Amendment message associated with SessionID ['+ ISNULL(rh.SessionID,'NULL') +'] was NOT successfully '
		+ (CASE WHEN st.Status = 'Failed to Retrieve' THEN 'RETRIEVED' ELSE 'GENERATED' END)
		+ '. Please review it.' AS Content
FROM MessageNotification.dbo.SettlementResultHist AS rh WITH (NOLOCK)
	LEFT JOIN MessageNotification.dbo.NotiStatus AS st WITH (NOLOCK) ON rh.StatusID = st.StatusID
WHERE rh.SettlementLogID > @FromSettlID
	AND rh.SettlementLogID <= @ToSettlID
	AND rh.IsTest = 0
	AND st.Status IN ('Failed to Retrieve','Failed to Generate')

/**************************************************************************************
	3.Remove EXISTED
	
	Key to remove EXISTED
	- NotificationID
	- SessionID
	- LastModifiedTime

*/
CREATE CLUSTERED INDEX CIX_tmpFailed_New ON #tmpFailed_New (SessionID)

/**************************************************************************************
	check EXISTS
*/
IF NOT EXISTS (SELECT 1 FROM MessageNotification.dbo.AlertRule WITH (NOLOCK) WHERE RuleID = @RuleID) --may no need, check @RuleID is null
BEGIN
	DROP TABLE IF EXISTS #tmpFailed_New
	DROP TABLE IF EXISTS #tmpFailed_Old
	
	SELECT @JSAlertResult = ''
		,@LastScan = @FromSettlID

	RETURN
END
ELSE IF NOT EXISTS (SELECT 1 FROM #tmpFailed_New)
BEGIN
	DROP TABLE IF EXISTS #tmpFailed_New
	DROP TABLE IF EXISTS #tmpFailed_Old
	
	SELECT @JSAlertResult = ''
		,@LastScan = ISNULL(@ToSettlID,@FromSettlID) -- may change LastScan to @ToSettlID

	RETURN
END

INSERT INTO #tmpFailed_Old (
	SessionID
	,SettlementLogID
	,LastModifiedTime
)
SELECT DISTINCT a.RefID AS SessionID
	,ext.SettlementLogID
	,ext.LastModifiedTime
FROM MessageNotification.dbo.Alert AS a WITH (NOLOCK)
	INNER JOIN #tmpFailed_New AS sn ON a.RefID = sn.SessionID
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

UPDATE n
SET n.DeleteReason = (CASE WHEN o.SettlementLogID IS NOT NULL THEN 1 ELSE 0 END)
FROM #tmpFailed_New AS n
	LEFT JOIN #tmpFailed_Old AS o
		ON n.SettlementLogID = o.SettlementLogID
			AND n.SessionID = o.SessionID
			AND n.LastModifiedTime = o.LastModifiedTime

/**************************************************************************************
	4.Return result
*/
IF EXISTS (SELECT 1 FROM #tmpFailed_New WHERE DeleteReason = 0)
BEGIN
	;WITH CTE_Sett AS (
		SELECT s.SessionID AS RefID
			,s.Content
			,CONVERT(NVARCHAR(MAX),(
					SELECT DISTINCT 'SessionID' AS RefInfo
						,t.SettlementLogID
						,t.MatchID
						,t.LastModifiedTime
					FROM #tmpFailed_New AS t
					WHERE t.SessionID = s.SessionID
						AND t.Content = s.Content
						AND t.DeleteReason = 0
					FOR JSON PATH)
				) AS RefExtraInfo
		FROM #tmpFailed_New AS s
		WHERE DeleteReason = 0
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
	
	SELECT @LastScan = @FromSettlID -- re-scan in next schedule
END
ELSE
BEGIN
	SELECT @JSAlertResult = ''
	
	SELECT @LastScan = ISNULL(@ToSettlID,@FromSettlID)
END

DROP TABLE IF EXISTS #tmpFailed_New
DROP TABLE IF EXISTS #tmpFailed_Old

--Return for Unit Testing
-- SELECT @JSAlertResult AS [@JSAlertResult]