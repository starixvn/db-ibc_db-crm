/*<info serverAlias="DBCRM-MessageNotification" executers="wsv_lap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE Lrf_AdmTicketListSel
	@FEventDate DATE
	,@TEventDate DATE
	,@AgentList VARCHAR(MAX)
	,@NotiID INT = NULL
	,@LanguageCode VARCHAR(10) = 'en'
AS
/*
	Created: 20231213@Roy
	Task: Get all LAP Affected Tickets by NotificationID
	DB: DBCRM.MessageNotification
	Revisions:
		20231121@Roy: CRM - Implement Message Notifications Center for Result Amendment of Cricket(#197621)
		20240610@Luke: LAP - Enhance Result Amendment [Redmine: #199443]
	
	Param's Explanation:
		@AgentList: List agent need to view notification's ticket list or export excel
		@NotiID: NotificationID need to view ticket list [Notification.NotificationID]
		@FEventDate, @TEventDate: Date to get ticket list exported to excel
	
	Example:
		EXEC MessageNotification.dbo.Lrf_AdmTicketListSel
			@AgentList = '<ROOT><Agent AgentId="20121327"/><Agent AgentId="119277091"/></ROOT>'
			,@NotiID = 554
			,@FEventDate = '2024-06-01'
			,@TEventDate = '2024-06-11'
		
		EXEC MessageNotification.dbo.Lrf_AdmTicketListSel
			@AgentList = '<ROOT><Agent AgentId="20121327"/><Agent AgentId="119277091"/></ROOT>'
			,@FEventDate = '2024-06-01'
			,@TEventDate = '2024-06-11'
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @DocHandler INT

	CREATE TABLE #AgentIDs (AgentId INT)
	
	exec sp_xml_preparedocument @DocHandler OUTPUT, @AgentList

	INSERT INTO #AgentIDs (AgentId)
	SELECT Data.AgentId
	FROM OPENXML (@DocHandler, 'ROOT/Agent',1 ) WITH (AgentId INT) AS Data

	exec sp_xml_removedocument @DocHandler

	CREATE TABLE #tmpNoti (NotificationID INT)

	INSERT INTO #tmpNoti (NotificationID)

	SELECT DISTINCT n.NotificationID
	FROM dbo.Notification n WITH (NOLOCK)
		INNER JOIN dbo.NotificationExtra e WITH (NOLOCK) ON n.NotificationID = e.NotificationID
		INNER JOIN dbo.NotificationTarget t WITH (NOLOCK) ON e.NotificationID = t.NotificationID
		INNER JOIN #AgentIDs a ON a.AgentId = t.TargetID
	WHERE n.StatusID IN (SELECT StatusID FROM dbo.NotiStatus WITH (NOLOCK) WHERE Status = 'Active')
		AND n.NotificationType = 2
		AND e.EventDate BETWEEN @FEventDate AND @TEventDate
		AND e.NotificationID = CASE WHEN @NotiID IS NOT NULL THEN @NotiID
								ELSE e.NotificationID END

	CREATE TABLE #tmpAffectedTicket (
		NotiID INT
		,TransID BIGINT
		,Username NVARCHAR(50)
		,Username2 NVARCHAR(50)
	)

	CREATE TABLE #EventInfo (NotiID INT, EventName NVARCHAR(100), EventDate DATE)
	
	----------------------------------------------------------------	
	IF EXISTS (SELECT 1 FROM #tmpNoti)
	BEGIN
		INSERT INTO #tmpAffectedTicket (
			NotiID
			,TransID
			,Username
			,Username2
		)
		SELECT DISTINCT 
			nt.NotificationID AS NotiID
			,t.value AS TransID
			,c.Username
			,c.username2
		FROM dbo.NotificationTarget AS nt WITH (NOLOCK)
			OUTER APPLY OPENJSON(nt.ExtraInfo) WITH (
							CustID INT '$.CustID'
							,TransIDs VARCHAR(MAX) '$.TransIDs'
						) AS nc --OPENJSON case-sensitive
			OUTER APPLY STRING_SPLIT(nc.TransIDs, ',') AS t
			INNER JOIN bodb02.dbo.Customer AS c WITH (NOLOCK) ON nc.CustID = c.CustID
		WHERE nt.NotificationID IN (SELECT NotificationID FROM #tmpNoti)
			AND c.roleid = 1 --cust only
			AND TRY_CONVERT(BIGINT,t.value) IS NOT NULL
			AND ISJSON(nt.ExtraInfo) = 1
		OPTION (RECOMPILE)

		CREATE CLUSTERED INDEX CIX_tmpAffectedTicket ON #tmpAffectedTicket (Username)

		--Hometeam -vs- Awayteam - DD/MMM/YYYY
		INSERT INTO #EventInfo (NotiID, EventName, EventDate)
		SELECT LapEx.NotificationId
				,m.HomeNameEN + ISNULL(' ' + m.NeutralEN,'') + ' -vs- ' + m.AwayNameEN
					+ ' - '
					+ CONVERT(VARCHAR,LapEx.EventDate, 106) AS EventName--DD/MMM/YYYY
				,LapEx.EventDate
		FROM dbo.NotificationExtra AS LapEx WITH (NOLOCK)
			OUTER APPLY OPENJSON(LapEx.ExtraInfo) WITH (
							HomeNameEN NVARCHAR(500) '$.HomeNameEN'
							,AwayNameEN NVARCHAR(500) '$.AwayNameEN'
							,NeutralEN NVARCHAR(10) '$.NeutralEN'
						) AS m --OPENJSON case-sensitive
		WHERE LapEx.NotificationID IN (SELECT NotificationID FROM #tmpNoti)
			AND ISJSON(LapEx.ExtraInfo) = 1
		OPTION (RECOMPILE)
	END
	
	-----return----
	SELECT NotiId, EventName, EventDate
	FROM #EventInfo
	
	SELECT NotiID
		,TransID AS RefNo
		,STUFF(Username2, 1, CHARINDEX('$', Username2), '') AS ExternalID
		,Username AS SystemID
	FROM #tmpAffectedTicket
	ORDER BY NotiId
		,Username
		,TransID
	
	DROP TABLE #tmpAffectedTicket, #tmpNoti, #AgentIDs, #EventInfo
END
GO