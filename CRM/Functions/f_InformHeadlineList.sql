ALTER FUNCTION [dbo].[f_InformHeadlineList] (@Currency VARCHAR(1000), @Level VARCHAR(10), @Site VARCHAR(4000), @TypeAccount TINYINT)
RETURNS @DirectAcc TABLE (
	[CustID] [INT],
	[GroupID] [INT] 
PRIMARY KEY CLUSTERED ([CustID])) 
AS 
/*	Created: Elodie
	Date: 20150414
	Task: Get Inform Headline
	DB: DBEXT/bodb02
	Revisions:	
	
*/
BEGIN
	DECLARE @tmpCurrency TABLE (currency INT)	
	DECLARE @tmpLevel TABLE (roleID TINYINT)	
	DECLARE @tmpSite TABLE (Site VARCHAR(50))	

	INSERT INTO @tmpCurrency
	SELECT val
	FROM strSplit (@Currency,',')

	INSERT INTO @tmpLevel
	SELECT val
	FROM strSplit (@Level,',')

	INSERT INTO @tmpSite
	SELECT s.SiteName
	FROM strSplit (@Site,',') v
		INNER JOIN bodb_CRM.dbo.crmSite s ON v.val = s.SiteID

	IF @TypeAccount = 1 OR @TypeAccount = 3
	BEGIN
		IF EXISTS (SELECT 1 FROM @tmpLevel WHERE roleID = 4)
			INSERT INTO @DirectAcc (CustID, GroupID)
			SELECT DISTINCT hl.custid, hl.groupID
			FROM dbo.custAccount hl WITH (NOLOCK)  
				INNER JOIN dbo.Customer ch WITH (NOLOCK) ON hl.custid = ch.custid
				INNER JOIN dbo.CustSuper cs WITH (NOLOCK) ON ch.custid = cs.custid
				INNER JOIN dbo.CustInfo cih WITH (NOLOCK) ON ch.custid = cih.custid				
				INNER JOIN dbo.custAccount m WITH (NOLOCK) ON hl.groupID = m.groupID
				INNER JOIN dbo.Customer cm WITH (NOLOCK) ON m.custid = cm.custid
				INNER JOIN dbo.CustInfo cim WITH (NOLOCK) ON cm.custid = cim.custid
				LEFT JOIN dbo.Customer cma WITH (NOLOCK) ON cm.recommend = cma.custid
			WHERE hl.IsGroupHeadLine = 1 
				AND ch.roleid = 4
				AND cs.IsInternal = 0
				AND ((cih.closed=0 AND ISNULL(cih.reject,0) = 0 AND cih.Enabled = 1 AND ch.currency IN (SELECT currency FROM @tmpCurrency) AND ch.site IN (SELECT Site FROM @tmpSite))
					OR (cim.closed=0 AND ISNULL(cim.reject,0) = 0 AND cim.Enabled = 1 AND cm.currency IN (SELECT currency FROM @tmpCurrency) AND (cm.site IN (SELECT Site FROM @tmpSite) OR cma.site IN (SELECT Site FROM @tmpSite))))
				AND hl.groupID > 0
		
		IF EXISTS (SELECT 1 FROM @tmpLevel WHERE roleID = 3)
			INSERT INTO @DirectAcc (CustID, GroupID)
			SELECT DISTINCT hl.custid, hl.groupID
			FROM dbo.custAccount hl WITH (NOLOCK)  
				INNER JOIN dbo.Customer ch WITH (NOLOCK) ON hl.custid = ch.custid
				INNER JOIN dbo.CustMaster cmaster WITH (NOLOCK) ON ch.custid = cmaster.custid
				INNER JOIN dbo.CustSuper cs WITH (NOLOCK) ON ch.srecommend = cs.custid
				INNER JOIN dbo.CustInfo cih WITH (NOLOCK) ON ch.custid = cih.custid				
				INNER JOIN dbo.custAccount m WITH (NOLOCK) ON hl.groupID = m.groupID
				INNER JOIN dbo.Customer cm WITH (NOLOCK) ON m.custid = cm.custid
				INNER JOIN dbo.CustInfo cim WITH (NOLOCK) ON cm.custid = cim.custid
				LEFT JOIN dbo.Customer cma WITH (NOLOCK) ON cm.recommend = cma.custid
			WHERE hl.IsGroupHeadLine = 1 
				AND ch.roleid = 3
				AND cs.IsInternal = 0 AND cmaster.IsInternal = 0
				AND ((cih.closed=0 AND ISNULL(cih.reject,0) = 0 AND cih.Enabled = 1 AND ch.currency IN (SELECT currency FROM @tmpCurrency) AND ch.site IN (SELECT Site FROM @tmpSite)) 
					OR (cim.closed=0 AND ISNULL(cim.reject,0) = 0 AND cim.Enabled = 1 AND cm.currency IN (SELECT currency FROM @tmpCurrency) AND (cm.site IN (SELECT Site FROM @tmpSite) OR cma.site IN (SELECT Site FROM @tmpSite))))
				AND hl.groupID > 0

		IF EXISTS (SELECT 1 FROM @tmpLevel WHERE roleID = 2)
			INSERT INTO @DirectAcc (CustID, GroupID)
			SELECT DISTINCT hl.custid, hl.groupID
			FROM dbo.custAccount hl WITH (NOLOCK)  
				INNER JOIN dbo.Customer ch WITH (NOLOCK) ON hl.custid = ch.custid
				INNER JOIN dbo.CustAgent ca WITH (NOLOCK) ON ch.custid = ca.custid
				INNER JOIN dbo.CustMaster cmaster WITH (NOLOCK) ON ch.mrecommend = cmaster.custid
				INNER JOIN dbo.CustSuper cs WITH (NOLOCK) ON ch.srecommend = cs.custid
				INNER JOIN dbo.CustInfo cih WITH (NOLOCK) ON ch.custid = cih.custid				
				INNER JOIN dbo.custAccount m WITH (NOLOCK) ON hl.groupID = m.groupID
				INNER JOIN dbo.Customer cm WITH (NOLOCK) ON m.custid = cm.custid
				INNER JOIN dbo.CustInfo cim WITH (NOLOCK) ON cm.custid = cim.custid
				LEFT JOIN dbo.Customer cma WITH (NOLOCK) ON cm.recommend = cma.custid
			WHERE hl.IsGroupHeadLine = 1 
				AND ch.roleid = 2
				AND cs.IsInternal = 0 AND cmaster.IsInternal = 0 AND ca.IsInternal = 0
				AND ((cih.closed=0 AND ISNULL(cih.reject,0) = 0 AND cih.Enabled = 1 AND ch.currency IN (SELECT currency FROM @tmpCurrency) AND ch.site IN (SELECT Site FROM @tmpSite)) 
					OR (cim.closed=0 AND ISNULL(cim.reject,0) = 0 AND cim.Enabled = 1 AND cm.currency IN (SELECT currency FROM @tmpCurrency) AND (cm.site IN (SELECT Site FROM @tmpSite) OR cma.site IN (SELECT Site FROM @tmpSite))))
				AND hl.groupID > 0

		IF EXISTS (SELECT 1 FROM @tmpLevel WHERE roleID = 1)
			INSERT INTO @DirectAcc (CustID, GroupID)
			SELECT DISTINCT hl.custid, hl.groupID
			FROM dbo.custAccount hl WITH (NOLOCK)  
				INNER JOIN dbo.Customer ch WITH (NOLOCK) ON hl.custid = ch.custid
				INNER JOIN dbo.CustAgent ca WITH (NOLOCK) ON ch.recommend = ca.custid
				INNER JOIN dbo.CustMaster cmaster WITH (NOLOCK) ON ch.mrecommend = cmaster.custid
				INNER JOIN dbo.CustSuper cs WITH (NOLOCK) ON ch.srecommend = cs.custid
				INNER JOIN dbo.CustInfo cih WITH (NOLOCK) ON ch.custid = cih.custid
				LEFT JOIN dbo.Customer cha WITH (NOLOCK) ON ch.recommend = cha.custid
				INNER JOIN dbo.custAccount m WITH (NOLOCK) ON hl.groupID = m.groupID
				INNER JOIN dbo.Customer cm WITH (NOLOCK) ON m.custid = cm.custid
				INNER JOIN dbo.CustInfo cim WITH (NOLOCK) ON cm.custid = cim.custid
				LEFT JOIN dbo.Customer cma WITH (NOLOCK) ON cm.recommend = cma.custid
			WHERE hl.IsGroupHeadLine = 1 
				AND ch.roleid = 1
				AND cs.IsInternal = 0 AND cmaster.IsInternal = 0 AND ca.IsInternal = 0
				AND ((cih.closed=0 AND ISNULL(cih.reject,0) = 0 AND cih.Enabled = 1 AND ch.currency IN (SELECT currency FROM @tmpCurrency) AND (ch.site IN (SELECT Site FROM @tmpSite) OR cha.site IN (SELECT Site FROM @tmpSite))) 
					OR (cim.closed=0 AND ISNULL(cim.reject,0) = 0 AND cim.Enabled = 1 AND cm.currency IN (SELECT currency FROM @tmpCurrency) AND (cm.site IN (SELECT Site FROM @tmpSite) OR cma.site IN (SELECT Site FROM @tmpSite))))
				AND hl.groupID > 0

	END

	IF @TypeAccount = 2 OR @TypeAccount = 3
	BEGIN
		IF EXISTS (SELECT 1 FROM @tmpLevel WHERE roleID = 4)
			INSERT INTO @DirectAcc (CustID, GroupID)
			SELECT DISTINCT c.CustID, 0
			FROM dbo.Customer c WITH (NOLOCK) 
				INNER JOIN dbo.CustInfo ci WITH (NOLOCK) ON c.custid = ci.custid
				INNER JOIN dbo.CustSuper cs WITH (NOLOCK) ON c.custid = cs.custid
			WHERE c.roleid = 4 
				AND cs.IsInternal = 0
				AND NOT EXISTS (SELECT 1 FROM dbo.Acc_CustDirect d1 WITH(NOLOCK) WHERE c.custid = d1.custid)
				AND NOT EXISTS (SELECT 1 FROM dbo.custAccount WITH (NOLOCK) WHERE custid = c.custid AND groupid > 0)
				AND c.currency IN (SELECT currency FROM @tmpCurrency) 
				AND c.site IN (SELECT Site FROM @tmpSite)
				AND ci.closed=0 AND ISNULL(ci.reject,0) = 0	AND ci.Enabled = 1

		IF EXISTS (SELECT 1 FROM @tmpLevel WHERE roleID = 3)
			INSERT INTO @DirectAcc (CustID, GroupID)
			SELECT c.CustID, 0
			FROM dbo.Customer c WITH (NOLOCK) 
				INNER JOIN dbo.CustInfo ci WITH (NOLOCK) ON c.custid = ci.custid
				INNER JOIN dbo.CustMaster cm WITH (NOLOCK) ON c.custid = cm.custid
				INNER JOIN dbo.Acc_CustDirect d WITH (NOLOCK) ON c.srecommend = d.custid 
				INNER JOIN dbo.CustSuper cs WITH (NOLOCK) ON c.srecommend = cs.custid
			WHERE c.roleid = 3 AND d.roleid = 4 
				AND cm.IsInternal = 0 AND cs.IsInternal = 0
				AND NOT EXISTS (SELECT 1 FROM dbo.Acc_CustDirect d1 WITH(NOLOCK) WHERE c.custid = d1.custid)
				AND NOT EXISTS (SELECT 1 FROM dbo.custAccount WITH (NOLOCK) WHERE custid = c.custid AND groupid > 0)
				AND c.currency IN (SELECT currency FROM @tmpCurrency) 
				AND c.site IN (SELECT Site FROM @tmpSite)
				AND ci.closed=0 AND ISNULL(ci.reject,0) = 0	AND ci.Enabled = 1

		IF EXISTS (SELECT 1 FROM @tmpLevel WHERE roleID = 2)
			INSERT INTO @DirectAcc (CustID, GroupID)
			SELECT c.CustID, 0
			FROM dbo.Customer c WITH (NOLOCK) 
				INNER JOIN dbo.CustInfo ci WITH (NOLOCK) ON c.custid = ci.custid
				INNER JOIN dbo.CustAgent ca WITH (NOLOCK) ON c.custid = ca.custid
				INNER JOIN dbo.Acc_CustDirect d WITH (NOLOCK) ON c.mrecommend = d.custid 
				INNER JOIN dbo.CustSuper cs WITH (NOLOCK) ON c.srecommend = cs.custid 
				INNER JOIN dbo.CustMaster cm WITH (NOLOCK) ON c.mrecommend = cm.custid 
			WHERE c.roleid = 2 AND d.roleid = 3 
				AND ca.IsInternal = 0 AND cs.IsInternal = 0 AND cm.IsInternal = 0
				AND NOT EXISTS (SELECT 1 FROM dbo.Acc_CustDirect d1 WITH(NOLOCK) WHERE c.custid = d1.custid)
				AND NOT EXISTS (SELECT 1 FROM dbo.custAccount WITH (NOLOCK) WHERE custid = c.custid AND groupid > 0)
				AND c.currency IN (SELECT currency FROM @tmpCurrency) 
				AND c.site IN (SELECT Site FROM @tmpSite)
				AND ci.closed=0 AND ISNULL(ci.reject,0) = 0	AND ci.Enabled = 1

		IF EXISTS (SELECT 1 FROM @tmpLevel WHERE roleID = 1)
			INSERT INTO @DirectAcc (CustID, GroupID)
			SELECT c.CustID, 0
			FROM dbo.Customer c WITH (NOLOCK) 
				INNER JOIN dbo.CustInfo ci WITH (NOLOCK) ON c.custid = ci.custid
				INNER JOIN dbo.Acc_CustDirect d WITH (NOLOCK) ON c.recommend = d.custid 
				INNER JOIN dbo.Customer ca WITH (NOLOCK) ON c.recommend = ca.custid
				INNER JOIN dbo.CustSuper cs WITH (NOLOCK) ON c.srecommend = cs.custid 
				INNER JOIN dbo.CustMaster cm WITH (NOLOCK) ON c.mrecommend = cm.custid 
				INNER JOIN dbo.CustAgent cagent WITH (NOLOCK) ON c.recommend = cagent.custid 
			WHERE c.roleid = 1 AND d.roleid = 2
				AND cs.IsInternal = 0 AND cm.IsInternal = 0 AND cagent.IsInternal = 0 
				AND NOT EXISTS (SELECT 1 FROM dbo.Acc_CustDirect d1 WITH(NOLOCK) WHERE c.custid = d1.custid)
				AND NOT EXISTS (SELECT 1 FROM dbo.custAccount WITH (NOLOCK) WHERE custid = c.custid AND groupid > 0)
				AND c.currency IN (SELECT currency FROM @tmpCurrency) 
				AND ca.site IN (SELECT Site FROM @tmpSite)
				AND ci.closed=0 AND ISNULL(ci.reject,0) = 0	AND ci.Enabled = 1
	END		
	RETURN
END

GO 
GRANT SELECT ON [dbo].[f_InformHeadlineList] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[f_InformHeadlineList] TO [vnteam] AS [dbo]