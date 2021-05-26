/*<info serverAlias="DBOIC-bodb_OIC" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.Acc_CRM_OICLicenseeSel	
AS
/*
	Created: 20210526@Johnson	
	Task: get list OIC licensees to synchronize into CRM
	DB:	DBOIC/bodb_OIC
	Original:
	
	Revisions:
		- 20210526@Johnson: initial sp [redmine:#154840]
	
	Parameter's Explanations:
*/	
BEGIN
	SET NOCOUNT ON;
		
	SELECT RegisteredLicenseeName as LicenseeName,LicenseeStatusId statusID 
	From Licensee WITH(NOLOCK)
	WHERE RegisteredLicenseeName IS NOT NULL
	ORDER BY LicenseeName
END	