/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_ActivityLogList]
(
	@UserRole	INT = 2
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
	WHERE (ActionID BETWEEN 100 AND 199 OR ActionID BETWEEN 200 AND 299 OR ActionID BETWEEN 500 AND 599 OR ActionID BETWEEN 600 AND 699)
		AND (@UserRole=2 OR(@UserRole=1 AND ExcludedForCn88 = 0))
END
GO 
