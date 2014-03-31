
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.Acc_CRM_MainCategoryList    Script Date: 3/26/2014 6:06:07 PM ******/
create procedure Acc_CRM_MainCategoryList
as
select * from crmMainCategory(nolock) where IsActive = 1
GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_MainCategoryList] TO [bodbAdminNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_MainCategoryList] TO [vnteam]
GO 
