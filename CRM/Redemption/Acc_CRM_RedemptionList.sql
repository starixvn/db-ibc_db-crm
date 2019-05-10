/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE Acc_CRM_RedemptionList
	@CustID		INT,
	@FromDate	DATETIME,
	@ToDate		DATETIME,
	@StatusID	INT = 0,
	@Handler	INT = 0,
	@UserRole	TINYINT
AS

/*
Created: 20140207@Dom
Task : Return list of redemption log
DB: DBCRM.bodb_CRM
Original:

Revisions:
	- Dom@20141128: add more field
	- 20190506@Winnie:  CN88 Permission RedmineID: #112637
Param's Explanation:
*/
BEGIN
	SELECT r.ID
			,r.Subject
			,r.ClaimTime
			,st.Name Status 
			,r.Amount
			,ISNULL(ex.Currency,'N/A') Currency
			,c.Username
			,r.Doneby
	FROM crmRedemption(NOLOCK) r
	LEFT JOIN crmStatus(NOLOCK) st ON st.StatusID = r.StatusID
	LEFT JOIN bodb02.dbo.exchange ex WITH(NOLOCK) ON ex.exchangeid = r.CurrencyID
	INNER JOIN crmCustomer c WITH(NOLOCK) ON c.CustID = r.CustID
	WHERE r.CustID = @CustID
	AND r.ClaimTime BETWEEN @FromDate AND @todate
	AND (ISNULL(@StatusID,0) = 0 OR r.StatusID = @StatusID)
	AND (ISNULL(@Handler,0) = 0 OR r.Creator = @Handler)
	AND ((@UserRole=1 AND c.SiteID=33002) OR (@UserRole=2 AND c.SiteID<>33002))
	ORDER BY 1 DESC
END
GO

 GRANT EXECUTE ON [dbo].[Acc_CRM_RedemptionList] TO [bodbAdminNet]
GO 


