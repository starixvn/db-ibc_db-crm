/*<info serverAlias="DBEXT-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_GroupHeadlineVipSel]
	@custids VARCHAR(MAX) 
AS
/*
	Created: 20211207@Winfred
	Task : Get headline And IsVip for list customers 
	DB: DBEXT-bodb02
	Original: Acc_CRM_GroupHeadlineSel

	Revisions:
		- 20211207@Winfred: Initial sp [redmine:#130949]
		- 20230223@Tacy: CRM - Split 789y site [redmineID: #182438]

	Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @tblCust TABLE (custid INT, 
							srecommend INT,
							mrecommend INT, 
							recommend INT,
							GroupName VARCHAR(50),
							HeadlineID INT,
							HeadlineName VARCHAR(50),
							site	varchar(10),
							IsVip BIT)
		
	CREATE TABLE #GroupHeadline
	(
		GroupID			SMALLINT PRIMARY KEY,
		CustID			INT
	)
	
	INSERT INTO @tblCust(custid)
	SELECT val
	FROM strSplit (@custids,',')
	
	UPDATE t
	SET t.srecommend = c.srecommend,
		t.mrecommend = c.mrecommend,
		t.recommend = c.recommend
	FROM @tblCust t 
		INNER JOIN customer c WITH(NOLOCK) ON t.custid = c.custid
		
	-- Update headline
	INSERT INTO #GroupHeadline (GroupID, CustID)
	SELECT ca.GroupID, t.CustID
	FROM dbo.custAccount ca WITH (NOLOCK)
		INNER JOIN dbo.CustGroupHeadline t WITH (NOLOCK) ON t.GroupID = ca.GroupID AND ca.custid = t.CustID
	WHERE ca.IsGroupHeadLine = 1
	
	UPDATE t
	SET t.HeadlineID = hed.CustID
	FROM @tblCust t	
		INNER JOIN custAccount ca WITH (NOLOCK) ON t.srecommend = ca.custid -- super
		INNER JOIN #GroupHeadline hed WITH (NOLOCK) ON ca.groupID = hed.groupID

	UPDATE t
	SET t.HeadlineID = hed.CustID
	FROM @tblCust t
		INNER JOIN custAccount ca WITH (NOLOCK) ON t.mrecommend = ca.custid -- master
		INNER JOIN #GroupHeadline hed WITH (NOLOCK) ON ca.groupID = hed.groupID
	WHERE t.HeadlineID IS NULL

	UPDATE t
	SET t.HeadlineID = hed.CustID
	FROM @tblCust t	
		INNER JOIN custAccount ca WITH (NOLOCK) ON t.recommend = ca.custid -- agent
		INNER JOIN #GroupHeadline hed WITH (NOLOCK) ON ca.groupID = hed.groupID
	WHERE t.HeadlineID IS NULL

	UPDATE t
	SET t.HeadlineID = hed.CustID
	FROM @tblCust t	
		INNER JOIN custAccount ca WITH (NOLOCK) ON t.custid = ca.custid -- member
		INNER JOIN #GroupHeadline hed WITH (NOLOCK) ON ca.groupID = hed.groupID
	WHERE t.HeadlineID IS NULL
		
	UPDATE t
	SET HeadlineName = c.username , t.site = c.site	
	FROM @tblCust t
		INNER JOIN customer c WITH(NOLOCK) ON t.HeadlineID = c.custid
			
	--check for ETUS
	IF EXISTS(SELECT 1 FROM @tblCust WHERE HeadlineName = 'ETUS')
	BEGIN
		--update groupname follow by super
		UPDATE t
		SET t.groupname = cg.GroupName
		FROM @tblCust t
			INNER JOIN Acc_CustGroup cg WITH(NOLOCK) ON t.srecommend = cg.custid
		WHERE cg.GroupName IN ('ACCYEN668','ACCYEN789','ACCYEN889')
		
		--Change hl to ET789, ET889
		;WITH tmpGroup AS (
			SELECT c.custid, c.username, c.site, g.GroupName				
			FROM customer c WITH(NOLOCK)
			INNER JOIN (SELECT 'ET789' username, 'ACCYEN668' GroupName
					UNION ALL SELECT 'ET789', 'ACCYEN789'
					UNION ALL SELECT 'ET889', 'ACCYEN889'					
				)g ON c.username = g.username			
		)
		UPDATE t
		SET t.HeadlineId = gr.custid,
			t.HeadlineName = gr.username,
			t.site = gr.site
		FROM @tblCust t
			INNER JOIN tmpGroup gr ON gr.GroupName = t.GroupName
		
		--change hl for other customers under ETUS to XT
		UPDATE t
		SET t.HeadlineID = c.custid,
			t.HeadlineName = c.username,
			t.site = c.site
		FROM @tblCust t
			CROSS APPLY (SELECT custid, username , site FROM customer WITH(NOLOCK) WHERE username = 'XT') c
		WHERE HeadlineName = 'ETUS'
	END
	
	--check for customer without group, assign to direct customer
	IF EXISTS(SELECT TOP (1) 1 FROM @tblCust WHERE headlineID IS NULL)
	BEGIN
		--hl is super
		UPDATE t
		SET t.headlineID = c.custid,
			t.HeadlineName = c.username,
			t.site = c.site
		FROM @tblCust t
			CROSS APPLY (SELECT custid,username , site FROM customer c WITH(NOLOCK) WHERE c.custid = t.srecommend)c
		WHERE headlineID IS NULL
			AND NOT EXISTS(SELECT 1 
						FROM Acc_CustDirect c WITH(NOLOCK)
						WHERE t.srecommend = c.custid
						)
			AND NOT EXISTS(SELECT 1 
						FROM Acc_CustDirect c WITH(NOLOCK)
						WHERE t.mrecommend = c.custid
						)
			AND NOT EXISTS(SELECT 1 
						FROM Acc_CustDirect c WITH(NOLOCK)
						WHERE t.recommend = c.custid
						)
						
		--hl is direct master
		UPDATE t
		SET t.headlineID = c.custid,
			t.HeadlineName = c.username,
			t.site = c.site
		FROM @tblCust t
			CROSS APPLY (SELECT custid,username, site FROM customer c WITH(NOLOCK) WHERE c.custid = t.mrecommend)c
		WHERE headlineID IS NULL
			AND NOT EXISTS(SELECT 1 
						FROM Acc_CustDirect c WITH(NOLOCK)
						WHERE t.mrecommend = c.custid
						)	
			AND NOT EXISTS(SELECT 1 
						FROM Acc_CustDirect c WITH(NOLOCK)
						WHERE t.recommend = c.custid
						)
						
		--hl is direct agent
		UPDATE t
		SET t.headlineID = c.custid,
			t.HeadlineName = c.username,
			t.site = c.site
		FROM @tblCust t
			CROSS APPLY (SELECT custid,username, site FROM customer c WITH(NOLOCK) WHERE c.custid = t.recommend)c
		WHERE headlineID IS NULL
			AND NOT EXISTS(SELECT 1 
						FROM Acc_CustDirect c WITH(NOLOCK)
						WHERE t.recommend = c.custid
						)
							
		--hl is direct member
		UPDATE t
		SET t.headlineID = c.custid,
			t.HeadlineName = c.username,
			t.site = c.site
		FROM @tblCust t
			CROSS APPLY (SELECT custid,username, site FROM customer c WITH(NOLOCK) WHERE c.custid = t.custid)c
		WHERE headlineID IS NULL
			AND NOT EXISTS(SELECT 1 
						FROM Acc_CustDirect c WITH(NOLOCK)
						WHERE t.custid = c.custid
						)					
	END
	-- Check IsVip
	UPDATE t
	SET t.IsVip = ISNULL(hl.IsVip,0)
	FROM @tblCust t
		LEFT JOIN bodb_CRM.dbo.crmCustomer hl WITH(NOLOCK) ON t.HeadlineID = hl.custid
	
	SELECT custid,		
		HeadlineID,
		HeadlineName,
		c.site,
		s.SiteLabel,
		IsVip
	FROM @tblCust c
	INNER JOIN bodb02.dbo.Site s WITH (NOLOCK) ON s.site=c.site
	
	DROP TABLE #GroupHeadline
END	