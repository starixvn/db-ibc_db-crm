/*<info serverAlias="DBCRM-MessageNotification" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE MNC_Notification_AdmSelNoti
	@FCreatedDate DATETIME = NULL
	,@TCreatedDate DATETIME = NULL
	,@NotiType TINYINT
	,@FNotiID INT = NULL
	,@TNotiID INT = NULL
	,@MatchID INT = NULL
	,@MsgID INT = NULL
	,@Content NVARCHAR(MAX) = NULL
	,@Status VARCHAR(MAX) = NULL
	,@Sender VARCHAR(50) = NULL
	,@IncludeTest BIT = NULL
AS
/*
	Created: 20231213@Roy
	Task: Get all Notifications by filter criteria
	DB: DBCRM.MessageNotification
	Revisions:
		20231121@Roy: CRM - Implement Message Notifications Center for Result Amendment of Cricket(#197621)
	
	Param's Explanation:
		@FCreatedDate, @TCreatedDate: created date of notifications - Default Yesterday and Today
		@NotiType: 1 - Amendment to Msg; 2 - Amendment to LAP
		@FNotiID, @TNotiID: disable others filter (EXCEPT @NotiType) IF these value NOT NULL
		@MatchID: matchid of amended event
		@MsgID: Msg.MessageID
		@Content:
		@StatusIDs: list of Status
					OST: New, Sent, Failed, Cancelled, Draft, Sending
					Licensee CSD: New, Active, Inactive
		@Sender: who confirm to push notification to Msg (NotificationExtra.ExtraInfo.MsgSender)
								OR Active LAP Noti (NotificationExtra.ExtraInfo.LapSender)
		@IncludeTest: NotificationExtra.ExtraInfo.IsTest
	
	Example:
		EXEC MessageNotification.dbo.MNC_Notification_AdmSelNoti
			@FNotiID = 1
			,@NotiType = 1
*/
BEGIN
	SET NOCOUNT ON
	
	CREATE TABLE #tmpNoti (
		NotiID INT
	)
	
	CREATE TABLE #tmpNotiExt (
		NotiID INT
		,MsgID INT
		,MatchID INT
		,EventDate DATE
		,EventName NVARCHAR(500)
		,IsTest BIT
		,Sender VARCHAR(50)
		,SendDate DATETIME
	)
	
	CREATE TABLE #tmpAffectedSite (
		NotiID INT
		,SiteType VARCHAR(50)
		,SiteGroup VARCHAR(50)
		,SiteNames NVARCHAR(MAX)
	)
	
	CREATE TABLE #tmpStsByNotiType (
		NotiType TINYINT
		,StatusID TINYINT
	)
	
	--hard code status based on NotiType - check consistency MNC_Notification_AdmUpdNotiSts
	INSERT INTO #tmpStsByNotiType (
		NotiType
		,StatusID
	)
	SELECT 1 AS NotiType--Msg
		,s.StatusID
	FROM STRING_SPLIT('New,Draft,Cancelled,Sending,Sent,Failed to Send', ',') AS m
		INNER JOIN dbo.NotiStatus AS s WITH (NOLOCK) ON m.value = s.Status
	
	UNION ALL
	
	SELECT 2 AS NotiType--LAP
		,s.StatusID
	FROM STRING_SPLIT('New,Active,Inactive', ',') AS l
		INNER JOIN dbo.NotiStatus AS s WITH (NOLOCK) ON l.value = s.Status
	/*****************************************   APPLY filter criterias   *********************************************************/
	
	--Get Notifications by @FNotiID, @TNotiID, @NotiType
	IF @NotiType IN (1,2)
		AND (@FNotiID IS NOT NULL OR @TNotiID IS NOT NULL)
	BEGIN
		--correct if any NULL
		SELECT @FNotiID = ISNULL(@FNotiID,@TNotiID)
			,@TNotiID = ISNULL(@TNotiID,@FNotiID)
		
		INSERT INTO #tmpNoti (NotiID)
		SELECT DISTINCT n.NotificationID
		FROM dbo.Notification AS n WITH (NOLOCK)
			INNER JOIN #tmpStsByNotiType AS s ON n.NotificationType = s.NotiType AND n.StatusID = s.StatusID
		WHERE n.NotificationID BETWEEN @FNotiID AND @TNotiID
			AND n.NotificationType = @NotiType
		OPTION (RECOMPILE)
	END
	ELSE IF @NotiType IN (1,2) --get by @FCreatedDate, @TCreatedDate, @NotiType
	BEGIN
		INSERT INTO #tmpNoti (NotiID)
		SELECT n.NotificationID
		FROM dbo.Notification AS n WITH (NOLOCK)
			INNER JOIN #tmpStsByNotiType AS s ON n.NotificationType = s.NotiType AND n.StatusID = s.StatusID
		WHERE n.InsertedTime BETWEEN DATEADD(HH, -12, @FCreatedDate) AND DATEADD(HH, -12, @TCreatedDate) --convert to GMT-4
			AND n.NotificationType = @NotiType
		OPTION (RECOMPILE)
	END
	
	CREATE UNIQUE CLUSTERED INDEX CIX_tmpNoti ON #tmpNoti (NotiID)
	
	-----------For LAP Notification, ONLY show if MsgNotiID push successful(Sent)-----------
	IF @NotiType = 2
	BEGIN
		DELETE i
		FROM #tmpNoti AS i
		WHERE NOT EXISTS (
			SELECT 1
			FROM dbo.NotificationExtra AS ne WITH (NOLOCK)
				CROSS APPLY OPENJSON(ne.ExtraInfo) WITH (
								MsgNotiID INT '$.MsgNotiID'
							) AS ext --OPENJSON case-sensitive
				INNER JOIN dbo.Notification AS msgn WITH (NOLOCK) ON ext.MsgNotiID = msgn.NotificationID
				INNER JOIN dbo.NotiStatus AS s WITH (NOLOCK) ON msgn.StatusID = s.StatusID
			WHERE ne.NotificationID = i.NotiID
				AND s.Status = 'Sent' --push successful
		)
		
		---Get data from NotificationExtra
		INSERT INTO #tmpNotiExt (
			NotiID
			,MsgID
			,MatchID
			,EventDate
			,EventName
			,IsTest
			,Sender
			,SendDate
		)
		SELECT i.NotiID
			,nMsg.RefID
			,extMsg.MatchID
			,neMsg.EventDate
			,extMsg.HomeNameEN + ISNULL(' ' + extMsg.NeutralEN,'') + ' -vs- ' + extMsg.AwayNameEN AS EventName
			,extMsg.IsTest
			,extLap.LapSender
			,extLap.LapSendDate
		FROM #tmpNoti AS i
			INNER JOIN dbo.NotificationExtra AS neLap WITH (NOLOCK) ON i.NotiID = neLap.NotificationID
			CROSS APPLY OPENJSON(neLap.ExtraInfo) WITH (
							MsgNotiID INT '$.MsgNotiID'
							,LapSender VARCHAR(50) '$.LapSender'
							,LapSendDate DATETIME '$.LapSendDate'
						) AS extLap --OPENJSON case-sensitive
			INNER JOIN dbo.Notification AS nMsg WITH (NOLOCK) ON extLap.MsgNotiID = nMsg.NotificationID
			INNER JOIN dbo.NotificationExtra AS neMsg WITH (NOLOCK) ON extLap.MsgNotiID = neMsg.NotificationID
			CROSS APPLY OPENJSON(neMsg.ExtraInfo) WITH (
							MatchID INT '$.MatchID'
							,IsTest BIT '$.IsTest'
							,HomeNameEN NVARCHAR(500) '$.HomeNameEN'
							,NeutralEN NVARCHAR(10) '$.NeutralEN'
							,AwayNameEN NVARCHAR(500) '$.AwayNameEN'
						) AS extMsg --OPENJSON case-sensitive
	END
	ELSE --Msg Notification
	BEGIN
		INSERT INTO #tmpNotiExt (
			NotiID
			,MsgID
			,MatchID
			,EventDate
			,EventName
			,IsTest
			,Sender
			,SendDate
		)
		SELECT i.NotiID
			,n.RefID
			,ext.MatchID
			,ne.EventDate
			,ext.HomeNameEN + ISNULL(' ' + ext.NeutralEN,'') + ' -vs- ' + ext.AwayNameEN AS EventName
			,ext.IsTest
			,ext.MsgSender
			,ext.MsgSendDate
		FROM #tmpNoti AS i
			INNER JOIN dbo.Notification AS n WITH (NOLOCK) ON i.NotiID = n.NotificationID
			INNER JOIN dbo.NotificationExtra AS ne WITH (NOLOCK) ON i.NotiID = ne.NotificationID
			CROSS APPLY OPENJSON(ne.ExtraInfo) WITH (
							MatchID INT '$.MatchID'
							,IsTest BIT '$.IsTest'
							,MsgSender VARCHAR(50) '$.MsgSender'
							,MsgSendDate DATETIME '$.MsgSendDate'
							,HomeNameEN NVARCHAR(500) '$.HomeNameEN'
							,NeutralEN NVARCHAR(10) '$.NeutralEN'
							,AwayNameEN NVARCHAR(500) '$.AwayNameEN'
						) AS ext --OPENJSON case-sensitive
	END
	
	CREATE UNIQUE CLUSTERED INDEX CIX_tmpNotiExt ON #tmpNotiExt (NotiID)
	
	--apply filter ONLY IF input NotiID NULL
	IF @FNotiID IS NULL
	BEGIN
		--filter by @MsgID
		IF @MsgID IS NOT NULL
		BEGIN
			DELETE i
			FROM #tmpNoti AS i
			WHERE NOT EXISTS (
				SELECT 1
				FROM dbo.Notification AS n WITH (NOLOCK)
				WHERE n.NotificationID = i.NotiID
					AND n.RefID = @MsgID
			)
			
			UPDATE STATISTICS #tmpNoti
		END
		
		--filter by @Status
		IF ISNULL(TRIM(@Status),'') <> ''
		BEGIN
			DELETE i
			FROM #tmpNoti AS i
				INNER JOIN dbo.Notification AS n WITH (NOLOCK) ON i.NotiID = n.NotificationID
			WHERE n.StatusID NOT IN (
				SELECT s.StatusID
				FROM STRING_SPLIT(@Status, ',') AS i
					INNER JOIN dbo.NotiStatus AS s WITH (NOLOCK) ON (CASE WHEN i.value = 'Failed' THEN 'Failed to Send' ELSE i.value END) = s.Status
			)
			
			UPDATE STATISTICS #tmpNoti
		END
		
		--filter by @Content
		IF ISNULL(TRIM(@Content),'') <> ''
		BEGIN
			DELETE i
			FROM #tmpNoti AS i
			WHERE NOT EXISTS (
				SELECT 1
				FROM dbo.Notification AS n WITH (NOLOCK)
				WHERE n.NotificationID = i.NotiID
					AND (
						n.Content_en LIKE '%' + TRIM(@Content) + '%'
						OR n.Content_ch LIKE '%' + TRIM(@Content) + '%'
						OR n.Content_cs LIKE '%' + TRIM(@Content) + '%'
					)
			)
			
			UPDATE STATISTICS #tmpNoti
		END
	
		--filter by @MatchID
		IF @MatchID IS NOT NULL
			OR @IncludeTest IS NOT NULL
			OR ISNULL(TRIM(@Sender),'') <> ''
		BEGIN
			DELETE i
			FROM #tmpNoti AS i
			WHERE NOT EXISTS (
				SELECT 1
				FROM #tmpNotiExt AS ext
				WHERE ext.NotiID = i.NotiID
					AND ext.MatchID = @MatchID
			)
			
			UPDATE STATISTICS #tmpNoti
		END
		
		--filter by @IncludeTest
		IF @IncludeTest IS NOT NULL
		BEGIN
			DELETE i
			FROM #tmpNoti AS i
			WHERE NOT EXISTS (
				SELECT 1
				FROM #tmpNotiExt AS ext
				WHERE ext.NotiID = i.NotiID
					AND ext.IsTest IN (0, @IncludeTest)
			)
			
			UPDATE STATISTICS #tmpNoti
		END
		
		--filter by @Sender
		IF ISNULL(TRIM(@Sender),'') <> ''
		BEGIN
			DELETE i
			FROM #tmpNoti AS i
			WHERE NOT EXISTS (
				SELECT 1
				FROM #tmpNotiExt AS ext
				WHERE ext.NotiID = i.NotiID
					AND ext.Sender = @Sender
			)
			
			UPDATE STATISTICS #tmpNoti
		END
	END
	
	/*****************************************   Prepare for return   *********************************************************/
	;WITH CTE_Site AS (
		SELECT DISTINCT i.NotiID
			,CASE WHEN s.isDeposit = 1 THEN 'Licensee' ELSE 'Credit' END AS SiteType
			,CASE WHEN s.isDeposit = 1 THEN --Licensee
				(CASE WHEN s.IsChinaView = 1 THEN 'CV licensees'
					WHEN s.SpecialPlatfrom > 0 THEN 'JS licensees'
					ELSE 'Normal licensees' END
				)
				ELSE ISNULL(s.SiteLabel,'Others') --Credit
				END AS SiteGroup
			,nt.TargetSite
		FROM #tmpNoti AS i
			INNER JOIN dbo.NotificationTarget AS nt WITH (NOLOCK) ON i.NotiID = nt.NotificationID
			LEFT JOIN bodb02.dbo.Site AS s WITH (NOLOCK) ON nt.TargetSite = s.site
	)
	INSERT INTO #tmpAffectedSite (
		NotiID
		,SiteType
		,SiteGroup
		,SiteNames
	)
	SELECT NotiID
		,SiteType
		,SiteGroup
		,STRING_AGG(CONVERT(NVARCHAR(MAX),TargetSite),', ') WITHIN GROUP (ORDER BY TargetSite) AS SiteNames
	FROM CTE_Site
	GROUP BY NotiID
		,SiteType
		,SiteGroup
	
	-----------------------------------------Return-------------------------------------------
	
	----------All Notification----------
	IF @NotiType = 1 --Msg
	BEGIN
		SELECT DISTINCT n.NotificationID
			,ext.MsgID AS MessageID
			,rh.SessionID
			,FORMAT(ext.EventDate, 'MMM dd, yyyy') AS EventDate --GMT-4
			,ext.EventName
			,FORMAT(DATEADD(HH, 12, n.InsertedTime), 'MMM dd, yyyy hh:mm:ss tt') AS CreatedTime --GMT+8
			,n.Subject AS Subject
			,n.Content_en
			,n.Content_ch
			,n.Content_cs
			,s.Status
			,ext.Sender
			,FORMAT(DATEADD(HH, 12, ext.SendDate), 'MMM dd, yyyy hh:mm:ss tt') AS SendDate --GMT+8
		FROM #tmpNoti AS i
			INNER JOIN #tmpNotiExt AS ext ON i.NotiID = ext.NotiID
			INNER JOIN dbo.Notification AS n WITH (NOLOCK) ON i.NotiID = n.NotificationID
			INNER JOIN dbo.NotiStatus AS s WITH (NOLOCK) ON n.StatusID = s.StatusID
			INNER JOIN dbo.NotiMapping AS nm WITH (NOLOCK) ON i.NotiID = nm.NotificationID
			INNER JOIN dbo.SettlementResultHist AS rh WITH (NOLOCK) ON nm.SettlementLogID = rh.SettlementLogID
		ORDER BY n.NotificationID DESC
	END
	ELSE --LAP
	BEGIN
		SELECT DISTINCT n.NotificationID
			,ext.MsgID AS MessageID
			,rh.SessionID
			,FORMAT(ext.EventDate, 'MMM dd, yyyy') AS EventDate --GMT-4
			,ext.EventName
			,FORMAT(DATEADD(HH, 12, n.InsertedTime), 'MMM dd, yyyy hh:mm:ss tt') AS CreatedTime --GMT+8
			,CASE WHEN si.SiteGroup <> 'Normal licensees' THEN 'Result Amendment for Cricket - Special licensees' ELSE 'Result Amendment for Cricket - Normal licensees' END AS Subject
			,nex.Subject_en + '</b><br/><br/>' + n.Content_en AS Content_en
			,nex.Subject_ch + '</b><br/><br/>' + n.Content_ch AS Content_ch
			,nex.Subject_cs + '</b><br/><br/>' + n.Content_cs AS Content_cs
			,s.Status
			,ext.Sender
			,FORMAT(DATEADD(HH, 12, ext.SendDate), 'MMM dd, yyyy hh:mm:ss tt') AS SendDate --GMT+8
		FROM #tmpNoti AS i
			INNER JOIN #tmpNotiExt AS ext ON i.NotiID = ext.NotiID
			INNER JOIN #tmpAffectedSite AS si ON i.NotiID = si.NotiID
			INNER JOIN dbo.Notification AS n WITH (NOLOCK) ON i.NotiID = n.NotificationID
			CROSS APPLY OPENJSON(n.Subject) WITH (
							Subject_en NVARCHAR(300) '$.Subject_en'
							,Subject_ch NVARCHAR(300) '$.Subject_ch'
							,Subject_cs NVARCHAR(300) '$.Subject_cs'
						) AS nex --OPENJSON case-sensitive
			INNER JOIN dbo.NotiStatus AS s WITH (NOLOCK) ON n.StatusID = s.StatusID
			INNER JOIN dbo.NotiMapping AS nm WITH (NOLOCK) ON i.NotiID = nm.NotificationID
			INNER JOIN dbo.SettlementResultHist AS rh WITH (NOLOCK) ON nm.SettlementLogID = rh.SettlementLogID
		ORDER BY n.NotificationID DESC
	END
	
	----------Site by NotificationID----------
	SELECT NotiID AS NotificationID
		,SiteType
		,SiteGroup
		,SiteNames
	FROM #tmpAffectedSite
	ORDER BY NotiID
	
	DROP TABLE #tmpNoti
	DROP TABLE #tmpNotiExt
	DROP TABLE #tmpStsByNotiType
	DROP TABLE #tmpAffectedSite
END