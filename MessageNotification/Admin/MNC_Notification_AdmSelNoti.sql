/*<info serverAlias="DBCRM-MessageNotification" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE MNC_Notification_AdmSelNoti
	@FCreatedDateGMT8 DATE = NULL
	,@TCreatedDateGMT8 DATE = NULL
	,@NotiType TINYINT
	,@FNotiID INT = NULL
	,@TNotiID INT = NULL
	,@MatchID INT = NULL
	,@MsgID INT = NULL
	,@Content NVARCHAR(MAX) = NULL
	,@Status VARCHAR(MAX) = NULL
	,@Sender VARCHAR(50) = NULL
	,@IncludeTest BIT = NULL
	---permission control---
	,@UserRole TINYINT = 2
	,@LicenseeType INT = 0
	,@SitePermission NVARCHAR(MAX) = NULL
	---paging---
	,@PageSize INT = 100
	,@PageIndex INT = 1
	,@TotalRows INT = 0 OUTPUT
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
		@PageSize ,@PageIndex ,@TotalRows: handle paging
		
		-------------permission control-------------
		@UserRole = 0: Manager
					1: CN88 staff
					2: Company staff
        @LicenseeType = -1: None
						0: Both
						1: Credit
						2: Licensee
        @SitePermission: Value depend on user's permission and maybe NULL
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
		,SportName NVARCHAR(500)
		,IsTest BIT
		,Sender VARCHAR(50)
		,SendDate DATETIME
		,Subject NVARCHAR(MAX)
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
	
	CREATE TABLE #tmpResult (
		RNo INT IDENTITY(1, 1) PRIMARY KEY
		,NotificationID INT
		,MessageID INT
		,SessionID VARCHAR(50)
		,EventDate4GMT VARCHAR(50)
		,EventName NVARCHAR(500)
		,CreatedTimeGMT8 VARCHAR(50)
		,Subject NVARCHAR(1000)
		,Content_en NVARCHAR(4000)
		,Content_ch NVARCHAR(4000)
		,Content_cs NVARCHAR(4000)
		,Status VARCHAR(50)
		,Sender VARCHAR(50)
		,SendDateGMT8 VARCHAR(50)
	)
	
	CREATE TABLE #tmpValidSite (
		SiteName NVARCHAR(100)
		,isDeposit BIT
	)
	
	/*
		Convert permission control to Sites
	*/
	---- @UserRole - CN88 ---------
	;WITH CTE_UserRole AS (
		SELECT sc.SettingValue AS SiteCategory
		FROM bodb_CRM.dbo.crmSetting AS sc WITH (NOLOCK)
		WHERE sc.SettingName = 'SiteCategory'
			AND ((@UserRole = 1 AND sc.SettingID = 33002) OR (@UserRole = 2 AND ISNULL(sc.SettingID,0) <> 33002))
			AND ISNULL(sc.SiteOffer, @UserRole) = @UserRole
	)
	INSERT INTO #tmpValidSite (
		SiteName
		,isDeposit
	)
	SELECT DISTINCT si.SettingValue AS SiteName
		,(CASE WHEN sc.SettingID = 33000 THEN 1 --Licensee
			WHEN sc.SettingID = 33001 THEN 0 --Credit
			-- ELSE -1 END --Unknown
			END) AS isDeposit
	FROM bodb_CRM.dbo.crmSetting AS sc WITH (NOLOCK)
		INNER JOIN bodb_CRM.dbo.crmSettingRelation AS sr WITH (NOLOCK) ON sr.ParentID = sc.SettingID
		INNER JOIN bodb_CRM.dbo.crmSetting AS si WITH (NOLOCK) ON si.SettingName = 'Site' AND sr.SettingID = si.SettingID
	WHERE sc.SettingName = 'SiteCategory'
		AND sc.SettingValue IN (
			SELECT SiteCategory FROM CTE_UserRole
		)
	
	---- Filter by Licensee ---------
	;WITH CTE_Licensee AS (
		SELECT sc.SettingValue AS SiteCategory
		FROM bodb_CRM.dbo.crmSetting AS sc WITH (NOLOCK)
		WHERE sc.SettingName = 'SiteCategory'
			AND sc.SettingID = 33000 --Licensee
			AND (
				@LicenseeType = 0
				OR (@LicenseeType = 2 AND ISNULL(TRIM(@SitePermission),'') = '')
			)
	)
	,CTE_CRMLic AS (
		SELECT DISTINCT si.SettingValue AS SiteName
		FROM bodb_CRM.dbo.crmSetting AS sc WITH (NOLOCK)
			INNER JOIN bodb_CRM.dbo.crmSettingRelation AS sr WITH (NOLOCK) ON sr.ParentID = sc.SettingID
			INNER JOIN bodb_CRM.dbo.crmSetting AS si WITH (NOLOCK) ON si.SettingName = 'Site' AND sr.SettingID = si.SettingID
		WHERE sc.SettingName = 'SiteCategory'
			AND sc.SettingValue IN (
				SELECT SiteCategory FROM CTE_Licensee
			)
	)
	DELETE v
	FROM #tmpValidSite AS v
		LEFT JOIN CTE_CRMLic AS lic ON v.SiteName = lic.SiteName
	WHERE v.isDeposit = 1
		AND lic.SiteName IS NULL
		AND @LicenseeType IN (0,2)
	
	---- Credit ---------
	;WITH CTE_Credit AS (
		SELECT sc.SettingValue AS SitePermission
		FROM bodb_CRM.dbo.crmSetting AS sc WITH (NOLOCK)
			LEFT JOIN STRING_SPLIT(@SitePermission, ',') AS sp ON sc.SettingValue = sp.value
		WHERE sc.SettingName = 'SitePermission'
			AND (
				@LicenseeType = 0
				OR (@LicenseeType = 1 AND sp.value IS NOT NULL)
			)
	)
	,CTE_CRMCredit AS (
		SELECT DISTINCT si.SettingValue AS SiteName
		FROM bodb_CRM.dbo.crmSetting AS sc WITH (NOLOCK)
			INNER JOIN bodb_CRM.dbo.crmSettingRelation AS sr WITH (NOLOCK) ON sr.ParentID = sc.SettingID
			INNER JOIN bodb_CRM.dbo.crmSetting AS si WITH (NOLOCK) ON si.SettingName = 'Site' AND sr.SettingID = si.SettingID
		WHERE sc.SettingName = 'SitePermission'
			AND sc.SettingValue IN (
				SELECT SitePermission FROM CTE_Credit
			)
	)
	DELETE v
	FROM #tmpValidSite AS v
		LEFT JOIN CTE_CRMCredit AS cre ON v.SiteName = cre.SiteName
	WHERE v.isDeposit = 0
		AND cre.SiteName IS NULL
		AND @LicenseeType IN (0,1)
	
	CREATE CLUSTERED INDEX CIX_tmpValidSite ON #tmpValidSite (SiteName)
	
	-----------------------------------------------------------------
	DECLARE @FCreatedTime4GMT DATETIME
		,@TCreatedTime4GMT DATETIME
	/*
		Ex: @FCreatedDateGMT8 = 2024-01-02 => meaning [2024-01-02 00:00:00]
			@TCreatedDateGMT8 = 2024-01-03 => meaning [2024-01-03 23:59:59]
			
		After convert GMT-4
			@FCreatedTime4GMT = 2024-01-01 12:00:00
			@TCreatedTime4GMT
				= 2024-01-03 11:59:59 for compare [<=]
				= 2024-01-03 12:00:00 for compare [<]
	*/
	SELECT @FCreatedTime4GMT = DATEADD(HH, -12, CONVERT(DATETIME, @FCreatedDateGMT8))
		,@TCreatedTime4GMT = DATEADD(HH, -12, CONVERT(DATETIME, DATEADD(DD, 1, @TCreatedDateGMT8))) --for compare [<]
	
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
			--filter by User Permission
			INNER JOIN dbo.NotificationTarget AS nt WITH (NOLOCK) ON n.NotificationType = nt.NotificationID
			INNER JOIN #tmpValidSite AS vs ON nt.TargetSite = vs.SiteName
		WHERE n.NotificationID BETWEEN @FNotiID AND @TNotiID
			AND n.NotificationType = @NotiType
		OPTION (RECOMPILE)
	
	END
	ELSE IF @NotiType IN (1,2) --get by @FCreatedDate, @TCreatedDate, @NotiType
	BEGIN
		INSERT INTO #tmpNoti (NotiID)
		SELECT DISTINCT n.NotificationID
		FROM dbo.Notification AS n WITH (NOLOCK)
			INNER JOIN #tmpStsByNotiType AS s ON n.NotificationType = s.NotiType AND n.StatusID = s.StatusID
			--filter by User Permission
			INNER JOIN dbo.NotificationTarget AS nt WITH (NOLOCK) ON n.NotificationType = nt.NotificationID
			INNER JOIN #tmpValidSite AS vs ON nt.TargetSite = vs.SiteName
		WHERE n.InsertedTime >= @FCreatedTime4GMT
			AND n.InsertedTime < @TCreatedTime4GMT
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
				OUTER APPLY OPENJSON(ne.ExtraInfo) WITH (
								MsgNotiID INT '$.MsgNotiID'
							) AS ext --OPENJSON case-sensitive
				INNER JOIN dbo.Notification AS msgn WITH (NOLOCK) ON ext.MsgNotiID = msgn.NotificationID
				INNER JOIN dbo.NotiStatus AS s WITH (NOLOCK) ON msgn.StatusID = s.StatusID
			WHERE ne.NotificationID = i.NotiID
				AND s.Status = 'Sent' --push successful
				AND ISJSON(ne.ExtraInfo) = 1
		)
		
		---Get data from LAP NotificationExtra
		INSERT INTO #tmpNotiExt (
			NotiID
			,MsgID
			,MatchID
			,EventDate
			,EventName
			,SportName
			,IsTest
			,Sender
			,SendDate
			,Subject
		)
		SELECT DISTINCT i.NotiID
			,nMsg.RefID
			,extMsg.MatchID
			,neMsg.EventDate
			,extMsg.HomeNameEN + ISNULL(' ' + extMsg.NeutralEN,'') + ' -vs- ' + extMsg.AwayNameEN AS EventName
			,extMsg.SportNameEN
			,extMsg.IsTest
			,extLap.LapSender
			,extLap.LapSendDate
			,neLap.ExtraInfo AS Subject
		FROM #tmpNoti AS i
			INNER JOIN dbo.NotificationExtra AS neLap WITH (NOLOCK) ON i.NotiID = neLap.NotificationID
			OUTER APPLY OPENJSON(neLap.ExtraInfo) WITH (
							MsgNotiID INT '$.MsgNotiID'
							,LapSender VARCHAR(50) '$.LapSender'
							,LapSendDate DATETIME '$.LapSendDate'
						) AS extLap --OPENJSON case-sensitive
			INNER JOIN dbo.Notification AS nMsg WITH (NOLOCK) ON extLap.MsgNotiID = nMsg.NotificationID
			INNER JOIN dbo.NotificationExtra AS neMsg WITH (NOLOCK) ON extLap.MsgNotiID = neMsg.NotificationID
			OUTER APPLY OPENJSON(neMsg.ExtraInfo) WITH (
							MatchID INT '$.MatchID'
							,IsTest BIT '$.IsTest'
							,HomeNameEN NVARCHAR(500) '$.HomeNameEN'
							,NeutralEN NVARCHAR(10) '$.NeutralEN'
							,AwayNameEN NVARCHAR(500) '$.AwayNameEN'
							,SportNameEN NVARCHAR(500) '$.SportNameEN'
						) AS extMsg --OPENJSON case-sensitive
		WHERE ISJSON(neLap.ExtraInfo) = 1
			AND ISJSON(neMsg.ExtraInfo) = 1
	END
	ELSE --Msg Notification
	BEGIN
		INSERT INTO #tmpNotiExt (
			NotiID
			,MsgID
			,MatchID
			,EventDate
			,EventName
			,SportName
			,IsTest
			,Sender
			,SendDate
		)
		SELECT DISTINCT i.NotiID
			,n.RefID
			,ext.MatchID
			,ne.EventDate
			,ext.HomeNameEN + ISNULL(' ' + ext.NeutralEN,'') + ' -vs- ' + ext.AwayNameEN AS EventName
			,ext.SportNameEN
			,ext.IsTest
			,ext.MsgSender
			,ext.MsgSendDate
		FROM #tmpNoti AS i
			INNER JOIN dbo.Notification AS n WITH (NOLOCK) ON i.NotiID = n.NotificationID
			INNER JOIN dbo.NotificationExtra AS ne WITH (NOLOCK) ON i.NotiID = ne.NotificationID
			OUTER APPLY OPENJSON(ne.ExtraInfo) WITH (
							MatchID INT '$.MatchID'
							,IsTest BIT '$.IsTest'
							,MsgSender VARCHAR(50) '$.MsgSender'
							,MsgSendDate DATETIME '$.MsgSendDate'
							,HomeNameEN NVARCHAR(500) '$.HomeNameEN'
							,NeutralEN NVARCHAR(10) '$.NeutralEN'
							,AwayNameEN NVARCHAR(500) '$.AwayNameEN'
							,SportNameEN NVARCHAR(500) '$.SportNameEN'
						) AS ext --OPENJSON case-sensitive
		WHERE ISJSON(ne.ExtraInfo) = 1
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
			INNER JOIN #tmpValidSite AS vs ON nt.TargetSite = vs.SiteName
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
		,STRING_AGG(CONVERT(NVARCHAR(MAX),TargetSite),', ') WITHIN GROUP (ORDER BY TargetSite) AS SiteNames --Rule 1 - SiteName sort by alphabetical
	FROM CTE_Site
	GROUP BY NotiID
		,SiteType
		,SiteGroup
	
	----------Notification----------
	IF @NotiType = 1 --Msg
	BEGIN
		INSERT INTO #tmpResult (
			NotificationID
			,MessageID
			,SessionID
			,EventDate4GMT
			,EventName
			,CreatedTimeGMT8
			,Subject
			,Content_en
			,Content_ch
			,Content_cs
			,Status
			,Sender
			,SendDateGMT8
		)
		SELECT DISTINCT n.NotificationID
			,ext.MsgID AS MessageID
			,rh.SessionID
			,FORMAT(ext.EventDate, 'MMM dd, yyyy') AS EventDate --GMT-4
			,ext.EventName
			,FORMAT(DATEADD(HH, 12, n.InsertedTime), 'MMM dd, yyyy hh:mm:ss tt') AS CreatedTime --GMT+8
			,n.Subject
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
		INSERT INTO #tmpResult (
			NotificationID
			,MessageID
			,SessionID
			,EventDate4GMT
			,EventName
			,CreatedTimeGMT8
			,Subject
			,Content_en
			,Content_ch
			,Content_cs
			,Status
			,Sender
			,SendDateGMT8
		)
		SELECT DISTINCT n.NotificationID
			,ext.MsgID AS MessageID
			,rh.SessionID
			,FORMAT(ext.EventDate, 'MMM dd, yyyy') AS EventDate --GMT-4
			,ext.EventName
			,FORMAT(DATEADD(HH, 12, n.InsertedTime), 'MMM dd, yyyy hh:mm:ss tt') AS CreatedTime --GMT+8
			,'Result Amendment for' + ISNULL(' ' + ext.SportName, 'NULL') AS Subject
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
			OUTER APPLY OPENJSON(ext.Subject) WITH (
							Subject_en NVARCHAR(300) '$.Subject_en'
							,Subject_ch NVARCHAR(300) '$.Subject_ch'
							,Subject_cs NVARCHAR(300) '$.Subject_cs'
						) AS nex --OPENJSON case-sensitive
			INNER JOIN dbo.NotiStatus AS s WITH (NOLOCK) ON n.StatusID = s.StatusID
			INNER JOIN dbo.NotiMapping AS nm WITH (NOLOCK) ON i.NotiID = nm.NotificationID
			INNER JOIN dbo.SettlementResultHist AS rh WITH (NOLOCK) ON nm.SettlementLogID = rh.SettlementLogID
		WHERE ISJSON(ext.Subject) = 1
		ORDER BY n.NotificationID DESC
	END
	
	-----------------------------------------Return-------------------------------------------
	----------Paging----------
	DECLARE @RStart INT = @PageSize * (@PageIndex - 1) + 1
	DECLARE @REnd INT = @RStart + @PageSize - 1
	
	SELECT @TotalRows = ISNULL((SELECT MAX(RNo) FROM #tmpResult), 0)
	
	--get all row if invalid Paging params
	IF NOT EXISTS (SELECT 1 WHERE @RStart <= @REnd)
	BEGIN
		
		SELECT @RStart = 0
			,@REnd = @TotalRows
	END
	----------NotificationIDs----------
	SELECT NotificationID
		,MessageID
		,SessionID
		,EventDate4GMT AS EventDate
		,EventName
		,CreatedTimeGMT8 AS CreatedTime
		,Subject
		,Content_en
		,Content_ch
		,Content_cs
		,Status
		,Sender
		,SendDateGMT8 AS SendDate
	FROM #tmpResult
	WHERE RNo BETWEEN @RStart AND @REnd
	ORDER BY RNo
	
	----------Site by NotificationID----------
	;WITH CTE_OrdRule AS (
		SELECT DISTINCT s.SiteGroup
			/*
				Rule 2 - SiteType: hardcode
					1.Credit
					2.Licensee
			*/
			,(CASE WHEN s.SiteType = 'Credit' THEN 1 ELSE 2 END) AS Ord2
			/*
				Rule 3 - Licensee: hardcode
					1.Normal licensees
					2.JS licensees
					3.CV licensees
			*/
			,(CASE WHEN s.SiteType = 'Licensee' AND s.SiteGroup = 'CV licensees' THEN 3
					WHEN s.SiteType = 'Licensee' AND s.SiteGroup = 'JS licensees' THEN 2
					WHEN s.SiteType = 'Licensee' THEN 1 --Normal licensees
			END) AS Ord3
			/*
				Rule 4 - Credit: Sort by alphabetical
			*/
			,SiteGroup AS Ord4
		FROM #tmpAffectedSite AS s
	)
	,CTE_SiteGroupOrder AS (
		SELECT DISTINCT SiteGroup
			,ROW_NUMBER() OVER ( ORDER BY Ord2, Ord3, Ord4 ) AS SiteGroupOrd
		FROM CTE_OrdRule
	)
	SELECT s.NotiID AS NotificationID
		,s.SiteType
		,s.SiteGroup
		,sgo.SiteGroupOrd
		,s.SiteNames
	FROM #tmpAffectedSite AS s
		LEFT JOIN CTE_SiteGroupOrder AS sgo ON s.SiteGroup = sgo.SiteGroup
	WHERE s.NotiID IN (
		SELECT NotificationID
		FROM #tmpResult
		WHERE RNo BETWEEN @RStart AND @REnd
	)
	ORDER BY s.NotiID
		,sgo.SiteGroupOrd
	
	DROP TABLE #tmpNoti
	DROP TABLE #tmpNotiExt
	DROP TABLE #tmpStsByNotiType
	DROP TABLE #tmpAffectedSite
	DROP TABLE #tmpValidSite
	DROP TABLE #tmpResult
END
