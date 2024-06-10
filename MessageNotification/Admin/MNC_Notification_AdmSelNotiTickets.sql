/*<info serverAlias="DBCRM-MessageNotification" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE MNC_Notification_AdmSelNotiTickets
	@NotiID INT
	---permission control---
	,@UserRole TINYINT = 2
	,@LicenseeType INT = 0
	,@SitePermission NVARCHAR(MAX) = NULL
AS
/*
	Created: 20231213@Roy
	Task: Get all Affected Tickets by NotificationID
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
		EXEC MessageNotification.dbo.MNC_Notification_AdmSelNotiTickets
			@NotiID = 1
*/
BEGIN
	SET NOCOUNT ON
	
	CREATE TABLE #tmpAffectedTicket (
		SiteType NVARCHAR(50) NOT NULL
		,SiteName NVARCHAR(50) NOT NULL
		,TransID BIGINT
		,CustID INT
		,Username NVARCHAR(50)
		,ExtInfo NVARCHAR(50)
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
	
	----------------------------------------------------------------	
	IF 1 = (SELECT NotificationType FROM Notification WITH (NOLOCK) WHERE NotificationID = @NotiID)--Msg
	BEGIN
		INSERT INTO #tmpAffectedTicket (
			SiteType
			,SiteName
			,TransID
			,CustID
			,Username
			,ExtInfo
		)
		SELECT DISTINCT (CASE WHEN vs.isDeposit = 1 THEN 'Licensee' ELSE 'Credit' END) AS SiteType
			,nt.TargetSite
			,t.TransID
			,c.CustID
			,c.Username
			,(CASE WHEN vs.isDeposit = 1 THEN c.username2 END) AS username2 --For licensee - get username2
		FROM dbo.NotificationTarget AS nt WITH (NOLOCK)
			INNER JOIN #tmpValidSite AS vs ON nt.TargetSite = vs.SiteName
			INNER JOIN bodb02.dbo.Customer AS c WITH (NOLOCK) ON nt.TargetID = c.CustID
			OUTER APPLY OPENJSON(nt.ExtraInfo) WITH (
							TransID BIGINT '$.TransID'
						) AS t --OPENJSON case-sensitive
		WHERE nt.NotificationID = @NotiID
			AND c.roleid = 1 --cust only
			AND ISJSON(nt.ExtraInfo) = 1
		OPTION (RECOMPILE)
	END
	ELSE --LAP
	BEGIN
		INSERT INTO #tmpAffectedTicket (
			SiteType
			,SiteName
			,TransID
			,CustID
		)
		SELECT DISTINCT (CASE WHEN vs.isDeposit = 1 THEN 'Licensee' ELSE 'Credit' END) AS SiteType
			,nt.TargetSite
			,t.value AS TransID
			,nc.CustID
		FROM dbo.NotificationTarget AS nt WITH (NOLOCK)
			INNER JOIN #tmpValidSite AS vs ON nt.TargetSite = vs.SiteName
			OUTER APPLY OPENJSON(nt.ExtraInfo) WITH (
							CustID INT '$.CustID'
							,TransIDs VARCHAR(MAX) '$.TransIDs'
						) AS nc --OPENJSON case-sensitive
			OUTER APPLY STRING_SPLIT(nc.TransIDs, ',') AS t
		WHERE nt.NotificationID = @NotiID
			AND TRY_CONVERT(BIGINT,t.value) IS NOT NULL
			AND ISJSON(nt.ExtraInfo) = 1
		OPTION (RECOMPILE)
		
		--Join with Customer later to increase perf
		UPDATE af
		SET af.Username = c.Username
			,af.ExtInfo = c.username2
		FROM #tmpAffectedTicket AS af
			INNER JOIN bodb02.dbo.Customer AS c WITH (NOLOCK) ON af.CustID = c.CustID
		WHERE af.TransID IS NOT NULL
			AND c.roleid = 1 --cust only
		
		DELETE FROM #tmpAffectedTicket
		WHERE Username IS NULL
	END
	
	CREATE CLUSTERED INDEX CIX_tmpAffectedTicket ON #tmpAffectedTicket (CustID)
	
	--For credit - get Headline
	IF EXISTS (SELECT 1 FROM #tmpAffectedTicket WHERE SiteType = 'Credit')
	BEGIN
		DECLARE @CreditCustIDs VARCHAR(MAX)
		
		CREATE TABLE #tmpHeadline (
			CustID INT
			,HeadlineID INT
			,HeadlineName VARCHAR(50)
		)
		
		;WITH CTE_CustIDs AS (
			SELECT DISTINCT CustID
			FROM #tmpAffectedTicket
			WHERE SiteType = 'Credit'
		)
		SELECT @CreditCustIDs = STRING_AGG(CONVERT(NVARCHAR(MAX),CustID),',') WITHIN GROUP (ORDER BY CustID)
		FROM CTE_CustIDs
		
		--get Headline of CustID
		INSERT INTO #tmpHeadline (CustID,HeadlineID,HeadlineName)
		EXEC bodb02.dbo.Acc_CRM_GroupHeadlineSel @custids = @CreditCustIDs
		
		CREATE CLUSTERED INDEX CIX_tmpHeadline ON #tmpHeadline (CustID)
		
		UPDATE a
		SET a.ExtInfo = (CASE WHEN hed.CustID IS NOT NULL AND h.HeadlineName IS NOT NULL THEN h.HeadlineName ELSE 'Not assigned group' END)
		FROM #tmpAffectedTicket AS a
			LEFT JOIN #tmpHeadline AS h ON a.CustID = h.CustID
			LEFT JOIN bodb02.dbo.CustGroupHeadline AS hed WITH (NOLOCK) ON h.HeadlineID = hed.CustID
		WHERE a.SiteType = 'Credit'
	END
	
	--For licensee - Remove prefix $
	IF EXISTS (SELECT 1 FROM #tmpAffectedTicket WHERE SiteType <> 'Credit')
	BEGIN
		UPDATE a
		SET a.ExtInfo = RIGHT(a.ExtInfo, LEN(a.ExtInfo) - CHARINDEX('$', a.ExtInfo))
		FROM #tmpAffectedTicket AS a
		WHERE a.SiteType <> 'Credit'
	END
	
	-----return----
	SELECT SiteType
		,SiteName
		,TransID
		,Username
		,ExtInfo
	FROM #tmpAffectedTicket
	ORDER BY SiteType
		,SiteName
		,Username
		,TransID
	
	DROP TABLE #tmpAffectedTicket
	DROP TABLE IF EXISTS #tmpHeadline
	DROP TABLE #tmpValidSite
END