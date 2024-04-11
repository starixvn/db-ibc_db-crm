
/*
Created: Roy@20240327
Description: Alert rule for [Running] status

--Output Param: 

		--Declaration for Unit Testing
		DECLARE @JSAlertResult NVARCHAR(MAX) = ''

Revision:
	20240327@Roy: CRM - Implement Message Notifications Center for Result Amendment of Cricket(#197621)
*/
SET NOCOUNT ON
SELECT @JSAlertResult = ''

CREATE TABLE #tmpResult (
	RefID INT
	,Content NVARCHAR(4000)
)

DECLARE @WaitSec INT = 0
	,@Sts TINYINT

---For [Retrieving] status---
SELECT @WaitSec = ISNULL(TRY_CONVERT(INT, VValue),0) * 2
FROM SystemSetting WITH (NOLOCK)
WHERE VID = 11 --Retrieving_WaitSec

SELECT @Sts = StatusID
FROM NotiStatus WITH (NOLOCK)
WHERE Status = 'Retrieving'

;WITH CTE_LongSession AS (
	SELECT DISTINCT SessionID
	FROM SettlementResultHist WITH (NOLOCK)
	WHERE StatusID = @Sts
	GROUP BY SessionID
	HAVING DATEDIFF(SECOND, LastModifiedTime,GETDATE()) > @WaitSec
)
INSERT INTO #tmpResult (
	RefID
	,Content
)
SELECT DISTINCT SettlementLogID
	,'EXISTS SettlementLogID in [Retrieving] state too long, exceeding '+ ISNULL(CONVERT(VARCHAR, @WaitSec),'NULL')+' seconds. Please double check [Capture Data] process.' AS Content
FROM SettlementResultHist AS rh WITH (NOLOCK)
	INNER JOIN CTE_LongSession AS l ON rh.SessionID = l.SessionID
WHERE rh.StatusID = @Sts

---For [Generating] status---
SELECT @WaitSec = 60
SELECT @Sts = StatusID
FROM NotiStatus WITH (NOLOCK)
WHERE Status = 'Generating'

;WITH CTE_LongSession AS (
	SELECT DISTINCT SessionID
	FROM SettlementResultHist WITH (NOLOCK)
	WHERE StatusID = @Sts
	GROUP BY SessionID
	HAVING DATEDIFF(SECOND, LastModifiedTime,GETDATE()) > @WaitSec
)
INSERT INTO #tmpResult (
	RefID
	,Content
)
SELECT DISTINCT SettlementLogID
	,'EXISTS SettlementLogID in [Generating] state too long, exceeding '+ ISNULL(CONVERT(VARCHAR, @WaitSec),'NULL')+' seconds. Please double check [Generate Notification] process.' AS Content
FROM SettlementResultHist AS rh WITH (NOLOCK)
	INNER JOIN CTE_LongSession AS l ON rh.SessionID = l.SessionID
WHERE rh.StatusID = @Sts

---For [Sending] status---
SELECT @WaitSec = 60
SELECT @Sts = StatusID
FROM NotiStatus WITH (NOLOCK)
WHERE Status = 'Sending'

INSERT INTO #tmpResult (
	RefID
	,Content
)
SELECT DISTINCT NotificationID
	,'EXISTS NotificationID in [Sending] state too long, exceeding '+ ISNULL(CONVERT(VARCHAR, @WaitSec),'NULL')+' seconds. Please double check [Push Notification] process.' AS Content
FROM Notification WITH (NOLOCK)
WHERE StatusID = @Sts
GROUP BY NotificationID
HAVING DATEDIFF(SECOND, LastModifiedTime,GETDATE()) > @WaitSec

---For [LAP message]---
SELECT @WaitSec = 60

INSERT INTO #tmpResult (
	RefID
	,Content
)
SELECT DISTINCT n.NotificationID
	,'NOT EXISTS LAP NotificationID after being approved for more than '+ ISNULL(CONVERT(VARCHAR, @WaitSec),'NULL')+' seconds. Please double check [Generate LAP Notification] process.' AS Content
FROM Notification AS n WITH (NOLOCK)
	INNER JOIN NotiMapping AS nm WITH (NOLOCK) ON n.NotificationID = nm.NotificationID
	INNER JOIN NotificationTarget AS nt WITH (NOLOCK) ON n.NotificationID = nt.NotificationID
	INNER JOIN bodb02.dbo.Dep_CustSuper AS d WITH (NOLOCK) ON nt.TargetID = d.CustID --deposit Super
	---LAP
	LEFT JOIN NotiMapping AS nmlap WITH (NOLOCK) ON nm.SettlementLogID = nmlap.SettlementLogID
	LEFT JOIN Notification AS nlap WITH (NOLOCK) ON nmlap.NotificationID = nlap.NotificationID AND nlap.NotificationType = 2
WHERE n.NotificationType = 1 --1: Result Amendment to Msg
	AND n.StatusID IN (
			9 --Ready to Send
			,12 --Sending
			,13 --Sent
			,14 --Failed to Send
		)--only need Status over the 'Ready to Send' step
	AND DATEDIFF(SECOND, n.LastModifiedTime,GETDATE()) > @WaitSec
	---LAP
	AND nlap.NotificationID IS NULL

--build result
IF NOT EXISTS (SELECT 1 FROM #tmpResult)
BEGIN
	SELECT @JSAlertResult = ''
END
ELSE
BEGIN
	;WITH CTE_ListRefID AS (
		SELECT STRING_AGG(CONVERT(VARCHAR(MAX),RefID),',') AS RefID
			,Content
		FROM #tmpResult
		GROUP BY Content
	)
	SELECT @JSAlertResult = CONVERT(NVARCHAR(MAX),(
				SELECT RefID
					,Content
				FROM CTE_ListRefID
				FOR JSON AUTO
			))
END

DROP TABLE #tmpResult

SELECT @JSAlertResult AS JSAlertResult

