/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_ConfigAutoFeedback_ServiceSel] 	
AS
/*
	Created: Winfred
	Task : Get name system setting config for all service
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20221028@Winfred: Get name system setting config for all service [redmine:#158258]
		
*/
BEGIN
	SET NOCOUNT ON
				
	SELECT DISTINCT ServiceName 
	FROM SystemSetting WITH(NOLOCK)
END