/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_ActionTypeSel]
AS
/*
Created: 20200724@Malcolm
Task :  Get action type
DB: DBCRM/bodb_CRM
Original:

	Revisions:
		- 20200724@Malcolm: Get action type [Redmine: #137144]
	Param's Explanation:
		
		
*/
BEGIN 
	SET NOCOUNT ON

	SELECT ActionTypeID, ActionTypeName
	FROM dbo.crmLogActionType WITH(NOLOCK)	
	WHERE ActionTypeID <> 1

END