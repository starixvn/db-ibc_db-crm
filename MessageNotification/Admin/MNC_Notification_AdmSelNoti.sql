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
		,TemplateName NVARCHAR(1000)
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
		,RealStatus VARCHAR(50)
		,ViewStatus VARCHAR(50)
	)
	
	CREATE TABLE #tmpResult (
		RNo INT IDENTITY(1, 1) PRIMARY KEY
		,NotificationID INT
		,MessageID INT
		,SessionID VARCHAR(50)
		,EventDate4GMT VARCHAR(50)
		,EventName NVARCHAR(500)
		,CreatedTimeGMT8 VARCHAR(50)
		,TemplateName NVARCHAR(1000)
		,Content_en NVARCHAR(4000)
		,Content_ch NVARCHAR(4000)
		,Content_cs NVARCHAR(4000)
		,Status VARCHAR(50)
		,Sender VARCHAR(50)
		,SendDateGMT8 VARCHAR(50)
	)
	
	CREATE TABLE #tmpValidSite (
		SiteName NVARCHAR(100)
		,IsDeposit BIT
		,SiteLabel VARCHAR(50)
	)
	
	/*
		Convert permission control to Sites
	*/
	---- Filter by Credit ---------
	/* Currently, The SitePermission applied only for Credit */
	;WITH CTE_Permission AS (
		SELECT sc.SettingValue AS SitePermission
		FROM bodb_CRM.dbo.crmSetting AS sc WITH (NOLOCK)
			LEFT JOIN STRING_SPLIT(@SitePermission, ',') AS sp ON sc.SettingValue = sp.value
		WHERE sc.SettingName = 'SitePermission'
			AND @LicenseeType IN (0, 1)
			AND ( ISNULL(TRIM(@SitePermission),'') = ''
				OR (ISNULL(TRIM(@SitePermission),'') <> '' AND sp.value IS NOT NULL)
			)
	)
	,CTE_SiteByPermission AS (
		SELECT DISTINCT si.SettingValue AS SiteName
			,si.ExtraInfo AS SiteLabel
		FROM bodb_CRM.dbo.crmSetting AS sc WITH (NOLOCK)
			INNER JOIN bodb_CRM.dbo.crmSettingRelation AS sr WITH (NOLOCK) ON sr.ParentID = sc.SettingID
			INNER JOIN bodb_CRM.dbo.crmSetting AS si WITH (NOLOCK) ON si.SettingName = 'Site' AND sr.SettingID = si.SettingID
		WHERE sc.SettingName = 'SitePermission'
			AND sc.SettingValue IN (
				SELECT SitePermission FROM CTE_Permission
			)
	)
	,CTE_CRMCredit AS (
		SELECT si.SettingValue AS SiteName
			,si.ExtraInfo AS SiteLabel
		FROM bodb_CRM.dbo.crmSettingRelation sr WITH (NOLOCK)
		INNER JOIN bodb_CRM.dbo.crmSetting sc WITH (NOLOCK) ON sc.SettingName = 'SiteCategory' AND sr.ParentID = sc.SettingID
		INNER JOIN bodb_CRM.dbo.crmSetting si WITH (NOLOCK) ON si.SettingName = 'Site' AND sr.SettingID = si.SettingID
		WHERE sr.ParentID = 33001 --Credit
	)
	INSERT INTO #tmpValidSite (
		SiteName
		,IsDeposit
		,SiteLabel
	)
	SELECT DISTINCT p.SiteName
		,0 AS IsDeposit
		,cr.SiteLabel
	FROM CTE_SiteByPermission AS p
		INNER JOIN CTE_CRMCredit AS cr ON p.SiteName = cr.SiteName
	
	---- Filter by Licensee ---------
	;WITH CTE_CRMLic AS (
		SELECT DISTINCT si.SettingValue AS SiteName
			,1 AS IsDeposit
		FROM bodb_CRM.dbo.crmSettingRelation AS sr WITH (NOLOCK)
			INNER JOIN bodb_CRM.dbo.crmSetting AS sc WITH (NOLOCK) ON sc.SettingName = 'SiteCategory' AND sr.ParentID = sc.SettingID
			INNER JOIN bodb_CRM.dbo.crmSetting AS si WITH (NOLOCK) ON si.SettingName = 'Site' AND sr.SettingID = si.SettingID
		WHERE sr.ParentID = 33000 --Licensee
			AND (
				@LicenseeType = 0
				OR (@LicenseeType = 2 AND ISNULL(TRIM(@SitePermission),'') = '') --Exclude @SitePermission for Deposit
			)
	)
	INSERT INTO #tmpValidSite (
		SiteName
		,IsDeposit
		,SiteLabel
	)
	SELECT DISTINCT lic.SiteName
		,lic.IsDeposit
		,(CASE WHEN s.IsChinaView = 1 THEN 'CV licensees'
				WHEN s.SpecialPlatfrom > 0 THEN 'JS licensees'
				ELSE 'Normal licensees' END
		) AS SiteLabel
	FROM CTE_CRMLic AS lic
		LEFT JOIN bodb02.dbo.Site AS s WITH (NOLOCK) ON lic.SiteName = s.site
		
	---- @UserRole - CN88 ---------
	;WITH CTE_SiteByRole AS (
		SELECT DISTINCT SiteName
			,IsDeposit
		FROM (
			--CN88--
			SELECT sc.SettingValue AS SiteName
				,0 AS IsDeposit
			FROM bodb_CRM.dbo.crmSetting AS sc WITH (NOLOCK)
			WHERE sc.SettingName = 'SiteCategory'
				AND @UserRole = 1
				AND sc.SettingID = 33002
				AND ISNULL(sc.SiteOffer, @UserRole) = @UserRole

			UNION ALL

			SELECT si.SettingValue AS SiteName
				,(CASE WHEN sc.SettingID = 33000 THEN 1 --Licensee
						WHEN sc.SettingID = 33001 THEN 0 --Credit
						-- ELSE -1 END --Unknown
						END ) AS IsDeposit
			FROM bodb_CRM.dbo.crmSetting AS sc WITH (NOLOCK)
				INNER JOIN bodb_CRM.dbo.crmSettingRelation AS sr WITH (NOLOCK) ON sr.ParentID = sc.SettingID
				INNER JOIN bodb_CRM.dbo.crmSetting AS si WITH (NOLOCK) ON si.SettingName = 'Site' AND sr.SettingID = si.SettingID
			WHERE sc.SettingName = 'SiteCategory'
				AND @UserRole = 2
				AND ISNULL(sc.SettingID, 0) <> 33002
				AND ISNULL(sc.SiteOffer, @UserRole) = @UserRole
		) AS s
		WHERE IsDeposit IN (0, 1)
	)
	DELETE v
	FROM #tmpValidSite AS v
		LEFT JOIN CTE_SiteByRole AS s ON v.SiteName = s.SiteName AND v.IsDeposit = s.IsDeposit
	WHERE s.SiteName IS NULL
	
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
		,RealStatus
		,ViewStatus
	)
	SELECT 1 AS NotiType--Msg
		,s.StatusID
		,s.Status AS RealStatus
		,(CASE WHEN s.Status = 'Failed to Send' THEN 'Failed' ELSE s.Status END) AS ViewStatus
	FROM STRING_SPLIT('New,Draft,Cancelled,Sending,Sent,Failed to Send', ',') AS m
		INNER JOIN dbo.NotiStatus AS s WITH (NOLOCK) ON m.value = s.Status
	
	UNION ALL
	
	SELECT 2 AS NotiType--LAP
		,s.StatusID
		,s.Status AS RealStatus
		,s.Status AS ViewStatus
	FROM STRING_SPLIT('New,Active,Inactive', ',') AS l
		INNER JOIN dbo.NotiStatus AS s WITH (NOLOCK) ON l.value = s.Status
	
	CREATE CLUSTERED INDEX CIX_tmpStsByNotiType ON #tmpStsByNotiType (StatusID)
	/*****************************************   APPLY filter criterias   *********************************************************/
	
	--Get Notifications by @FNotiID, @TNotiID, @NotiType
	IF @NotiType IN (1,2)
		AND (@FNotiID IS NOT NULL OR @TNotiID IS NOT NULL)
	BEGIN
		--correct if any NULL
		SELECT @FNotiID = ISNULL(@FNotiID,@TNotiID)
			,@TNotiID = ISNULL(@TNotiID,@FNotiID)
		
		INSERT INTO #tmpNoti (NotiID)
		SELECT DISTINCT n.NotificationID
		FROM dbo.Notification AS n WITH (NOLOCK)
			INNER JOIN #tmpStsByNotiType AS s ON n.NotificationType = s.NotiType AND n.StatusID = s.StatusID
			--filter by User Permission
			INNER JOIN dbo.NotificationTarget AS nt WITH (NOLOCK) ON n.NotificationID = nt.NotificationID
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
			INNER JOIN dbo.NotificationTarget AS nt WITH (NOLOCK) ON n.NotificationID = nt.NotificationID
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
				INNER JOIN #tmpStsByNotiType AS s ON msgn.StatusID = s.StatusID
			WHERE ne.NotificationID = i.NotiID
				AND s.RealStatus = 'Sent' --push successful
				AND ISJSON(ne.ExtraInfo) = 1
		)
	END
	
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
		,TemplateName
	)
	SELECT DISTINCT i.NotiID
		,n.RefID
		,ext.MatchID
		,ne.EventDate
		,ext.HomeNameEN + ISNULL(' ' + ext.NeutralEN,'') + ' -vs- ' + ext.AwayNameEN AS EventName
		,ext.SportNameEN
		,ext.IsTest
		,CASE WHEN n.NotificationType = 1 THEN ext.MsgSender ELSE ext.LapSender END
		,CASE WHEN n.NotificationType = 1 THEN ext.MsgSendDate ELSE ext.LapSendDate END
		,ext.TemplateName
	FROM #tmpNoti AS i
		INNER JOIN dbo.Notification AS n WITH (NOLOCK) ON i.NotiID = n.NotificationID
		INNER JOIN dbo.NotificationExtra AS ne WITH (NOLOCK) ON i.NotiID = ne.NotificationID
		OUTER APPLY OPENJSON(ne.ExtraInfo) WITH (
						MatchID INT '$.MatchID'
						,IsTest BIT '$.IsTest'
						,MsgSender VARCHAR(50) '$.MsgSender'
						,MsgSendDate DATETIME '$.MsgSendDate'
						,LapSender VARCHAR(50) '$.LapSender'
						,LapSendDate DATETIME '$.LapSendDate'
						,HomeNameEN NVARCHAR(500) '$.HomeNameEN'
						,NeutralEN NVARCHAR(10) '$.NeutralEN'
						,AwayNameEN NVARCHAR(500) '$.AwayNameEN'
						,SportNameEN NVARCHAR(500) '$.SportNameEN'
						,TemplateName NVARCHAR(1000) '$.TemplateName'
					) AS ext --OPENJSON case-sensitive
	WHERE ISJSON(ne.ExtraInfo) = 1
	
	CREATE UNIQUE CLUSTERED INDEX CIX_tmpNotiExt ON #tmpNotiExt (NotiID)
	
	--apply filter ONLY IF input NotiID NULL
	IF @FNotiID IS NULL
	BEGIN
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
					INNER JOIN #tmpStsByNotiType AS s ON i.value = s.ViewStatus
			)
			
			UPDATE STATISTICS #tmpNoti
		END
		
		--filter by @Content
		IF ISNULL(@Content,'') <> ''
		BEGIN
			DELETE i
			FROM #tmpNoti AS i
			WHERE NOT EXISTS (
				SELECT 1
				FROM dbo.Notification AS n WITH (NOLOCK)
				WHERE n.NotificationID = i.NotiID
					AND (
						n.Content_en LIKE '%' + @Content + '%'
						OR n.Content_ch LIKE '%' + @Content + '%'
						OR n.Content_cs LIKE '%' + @Content + '%'
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
			,CASE WHEN vs.IsDeposit = 1 THEN 'Licensee' ELSE 'Credit' END AS SiteType
			,(CASE WHEN vs.IsDeposit = 1 AND vs.SiteLabel IS NULL THEN 'Normal licensees' --Licensee
				WHEN vs.IsDeposit = 0 AND vs.SiteLabel IS NULL THEN 'Others' --Credit
				ELSE vs.SiteLabel
				END) AS SiteGroup
			,nt.TargetSite
		FROM #tmpNoti AS i
			INNER JOIN dbo.NotificationTarget AS nt WITH (NOLOCK) ON i.NotiID = nt.NotificationID
			INNER JOIN #tmpValidSite AS vs ON nt.TargetSite = vs.SiteName
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
		,STRING_AGG(CONVERT(NVARCHAR(MAX),TargetSite),', ') WITHIN GROUP (ORDER BY TargetSite) AS SiteNames --SiteName sort by alphabetical
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
			,TemplateName
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
			,ext.TemplateName
			,n.Content_en
			,n.Content_ch
			,n.Content_cs
			,s.ViewStatus AS Status
			,ext.Sender
			,FORMAT(DATEADD(HH, 12, ext.SendDate), 'MMM dd, yyyy hh:mm:ss tt') AS SendDate --GMT+8
		FROM #tmpNoti AS i
			INNER JOIN #tmpNotiExt AS ext ON i.NotiID = ext.NotiID
			INNER JOIN dbo.Notification AS n WITH (NOLOCK) ON i.NotiID = n.NotificationID
			INNER JOIN #tmpStsByNotiType AS s ON n.StatusID = s.StatusID
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
			,TemplateName
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
			,ext.TemplateName
			,n.Content_en
			,n.Content_ch
			,n.Content_cs
			,s.ViewStatus AS Status
			,ext.Sender
			,FORMAT(DATEADD(HH, 12, ext.SendDate), 'MMM dd, yyyy hh:mm:ss tt') AS SendDate --GMT+8
		FROM #tmpNoti AS i
			INNER JOIN #tmpNotiExt AS ext ON i.NotiID = ext.NotiID
			INNER JOIN #tmpAffectedSite AS si ON i.NotiID = si.NotiID
			INNER JOIN dbo.Notification AS n WITH (NOLOCK) ON i.NotiID = n.NotificationID
			INNER JOIN #tmpStsByNotiType AS s ON n.StatusID = s.StatusID
			INNER JOIN dbo.NotiMapping AS nm WITH (NOLOCK) ON i.NotiID = nm.NotificationID
			INNER JOIN dbo.SettlementResultHist AS rh WITH (NOLOCK) ON nm.SettlementLogID = rh.SettlementLogID
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
		,TemplateName AS Subject
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
				Rule 1 - SiteType: hardcode follow order
					1.Credit
					2.Licensee
			*/
			,(CASE WHEN s.SiteType = 'Credit' THEN 1 ELSE 2 END) AS Ord1
			/*
				Rule 2 - Licensee: hardcode follow order
					1.Normal licensees
					2.JS licensees
					3.CV licensees
			*/
			,(CASE WHEN s.SiteType = 'Licensee' AND s.SiteGroup = 'CV licensees' THEN 3
					WHEN s.SiteType = 'Licensee' AND s.SiteGroup = 'JS licensees' THEN 2
					WHEN s.SiteType = 'Licensee' THEN 1 --Normal licensees
			END) AS Ord2
			/*
				Rule 3 - Credit: Sort by alphabetical
			*/
			,SiteGroup AS Ord3
		FROM #tmpAffectedSite AS s
	)
	,CTE_SiteGroupOrder AS (
		SELECT DISTINCT SiteGroup
			,ROW_NUMBER() OVER ( ORDER BY Ord1, Ord2, Ord3 ) AS SiteGroupOrd
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
