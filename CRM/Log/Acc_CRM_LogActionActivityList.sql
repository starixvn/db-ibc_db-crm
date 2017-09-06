
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.Acc_CRM_LogActionActivityList    Script Date: 3/26/2014 6:06:07 PM ******/
ALTER procedure [dbo].[Acc_CRM_LogActionActivityList]
	@username	varchar(50) = NULL,
	@fromdate	datetime,
	@todate		datetime,
	@actionid	int = null,
	@custid		int
as

/*
Created: Dom
Date: 20140217
Task : Get list of activities
DB: DBCRM.bodb_CRM
Original:

Revisions:
	-- 20170614@Winnie: Get log for update siteid,LicenseeType RedmineID:77820
Param's Explanation:
*/


	select lc.LogDate,ci.username, lc.OldValues,lc.Doing NewValues,la.ActionNameEN ActionName
	from crmLogCustomer(nolock) lc
	inner join bodb02.dbo.custInfo(nolock) ci on ci.custid = lc.UserID
	INNER JOIN crmLogAction(NOLOCK) la ON la.ActionID = lc.ActionID
	where (lc.actionid BETWEEN 100 and 199 OR lc.actionid BETWEEN 600 and 699)
	and (ISNULL(@username,'') = '' OR ci.username = @username) 
	and (ISNULL(@actionid,0) = 0 or lc.ActionID = @ActionID)
	and lc.custid = @CustID
	and lc.LogDate BETWEEN @FromDate and @Todate
	UNION ALL
	select lc.LogDate,ci.username, lc.OldValues,lc.Doing  NewValues,la.ActionNameEN ActionName
	from crmLogFeedback(nolock) lc
	inner join bodb02.dbo.custInfo(nolock) ci on ci.custid = lc.UserID
	INNER JOIN crmLogAction(NOLOCK) la ON la.ActionID = lc.ActionID
	where (lc.actionid BETWEEN 200 and 299 or lc.actionid BETWEEN 400 and 499 or lc.ActionID=704) AND lc.ActionID NOT IN(400,401,402)
	and (ISNULL(@username,'') = '' OR ci.username = @username) 
	and (ISNULL(@actionid,0) = 0 or lc.ActionID = @ActionID)
	and lc.custid = @CustID
	and lc.LogDate BETWEEN @FromDate and @Todate
	UNION ALL
	select lc.LogDate,ci.username, lc.OldValues,lc.NewValues,la.ActionNameEN ActionName
	from crmLogRedemption(nolock) lc
	inner join bodb02.dbo.custInfo(nolock) ci on ci.custid = lc.UserID
	INNER JOIN crmLogAction(NOLOCK) la ON la.ActionID = lc.ActionID
	where lc.actionid BETWEEN 500 and 599
	and (ISNULL(@username,'') = '' OR ci.username = @username) 
	and (ISNULL(@actionid,0) = 0 or lc.ActionID = @ActionID)
	and lc.custid = @CustID
	and lc.LogDate BETWEEN @FromDate and @Todate
	UNION ALL
	select lc.LogDate,ci.username, lc.OldValues,lc.NewValues,la.ActionNameEN ActionName
	from crmLogCustomerRemark(nolock) lc
	inner join bodb02.dbo.custInfo(nolock) ci on ci.custid = lc.UserID
	INNER JOIN crmLogAction(NOLOCK) la ON la.ActionID = lc.ActionID
	where (lc.actionid BETWEEN 600 and 699)
	and (ISNULL(@username,'') = '' OR ci.username = @username) 
	and (ISNULL(@actionid,0) = 0 or lc.ActionID = @ActionID)
	and lc.custid = @CustID
	and lc.LogDate BETWEEN @FromDate and @Todate
	ORDER BY 1 DESC

--	select * from crmLogAction
--	select * from crmLogFeedback where ActionID in (400
--,401
--,402)
GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_LogActionActivityList] TO [bodbAdminNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_LogActionActivityList] TO [vnteam]
GO 
