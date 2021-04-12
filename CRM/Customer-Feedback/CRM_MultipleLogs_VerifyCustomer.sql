/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[CRM_MultipleLogs_VerifyCustomer] @Username NVARCHAR(MAX) = ''
AS
/*
Created: 20200303@Tim
Task : Support "is related customers" function in Create Multiple Logs
DB: DBCRM/bodb_CRM
Original:

Revisions:
	20200303@Tim: Support "is related customers" function in Create Multiple Logs - RedmineId: #129144
	202010315@Winfred: get related customer when not guest [Redmine: #112637]	
Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @tblCustomer TABLE (Username VARCHAR(50))
	CREATE TABLE #tblDirectCustomer (CustId INT PRIMARY KEY)
	CREATE TABLE #tblResult (
		HeadlineId INT
		,Headline VARCHAR(50)
		,CustId INT
		,Username VARCHAR(50)
		,IsHeadline BIT
		,IsDirectAccount BIT
		)

	INSERT INTO @tblCustomer (Username)
	SELECT ltrim(rtrim(val))
	FROM dbo.f_CRM_strSplit(@Username, ',')

	-- super not belong to any group headline
	INSERT INTO #tblDirectCustomer (CustId)
	SELECT c.custid
	FROM bodb02.dbo.Customer AS c WITH (NOLOCK)
		INNER JOIN bodb02.dbo.CustSuper AS cs WITH (NOLOCK) ON c.custid = cs.custid
		AND cs.IsInternal = 0
		AND c.roleid = 4
	WHERE EXISTS (
			SELECT 1
			FROM @tblCustomer AS tbl
			WHERE c.username = tbl.Username
			)
		AND NOT EXISTS (
			SELECT 1
			FROM bodb02.dbo.custAccount AS ca WITH (NOLOCK)
			WHERE ca.custid = c.custid AND ca.groupId <> 0
			)
		AND NOT EXISTS (
			SELECT 1
			FROM bodb02.dbo.Acc_CustDirect AS cd WITH (NOLOCK)
			WHERE cd.custid = c.custid
		)

	-- direct master, agent, member
	INSERT INTO #tblDirectCustomer (CustId)
	SELECT ci.custid
	FROM bodb02.dbo.custInfo AS ci WITH (NOLOCK)
		INNER JOIN bodb02.dbo.CustDirectAccount AS d WITH (NOLOCK) ON ci.custid = d.custid
	WHERE EXISTS (
			SELECT 1
			FROM @tblCustomer AS tbl
			WHERE ci.username = tbl.Username
			)
		AND NOT EXISTS (
			SELECT 1
			FROM #tblDirectCustomer AS tbl WITH (NOLOCK)
			WHERE ci.custid = tbl.CustId
			)
		AND NOT EXISTS (
			SELECT 1
			FROM bodb02.dbo.custAccount AS ca WITH (NOLOCK)
			WHERE ca.custid = ci.custid AND ca.groupId <> 0
			)
		AND NOT EXISTS (
			SELECT 1
			FROM bodb02.dbo.CustMaster AS cm WITH (NOLOCK)
			WHERE ci.custid = cm.custid AND cm.IsInternal = 1
			)
		AND NOT EXISTS (
			SELECT 1
			FROM bodb02.dbo.CustAgent AS ca WITH (NOLOCK)
			WHERE (ci.custid = ca.custid OR ci.recommend = ca.custid) AND ca.IsInternal = 1
			)

	INSERT INTO #tblResult (
		HeadlineId
		,Headline
		,CustId
		,Username
		,IsHeadline
		,IsDirectAccount
		)
	SELECT gh.CustId AS HeadlineId
		,gh.username AS Headline
		,c.custid
		,c.username
		,CASE WHEN gh.custid = c.custid THEN 1 ELSE 0 END
		,CASE WHEN da.CustId IS NOT NULL THEN 1 ELSE 0 END
	FROM bodb02.dbo.custAccount AS ca WITH (NOLOCK)
		INNER JOIN bodb02.dbo.Customer AS c WITH (NOLOCK) ON c.custid = ca.custid
		OUTER APPLY (
			SELECT gh.custid, ghi.username
			FROM bodb02.dbo.custAccount AS gh WITH (NOLOCK)
				INNER JOIN bodb02.dbo.Customer AS ghi WITH (NOLOCK) ON gh.custid = ghi.custid
			WHERE ca.groupId = gh.groupId AND gh.IsGroupHeadLine = 1
		) AS gh
		LEFT JOIN #tblDirectCustomer AS da WITH (NOLOCK) ON c.custid = da.CustId
	WHERE ISNULL(c.[site], '') <> 'CN88'
		AND EXISTS (
			SELECT 1
			FROM @tblCustomer AS tbl
			WHERE tbl.Username = c.username
			)
	UNION
	SELECT NULL AS HeadlineId
		,NULL AS Headline
		,c.custid
		,c.username
		,0
		,CASE  WHEN da.CustId IS NOT NULL THEN 1 ELSE 0 END
	FROM bodb02.dbo.Customer AS c WITH (NOLOCK)
		LEFT JOIN #tblDirectCustomer AS da WITH (NOLOCK) ON c.custid = da.CustId
	WHERE ISNULL(c.[site], '') <> 'CN88'
		AND EXISTS (
			SELECT 1
			FROM @tblCustomer AS tbl
			WHERE tbl.Username = c.username
			)
		AND NOT EXISTS (
			SELECT 1
			FROM bodb02.dbo.custAccount AS ca WITH (NOLOCK)
			WHERE c.custid = ca.custid
			)

	INSERT INTO #tblResult (CustId, Username)
	SELECT CustId,Username
	FROM (
	SELECT c.CustId, c.Username , ROW_NUMBER() OVER (Order by CustId DESC) AS ROWNUM
	FROM dbo.crmCustomer AS c WITH (NOLOCK)
	WHERE c.SiteId <> 33002
		AND EXISTS (
			SELECT 1
			FROM @tblCustomer AS tbl
			WHERE tbl.Username = c.Username
			)
	) KQ 
	WHERE KQ .ROWNUM = 1
	ORDER BY KQ.Username,KQ.CustId		

	INSERT INTO #tblResult (CustId, Username)
	SELECT 0, c.Username
	FROM @tblCustomer AS c
	WHERE NOT EXISTS (
			SELECT 1
			FROM #tblResult AS tbl WITH (NOLOCK)
			WHERE tbl.Username = c.Username
			)
	
	--hardcode reset hl for ETUS
	IF EXISTS(SELECT 1 FROM @tblCustomer 
			WHERE username IN ('ETUS')
			)
	BEGIN
		UPDATE t
		SET IsHeadline = 0
		FROM #tblResult	 t
		WHERE username IN ('ETUS')
	END	
	
	--Hardcode headline incase username in ('ET789','ET889','XT')	
	IF EXISTS(SELECT 1 FROM @tblCustomer 
			WHERE username IN ('ET789','ET889','XT')
			)
	BEGIN
		UPDATE t
		SET HeadlineID = custid,
			Headline = 'ETUS('+username+')',
			IsHeadline = 1
		FROM #tblResult	 t
		WHERE username IN ('ET789','ET889','XT')
	END	
	
	SELECT HeadlineId
		,Headline
		,CustId
		,Username
		,IsHeadline
		,IsDirectAccount
	FROM #tblResult WITH (NOLOCK)
	ORDER BY Username

	DROP TABLE #tblResult
	DROP TABLE #tblDirectCustomer
END
