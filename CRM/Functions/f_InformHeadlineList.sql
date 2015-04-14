ALTER FUNCTION f_InformHeadlineList (@Currency VARCHAR(1000), @Level VARCHAR(10), @Site VARCHAR(4000), @TypeAccount TINYINT)
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
	SELECT val
	FROM strSplit (@Site,',')

	IF @TypeAccount = 1 OR @TypeAccount = 3
	BEGIN
	INSERT INTO @DirectAcc (CustID, GroupID)
	SELECT DISTINCT hl.custid, hl.groupID
	FROM bodb02.dbo.custAccount hl WITH (NOLOCK)  
		INNER JOIN bodb02.dbo.Customer ch WITH (NOLOCK) ON hl.custid = ch.custid
		INNER JOIN bodb02.dbo.CustInfo cih WITH (NOLOCK) ON ch.custid = cih.custid
		INNER JOIN bodb02.dbo.custAccount m WITH (NOLOCK) ON hl.groupID = m.groupID
		INNER JOIN bodb02.dbo.Customer cm WITH (NOLOCK) ON m.custid = cm.custid
		INNER JOIN bodb02.dbo.CustInfo cim WITH (NOLOCK) ON cm.custid = cim.custid
	WHERE hl.IsGroupHeadLine = 1 
		AND m.IsGroupHeadLine = 0 
		AND ch.roleid IN (SELECT roleID FROM @tmpLevel)
		AND (ch.currency IN (SELECT currency FROM @tmpCurrency) OR cm.currency IN (SELECT currency FROM @tmpCurrency)) 
		AND (ch.site IN (SELECT Site FROM @tmpSite) OR cm.site IN (SELECT Site FROM @tmpSite))
		AND ((cih.closed=0 AND ISNULL(cih.reject,0) = 0 AND cih.Enabled = 1) OR (cim.closed=0 AND ISNULL(cim.reject,0) = 0) AND cim.Enabled = 1)
		AND hl.groupID > 0
	END

	IF @TypeAccount = 2 OR @TypeAccount = 3
	BEGIN
		IF EXISTS (SELECT 1 FROM @tmpLevel WHERE roleID = 4)
			INSERT INTO @DirectAcc (CustID, GroupID)
			SELECT c.CustID, 0
			FROM bodb02.dbo.Customer c WITH (NOLOCK) 
				INNER JOIN bodb02.dbo.CustInfo ci WITH (NOLOCK) ON c.custid = ci.custid
			WHERE c.roleid = 4
				AND NOT EXISTS (SELECT 1 FROM dbo.Acc_CustDirect d1 WITH(NOLOCK) WHERE c.custid = d1.custid)
				AND NOT EXISTS (SELECT 1 FROM bodb02.dbo.custAccount WITH (NOLOCK) WHERE custid = c.custid AND groupid > 0)
				AND c.currency IN (SELECT currency FROM @tmpCurrency) 
				AND c.site IN (SELECT Site FROM @tmpSite)
				AND ci.closed=0 AND ISNULL(ci.reject,0) = 0	AND ci.Enabled = 1

		IF EXISTS (SELECT 1 FROM @tmpLevel WHERE roleID = 3)
			INSERT INTO @DirectAcc (CustID, GroupID)
			SELECT c.CustID, 0
			FROM bodb02.dbo.Customer c WITH (NOLOCK) 
				INNER JOIN bodb02.dbo.CustInfo ci WITH (NOLOCK) ON c.custid = ci.custid
				INNER JOIN bodb02.dbo.Acc_CustDirect d WITH (NOLOCK) ON c.srecommend = d.custid 
			WHERE c.roleid = 3 AND d.roleid = 4
				AND NOT EXISTS (SELECT 1 FROM dbo.Acc_CustDirect d1 WITH(NOLOCK) WHERE c.custid = d1.custid)
				AND NOT EXISTS (SELECT 1 FROM bodb02.dbo.custAccount WITH (NOLOCK) WHERE custid = c.custid AND groupid > 0)
				AND c.currency IN (SELECT currency FROM @tmpCurrency) 
				AND c.site IN (SELECT Site FROM @tmpSite)
				AND ci.closed=0 AND ISNULL(ci.reject,0) = 0	AND ci.Enabled = 1

		IF EXISTS (SELECT 1 FROM @tmpLevel WHERE roleID = 2)
			INSERT INTO @DirectAcc (CustID, GroupID)
			SELECT c.CustID, 0
			FROM bodb02.dbo.Customer c WITH (NOLOCK) 
				INNER JOIN bodb02.dbo.CustInfo ci WITH (NOLOCK) ON c.custid = ci.custid
				INNER JOIN bodb02.dbo.Acc_CustDirect d WITH (NOLOCK) ON c.srecommend = d.custid 
			WHERE c.roleid = 2 AND d.roleid = 3
				AND NOT EXISTS (SELECT 1 FROM dbo.Acc_CustDirect d1 WITH(NOLOCK) WHERE c.custid = d1.custid)
				AND NOT EXISTS (SELECT 1 FROM bodb02.dbo.custAccount WITH (NOLOCK) WHERE custid = c.custid AND groupid > 0)
				AND c.currency IN (SELECT currency FROM @tmpCurrency) 
				AND c.site IN (SELECT Site FROM @tmpSite)
				AND ci.closed=0 AND ISNULL(ci.reject,0) = 0	AND ci.Enabled = 1

		IF EXISTS (SELECT 1 FROM @tmpLevel WHERE roleID = 1)
			INSERT INTO @DirectAcc (CustID, GroupID)
			SELECT c.CustID, 0
			FROM bodb02.dbo.Customer c WITH (NOLOCK) 
				INNER JOIN bodb02.dbo.CustInfo ci WITH (NOLOCK) ON c.custid = ci.custid
				INNER JOIN bodb02.dbo.Acc_CustDirect d WITH (NOLOCK) ON c.srecommend = d.custid 
			WHERE c.roleid = 1 AND d.roleid = 2
				AND NOT EXISTS (SELECT 1 FROM dbo.Acc_CustDirect d1 WITH(NOLOCK) WHERE c.custid = d1.custid)
				AND NOT EXISTS (SELECT 1 FROM bodb02.dbo.custAccount WITH (NOLOCK) WHERE custid = c.custid AND groupid > 0)
				AND c.currency IN (SELECT currency FROM @tmpCurrency) 
				AND c.site IN (SELECT Site FROM @tmpSite)
				AND ci.closed=0 AND ISNULL(ci.reject,0) = 0	AND ci.Enabled = 1
	END		
	RETURN
END
