/*<info serverAlias="DBCRM-MessageNotification" isFunction="0" isNested="0"></info>*/
/*
Created by Roy.Du@20240510
Run at DBCRM@MessageNotification
Task: Update Rule#1
*/

USE [MessageNotification]
GO

DECLARE @sqlStm NVARCHAR(MAX)
DECLARE @RuleID INT = 3

SELECT @sqlStm =
'
/*
Created: Roy@20240327
Description: Alert rule for [Insert DBMSG]

AlertRule properties
	RuleType: PushErr
	Target: OST/777
	Scan Range: LastModifiedTime BETWEEN DATEADD(DD, -1, GETDATE()) AND GETDATE()

Alert rule
	1.Any [Failed to Send] Notification(s)

-----Steps of Rule-----
1.Exec Rule and insert into [Error_New] table with Key Columns
	- NotificationID
	- SessionID
	- LastModifiedTime
2.Remove EXISTED
	- Load [Error_Old] by @RuleID
	- Remove EXISTED from [Error_New] based on [Error_Old]
3.Return result
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

--Output Param: 

		--Declaration for Unit Testing
		DECLARE @RuleID INT = 3
			,@JSAlertResult NVARCHAR(MAX) = ''''

Revision:
	20240327@Roy: CRM - Implement Message Notifications Center for Result Amendment of Cricket(#197621)
*/

SET NOCOUNT ON
SELECT @JSAlertResult = ''''

DECLARE @StsFailedSend TINYINT
	,@FromModifiedTime DATETIME = DATEADD(DD, -1, GETDATE())
	,@ToModifiedTime DATETIME = GETDATE()

CREATE TABLE #tmpFailedSendNoti_New (
	NotificationID INT NOT NULL
	,SessionID NVARCHAR(50) NOT NULL
	,LastModifiedTime DATETIME NOT NULL
	-----------
	,MatchID INT NOT NULL
	,Content NVARCHAR(4000)
)

CREATE TABLE #tmpFailedSendNoti_Old (
	NotificationID INT
	,SessionID NVARCHAR(50)
	,LastModifiedTime DATETIME
)

SELECT @StsFailedSend = StatusID
FROM MessageNotification.dbo.NotiStatus WITH (NOLOCK)
WHERE Status = ''Failed to Send''

/**************************************************************************************
	2.Exec Rule and insert into [Error_New] table with Key Columns
*/
INSERT INTO #tmpFailedSendNoti_New (
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
	,''Result Amendment message associated with SessionID [''+ ISNULL(rh.SessionID,''NULL'') +''] was NOT successfully inserted to DBMSG. Please review it.'' AS Content
FROM MessageNotification.dbo.Notification AS n WITH (NOLOCK)
	LEFT JOIN MessageNotification.dbo.NotiMapping AS nm WITH (NOLOCK) ON n.NotificationID = nm.NotificationID
	LEFT JOIN MessageNotification.dbo.SettlementResultHist AS rh WITH (NOLOCK) ON nm.SettlementLogID = rh.SettlementLogID
WHERE n.StatusID = @StsFailedSend
	AND n.NotificationType = 1
	AND n.LastModifiedTime > @FromModifiedTime
	AND n.LastModifiedTime <= @ToModifiedTime

/**************************************************************************************
	3.Remove EXISTED
	
	Key to remove EXISTED
	- NotificationID
	- SessionID
	- LastModifiedTime

*/
CREATE CLUSTERED INDEX CIX_tmpFailedSendNoti_New ON #tmpFailedSendNoti_New (NotificationID)

/**************************************************************************************
	check EXISTS
*/
IF NOT EXISTS (SELECT 1 FROM MessageNotification.dbo.AlertRule WITH (NOLOCK) WHERE RuleID = @RuleID) --may no need, check @RuleID is null
	OR NOT EXISTS (SELECT 1 FROM #tmpFailedSendNoti_New)
BEGIN
	DROP TABLE IF EXISTS #tmpFailedSendNoti_New
	DROP TABLE IF EXISTS #tmpFailedSendNoti_Old

	RETURN
END

INSERT INTO #tmpFailedSendNoti_Old (
	NotificationID
	,SessionID
	,LastModifiedTime
)
SELECT DISTINCT a.RefID AS NotificationID
	,ext.SessionID
	,ext.LastModifiedTime
FROM MessageNotification.dbo.Alert AS a WITH (NOLOCK)
	INNER JOIN #tmpFailedSendNoti_New AS sn ON a.RefID = TRY_CONVERT(NVARCHAR, sn.NotificationID)
	OUTER APPLY OPENJSON(a.RefExtraInfo) WITH (
			RefInfo VARCHAR(50) ''$.RefInfo''
			,SessionID NVARCHAR(50) ''$.SessionID''
			,LastModifiedTime DATETIME ''$.LastModifiedTime''
		) AS ext --OPENJSON case-sensitive
WHERE a.RuleID = @RuleID
	AND ISJSON(a.RefExtraInfo) = 1
	AND ext.RefInfo = ''NotificationID''
	AND ext.SessionID IS NOT NULL
	AND ext.LastModifiedTime IS NOT NULL

DELETE n
FROM #tmpFailedSendNoti_New AS n
	INNER JOIN #tmpFailedSendNoti_Old AS o ON n.NotificationID = o.NotificationID AND n.SessionID = o.SessionID AND n.LastModifiedTime = o.LastModifiedTime

/**************************************************************************************
	4.Return result
*/
IF EXISTS (SELECT 1 FROM #tmpFailedSendNoti_New)
BEGIN
	;WITH CTE_Noti AS (
		SELECT CONVERT(NVARCHAR,s.NotificationID) AS RefID
			,s.Content
			,CONVERT(NVARCHAR(MAX),(
					SELECT DISTINCT ''NotificationID'' AS RefInfo
						,t.MatchID
						,t.SessionID
						,t.LastModifiedTime
					FROM #tmpFailedSendNoti_New AS t
					WHERE t.NotificationID = s.NotificationID
						AND t.Content = s.Content
					FOR JSON PATH)
				) AS RefExtraInfo
		FROM #tmpFailedSendNoti_New AS s
		GROUP BY s.NotificationID
			,s.Content
	)
	SELECT @JSAlertResult = CONVERT(NVARCHAR(MAX),(
				SELECT *
				FROM CTE_Noti
				FOR JSON PATH
			))
END

DROP TABLE IF EXISTS #tmpFailedSendNoti_New
DROP TABLE IF EXISTS #tmpFailedSendNoti_Old

--Return for Unit Testing
-- SELECT @JSAlertResult AS [@JSAlertResult]
'
----------------------------------
UPDATE MessageNotification.dbo.AlertRule
SET SQLStatement = @sqlStm
WHERE RuleID = @RuleID
