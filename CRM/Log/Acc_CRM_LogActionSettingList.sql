
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.Acc_CRM_LogActionSettingList    Script Date: 3/26/2014 6:06:07 PM ******/
CREATE procedure [dbo].[Acc_CRM_LogActionSettingList]
	@username	varchar(50) = NULL,
	@fromdate	datetime,
	@todate		datetime,
	@actionid	int = null
as

/*
Created: 20140217@Dom
Task : Get list of setting log
DB: DBCRM.bodb_CRM
Original:

Revisions:
	
Param's Explanation:
*/

select lc.LogDate,lc.ActionID,la.ActionNameEN ActionName,ci.username,'Setting' Entity, lc.SettingID ID, lc.OldValues,lc.Doing NewValues
from crmLogSetting(nolock) lc
inner join crmLogAction(NOLOCK) la on la.ActionID = lc.ActionID
inner join bodb02.dbo.custInfo(nolock) ci on ci.custid = lc.UserID
where lc.actionid BETWEEN 300 and 399
and (ISNULL(@username,'')='' OR ci.username = @username) 
and (ISNULL(@actionid,0)=0  or lc.ActionID = @ActionID)
and lc.LogDate BETWEEN @FromDate and @Todate
order by lc.LogDate desc


GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_LogActionSettingList] TO [bodbAdminNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_LogActionSettingList] TO [vnteam]
GO 
