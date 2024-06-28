/*<info serverAlias="DBCRM-MessageNotification" isFunction="0" isNested="0"></info>*/
/*
Created by Roy.Du@20240510
Run at DBCRM@MessageNotification
Task: Update Rule#1
*/

USE [MessageNotification]
GO

DECLARE @sqlStm NVARCHAR(MAX)
DECLARE @RuleID INT = 4

SELECT @sqlStm =
'
/*
Created: Roy@20240327
Description:
AlertRule properties
	RuleType: SysErr
	Target: OST / 777
	LastScan: compare with SettlementLogID

Alert rule
	1. Missing data from any SiteGroupDB

-----Steps of Rule-----
1.Define @LastScan
2.Exec Rule and insert into [Error_New] table with Key Columns
	- SessionID
3.Remove EXISTED
	- Load [Error_Old] by @RuleID
	- Remove EXISTED from [Error_New] based on [Error_Old]
4.Return result
	- @JSAlertResult
		+ RefID: SessionID
		+ RefExtraInfo
			[{
				"MatchID": 83531721,
				"RefInfo": "NotificationID",
			}]
		+ Content
	- @LastScan
	
--Output Param: 

		--Declaration for Unit Testing
		DECLARE @RuleID INT = 4
			,@LastScan VARCHAR(500)
			,@JSAlertResult NVARCHAR(MAX) = ''''

Revision:
	20240327@Roy: CRM - Implement Message Notifications Center for Result Amendment of Cricket(#197621)
*/
SET NOCOUNT ON
SELECT @JSAlertResult = ''''

DECLARE @FromSettlID INT
	,@ToSettlID INT
	,@SiteCnt INT = 0
	,@WaitSec INT = 0

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
)
SELECT @FromSettlID = MIN(FromSettlID)
FROM CTE_FromSettl

SELECT @ToSettlID = ISNULL((SELECT MAX(SettlementLogID) FROM MessageNotification.dbo.SettlementResultHist WITH (NOLOCK) WHERE SettlementLogID > @FromSettlID), @FromSettlID)

SELECT @WaitSec = ISNULL(TRY_CONVERT(INT, VValue),0) * 2
FROM MessageNotification.dbo.SystemSetting WITH (NOLOCK)
WHERE VID = 11 --Retrieving_WaitSec

SELECT @SiteCnt = COUNT(DISTINCT SiteDBGroupID)
FROM bodb02.dbo.SiteDBConfig WITH (NOLOCK)
WHERE SiteDBGroupID <> 0

CREATE TABLE #tmpSettlError_New (
	SessionID VARCHAR(50) NOT NULL
	,SiteCnt INT
	,Mi_InsertedTime DATETIME
	,DeleteReason TINYINT
)

CREATE TABLE #tmpSettlError_Old (
	SessionID VARCHAR(50)
)

/**************************************************************************************
	2.Exec Rule and insert into [Error_New] table with Key Columns
	
	Get SessionID info
	DeleteReason
		0: Error => Insert Alert
		1: Enough SiteDBs count => Ignore
		2: NOT enough SiteDBs count BUT Wait time < @WaitSec => Ignore
		3: Error BUT EXISTED IN Alert => Ignore
*/
;WITH CTE_SessionInfo AS (
	SELECT s.SessionID
		,COUNT(DISTINCT rh.SiteDBGroupID) AS SiteCnt
		,MIN(rh.InsertedTime) AS Mi_InsertedTime
	FROM MessageNotification.dbo.SettlementResultHist AS s WITH (NOLOCK) 
		INNER JOIN MessageNotification.dbo.SettlementResultHist AS rh WITH (NOLOCK) ON s.SessionID = rh.SessionID
	WHERE s.SettlementLogID > @FromSettlID
		AND s.SettlementLogID <= @ToSettlID
	GROUP BY s.SessionID
)
INSERT INTO #tmpSettlError_New (
	SessionID
	,SiteCnt
	,Mi_InsertedTime
	,DeleteReason
)
SELECT SessionID
	,SiteCnt
	,Mi_InsertedTime
	,(CASE WHEN SiteCnt = @SiteCnt THEN 1 --Enough SiteDBs count => Ignore
			WHEN DATEDIFF(SECOND, Mi_InsertedTime,GETDATE()) < @WaitSec THEN 2 --NOT enough SiteDBs count BUT Wait time < @WaitSec => Ignore
			ELSE 0
		END
	) AS DeleteReason
FROM CTE_SessionInfo

/**************************************************************************************
	3.Remove EXISTED
	
	Key to remove EXISTED
	- SessionID

*/
CREATE CLUSTERED INDEX CIX_tmpSettlError_New ON #tmpSettlError_New (SessionID)

/**************************************************************************************
	check EXISTS
*/
IF NOT EXISTS (SELECT 1 FROM MessageNotification.dbo.AlertRule WITH (NOLOCK) WHERE RuleID = @RuleID) --may no need, check @RuleID is null
BEGIN
	DROP TABLE IF EXISTS #tmpSettlError_New
	DROP TABLE IF EXISTS #tmpSettlError_Old
	
	SELECT @JSAlertResult = ''''
		,@LastScan = @FromSettlID

	RETURN
