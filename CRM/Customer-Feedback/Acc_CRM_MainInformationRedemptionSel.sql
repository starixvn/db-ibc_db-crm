
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.Acc_CRM_MainInformationRedemptionSel    Script Date: 3/26/2014 6:06:08 PM ******/
CREATE PROC Acc_CRM_MainInformationRedemptionSel
	@CustID INT
AS

/*
Created: Dom
Date: 20140212
Task : Get data for main tab
DB: DBCRM.bodb_CRM
Original:

Revisions:	
	
Param's Explanation:	
*/

SELECT TOP 5 r.ID RedemptionID,r.Subject,r.ClaimTime,st.Name Status 
FROM crmRedemption(NOLOCK) r
INNER JOIN crmStatus(NOLOCK) st ON st.StatusID = r.StatusID
WHERE r.CustID = @CustID
ORDER BY r.ID DESC

GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_MainInformationRedemptionSel] TO [bodbAdminNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_MainInformationRedemptionSel] TO [vnteam]
GO 
