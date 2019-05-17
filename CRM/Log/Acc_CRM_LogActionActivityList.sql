/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER procedure [dbo].[Acc_CRM_LogActionActivityList]
	@username	varchar(50) = NULL,
	@fromdate	datetime,
	@todate		datetime,
	@actionid	int = null,
	@custid		int,
	@UserRole	TINYINT
as

/*
Created: Dom
Date: 20140217
Task : Get list of activities
DB: DBCRM.bodb_CRM
Original:

Revisions:
	- 20170614@Winnie: Get log for update siteid,LicenseeType RedmineID:77820
	- 20190506@Winnie:  CN88 Permission RedmineID: #112637
Param's Explanation:
*/
BEGIN
	CREATE TABLE #Super(CustID INT PRIMARY KEY)
	INSERT INTO #Super(CustID)
	SELECT Custid FROM bodb02.dbo.CustSuper WITH(NOLOCK)

	WHERE UplineId IS NULL
	select lc.LogDate,ci.username, lc.OldValues,lc.Doing NewValues,la.ActionNameEN ActionName
	from crmLogCustomer(nolock) lc
	inner join bodb02.dbo.custInfo(nolock) ci on ci.custid = lc.UserID
	INNER JOIN crmLogAction(NOLOCK) la ON la.ActionID = lc.ActionID
	where (lc.actionid BETWEEN 100 and 199 OR lc.actionid BETWEEN 600 and 699)
	and (ISNULL(@username,'') = '' OR ci.username = @username) 
	and (ISNULL(@actionid,0) = 0 or lc.ActionID = @ActionID)
	and lc.custid = @CustID
	and lc.LogDate BETWEEN @FromDate and @Todate
	AND ((@UserRole=1 AND (ci.srecommend IN(SELECT CustID FROM #Super) OR ci.roleid=0)) OR (@UserRole=2 AND ci.srecommend NOT IN(SELECT CustID FROM #Super)))
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
	AND ((@UserRole=1 AND (ci.srecommend IN(SELECT CustID FROM #Super) OR ci.roleid=0)) OR (@UserRole=2 AND ci.srecommend NOT IN(SELECT CustID FROM #Super)))
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
	AND ((@UserRole=1 AND (ci.srecommend IN(SELECT CustID FROM #Super)OR ci.roleid=0)) OR (@UserRole=2 AND ci.srecommend NOT IN(SELECT CustID FROM #Super)))
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
	AND ((@UserRole=1 AND (ci.srecommend IN(SELECT CustID FROM #Super) OR ci.roleid=0)) OR (@UserRole=2 AND ci.srecommend NOT IN(SELECT CustID FROM #Super)))
	ORDER BY 1 DESC
END
GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_LogActionActivityList] TO [bodbAdminNet]
GO 
