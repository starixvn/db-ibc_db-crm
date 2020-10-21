/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_ChatBot_RecipientType_Sel]
AS
/*
Created: 20200810@Malcolm
Task :  Get all recipient types
DB: DBCRM/bodb_CRM
Original:
	Revisions:
		- 20200810@Malcolm: Initialize SPs [Redmine: #130544]
	Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	SELECT 
		RecipientTypeId,
		RecipientTypeName
	FROM dbo.crmRecipientType WITH(NOLOCK)
END
GO