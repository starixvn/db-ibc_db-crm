
ALTER PROCEDURE [dbo].[Acc_CRM_CustomerGetUplineList]
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
	
Param's Explanation:	
*/
BEGIN	
	SET NOCOUNT ON

	SELECT s.UserName, s.CustID, s.roleid
	FROM
		bodb02.dbo.custinfo c WITH(NOLOCK) 
			INNER JOIN bodb02.dbo.custinfo s WITH(NOLOCK) ON c.srecommend = s.CustID
	WHERE
		c.CustID = @CustID--COALESCE(@CustID,c.CustID)  AND c.UserName = COALESCE(@UserName,c.UserName)

	UNION ALL

	SELECT m.UserName, m.CustID, m.roleid
	
	FROM
		bodb02.dbo.custinfo c WITH(NOLOCK) 
			INNER JOIN bodb02.dbo.custinfo m WITH(NOLOCK) ON c.mrecommend = m.CustID
	WHERE
		c.CustID = @CustID--COALESCE(@CustID,c.CustID)  AND c.UserName = COALESCE(@UserName,c.UserName)

	UNION ALL

	SELECT	a.UserName, a.CustID, a.roleid
	FROM
		bodb02.dbo.custinfo c WITH(NOLOCK) 
			INNER JOIN bodb02.dbo.custinfo a WITH(NOLOCK) ON c.recommend  = a.CustID 
	WHERE
		c.CustID = @CustID--COALESCE(@CustID,c.CustID)  AND c.UserName = COALESCE(@UserName,c.UserName)
	
END




GO
GRANT EXECUTE ON [dbo].[Acc_CRM_CustomerGetUplineList] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_CustomerGetUplineList] TO [vnteam] 