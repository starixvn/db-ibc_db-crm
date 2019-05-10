/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE Acc_CRM_CustomerRemarkSel
	@CustID		INT,
	@UserRole   TINYINT
AS
/*
	Created: Winnie
	Date: 20190510
	Task : sel remark
	DB: DBCRM/bodb_CRM
	Original:
	Revisions:		
		- 20190506@Winnie:  CN88 Permission RedmineID: #112637
	Param's Explanation:	
*/
BEGIN
SELECT * 
		FROM crmCustomerRemark a WITH(NOLOCK) 
			INNER JOIN crmCustomer b WITH(NOLOCK) ON a.CustID=b.CustID
		WHERE CustID = @CustID
			AND ((@UserRole=1 AND b.SiteID=33002) OR (@UserRole=2 AND b.SiteID<>33002))
END
GO

 GRANT EXECUTE ON [dbo].[Acc_CRM_CustomerRemarkSel] TO [bodbAdminNet]
GO 
