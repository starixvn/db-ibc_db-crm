/*<info serverAlias="DBCRM-MessageNotification" isFunction="0" isNested="0"></info>*/
/*
Created by Roy.Du@20240510
Run at DBCRM@MessageNotification
Task: Update Rule#2
*/

USE [MessageNotification]
GO

DECLARE @sqlStm NVARCHAR(MAX)
DECLARE @RuleID INT = 2

SELECT @sqlStm =
'
/*
Created: Roy@20240327
Description: Alert rule for [review]

AlertRule properties
	RuleType: NewNoti
	Target: OST/777
	LastScan: compare with LastModifiedTime

Alert rule
	1.Any [New] Notification(s) of Msg or Lap

-----Steps of Rule-----
1.Define @LastScan
2.Exec Rule and insert into [Error_New] table with Key Columns
	- NotificationID
	- SessionID
	- LastModifiedTime
3.Remove EXISTED
	- Load [Error_Old] by @RuleID
	- Remove EXISTED from [Error_New] based on [Error_Old]
4.Return result
	- @JSAlertResult
		+ RefID: NotificationID
		+ RefExtraInfo
			[{
				"LastModifiedTime": "2024-05-08T05:29:15.880",
				"MatchID": 83531721,
				"RefInfo": "NotificationID",
				"SessionID": "e230ee02-fa38-42e9-ac76-8c27093a0f48"
			}]
		+ Content
	- @LastScan

--Output Param: 

		--Declaration for Unit Testing
		DECLARE @RuleID INT = 2
			,@LastScan VARCHAR(500)
			,@JSAlertResult NVARCHAR(MAX) = ''''

Revision:
	20240327@Roy: CRM - Implement Message Notifications Center for Result Amendment of Cricket(#197621)
*/

SET NOCOUNT ON
SELECT @JSAlertResult = ''''

DECLARE @StsNew TINYINT
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
	SELECT @FromModifiedTime = MIN(LastModifiedTime)
	FROM MessageNotification.dbo.Notification WITH (NOLOCK)
END

-- NOT EXISTS data in SettlementResultHist => ignore check
IF @FromModifiedTime IS NULL
	OR @FromModifiedTime >= @ToModifiedTime
	OR NOT EXISTS (SELECT 1 FROM MessageNotification.dbo.AlertRule WITH (NOLOCK) WHERE RuleID = @RuleID) --may no need, check @RuleID is null
BEGIN
	SELECT @JSAlertResult = ''''
		,@LastScan = ISNULL(@FromModifiedTime,DATEADD(ms,3,@ToModifiedTime)) --because condition [LastModifiedTime > @FromModifiedTime] => cover PointTime @ToModifiedTime
	
	RETURN
END

/******************************************Start to Check****************************************************/
CREATE TABLE #tmpNewNoti_New (
	NotificationID INT NOT NULL
	,SessionID VARCHAR(50) NOT NULL
	,LastModifiedTime DATETIME NOT NULL
	-----------
	,MatchID INT NOT NULL
	,Content NVARCHAR(4000)
)

CREATE TABLE #tmpNewNoti_Old (
	NotificationID INT
	,SessionID VARCHAR(50)
	,LastModifiedTime DATETIME
)

SELECT @StsNew = StatusID
FROM MessageNotification.dbo.NotiStatus WITH (NOLOCK)
WHERE Status = ''New''

/**************************************************************************************
	2.Exec Rule and insert into [Error_New] table with Key Columns
*/
INSERT INTO #tmpNewNoti_New (
	NotificationID
	,SessionID
	,LastModifiedTime
	-----------
	,MatchID
	,Content
)
SELECT DISTINCT n.NotificationID
	,rh.SessionID
	,n.LastModifiedTime
	,rh.MatchID
	,''Result Amendment message(s) for SessionID [''+ ISNULL(rh.SessionID,''NULL'') +''] created. Please review it.'' AS Content
FROM MessageNotification.dbo.Notification AS n WITH (NOLOCK)
	LEFT JOIN MessageNotification.dbo.NotiMapping AS nm WITH (NOLOCK) ON n.NotificationID = nm.NotificationID
	LEFT JOIN MessageNotification.dbo.SettlementResultHist AS rh WITH (NOLOCK) ON nm.SettlementLogID = rh.SettlementLogID
WHERE n.StatusID = @StsNew
	AND n.LastModifiedTime > @FromModifiedTime
	AND n.LastModifiedTime <= @ToModifiedTime
	AND n.NotificationType = 1 --Only for OST, LAP notified by Chatbot LIC

/**************************************************************************************
	3.Remove EXISTED
	
	Key to remove EXISTED
		- NotificationID
		- SessionID
		- LastModifiedTime

*/
CREATE CLUSTERED INDEX CIX_tmpNewNoti_New ON #tmpNewNoti_New (NotificationID)

INSERT INTO #tmpNewNoti_Old (
	NotificationID
	,SessionID
	,LastModifiedTime
)
SELECT DISTINCT RefID AS NotificationID
	,ext.SessionID
	,ext.LastModifiedTime
FROM MessageNotification.dbo.Alert AS a WITH (NOLOCK)
	INNER JOIN #tmpNewNoti_New AS sn ON a.RefID = CONVERT(NVARCHAR, sn.NotificationID)
	OUTER APPLY OPENJSON(a.RefExtraInfo) WITH (
			RefInfo VARCHAR(50) ''$.RefInfo''
			,SessionID VARCHAR(50) ''$.SessionID''
			,LastModifiedTime DATETIME ''$.LastModifiedTime''
		) AS ext --OPENJSON case-sensitive
WHERE a.RuleID = @RuleID
	AND ISJSON(a.RefExtraInfo) = 1
	AND ext.RefInfo = ''NotificationID''
	AND ext.SessionID IS NOT NULL
	AND ext.LastModifiedTime IS NOT NULL

DELETE n
FROM #tmpNewNoti_New AS n
	INNER JOIN #tmpNewNoti_Old AS o ON n.NotificationID = o.NotificationID AND n.SessionID = o.SessionID AND n.LastModifiedTime = o.LastModifiedTime

/**************************************************************************************
	4.Return result
*/
IF NOT EXISTS (SELECT 1 FROM #tmpNewNoti_New)
BEGIN
	SELECT @JSAlertResult = ''''
		,@LastScan = CONVERT(VARCHAR, @ToModifiedTime, 25)
END
ELSE
BEGIN
	;WITH CTE_Noti AS (
		SELECT CONVERT(NVARCHAR,s.NotificationID) AS RefID
			,s.Content
			,CONVERT(NVARCHAR(MAX),(
					SELECT DISTINCT ''NotificationID'' AS RefInfo
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
		,@LastScan = CONVERT(VARCHAR, @ToModifiedTime, 25)
END

DROP TABLE #tmpNewNoti_New
DROP TABLE #tmpNewNoti_Old

--Return for Unit Testing
-- SELECT @LastScan AS [@LastScan]
	-- ,@JSAlertResult AS [@JSAlertResult]
'
----------------------------------
UPDATE MessageNotification.dbo.AlertRule
SET SQLStatement = @sqlStm
WHERE RuleID = @RuleID
