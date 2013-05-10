 ALTER PROCEDURE [dbo].[Acc_CRM_GuestSelByTimestamp]
(
	@tstamp timestamp
)
AS
/*
Created: Elodie	
Date: 20120423
Task : Get guest info by timestamp
DB: DB052.bodb_CRM
Original:

Revisions:	
			   
Param's Explanation:	
*/
BEGIN	
	SET NOCOUNT ON		
	SELECT CustID, UserName, tstamp		
	FROM crmCustomer WITH(NOLOCK) 					
	WHERE tstamp > @tstamp and CustID < 0
	ORDER BY tstamp asc
END

GO
GRANT EXECUTE ON [dbo].[Acc_CRM_GuestSelByTimestamp] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_GuestSelByTimestamp] TO [vnteam]





