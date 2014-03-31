
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.Acc_CRM_BettypeList    Script Date: 3/26/2014 6:06:10 PM ******/
CREATE procedure [dbo].[Acc_CRM_BettypeList]
	@ProductID int = null
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

select * from crmBettype(nolock) 
where IsActive = 1 and (ISNULL(@ProductID,0)=0 OR ProductID = @ProductID)


GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_BettypeList] TO [bodbAdminNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_BettypeList] TO [vnteam]
GO 
