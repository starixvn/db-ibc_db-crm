/*<info serverAlias="DBCRM-MessageNotification" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE MNC_Notification_AdmSelNotiDetail
	@NotiID INT
	---permission control---
	,@UserRole TINYINT = 2
	,@LicenseeType INT = 0
	,@SitePermission NVARCHAR(MAX) = NULL
AS
/*
	Created: 20231213@Roy
	Task: Get detail NotificationID
	DB: DBCRM.MessageNotification
	Revisions:
		20231121@Roy: CRM - Implement Message Notifications Center for Result Amendment of Cricket(#197621)
	
	Param's Explanation:
		@NotiID: Notification.NotificationID
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
		EXEC MessageNotification.dbo.MNC_Notification_AdmSelNotiDetail
			@NotiID = 1
*/
BEGIN
	SET NOCOUNT ON
	
	CREATE TABLE #tmpAffectedTicket (
		NotiID INT
		,SiteType VARCHAR(100)
		,SiteGroup VARCHAR(50)
		,SiteName NVARCHAR(50)
		,TransID BIGINT
	)
	
	CREATE TABLE #tmpNotiExt (
		NotiID INT
		,MsgID INT
		,KOTime DATETIME
		,EventName NVARCHAR(500)
	)
	
	CREATE TABLE #tmpValidSite (
		CRMSiteName NVARCHAR(100)
		,MainSiteName NVARCHAR(100)
		,ViewSiteName NVARCHAR(100)
		,IsDeposit BIT
		,SiteLabel VARCHAR(50)
	)
	
	CREATE TABLE #tmpHardcodeSite (
		CRMSiteName NVARCHAR(100)
		,MainSiteName NVARCHAR(100)
		,ViewSiteName NVARCHAR(100)
	)
	
	/*
		Convert permission control to Sites
	*/
	
	--HARDCODE for Licensee only
	INSERT INTO #tmpHardcodeSite (
		CRMSiteName
		,MainSiteName
		,ViewSiteName
	)
	VALUES ('Kzing', 'IBO', 'Kzing (IBO)')
		,('LIVV88', 'KeenOcean', 'LIVV88 (KeenOcean)')
	
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
		SELECT DISTINCT si.SettingValue AS CRMSiteName
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
		SELECT si.SettingValue AS CRMSiteName
			,si.ExtraInfo AS SiteLabel
		FROM bodb_CRM.dbo.crmSettingRelation sr WITH (NOLOCK)
		INNER JOIN bodb_CRM.dbo.crmSetting sc WITH (NOLOCK) ON sc.SettingName = 'SiteCategory' AND sr.ParentID = sc.SettingID
		INNER JOIN bodb_CRM.dbo.crmSetting si WITH (NOLOCK) ON si.SettingName = 'Site' AND sr.SettingID = si.SettingID
		WHERE sr.ParentID = 33001 --Credit
	)
	INSERT INTO #tmpValidSite (
		CRMSiteName
		,IsDeposit
		,SiteLabel
		,MainSiteName
		,ViewSiteName
		
	)
	SELECT DISTINCT p.CRMSiteName
		,0 AS IsDeposit
		,cr.SiteLabel
		,p.CRMSiteName AS MainSiteName
		,p.CRMSiteName AS ViewSiteName
	FROM CTE_SiteByPermission AS p
		INNER JOIN CTE_CRMCredit AS cr ON p.CRMSiteName = cr.CRMSiteName
	
	---- Filter by Licensee ---------
	;WITH CTE_CRMLic AS (
		SELECT DISTINCT si.SettingValue AS CRMSiteName
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
		CRMSiteName
		,IsDeposit
		,SiteLabel
		,MainSiteName
		,ViewSiteName
		
	)
	SELECT DISTINCT lic.CRMSiteName
		,lic.IsDeposit
		,(CASE WHEN s.IsChinaView = 1 THEN 'CV licensees'
				WHEN s.SpecialPlatfrom > 0 THEN 'JS licensees'
				ELSE 'Normal licensees' END
		) AS SiteLabel
		,ISNULL(hs.MainSiteName, lic.CRMSiteName) AS MainSiteName
		,ISNULL(hs.ViewSiteName, lic.CRMSiteName) AS ViewSiteName
	FROM CTE_CRMLic AS lic
		LEFT JOIN #tmpHardcodeSite AS hs ON lic.CRMSiteName = hs.CRMSiteName --HARDCODE for Licensee only
		LEFT JOIN bodb02.dbo.Site AS s WITH (NOLOCK) ON ISNULL(hs.MainSiteName, lic.CRMSiteName) = s.site
	WHERE s.site IS NOT NULL
		
	---- @UserRole - CN88 ---------
	;WITH CTE_SiteByRole AS (
		SELECT DISTINCT CRMSiteName
			,IsDeposit
		FROM (
			--CN88--
			SELECT sc.SettingValue AS CRMSiteName
				,0 AS IsDeposit
			FROM bodb_CRM.dbo.crmSetting AS sc WITH (NOLOCK)
			WHERE sc.SettingName = 'SiteCategory'
				AND @UserRole = 1
				AND sc.SettingID = 33002
				AND ISNULL(sc.SiteOffer, @UserRole) = @UserRole

			UNION ALL

			SELECT si.SettingValue AS CRMSiteName
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
		LEFT JOIN CTE_SiteByRole AS s ON v.CRMSiteName = s.CRMSiteName AND v.IsDeposit = s.IsDeposit
	WHERE s.CRMSiteName IS NULL
	
	CREATE CLUSTERED INDEX CIX_tmpValidSite ON #tmpValidSite (CRMSiteName)
	
	/*****************************************   Prepare for return   *********************************************************/
	DECLARE @NotiType TINYINT
	SELECT @NotiType = NotificationType
	FROM dbo.Notification WITH (NOLOCK)
	WHERE NotificationID = @NotiID
	
	IF @NotiType = 1 --Msg
	BEGIN
		INSERT INTO #tmpNotiExt (
			NotiID
			,MsgID
			,KOTime
			,EventName
		)
		SELECT DISTINCT n.NotificationID
			,n.RefID
			,ext.KOTime
			,ext.HomeNameEN + ISNULL(' ' + ext.NeutralEN,'') + ' -vs- ' + ext.AwayNameEN AS EventName
		FROM dbo.Notification AS n WITH (NOLOCK)
			INNER JOIN dbo.NotificationExtra AS ne WITH (NOLOCK) ON n.NotificationID = ne.NotificationID
			OUTER APPLY OPENJSON(ne.ExtraInfo) WITH (
							HomeNameEN NVARCHAR(500) '$.HomeNameEN'
							,NeutralEN NVARCHAR(10) '$.NeutralEN'
							,AwayNameEN NVARCHAR(500) '$.AwayNameEN'
							,KOTime DATETIME '$.KOTime'
						) AS ext --OPENJSON case-sensitive
		WHERE n.NotificationID = @NotiID
			AND ISJSON(ne.ExtraInfo) = 1
		OPTION (RECOMPILE)
		
		INSERT INTO #tmpAffectedTicket (
			NotiID
			,SiteType
			,SiteGroup
			,SiteName
			,TransID
		)
		SELECT DISTINCT nt.NotificationID
			,CASE WHEN vs.IsDeposit = 1 THEN 'Licensee' ELSE 'Credit' END AS SiteType
			,(CASE WHEN vs.IsDeposit = 1 AND vs.SiteLabel IS NULL THEN 'Normal licensees' --Licensee
				WHEN vs.IsDeposit = 0 AND vs.SiteLabel IS NULL THEN 'Others' --Credit
				ELSE vs.SiteLabel
				END) AS SiteGroup
			,vs.ViewSiteName AS SiteName
			,t.TransID
		FROM dbo.NotificationTarget AS nt WITH (NOLOCK)
			INNER JOIN #tmpValidSite AS vs ON nt.TargetSite = vs.MainSiteName
			OUTER APPLY OPENJSON(nt.ExtraInfo) WITH (
							TransID BIGINT '$.TransID'
						) AS t --OPENJSON case-sensitive
		WHERE nt.NotificationID = @NotiID
			AND ISJSON(nt.ExtraInfo) = 1
		OPTION (RECOMPILE)
	END
	ELSE --LAP
	BEGIN
		INSERT INTO #tmpNotiExt (
			NotiID
			,MsgID
			,KOTime
			,EventName
		)
		SELECT DISTINCT nLap.NotificationID
			,nLap.RefID
			,extLap.KOTime
			,extLap.HomeNameEN + ISNULL(' ' + extLap.NeutralEN,'') + ' -vs- ' + extLap.AwayNameEN AS EventName
		FROM dbo.Notification AS nLap WITH (NOLOCK)
			INNER JOIN dbo.NotificationExtra AS neLap WITH (NOLOCK) ON nLap.NotificationID = neLap.NotificationID
			OUTER APPLY OPENJSON(neLap.ExtraInfo) WITH (
							MsgNotiID INT '$.MsgNotiID'
							,HomeNameEN NVARCHAR(500) '$.HomeNameEN'
							,NeutralEN NVARCHAR(10) '$.NeutralEN'
							,AwayNameEN NVARCHAR(500) '$.AwayNameEN'
							,KOTime DATETIME '$.KOTime'
						) AS extLap --OPENJSON case-sensitive
		WHERE nLap.NotificationID = @NotiID
			AND ISJSON(neLap.ExtraInfo) = 1
		OPTION (RECOMPILE)
		
		INSERT INTO #tmpAffectedTicket (
			NotiID
			,SiteType
			,SiteGroup
			,SiteName
			,TransID
		)
		SELECT DISTINCT nt.NotificationID
			,CASE WHEN vs.IsDeposit = 1 THEN 'Licensee' ELSE 'Credit' END AS SiteType
			,(CASE WHEN vs.IsDeposit = 1 AND vs.SiteLabel IS NULL THEN 'Normal licensees' --Licensee
				WHEN vs.IsDeposit = 0 AND vs.SiteLabel IS NULL THEN 'Others' --Credit
				ELSE vs.SiteLabel
				END) AS SiteGroup
			,vs.ViewSiteName AS SiteName
			,t.value AS TransID
		FROM dbo.NotificationTarget AS nt WITH (NOLOCK)
			INNER JOIN #tmpValidSite AS vs ON nt.TargetSite = vs.MainSiteName
			OUTER APPLY OPENJSON(nt.ExtraInfo) WITH (
							CustID INT '$.CustID'
							,TransIDs VARCHAR(MAX) '$.TransIDs'
						) AS nc --OPENJSON case-sensitive
			CROSS APPLY STRING_SPLIT(nc.TransIDs, ',') AS t
		WHERE nt.NotificationID = @NotiID
			AND TRY_CONVERT(BIGINT,t.value) IS NOT NULL
			AND ISJSON(nt.ExtraInfo) = 1
		OPTION (RECOMPILE)
		
	END
	
	CREATE UNIQUE CLUSTERED INDEX CIX_tmpNotiExt ON #tmpNotiExt (NotiID)	
	CREATE CLUSTERED INDEX CIX_tmpAffectedTicket ON #tmpAffectedTicket (SiteType, SiteGroup)
	
	-----------------------------------------Return-------------------------------------------
	
	----------Notification----------
	SELECT DISTINCT n.NotificationID
		,ext.MsgID AS MessageID
		,(CASE WHEN s.Status = 'Failed to Send' THEN 'Failed' ELSE s.Status END) AS Status
		,FORMAT(DATEADD(HH, 12, ext.KOTime),'MMM dd, yyyy hh:mm tt') AS EventTime --GMT+8
		,ext.EventName
		,n.Subject
		,n.Content_en
		,n.Content_ch
		,n.Content_cs
	FROM dbo.Notification AS n WITH (NOLOCK)
		INNER JOIN #tmpNotiExt AS ext ON n.NotificationID = ext.NotiID
		INNER JOIN #tmpAffectedTicket AS nt ON n.NotificationID = nt.NotiID
		INNER JOIN dbo.NotiStatus AS s WITH (NOLOCK) ON n.StatusID = s.StatusID
	
	----------Site by NotificationID----------
	;WITH CTE_BySite AS (
		SELECT SiteType
			,SiteGroup
			,STRING_AGG(CONVERT(NVARCHAR(MAX),SiteName),', ') WITHIN GROUP (ORDER BY SiteName) AS SiteNames --Rule 1 - SiteName sort by alphabetical
		FROM (
			SELECT DISTINCT SiteType
				,SiteGroup
				,SiteName
			FROM #tmpAffectedTicket
		) AS t
		GROUP BY SiteType
			,SiteGroup
	)
	,CTE_SiteGroupOrder AS (
		SELECT s.SiteGroup
			,ROW_NUMBER() OVER (
				ORDER BY
					/*
						Rule 2 - SiteType: hardcode
							1.Credit
							2.Licensee
					*/
					(CASE WHEN s.SiteType = 'Credit' THEN 1 ELSE 2 END)
					/*
						Rule 3 - Licensee: hardcode
							1.Normal licensees
							2.JS licensees
							3.CV licensees
					*/
					,(CASE WHEN s.SiteType = 'Licensee' AND s.SiteGroup = 'CV licensees' THEN 3
							WHEN s.SiteType = 'Licensee' AND s.SiteGroup = 'JS licensees' THEN 2
							WHEN s.SiteType = 'Licensee' THEN 1 --Normal licensees
					END)
					/*
						Rule 4 - Credit: Sort by alphabetical
					*/
					,SiteGroup
			) AS SiteGroupOrd
		FROM CTE_BySite AS s
	)
	,CTE_ByTicket AS (
		SELECT SiteType
			,SiteGroup
			,COUNT(DISTINCT TransID) AS TicketCnt
		FROM #tmpAffectedTicket
		GROUP BY SiteType
			,SiteGroup
	)
	SELECT s.SiteType
		,s.SiteGroup
		,sgo.SiteGroupOrd
		,s.SiteNames
		,t.TicketCnt
	FROM CTE_BySite AS s
		INNER JOIN CTE_ByTicket AS t ON s.SiteType = t.SiteType AND s.SiteGroup = t.SiteGroup
		LEFT JOIN CTE_SiteGroupOrder AS sgo ON s.SiteGroup = sgo.SiteGroup
	ORDER BY sgo.SiteGroupOrd
	
	DROP TABLE #tmpNotiExt
	DROP TABLE #tmpAffectedTicket
	DROP TABLE #tmpValidSite
	DROP TABLE #tmpHardcodeSite
END
