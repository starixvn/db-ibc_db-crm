/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
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
	- 20190506@Winnie: CN88 Permission RedmineID: #112637
Param's Explanation:	
*/

SELECT TOP 5 r.ID RedemptionID,r.Subject,r.ClaimTime,st.Name Status,e.Currency,r.Amount,r.DoneBy 
FROM crmRedemption(NOLOCK) r
INNER JOIN crmStatus(NOLOCK) st ON st.StatusID = r.StatusID
INNER JOIN bodb02.dbo.exchange(NOLOCK) e ON r.CurrencyID=e.exchangeid 
WHERE r.CustID = @CustID
AND r.StatusID <> 11004
AND r.StatusID <> 11019
ORDER BY r.ID DESC

GO

GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_MainInformationRedemptionSel] TO [bodbAdminNet]
GO 
 