/*<info serverAlias="DBCRM-bodb_CRM" executers="wsv_nap" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE dbo.Acc_CRM_CustomerRemarkSel @CustID   INT,
                                              @UserRole TINYINT
AS

/*
	Created: Winnie
	Date: 20190510
	Task : sel remark
	DB: DBCRM/bodb_CRM
	Original:
	Revisions:		
		- 20190506@Winnie:  CN88 Permission RedmineID: #112637
		- 20201120@Johnson: check incase SiteID = NULL  [redmine:#145439]
        - 20240826@Ned.Le:  CRM - Upgrade code to 3 tiers network (#197742)
	Param's Explanation:	
*/

BEGIN
	SET NOCOUNT ON
	
	SELECT DISTINCT a.RemarkID, a.CustID, a.Remark, a.IsSpecial, b.UserName
	FROM dbo.crmCustomerRemark a WITH(NOLOCK) 
		INNER JOIN dbo.crmCustomer b WITH(NOLOCK) ON a.CustID=b.CustID
	WHERE a.CustID = @CustID
		AND ((@UserRole=1 AND b.SiteID=33002) OR (@UserRole=2 AND ISNULL(b.SiteID,0)<>33002))
END
GO