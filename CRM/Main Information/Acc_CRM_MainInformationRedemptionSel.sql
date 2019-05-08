/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROC Acc_CRM_MainInformationRedemptionSel
	@CustID		INT,
	@UserRole   TINYINT
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
FROM crmRedemption r WITH(NOLOCK) 
	INNER JOIN crmStatus st WITH(NOLOCK)  ON st.StatusID = r.StatusID
	INNER JOIN bodb02.dbo.exchange e WITH(NOLOCK)  ON r.CurrencyID=e.exchangeid 
	INNER JOIN crmCustomer c WITH(NOLOCK) ON r.Custid=c.CustID
WHERE r.CustID = @CustID AND (@UserRole=0 OR (@UserRole=1 AND c.SiteID=33002) OR (@UserRole=2 AND c.SiteID<>33002))
AND r.StatusID <> 11004
ORDER BY r.ID DESC

GO

 GRANT EXECUTE ON [dbo].[Acc_CRM_MainInformationRedemptionSel] TO [bodbAdminNet]
GO 
