
/*
Created: Roy@20240327
Description: Alert rule for [OST review]

--Output Param: 

		--Declaration for Unit Testing
		DECLARE @JSAlertResult NVARCHAR(MAX) = ''

Revision:
	20240327@Roy: CRM - Implement Message Notifications Center for Result Amendment of Cricket(#197621)
*/
SET NOCOUNT ON
SELECT @JSAlertResult = ''

DECLARE @StsNew TINYINT

SELECT @StsNew = StatusID
FROM NotiStatus WITH (NOLOCK)
WHERE Status = 'New'

;WITH CTE_ListRefID AS (
	SELECT 'Result Amendment message(s) for SessionID ['+ ISNULL(rh.SessionID,'NULL') +'] (MatchID = '+ ISNULL(CONVERT(VARCHAR,rh.MatchID),'NULL') +') created. Please review it.' AS Content
		,STRING_AGG(CONVERT(VARCHAR(MAX),n.NotificationID),',') AS RefID
	FROM Notification AS n WITH (NOLOCK)
		INNER JOIN NotificationTarget AS nt WITH (NOLOCK) ON n.NotificationID = nt.NotificationID
		INNER JOIN NotiMapping AS nm WITH (NOLOCK) ON n.NotificationID = nm.NotificationID
		INNER JOIN SettlementResultHist AS rh WITH (NOLOCK) ON nm.SettlementLogID = rh.SettlementLogID
	WHERE n.StatusID = @StsNew
		AND n.NotificationType = 1
		AND nt.TargetSite = '777777'
	GROUP BY rh.SessionID
		,rh.MatchID
	ORDER BY rh.SessionID
		,rh.MatchID
)
SELECT @JSAlertResult = CONVERT(NVARCHAR(MAX),(
			SELECT RefID
				,Content
			FROM CTE_ListRefID
			FOR JSON AUTO
		))

SELECT @JSAlertResult AS JSAlertResult

