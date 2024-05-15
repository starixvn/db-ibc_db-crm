/*<info serverAlias="DBCRM-bodb_CRM" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_ConfigAutoFeedback_ServiceSel] 	
AS
/*
	Created: Winfred
	Task : Get name system setting config for all service
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20221028@Winfred: Get name system setting config for all service [redmine:#158258]
		- 20240515@Luke: CRM - Implement Message Notifications Center for Result Amendment of Cricket [Redmine: #197621]
		
*/
BEGIN
	SET NOCOUNT ON
				
	SELECT DISTINCT ServiceName 
	FROM SystemSetting WITH(NOLOCK)
	UNION ALL
	SELECT 'Notification Center'
END