END
ELSE IF NOT EXISTS (SELECT 1 FROM #tmpSettlError_New)
BEGIN
	DROP TABLE IF EXISTS #tmpSettlError_New
	DROP TABLE IF EXISTS #tmpSettlError_Old
	
	SELECT @JSAlertResult = ''''
		,@LastScan = ISNULL(@ToSettlID,@FromSettlID) -- may change LastScan to @ToSettlID

	RETURN
END

INSERT INTO #tmpSettlError_Old ( SessionID )
SELECT DISTINCT a.RefID
FROM MessageNotification.dbo.Alert AS a WITH (NOLOCK)
	INNER JOIN #tmpSettlError_New AS sn ON a.RefID = sn.SessionID AND sn.DeleteReason = 0
	OUTER APPLY OPENJSON(a.RefExtraInfo) WITH (
			RefInfo VARCHAR(50) ''$.RefInfo''
		) AS ext --OPENJSON case-sensitive
WHERE a.RuleID = @RuleID
	AND ISJSON(a.RefExtraInfo) = 1
	AND ext.RefInfo = ''SessionID''

UPDATE n
SET n.DeleteReason = 3 --Error BUT EXISTED IN Alert => Ignore
FROM #tmpSettlError_New AS n
	INNER JOIN #tmpSettlError_Old AS o ON n.SessionID = o.SessionID
WHERE n.DeleteReason = 0

/**************************************************************************************
	4.Return result
*/
IF NOT EXISTS (SELECT 1 FROM #tmpSettlError_New WHERE DeleteReason NOT IN (1, 3)) --Make sure everything [Enough SiteDBs count] OR [Error Inserted Alert]
BEGIN
	SELECT @JSAlertResult = ''''
	
	SELECT @LastScan = ISNULL(@ToSettlID,@FromSettlID)
END
ELSE IF EXISTS (SELECT 1 FROM #tmpSettlError_New WHERE DeleteReason = 0)
BEGIN
	SELECT @JSAlertResult = CONVERT(NVARCHAR(MAX),(
				SELECT DISTINCT s.SessionID AS RefID
					,CONVERT(NVARCHAR(MAX),(
							SELECT ''SessionID'' AS RefInfo
								,(SELECT TOP 1 MatchID FROM MessageNotification.dbo.SettlementResultHist AS rh WITH (NOLOCK) WHERE s.SessionID = rh.SessionID) AS MatchID
							FOR JSON PATH)
						) AS RefExtraInfo
					,''SessionID ['' + s.SessionID + ''] NOT enough data from SiteDBs, exceeding ''+ ISNULL(CONVERT(VARCHAR, @WaitSec),''NULL'')+'' seconds. Please double check [Capture Data] process.'' AS Content
				FROM #tmpSettlError_New AS s
				WHERE DeleteReason = 0
				FOR JSON PATH
			))
	
	SELECT @LastScan = @FromSettlID -- re-scan in next schedule
END
ELSE IF EXISTS (SELECT 1 FROM #tmpSettlError_New WHERE DeleteReason = 2) --NOT enough Site count BUT [Wait time < @WaitSec] => check next schedule
BEGIN
	SELECT @JSAlertResult = ''''
	
	SELECT @LastScan = @FromSettlID -- re-scan in next schedule
END

DROP TABLE IF EXISTS #tmpSettlError_New
DROP TABLE IF EXISTS #tmpSettlError_Old


--Return for Unit Testing
-- SELECT @LastScan AS [@LastScan]
	-- ,@JSAlertResult AS [@JSAlertResult]
'
----------------------------------
UPDATE MessageNotification.dbo.AlertRule
SET SQLStatement = @sqlStm
WHERE RuleID = @RuleID
