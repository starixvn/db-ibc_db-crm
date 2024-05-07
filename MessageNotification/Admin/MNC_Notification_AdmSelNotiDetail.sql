/*<info serverAlias="DBCRM-MessageNotification" executers="wsv_nap" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE MNC_Notification_AdmSelNotiDetail
	@NotiID INT
AS
/*
	Created: 20231213@Roy
	Task: Get detail NotificationID
	DB: DBCRM.MessageNotification
	Revisions:
		20231121@Roy: CRM - Implement Message Notifications Center for Result Amendment of Cricket(#197621)
	
	Param's Explanation:
		@NotiID: Notification.NotificationID
	
	Example:
		EXEC MessageNotification.dbo.MNC_Notification_AdmSelNotiDetail
			@NotiID = 1
*/
BEGIN
	SET NOCOUNT ON
	
	CREATE TABLE #tmpAffectedTicket (
		SiteType VARCHAR(100)
		,SiteGroup VARCHAR(50)
		,SiteName NVARCHAR(50)
		,TransID BIGINT
	)
	
	CREATE TABLE #tmpNotiExt (
		NotiID INT
		,MsgID INT
		,EventDate DATE
		,EventName NVARCHAR(500)
	)
	
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
			,EventDate
			,EventName
		)
		SELECT DISTINCT n.NotificationID
			,n.RefID
			,ne.EventDate
			,ext.HomeNameEN + ISNULL(' ' + ext.NeutralEN,'') + ' -vs- ' + ext.AwayNameEN AS EventName
		FROM dbo.Notification AS n WITH (NOLOCK)
			INNER JOIN dbo.NotificationExtra AS ne WITH (NOLOCK) ON n.NotificationID = ne.NotificationID
			OUTER APPLY OPENJSON(ne.ExtraInfo) WITH (
							HomeNameEN NVARCHAR(500) '$.HomeNameEN'
							,NeutralEN NVARCHAR(10) '$.NeutralEN'
							,AwayNameEN NVARCHAR(500) '$.AwayNameEN'
						) AS ext --OPENJSON case-sensitive
		WHERE n.NotificationID = @NotiID
			AND ISJSON(ne.ExtraInfo) = 1
		OPTION (RECOMPILE)
		
		INSERT INTO #tmpAffectedTicket (
			SiteType
			,SiteGroup
			,SiteName
			,TransID
		)
		SELECT DISTINCT (CASE WHEN s.isDeposit = 1 THEN 'Licensee' ELSE 'Credit' END) AS SiteType
			,CASE WHEN s.isDeposit = 1 THEN --Licensee
				(CASE WHEN s.IsChinaView = 1 THEN 'CV licensees'
					WHEN s.SpecialPlatfrom > 0 THEN 'JS licensees'
					ELSE 'Normal licensees' END
				)
				ELSE ISNULL(s.SiteLabel,'Others') --Credit
				END AS SiteGroup
			,nt.TargetSite
			,t.TransID
		FROM dbo.NotificationTarget AS nt WITH (NOLOCK)
			OUTER APPLY OPENJSON(nt.ExtraInfo) WITH (
							TransID BIGINT '$.TransID'
						) AS t --OPENJSON case-sensitive
			LEFT JOIN bodb02.dbo.Site AS s WITH (NOLOCK) ON nt.TargetSite = s.site
		WHERE nt.NotificationID = @NotiID
			AND ISJSON(nt.ExtraInfo) = 1
		OPTION (RECOMPILE)
	END
	ELSE --LAP
	BEGIN
		INSERT INTO #tmpNotiExt (
			NotiID
			,MsgID
			,EventDate
			,EventName
		)
		SELECT DISTINCT nLap.NotificationID
			,nMsg.RefID
			,neMsg.EventDate
			,extMsg.HomeNameEN + ISNULL(' ' + extMsg.NeutralEN,'') + ' -vs- ' + extMsg.AwayNameEN AS EventName
		FROM dbo.Notification AS nLap WITH (NOLOCK)
			INNER JOIN dbo.NotificationExtra AS neLap WITH (NOLOCK) ON nLap.NotificationID = neLap.NotificationID
			OUTER APPLY OPENJSON(neLap.ExtraInfo) WITH (
							MsgNotiID INT '$.MsgNotiID'
						) AS extLap --OPENJSON case-sensitive
			INNER JOIN dbo.Notification AS nMsg WITH (NOLOCK) ON extLap.MsgNotiID = nMsg.NotificationID
			INNER JOIN dbo.NotificationExtra AS neMsg WITH (NOLOCK) ON extLap.MsgNotiID = neMsg.NotificationID
			OUTER APPLY OPENJSON(neMsg.ExtraInfo) WITH (
							HomeNameEN NVARCHAR(500) '$.HomeNameEN'
							,NeutralEN NVARCHAR(10) '$.NeutralEN'
							,AwayNameEN NVARCHAR(500) '$.AwayNameEN'
						) AS extMsg --OPENJSON case-sensitive
		WHERE nLap.NotificationID = @NotiID
			AND ISJSON(neLap.ExtraInfo) = 1
			AND ISJSON(neMsg.ExtraInfo) = 1
		OPTION (RECOMPILE)
		
		INSERT INTO #tmpAffectedTicket (
			SiteType
			,SiteGroup
			,SiteName
			,TransID
		)
		SELECT DISTINCT (CASE WHEN s.isDeposit = 1 THEN 'Licensee' ELSE 'Credit' END) AS SiteType
			,CASE WHEN s.isDeposit = 1 THEN --Licensee
				(CASE WHEN s.IsChinaView = 1 THEN 'CV licensees'
					WHEN s.SpecialPlatfrom > 0 THEN 'JS licensees'
					ELSE 'Normal licensees' END
				)
				ELSE ISNULL(s.SiteLabel,'Others') --Credit
				END AS SiteGroup
			,nt.TargetSite
			,t.value AS TransID
		FROM dbo.NotificationTarget AS nt WITH (NOLOCK)
			OUTER APPLY OPENJSON(nt.ExtraInfo) WITH (
							CustID INT '$.CustID'
							,TransIDs VARCHAR(MAX) '$.TransIDs'
						) AS nc --OPENJSON case-sensitive
			CROSS APPLY STRING_SPLIT(nc.TransIDs, ',') AS t
			LEFT JOIN bodb02.dbo.Site AS s WITH (NOLOCK) ON nt.TargetSite = s.site
		WHERE nt.NotificationID = @NotiID
			AND TRY_CONVERT(BIGINT,t.value) IS NOT NULL
			AND ISJSON(nt.ExtraInfo) = 1
		OPTION (RECOMPILE)
		
	END
	
	CREATE UNIQUE CLUSTERED INDEX CIX_tmpNotiExt ON #tmpNotiExt (NotiID)	
	CREATE CLUSTERED INDEX CIX_tmpAffectedTicket ON #tmpAffectedTicket (SiteType, SiteGroup)
	
	-----------------------------------------Return-------------------------------------------
	
	----------Notification----------
	IF @NotiType = 1 --Msg
	BEGIN
		SELECT DISTINCT n.NotificationID
			,ext.MsgID AS MessageID
			,s.Status
			,FORMAT(ext.EventDate, 'MMM dd, yyyy') AS EventDate --GMT-4
			,ext.EventName
			,n.Content_en
			,n.Content_ch
			,n.Content_cs
		FROM dbo.Notification AS n WITH (NOLOCK)
			INNER JOIN #tmpNotiExt AS ext ON n.NotificationID = ext.NotiID
			INNER JOIN dbo.NotiStatus AS s WITH (NOLOCK) ON n.StatusID = s.StatusID
	END
	ELSE --LAP
	BEGIN
		SELECT DISTINCT n.NotificationID
			,ext.MsgID AS MessageID
			,s.Status
			,FORMAT(ext.EventDate, 'MMM dd, yyyy') AS EventDate --GMT-4
			,ext.EventName
			,nex.Subject_en + '<br/><br/>' + n.Content_en AS Content_en
			,nex.Subject_ch + '<br/><br/>' + n.Content_ch AS Content_ch
			,nex.Subject_cs + '<br/><br/>' + n.Content_cs AS Content_cs
		FROM dbo.Notification AS n WITH (NOLOCK)
			INNER JOIN #tmpNotiExt AS ext ON n.NotificationID = ext.NotiID
			OUTER APPLY OPENJSON(n.Subject) WITH (
							Subject_en NVARCHAR(300) '$.Subject_en'
							,Subject_ch NVARCHAR(300) '$.Subject_ch'
							,Subject_cs NVARCHAR(300) '$.Subject_cs'
						) AS nex --OPENJSON case-sensitive
			INNER JOIN dbo.NotiStatus AS s WITH (NOLOCK) ON n.StatusID = s.StatusID
		WHERE ISJSON(n.Subject) = 1
	END
	
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
END