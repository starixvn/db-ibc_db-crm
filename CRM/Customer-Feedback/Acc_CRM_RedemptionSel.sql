ALTER PROCEDURE Acc_CRM_RedemptionSel
	@ID INT
AS

/*
Created: 20140207@Dom
Task : Get redemption log
DB: DBCRM.bodb_CRM
Original:

Revisions:
	- 20141118@Dom: Add currency and amount
Param's Explanation:
*/
BEGIN
	SELECT r.ID
			,r.Subject
			,r.ClaimTime
			,r.StatusID
			,r.Remark
			,r.CustID 
			,r.DoneBy
			,r.CurrencyID
			,r.Amount
	FROM crmRedemption(NOLOCK) r
	WHERE r.ID = @ID

END
GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_RedemptionSel] TO [bodbAdminNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_RedemptionSel] TO [vnteam]
GO 
