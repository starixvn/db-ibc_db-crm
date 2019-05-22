ALTER PROC Acc_CRM_MainInformationRedemptionSel
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

SELECT TOP 5 r.ID RedemptionID,r.Subject,r.ClaimTime,st.Name Status,e.Currency,r.Amount,r.DoneBy 
FROM crmRedemption(NOLOCK) r
INNER JOIN crmStatus(NOLOCK) st ON st.StatusID = r.StatusID
INNER JOIN bodb02.dbo.exchange(NOLOCK) e ON r.CurrencyID=e.exchangeid 
WHERE r.CustID = @CustID
AND r.StatusID <> 11004
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