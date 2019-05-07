/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE procedure Acc_CRM_SubCategoryList
	@MainCategoryID int = null,
	@UserRole		TINYINT
as

/*
	Created: Dom
	Date: 20140217
	Task : Get List of sub categories
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20190507@Winnie:	CN88 	[RedmineID:#112637]
	Param's Explanation:
	
*/

select * from crmSubCategory(nolock) 
where IsActive = 1 and (ISNULL(@MainCategoryID,0)=0 OR MainCategoryID = @MainCategoryID)
	AND (siteoffer=@UserRole OR siteOffer=0 OR @UserRole=0)

GO

 GRANT EXECUTE ON [dbo].[Acc_CRM_SubCategoryList] TO [bodbAdminNet]
GO 
