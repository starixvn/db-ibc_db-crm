/*<info serverAlias="DBLIC-bodb_Licensee" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.Acc_CRM_LicenseeMappingSel
	@Settings VARCHAR(MAX)
AS
/*
	Created: 20200421@Johnson	
	Task: get list licensees for site setting for CRM
	DB:	DBLIC/bodb_Licensee
	Original:
	
	Revisions:
		- 20200421@Johnson: initial sp [redmine:#130949]
	
	Parameter's Explanations:
*/	
BEGIN
	SET NOCOUNT ON;
	
	SELECT LicenseeName as site 
	FROM Licensees WITH(NOLOCK)
	WHERE IsActive = 1
	ORDER BY site ASC 
END	