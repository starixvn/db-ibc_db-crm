
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.Acc_CRM_CustomerGetUplineList    Script Date: 3/26/2014 6:06:04 PM ******/

CREATE PROCEDURE [dbo].[Acc_CRM_CustomerGetUplineList]
(
	@CustID		INT				= NULL,
	@UserName	NVARCHAR(50)	= NULL
)
AS
/*
Created: Lukas
Date: 20101118
Task : get customer upline list
DB: DB06.bodb_CRM
Original:

Revisions:
	- 20140303@Dom: Modify for new structure
	- 20180910@Winnie: Show headline [RedmineID: #99982]
Param's Explanation:	
*/
BEGIN	
	SET NOCOUNT ON

	SELECT s.UserName, s.CustID, s.roleid,
			CASE WHEN s.Closed = 0 and ISNULL(s.reject,0) = 0 THEN 1 ELSE 0 END Active,
			CASE WHEN s.Closed = 1 THEN 1 ELSE 0 END Closed,
			CASE WHEN ISNULL(s.reject,0) = 1 and s.Closed = 0 THEN 1 ELSE 0 END Suspended
	FROM
		bodb02.dbo.custinfo c WITH(NOLOCK) 
			INNER JOIN bodb02.dbo.custinfo s WITH(NOLOCK) ON c.srecommend = s.CustID
	WHERE
		c.CustID = @CustID

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

	UNION ALL
	SELECT	c.UserName, c.CustID, 1000 AS RoleID,
			CASE WHEN c.Closed = 0 and ISNULL(c.reject,0) = 0 THEN 1 ELSE 0 END Active,
			CASE WHEN c.Closed = 1 THEN 1 ELSE 0 END Closed,
			CASE WHEN ISNULL(c.reject,0) = 1 and c.Closed = 0 THEN 1 ELSE 0 END Suspended
	FROM	bodb02.dbo.custAccount a WITH(NOLOCK) 
			LEFT JOIN bodb02.dbo.custAccount h WITH(NOLOCK) ON a.groupID=h.groupID AND h.IsGroupHeadLine=1
			INNER JOIN bodb02.dbo.custInfo c WITH(NOLOCK) ON h.custid=c.custid
	WHERE
		a.CustID = @CustID
END





GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_CustomerGetUplineList] TO [bodbAdminNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_CustomerGetUplineList] TO [vnteam]
GO 
