/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROC Acc_CRM_MainInformationSpecialRemarkSel
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
	- 20201120@Johnson: check incase SiteID = NULL  [redmine:#145439]
Param's Explanation:	
*/
BEGIN
	SET NOCOUNT ON
	
	SELECT TOP 5 a.Remark 
	FROM crmCustomerRemark a WITH(NOLOCK) 
		INNER JOIN crmCustomer b WITH(NOLOCK) ON a.CustID=b.CustID
	WHERE a.CustID = @CustID AND IsSpecial = 1
		AND((@UserRole=1 AND b.SiteID=33002) OR(@UserRole=2 AND ISNULL(b.SiteID,0) <>33002))
END
GO 
