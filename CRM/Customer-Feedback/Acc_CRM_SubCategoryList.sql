/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE procedure Acc_CRM_SubCategoryList
	@MainCategoryID INT = null,
	@UserRole		TINYINT,
	@Lang			VARCHAR(10)='en-US'
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

SELECT [SubCategoryID],
		CASE	WHEN @Lang='zh-TW' THEN ISNULL(NameCT,Name)
							WHEN @Lang='zh-CN' THEN ISNULL(NameCS,Name)
													ELSE Name
					END AS Name,
					DisplayOrder,
					1 AS IsActive,
		[MainCategoryID]
FROM crmSubCategory WITH(NOLOCK) 
WHERE IsActive = 1 and (ISNULL(@MainCategoryID,0)=0 OR MainCategoryID = @MainCategoryID)
	AND (siteoffer=@UserRole)

GO

 GRANT EXECUTE ON [dbo].[Acc_CRM_SubCategoryList] TO [bodbAdminNet]
GO 
