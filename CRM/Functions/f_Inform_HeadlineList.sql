/*<info serverAlias="DBCRM-bodb_CRM" selectors="bodbAdminNet" viewers="" isFunction="1"></info>*/
ALTER FUNCTION [dbo].[f_Inform_HeadlineList] (@Currency VARCHAR(1000), @Level VARCHAR(10), @Site VARCHAR(4000), @TypeAccount TINYINT)
RETURNS @DirectAcc TABLE (
	[CustID] [INT],
	[Username] VARCHAR(30),
	[GroupID] [INT] 
PRIMARY KEY CLUSTERED ([CustID])) 
AS 
/*	Created: Winnie
	Date: 20190729
	Task: Get Inform Headline
	DB: DBCRM/bodb_CRM
	Revisions:	
		- 20190311@Winnie: CRM - Enhance Inform Headline [RedmineID:#109775]	
		- 20200910@Johnson: get hl has account belong to active currency [redmine:#141329]
*/
BEGIN
	DECLARE @tmpCurrency TABLE (currency INT)	
	DECLARE @tmpLevel TABLE (roleID TINYINT)	
	DECLARE @tmpSite TABLE (Site VARCHAR(50))	

	INSERT INTO @tmpCurrency
	SELECT val
	FROM f_split (@Currency,',')

	INSERT INTO @tmpLevel
	SELECT val
	FROM f_split (@Level,',')

	IF EXISTS(SELECT TOP 1 1 FROM @tmpLevel WHERE roleID=0)
	BEGIN
		INSERT INTO @DirectAcc (CustID, GroupID,[Username])
		SELECT c.CustID, 0,ci.username
		FROM crmCustomer c WITH (NOLOCK) 
			INNER JOIN bodb02.dbo.custInfo ci WITH (NOLOCK) ON c.custid = ci.custid		
		WHERE  ci.srecommend IS NULL AND ci.roleid > 4 

		DELETE FROM @tmpLevel WHERE roleID=0
	END
	INSERT INTO @tmpSite
	SELECT s.SiteName
	FROM f_split (@Site,',') v
		INNER JOIN dbo.crmSite s ON v.val = s.SiteID

	IF EXISTS(SELECT TOP 1 1 FROM @tmpLevel WHERE roleID=1)
	BEGIN
		IF @TypeAccount = 1 OR @TypeAccount = 3
		BEGIN			
			INSERT INTO @DirectAcc (CustID, GroupID,[Username])	
			SELECT DISTINCT hl.custid, hl.groupID,ch.username
			FROM bodb02.dbo.custAccount hl WITH (NOLOCK)  
				INNER JOIN bodb02.dbo.Customer ch WITH (NOLOCK) ON hl.custid = ch.custid
				INNER JOIN bodb02.dbo.Customer agent WITH (NOLOCK) ON agent.custid = ch.recommend
				INNER JOIN bodb02.dbo.CustAgent ca WITH(NOLOCK) ON agent.custid=ca.custid AND ca.IsInternal=0
			WHERE hl.IsGroupHeadLine=1 AND ch.roleid=1 
				AND agent.site IN (SELECT Site FROM @tmpSite)
				AND EXISTS(SELECT TOP 1 1 
							FROM bodb02.dbo.custAccount g WITH(NOLOCK) 
								INNER JOIN bodb02.dbo.Custinfo ci WITH(NOLOCK) ON g.custid=ci.custid
								CROSS APPLY  (	SELECT CASE WHEN CloseInfo > 0 THEN 1 ELSE 0 END AS closed
													, CASE WHEN SuspendInfo > 0 THEN 1 ELSE 0 END AS reject
												FROM bodb02.dbo.CustProductStatus  WITH(NOLOCK)
												WHERE CustID = ci.custid
											) AS cs	
							WHERE hl.groupID=g.groupID 
								AND cs.closed=0 AND cs.reject = 0 AND ci.Enabled = 1
								--AND ci.closed=0 AND ISNULL(ci.reject,0) = 0 AND ci.Enabled = 1
								AND ci.currency IN (SELECT currency FROM @tmpCurrency)
						)
			
		END

		IF @TypeAccount = 2 OR @TypeAccount = 3
		BEGIN	
			INSERT INTO @DirectAcc (CustID, GroupID,[Username])
			SELECT c.CustID, 0,ci.username
			FROM bodb02.dbo.CustDirectAccount c WITH (NOLOCK) 
				INNER JOIN bodb02.dbo.custInfo ci WITH (NOLOCK) ON c.custid = ci.custid						
				INNER JOIN bodb02.dbo.Customer agent WITH (NOLOCK) ON agent.custid = ci.recommend	
				INNER JOIN bodb02.dbo.CustAgent ca WITH(NOLOCK) ON agent.custid=ca.custid AND ca.IsInternal=0
				CROSS APPLY  (	SELECT CASE WHEN CloseInfo > 0 THEN 1 ELSE 0 END AS closed
									, CASE WHEN SuspendInfo > 0 THEN 1 ELSE 0 END AS reject
								FROM bodb02.dbo.CustProductStatus  WITH(NOLOCK)
								WHERE CustID = ci.custid
							) AS cs	
			WHERE 
				ci.currency IN (SELECT currency FROM @tmpCurrency) 
				AND ci.roleid=1
				AND agent.site IN (SELECT Site FROM @tmpSite)
				AND cs.closed=0 AND cs.reject = 0 AND ci.Enabled = 1
				--AND ci.closed=0 AND ISNULL(ci.reject,0) = 0	AND ci.Enabled = 1
				AND NOT EXISTS (SELECT 1 FROM bodb02.dbo.custAccount WITH (NOLOCK) WHERE custid = c.custid AND groupid > 0)
		END		
		DELETE FROM @tmpLevel WHERE roleID=1
	END

	IF @TypeAccount = 1 OR @TypeAccount = 3
	BEGIN			
		INSERT INTO @DirectAcc (CustID, GroupID,[Username])	
		SELECT DISTINCT hl.custid, hl.groupID,ch.username
		FROM bodb02.dbo.custAccount hl WITH (NOLOCK)  
			INNER JOIN bodb02.dbo.Customer ch WITH (NOLOCK) ON hl.custid = ch.custid
			INNER JOIN @tmpLevel t ON ch.roleid= t.roleID
		WHERE hl.IsGroupHeadLine=1 
			AND ch.site IN (SELECT Site FROM @tmpSite)
			AND EXISTS(SELECT TOP 1 1 
						FROM bodb02.dbo.custAccount g WITH(NOLOCK) 
							INNER JOIN bodb02.dbo.Custinfo ci WITH(NOLOCK) ON g.custid=ci.custid
							CROSS APPLY  (	SELECT CASE WHEN CloseInfo > 0 THEN 1 ELSE 0 END AS closed
												, CASE WHEN SuspendInfo > 0 THEN 1 ELSE 0 END AS reject
											FROM bodb02.dbo.CustProductStatus  WITH(NOLOCK)
											WHERE CustID = ci.custid
										) AS cs	
						 WHERE hl.groupID=g.groupID 
							AND cs.closed=0 AND cs.reject = 0 AND ci.Enabled = 1
							--AND ci.closed=0 AND ISNULL(ci.reject,0) = 0 AND ci.Enabled = 1
							AND	ci.currency IN (SELECT currency FROM @tmpCurrency) 
						)
			AND NOT EXISTS(SELECT TOP 1 1 FROM bodb02.dbo.CustSuper cs WITH(NOLOCK) WHERE hl.custid=cs.custid AND cs.IsInternal=1)
			AND NOT EXISTS(SELECT TOP 1 1 FROM bodb02.dbo.CustMaster cs WITH(NOLOCK) WHERE hl.custid=cs.custid AND cs.IsInternal=1)
			AND NOT EXISTS(SELECT TOP 1 1 FROM bodb02.dbo.CustAgent cs WITH(NOLOCK) WHERE hl.custid=cs.custid AND cs.IsInternal=1)
	END

	IF @TypeAccount = 2 OR @TypeAccount = 3
	BEGIN	
		INSERT INTO @DirectAcc (CustID, GroupID,[Username])
		SELECT c.CustID, 0,ci.username
		FROM bodb02.dbo.CustDirectAccount c WITH (NOLOCK) 
			INNER JOIN bodb02.dbo.custInfo ci WITH (NOLOCK) ON c.custid = ci.custid			
			INNER JOIN bodb02.dbo.Customer co WITH (NOLOCK) ON co.custid = ci.custid				
			INNER JOIN @tmpLevel t ON ci.roleid=t.roleID		
			CROSS APPLY  (	SELECT CASE WHEN CloseInfo > 0 THEN 1 ELSE 0 END AS closed
								, CASE WHEN SuspendInfo > 0 THEN 1 ELSE 0 END AS reject
							FROM bodb02.dbo.CustProductStatus  WITH(NOLOCK)
							WHERE CustID = ci.custid
						) AS cs	
		WHERE 
			co.currency IN (SELECT currency FROM @tmpCurrency) 
			AND co.site IN (SELECT Site FROM @tmpSite)
			AND cs.closed=0 AND cs.reject = 0 AND ci.Enabled = 1
			--AND ci.closed=0 AND ISNULL(ci.reject,0) = 0	AND ci.Enabled = 1
			AND NOT EXISTS (SELECT 1 FROM bodb02.dbo.custAccount WITH (NOLOCK) WHERE custid = c.custid AND groupid > 0)
			AND NOT EXISTS(SELECT TOP 1 1 FROM bodb02.dbo.CustSuper cs WITH(NOLOCK) WHERE c.custid=cs.custid AND cs.IsInternal=1)
			AND NOT EXISTS(SELECT TOP 1 1 FROM bodb02.dbo.CustMaster cs WITH(NOLOCK) WHERE c.custid=cs.custid AND cs.IsInternal=1)
			AND NOT EXISTS(SELECT TOP 1 1 FROM bodb02.dbo.CustAgent cs WITH(NOLOCK) WHERE c.custid=cs.custid AND cs.IsInternal=1)
	END		
	RETURN
END

