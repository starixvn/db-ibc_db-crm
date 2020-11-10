/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE procedure Acc_CRM_SubCategoryList
	@MainCategoryID INT = null,
	@UserRole		TINYINT,
	@Active			TINYINT = 1,
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
		- 20201030@Johnson: add filter IsActive [redmine: #142194]
	Param's Explanation:
		- @Active = 1: get active
				= 2: get all 
	
*/
BEGIN
	SET NOCOUNT ON

	SELECT [SubCategoryID],
			CASE	WHEN @Lang='zh-TW' THEN ISNULL(NameCT,Name)
								WHEN @Lang='zh-CN' THEN ISNULL(NameCS,Name)
														ELSE Name
						END AS Name,
						DisplayOrder,
						IsActive AS IsActive,
			[MainCategoryID]
	FROM crmSubCategory WITH(NOLOCK) 
	WHERE 1 = CASE WHEN (@Active = 1 AND IsActive = 1) OR @Active = 2 THEN 1 ELSE 0 END
		AND (ISNULL(@MainCategoryID,0)=0 OR MainCategoryID = @MainCategoryID)
		AND (siteoffer=@UserRole)
END
GO

