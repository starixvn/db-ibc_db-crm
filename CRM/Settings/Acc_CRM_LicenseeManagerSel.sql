/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.Acc_CRM_LicenseeManagerSel
	@username VARCHAR(50) = ''	
AS
/*
	Created: 20200429@Johnson	
	Task: get Licensee mapping  
	DB:	DBCRM/bodb_CRM
	Original:
	
	Revisions:
		- 20200422@Johnson: initial sp [redmine:#130949]
	
	Parameter's Explanations:
*/	
BEGIN
	SET NOCOUNT ON;
	
	SELECT TOP (10) custid, username
	FROM crmCustomer WITH(NOLOCK)
	WHERE custid < 0
		AND username LIKE '%'+ @username + '%'
	ORDER BY username
END	
		