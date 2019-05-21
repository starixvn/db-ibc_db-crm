/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_CRM_ActivityLogList]
(
@UserRole	INT=2
)
AS
/*
Created: Winnie
Date: 20101020
Task : Get country list
DB: DB06.bodb_CRM
Original:

Revisions:
		- 20190521@Winnie: SiteOffer CN88
Param's Explanation:
	
*/
BEGIN

SELECT ActionID,SPName,ActionNameEN ActionName FROM crmLogAction(NOLOCK) 
WHERE ActionID NOT BETWEEN 300 and 399 AND ActionID NOT IN(400,401,402)
	AND (@UserRole=2 OR(@UserRole=1 AND ExcludedForCn88=1 ))

END
GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_ActivityLogList] TO [bodbAdminNet]
GO 
