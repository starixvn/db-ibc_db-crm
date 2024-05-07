/*<info serverAlias="DBCRM-MessageNotification" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE MNC_LAP_AdmSelNotiTickets
	@NotiID INT
	,@LanguageCode VARCHAR(10) = 'en'
AS
/*
	Created: 20231213@Roy
	Task: Get all LAP Affected Tickets by NotificationID
	DB: DBCRM.MessageNotification
	Revisions:
		20231121@Roy: CRM - Implement Message Notifications Center for Result Amendment of Cricket(#197621)
	
	Param's Explanation:
		@NotiID: Notification.NotificationID
	
	Example:
		EXEC MessageNotification.dbo.MNC_Notification_AdmSelNotiTickets
			@NotiID = 1
*/
BEGIN
	SET NOCOUNT ON
	
	CREATE TABLE #tmpAffectedTicket (
		TransID BIGINT
		,Username NVARCHAR(50)
		,Username2 NVARCHAR(50)
	)
	
	----------------------------------------------------------------	
	IF EXISTS (
		SELECT 1
		FROM Notification WITH (NOLOCK)
		WHERE NotificationID = @NotiID
			AND NotificationType = 2 --Lap
	)
	BEGIN
		INSERT INTO #tmpAffectedTicket (
			TransID
			,Username
			,Username2
		)
		SELECT DISTINCT t.value AS TransID
			,c.Username
			,c.username2
		FROM dbo.NotificationTarget AS nt WITH (NOLOCK)
			OUTER APPLY OPENJSON(nt.ExtraInfo) WITH (
							CustID INT '$.CustID'
							,TransIDs VARCHAR(MAX) '$.TransIDs'
						) AS nc --OPENJSON case-sensitive
			OUTER APPLY STRING_SPLIT(nc.TransIDs, ',') AS t
			INNER JOIN bodb02.dbo.Customer AS c WITH (NOLOCK) ON nc.CustID = c.CustID
		WHERE nt.NotificationID = @NotiID
			AND c.roleid = 1 --cust only
			AND TRY_CONVERT(BIGINT,t.value) IS NOT NULL
			AND ISJSON(nt.ExtraInfo) = 1
		OPTION (RECOMPILE)
	END
	
	CREATE CLUSTERED INDEX CIX_tmpAffectedTicket ON #tmpAffectedTicket (Username)
	
	DECLARE @EventName NVARCHAR(100)
	--Hometeam -vs- Awayteam - MM/DD/YYYY
	SELECT @EventName = (
			CASE WHEN @LanguageCode = 'en' THEN m.HomeNameEN + ISNULL(' ' + m.NeutralEN,'') + ' -vs- ' + m.AwayNameEN
			ELSE m.HomeNameCS + ISNULL(' ' + m.NeutralCS,'') + ' -vs- ' + m.AwayNameCS
		END)
		+ ' - '
		+ CONVERT(VARCHAR,LapEx.EventDate, 101) --MM/DD/YYYY
	FROM dbo.NotificationExtra AS LapEx WITH (NOLOCK)
		OUTER APPLY OPENJSON(LapEx.ExtraInfo) WITH (
						MsgNotiID INT '$.MsgNotiID'
					) AS Lap --OPENJSON case-sensitive
		INNER JOIN dbo.NotificationExtra AS MsgEx WITH (NOLOCK) ON Lap.MsgNotiID = MsgEx.NotificationID
		OUTER APPLY OPENJSON(MsgEx.ExtraInfo) WITH (
						HomeNameEN NVARCHAR(500) '$.HomeNameEN'
						,HomeNameCS NVARCHAR(500) '$.HomeNameCS'
						,AwayNameEN NVARCHAR(500) '$.AwayNameEN'
						,AwayNameCS NVARCHAR(500) '$.AwayNameCS'
						,NeutralEN NVARCHAR(10) '$.NeutralEN'
						,NeutralCS NVARCHAR(10) '$.NeutralCS'
					) AS m --OPENJSON case-sensitive
	WHERE LapEx.NotificationID = @NotiID
		AND ISJSON(LapEx.ExtraInfo) = 1
		AND ISJSON(MsgEx.ExtraInfo) = 1
	OPTION (RECOMPILE)
	
	-----return----
	SELECT @EventName AS EventName
	
	SELECT TransID AS RefNo
		,Username2 AS ExternalID
		,Username AS SystemID
	FROM #tmpAffectedTicket
	ORDER BY Username
		,TransID
	
	DROP TABLE #tmpAffectedTicket
END