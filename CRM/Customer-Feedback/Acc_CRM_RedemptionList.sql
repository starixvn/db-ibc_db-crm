
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.Acc_CRM_RedemptionList    Script Date: 3/26/2014 6:06:08 PM ******/
CREATE PROCEDURE Acc_CRM_RedemptionList
	@CustID		INT,
	@FromDate	DATETIME,
	@ToDate		DATETIME,
	@StatusID	INT = 0,
	@Handler	INT = 0
AS

/*
Created: 20140207@Dom
Task : Return list of redemption log
DB: DBCRM.bodb_CRM
Original:

Revisions:
	
Param's Explanation:
*/

SELECT r.ID,r.Subject,r.ClaimTime,st.Name Status FROM crmRedemption(NOLOCK) r
INNER JOIN crmStatus(NOLOCK) st ON st.StatusID = r.StatusID
WHERE r.CustID = @CustID
AND r.ClaimTime BETWEEN @FromDate AND @todate
AND (ISNULL(@StatusID,0) = 0 OR r.StatusID = @StatusID)
AND (ISNULL(@Handler,0) = 0 OR r.Creator = @Handler)
ORDER BY 1 DESC

GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_RedemptionList] TO [bodbAdminNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_RedemptionList] TO [vnteam]
GO 
