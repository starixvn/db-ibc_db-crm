/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE [dbo].[Acc_CRM_CustomerGetUplineList]
(
	@CustID		INT				= NULL,
	@UserName	NVARCHAR(50)	= NULL,
	@UserRole   TINYINT
)
AS
/*
	Created: Lukas
	Date: 20101118
	Task : get customer upline list
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20140303@Dom: Modify for new structure
		- 20180910@Winnie: Show headline [RedmineID: #99982]
		- 201810107@Winnie: Fix bug Show headline [RedmineID: #102925]
		- 20190506@Winnie: CN88 Permission RedmineID: #112637
		- 20190708@Elodie: Get CN88's customer status [RedmineId: #112637]

	Param's Explanation:	
*/
BEGIN	
	SET NOCOUNT ON

	DECLARE @srecommend INT,@mrecommend INT,@recommend INT

	SELECT @srecommend=srecommend,@mrecommend=mrecommend,@recommend=recommend
	FROM bodb02.dbo.custinfo c WITH(NOLOCK) 
	WHERE c.CustID = @CustID

	CREATE TABLE #SuperCN88(CustID INT PRIMARY KEY)
	INSERT INTO #SuperCN88(CustID)
	SELECT CustID FROM bodb02.dbo.CustSuper WITH(NOLOCK) 
	WHERE UplineId IS NOT NULL

	SELECT s.UserName, s.CustID, s.roleid,
			CASE WHEN s.Closed = 0 and ISNULL(s.reject,0) = 0 THEN 1 ELSE 0 END Active,
			CASE WHEN s.Closed = 1 THEN 1 ELSE 0 END Closed,
			CASE WHEN ISNULL(s.reject,0) = 1 and s.Closed = 0 THEN 1 ELSE 0 END Suspended
	FROM
		bodb02.dbo.custinfo c WITH(NOLOCK) 
			INNER JOIN bodb02.dbo.custinfo s WITH(NOLOCK) ON c.srecommend = s.CustID
	WHERE
		c.CustID = @CustID
			AND((@UserRole=1 AND (c.srecommend IN(SELECT Custid FROM #SuperCN88) OR c.srecommend=0)) 
				OR( @UserRole=2) AND ISNULL(c.srecommend,-1)<>0 AND ISNULL(c.srecommend,-1) NOT IN(SELECT Custid FROM #SuperCN88))	

	UNION ALL

	SELECT m.UserName, m.CustID, m.roleid,
			CASE WHEN m.Closed = 0 and ISNULL(m.reject,0) = 0 THEN 1 ELSE 0 END Active,
			CASE WHEN m.Closed = 1 THEN 1 ELSE 0 END Closed,
			CASE WHEN ISNULL(m.reject,0) = 1 and m.Closed = 0 THEN 1 ELSE 0 END Suspended
	FROM
		bodb02.dbo.custinfo c WITH(NOLOCK) 
			INNER JOIN bodb02.dbo.custinfo m WITH(NOLOCK) ON c.mrecommend = m.CustID
	WHERE
		c.CustID = @CustID
			AND((@UserRole=1 AND (c.srecommend IN(SELECT Custid FROM #SuperCN88) OR c.srecommend=0)) 
				OR( @UserRole=2) AND ISNULL(c.srecommend,-1)<>0 AND ISNULL(c.srecommend,-1) NOT IN(SELECT Custid FROM #SuperCN88))	

	UNION ALL

	SELECT	a.UserName, a.CustID, a.roleid,
			CASE WHEN a.Closed = 0 and ISNULL(a.reject,0) = 0 THEN 1 ELSE 0 END Active,
			CASE WHEN a.Closed = 1 THEN 1 ELSE 0 END Closed,
			CASE WHEN ISNULL(a.reject,0) = 1 and a.Closed = 0 THEN 1 ELSE 0 END Suspended
	FROM
		bodb02.dbo.custinfo c WITH(NOLOCK) 
			INNER JOIN bodb02.dbo.custinfo a WITH(NOLOCK) ON c.recommend  = a.CustID 
	WHERE
		c.CustID = @CustID
			AND((@UserRole=1 AND (c.srecommend IN(SELECT Custid FROM #SuperCN88) OR c.srecommend=0)) 
				OR( @UserRole=2) AND ISNULL(c.srecommend,-1)<>0 AND ISNULL(c.srecommend,-1) NOT IN(SELECT Custid FROM #SuperCN88))	

	UNION ALL
	SELECT	c.UserName, c.CustID, 7006 AS RoleID,
			CASE WHEN c.Closed = 0 and ISNULL(c.reject,0) = 0 THEN 1 ELSE 0 END Active,
			CASE WHEN c.Closed = 1 THEN 1 ELSE 0 END Closed,
			CASE WHEN ISNULL(c.reject,0) = 1 and c.Closed = 0 THEN 1 ELSE 0 END Suspended
	FROM	bodb02.dbo.custAccount a WITH(NOLOCK) 
			LEFT JOIN bodb02.dbo.custAccount h WITH(NOLOCK) ON a.groupID=h.groupID AND h.IsGroupHeadLine=1
			INNER JOIN bodb02.dbo.custInfo c WITH(NOLOCK) ON h.custid=c.custid
	WHERE
		a.CustID IN(@srecommend,@mrecommend,@recommend,@CustID)
			AND((@UserRole=1 AND (c.srecommend IN(SELECT Custid FROM #SuperCN88) OR c.srecommend=0)) 
				OR( @UserRole=2) AND ISNULL(c.srecommend,-1)<>0 AND ISNULL(c.srecommend,-1) NOT IN(SELECT Custid FROM #SuperCN88))	

END





GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_CustomerGetUplineList] TO [bodbAdminNet]
GO 
