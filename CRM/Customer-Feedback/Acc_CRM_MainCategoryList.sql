/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE Acc_CRM_MainCategoryList
(
@UserRole		TINYINT
)
AS
/*
	Created: Winnie
	Date: 20190506
	Task : Get List of sub categories
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20190507@Winnie:	CN88 	[RedmineID:#112637]
	Param's Explanation:
	
*/
BEGIN
SELECT * FROM crmMainCategory(nolock) where IsActive = 1
	AND (siteOffer=@UserRole OR SiteOffer=0 OR @UserRole=0)
END
GO

 GRANT EXECUTE ON [dbo].[Acc_CRM_MainCategoryList] TO [bodbAdminNet]
GO 
