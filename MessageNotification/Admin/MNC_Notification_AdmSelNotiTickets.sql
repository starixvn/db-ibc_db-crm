/*<info serverAlias="DBCRM-MessageNotification" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE MNC_Notification_AdmSelNotiTickets
	@NotiID INT
AS
/*
	Created: 20231213@Roy
	Task: Get all Affected Tickets by NotificationID
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
	
	DECLARE @LogUserID INT
		,@LogActionID SMALLINT
	
	SELECT @LogUserID = TRY_CONVERT(INT, VValue)
	FROM SystemSetting WITH (NOLOCK)
	WHERE VID = 2 --ID of StarixIT
	
	SELECT @LogActionID = ActionID
	FROM LogAction WITH (NOLOCK)
	WHERE ActName = ISNULL(OBJECT_NAME(@@PROCID),'Unknown')
	
	CREATE TABLE #tmpAffectedTicket (
		SiteType NVARCHAR(50)
		,SiteName NVARCHAR(50)
		,TransID BIGINT
		,CustID INT
		,Username NVARCHAR(50)
		,ExtInfo NVARCHAR(50)
	)
	
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
		SELECT DISTINCT (CASE WHEN s.isDeposit = 1 THEN 'Licensee' ELSE 'Credit' END) AS SiteType
			,nt.TargetSite
			,t.TransID
			,c.CustID
			,c.Username
			,(CASE WHEN s.isDeposit = 1 THEN c.username2 END) AS username2 --For licensee - get username2
		FROM dbo.NotificationTarget AS nt WITH (NOLOCK)
			INNER JOIN bodb02.dbo.Customer AS c WITH (NOLOCK) ON nt.TargetID = c.CustID
			OUTER APPLY OPENJSON(nt.ExtraInfo) WITH (
							TransID BIGINT '$.TransID'
						) AS t --OPENJSON case-sensitive
			LEFT JOIN bodb02.dbo.Site AS s WITH (NOLOCK) ON nt.TargetSite = s.site
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
			,Username
			,ExtInfo
		)
		SELECT DISTINCT (CASE WHEN s.isDeposit = 1 THEN 'Licensee' ELSE 'Credit' END) AS SiteType
			,nt.TargetSite
			,t.value AS TransID
			,nc.CustID
			,c.Username
			,(CASE WHEN s.isDeposit = 1 THEN c.username2 END) AS username2 --For licensee - get username2
		FROM dbo.NotificationTarget AS nt WITH (NOLOCK)
			OUTER APPLY OPENJSON(nt.ExtraInfo) WITH (
							CustID INT '$.CustID'
							,TransIDs VARCHAR(MAX) '$.TransIDs'
						) AS nc --OPENJSON case-sensitive
			OUTER APPLY STRING_SPLIT(nc.TransIDs, ',') AS t
			INNER JOIN bodb02.dbo.Customer AS c WITH (NOLOCK) ON nc.CustID = c.CustID
			LEFT JOIN bodb02.dbo.Site AS s WITH (NOLOCK) ON nt.TargetSite = s.site
		WHERE nt.NotificationID = @NotiID
			AND c.roleid = 1 --cust only
			AND TRY_CONVERT(BIGINT,t.value) IS NOT NULL
			AND ISJSON(nt.ExtraInfo) = 1
		OPTION (RECOMPILE)
	END
	
	CREATE CLUSTERED INDEX CIX_tmpAffectedTicket ON #tmpAffectedTicket (CustID)
	
	--For credit - get Headline
	IF EXISTS (SELECT 1 FROM #tmpAffectedTicket WHERE SiteType = 'Credit')
	BEGIN
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
		SET a.ExtInfo = ISNULL(h.HeadlineName,'Not assigned group')
		FROM #tmpAffectedTicket AS a
			LEFT JOIN #tmpHeadline AS h ON a.CustID = h.CustID
		WHERE a.SiteType = 'Credit'
	END
	
	--For licensee - get username2
	-- IF EXISTS (SELECT 1 FROM #tmpAffectedTicket WHERE SiteType <> 'Credit')
	-- BEGIN
		-- UPDATE a
		-- SET a.ExtInfo = c.username2
		-- FROM #tmpAffectedTicket AS a
			-- LEFT JOIN bodb02.dbo.Customer AS c WITH (NOLOCK) ON a.CustID = c.CustID
	-- END
	
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
END