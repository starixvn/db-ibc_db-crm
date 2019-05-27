/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE procedure [dbo].[Acc_CRM_LogActionSettingList]
	@username	varchar(50) = NULL,
	@fromdate	datetime,
	@todate		datetime,
	@actionid	int = null,
	@UserRole	TINYINT=2
as

/*
Created: 20140217@Dom
Task : Get list of setting log
DB: DBCRM.bodb_CRM
Original:

Revisions:
	- 20190506@Winnie:  CN88 Permission RedmineID: #112637
Param's Explanation:
*/

CREATE TABLE #SuperCN88(CustID INT PRIMARY KEY)
INSERT INTO #SuperCN88(CustID)
SELECT CustID FROM bodb02.dbo.CustSuper WITH(NOLOCK) 
WHERE UplineId IS NOT NULL

select lc.LogDate,lc.ActionID,la.ActionNameEN ActionName,ci.username,'Setting' Entity, lc.SettingID ID, lc.OldValues,lc.Doing NewValues
from crmLogSetting(nolock) lc
inner join crmLogAction(NOLOCK) la on la.ActionID = lc.ActionID
inner join bodb02.dbo.Customer (nolock) ci on ci.custid = lc.UserID
where lc.actionid BETWEEN 300 and 399
and (ISNULL(@username,'')='' OR ci.username = @username) 
and (ISNULL(@actionid,0)=0  or lc.ActionID = @ActionID)
and lc.LogDate BETWEEN @FromDate and @Todate
AND((@UserRole=1 AND (ci.srecommend IN(SELECT Custid FROM #SuperCN88) OR ci.srecommend=0)) 
				OR( @UserRole=2) AND ISNULL(ci.srecommend,-1)<>0 AND ISNULL(ci.srecommend,-1) NOT IN(SELECT Custid FROM #SuperCN88))
AND (@UserRole=2 OR(@UserRole=1 AND ISNULL(ExcludedForCn88,0)<>1 ))
order by lc.LogDate desc

GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_LogActionSettingList] TO [bodbAdminNet]
GO 
