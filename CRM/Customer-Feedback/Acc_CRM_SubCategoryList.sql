
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.Acc_CRM_SubCategoryList    Script Date: 3/26/2014 6:06:10 PM ******/
CREATE procedure Acc_CRM_SubCategoryList
	@MainCategoryID int = null
as

/*
	Created: Dom
	Date: 20140217
	Task : Get List of sub categories
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
	
	Param's Explanation:
	
*/

select * from crmSubCategory(nolock) 
where IsActive = 1 and (ISNULL(@MainCategoryID,0)=0 OR MainCategoryID = @MainCategoryID)


GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_SubCategoryList] TO [bodbAdminNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_SubCategoryList] TO [vnteam]
GO 
