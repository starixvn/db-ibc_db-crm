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
	
	EXEC sp_xml_preparedocument @DocHandler OUTPUT, @AgentList

	INSERT INTO #AgentIDs (AgentId)
	SELECT DISTINCT Data.AgentId
	FROM OPENXML (@DocHandler, 'ROOT/Agent',1 ) WITH (AgentId INT) AS Data
	
	CREATE UNIQUE CLUSTERED INDEX CIX_AgentIDs ON #AgentIDs (AgentId)
	
	EXEC sp_xml_removedocument @DocHandler

	CREATE TABLE #tmpNoti (NotificationID INT)

	INSERT INTO #tmpNoti (NotificationID)
	SELECT DISTINCT e.NotificationID
	FROM dbo.NotificationExtra AS e WITH (NOLOCK)
		INNER JOIN dbo.NotificationTarget AS t WITH (NOLOCK) ON e.NotificationID = t.NotificationID
		INNER JOIN dbo.Notification AS n WITH (NOLOCK) ON e.NotificationID = n.NotificationID
	WHERE e.EventDate BETWEEN @FEventDate AND @TEventDate
		AND (
			@NotiID IS NULL 
			OR e.NotificationID = @NotiID
		)
		AND EXISTS (
			SELECT 1
			FROM #AgentIDs AS a
			WHERE a.AgentId = t.TargetID
		)
		AND n.NotificationType = 2
		AND n.StatusID IN (
			SELECT st.StatusID
			FROM dbo.NotiStatus AS st WITH (NOLOCK)
			WHERE st.Status = 'Active'
		)
	OPTION (RECOMPILE)
	
	CREATE UNIQUE CLUSTERED INDEX CIX_tmpNoti ON #tmpNoti (NotificationID)

	CREATE TABLE #tmpAffectedTicket (
		NotiID INT
		,TransID BIGINT
		,CustID INT
		,Username NVARCHAR(50)
		,Username2 NVARCHAR(50)
	)

	CREATE TABLE #EventInfo (NotiID INT, EventName NVARCHAR(100), EventDate DATE)
	
	----------------------------------------------------------------	
	IF EXISTS (SELECT 1 FROM #tmpNoti)
	BEGIN
		INSERT INTO #tmpAffectedTicket (
			NotiID
			,CustID
			,TransID
		)
		SELECT DISTINCT 
			nt.NotificationID AS NotiID
			,nc.CustID
			,TRY_CONVERT(BIGINT,t.value) AS TransID
		FROM dbo.NotificationTarget AS nt WITH (NOLOCK)
			OUTER APPLY OPENJSON(nt.ExtraInfo) WITH (
							CustID INT '$.CustID'
							,TransIDs VARCHAR(MAX) '$.TransIDs'
						) AS nc --OPENJSON case-sensitive
			OUTER APPLY STRING_SPLIT(nc.TransIDs, ',') AS t
		WHERE nt.NotificationID IN (SELECT NotificationID FROM #tmpNoti)
			AND nt.TargetID IN (SELECT AgentId FROM #AgentIDs)
			AND ISJSON(nt.ExtraInfo) = 1
		OPTION (RECOMPILE)

		CREATE CLUSTERED INDEX CIX_tmpAffectedTicket ON #tmpAffectedTicket (CustID)
		
		--Get Username/Username2
		UPDATE af
		SET af.Username = c.Username
			,af.Username2 = c.Username2
		FROM #tmpAffectedTicket AS af
			INNER JOIN bodb02.dbo.Customer AS c WITH (NOLOCK) ON af.CustID = c.CustID AND c.roleid = 1 --cust only
		WHERE af.TransID IS NOT NULL

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
	WHERE Username IS NOT NULL
	ORDER BY NotiId
		,Username
		,TransID
	
	DROP TABLE #tmpAffectedTicket, #tmpNoti, #AgentIDs, #EventInfo
END
