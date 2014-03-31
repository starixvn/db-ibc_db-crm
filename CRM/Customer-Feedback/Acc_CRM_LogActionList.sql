
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.Acc_CRM_LogActionList    Script Date: 3/26/2014 6:06:07 PM ******/
CREATE procedure [dbo].[Acc_CRM_LogActionList]
	@username	varchar(50),
	@fromdate	datetime,
	@todate		datetime,
	@actionid	int = null
as
select lc.LogDate,ci.username, lc.OldValues,lc.Doing
from crmLogCustomer(nolock) lc
inner join bodb02.dbo.custInfo(nolock) ci on ci.custid = lc.UserID
where actionid BETWEEN 100 and 199
and (@username is null OR ci.username = @username) 
and (@actionid is null or lc.ActionID = @ActionID)
--UNION ALL


GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_LogActionList] TO [bodbAdminNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_LogActionList] TO [vnteam]
GO 
