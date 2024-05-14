
/*
Created: Roy@20240327
Description: Alert rule for [review]

AlertRule properties
	RuleType: NewNoti
	Target: OST/777
	LastScan: compare with LastModifiedTime

Alert rule
	1.Any [New] Notification(s) of Msg or Lap

Alert Output:
	RefID: NotificationID
	RefExtraInfo:
		- RefInfo = 'NotificationID'
		- SessionID
		- LastModifiedTime

--Output Param: 

		--Declaration for Unit Testing
		DECLARE @RuleID INT = 2
			,@LastScan VARCHAR(500)
			,@JSAlertResult NVARCHAR(MAX) = ''

Revision:
	20240327@Roy: CRM - Implement Message Notifications Center for Result Amendment of Cricket(#197621)
*/

SET NOCOUNT ON
SELECT @JSAlertResult = ''

DECLARE @StsNew TINYINT
	,@FromModifiedTime DATETIME
	,@ToModifiedTime DATETIME = GETDATE()

/*
	in this Rule, @LastScan IS LastModifiedTime
	
	Define @FromModifiedTime and @ToModifiedTime
*/
SELECT @FromModifiedTime = TRY_CONVERT(DATETIME,@LastScan)

IF @FromModifiedTime IS NULL
BEGIN
	SELECT @FromModifiedTime = MIN(LastModifiedTime)
	FROM Notification WITH (NOLOCK)
END

-- NOT EXISTS data in SettlementResultHist => ignore check
IF @FromModifiedTime IS NULL
	OR @FromModifiedTime >= @ToModifiedTime
	OR NOT EXISTS (SELECT 1 FROM AlertRule WITH (NOLOCK) WHERE RuleID = @RuleID) --may no need, check @RuleID is null
BEGIN
	SELECT @JSAlertResult = ''
		,@LastScan = ISNULL(@FromModifiedTime,DATEADD(ms,3,@ToModifiedTime)) --because condition [LastModifiedTime > @FromModifiedTime] => cover PointTime @ToModifiedTime
	
	RETURN
END

/******************************************Start to Check****************************************************/
CREATE TABLE #tmpNewNoti_New (
	NotificationID INT
	,MatchID INT
	,Content NVARCHAR(4000)
	,SessionID VARCHAR(50)
	,LastModifiedTime DATETIME
)

CREATE TABLE #tmpNewNoti_Old (
	NotificationID INT
	,SessionID VARCHAR(50)
	,LastModifiedTime DATETIME
)

SELECT @StsNew = StatusID
FROM NotiStatus WITH (NOLOCK)
WHERE Status = 'New'

INSERT INTO #tmpNewNoti_New (
	NotificationID
	,MatchID
	,SessionID
	,LastModifiedTime
	,Content
)
SELECT DISTINCT n.NotificationID
	,rh.MatchID
	,rh.SessionID
	,n.LastModifiedTime
	,CASE WHEN n.NotificationType = 2 THEN 'LAP ' ELSE '' END
		+ 'Result Amendment message(s) for SessionID ['+ ISNULL(rh.SessionID,'NULL') +'] created. Please review it.' AS Content
FROM Notification AS n WITH (NOLOCK)
	LEFT JOIN NotiMapping AS nm WITH (NOLOCK) ON n.NotificationID = nm.NotificationID
	LEFT JOIN SettlementResultHist AS rh WITH (NOLOCK) ON nm.SettlementLogID = rh.SettlementLogID
WHERE n.StatusID = @StsNew
	AND n.LastModifiedTime > @FromModifiedTime
	AND n.LastModifiedTime <= @ToModifiedTime

-----------------------Make Sure NOT EXISTS IN Alert--------------------------------------------------
CREATE CLUSTERED INDEX CIX_tmpNewNoti_New ON #tmpNewNoti_New (NotificationID)

INSERT INTO #tmpNewNoti_Old (
	NotificationID
	,SessionID
	,LastModifiedTime
)
SELECT DISTINCT RefID AS NotificationID
	,ext.SessionID
	,ext.LastModifiedTime
FROM Alert AS a WITH (NOLOCK)
	INNER JOIN #tmpNewNoti_New AS sn ON a.RefID = CONVERT(NVARCHAR, sn.NotificationID)
	OUTER APPLY OPENJSON(a.RefExtraInfo) WITH (
			RefInfo VARCHAR(50) '$.RefInfo'
			,SessionID VARCHAR(50) '$.SessionID'
			,LastModifiedTime DATETIME '$.LastModifiedTime'
		) AS ext --OPENJSON case-sensitive
WHERE a.RuleID = @RuleID
	AND ISJSON(a.RefExtraInfo) = 1
	AND ext.RefInfo = 'NotificationID'
	AND ext.SessionID IS NOT NULL
	AND ext.LastModifiedTime IS NOT NULL
--Delete EXISTED
DELETE n
FROM #tmpNewNoti_New AS n
	INNER JOIN #tmpNewNoti_Old AS o ON n.NotificationID = o.NotificationID AND n.SessionID = o.SessionID AND n.LastModifiedTime = o.LastModifiedTime

--build result
IF NOT EXISTS (SELECT 1 FROM #tmpNewNoti_New)
BEGIN
	SELECT @JSAlertResult = ''
		,@LastScan = @ToModifiedTime
END
ELSE
BEGIN
	;WITH CTE_Noti AS (
		SELECT CONVERT(NVARCHAR,s.NotificationID) AS RefID
			,s.Content
			,CONVERT(NVARCHAR(MAX),(
					SELECT DISTINCT 'NotificationID' AS RefInfo
						,t.MatchID
						,t.SessionID
						,t.LastModifiedTime
					FROM #tmpNewNoti_New AS t
					WHERE t.NotificationID = s.NotificationID
						AND t.Content = s.Content
					FOR JSON PATH)
				) AS RefExtraInfo
		FROM #tmpNewNoti_New AS s
		GROUP BY s.NotificationID
			,s.Content
	)
	SELECT @JSAlertResult = CONVERT(NVARCHAR(MAX),(
				SELECT *
				FROM CTE_Noti
				FOR JSON PATH
			))
		,@LastScan = @ToModifiedTime
END

DROP TABLE #tmpNewNoti_New
DROP TABLE #tmpNewNoti_Old

--Return for Unit Testing
-- SELECT @LastScan AS [@LastScan]
	-- ,@JSAlertResult AS [@JSAlertResult]