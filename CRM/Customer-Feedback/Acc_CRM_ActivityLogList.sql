
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.Acc_CRM_ActivityLogList    Script Date: 3/26/2014 6:06:07 PM ******/
CREATE PROCEDURE [dbo].[Acc_CRM_ActivityLogList]
AS
SELECT ActionID,SPName,ActionNameEN ActionName FROM crmLogAction(NOLOCK) WHERE ActionID NOT BETWEEN 300 and 399 AND ActionID NOT IN(400,401,402)


GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_ActivityLogList] TO [bodbAdminNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_ActivityLogList] TO [vnteam]
GO 
