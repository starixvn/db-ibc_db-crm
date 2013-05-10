
ALTER PROCEDURE [dbo].[Acc_CRM_CustomerVerify]
(
	@Username	NVARCHAR(50) = '',
	@CustID		INT = 0 OUTPUT
)
AS
/*
Created: Lukas
Date: 20101119
Task : verify customer
DB: DB06.bodb_CRM
Original:

Revisions:
	
Param's Explanation:	
*/
BEGIN
	SET NOCOUNT ON

	SELECT @CustID = 0

	SELECT @CustID = ISNULL(CustID,0)
	FROM 
		bodb02.dbo.custinfo c WITH(NOLOCK) 
	WHERE 
		c.UserName = @Username	
END






GO
GRANT EXECUTE ON [dbo].[Acc_CRM_CustomerVerify] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_CustomerVerify] TO [vnteam] 