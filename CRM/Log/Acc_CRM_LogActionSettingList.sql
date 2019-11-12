/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER procedure [dbo].[Acc_CRM_LogActionSettingList]
	@username	VARCHAR(50) = NULL,
	@fromdate	DATETIME,
	@todate		DATETIME,
	@actionid	INT = NULL,
	@UserRole	TINYINT = 2
AS
/*
	Created: 20140217@Dom
	Task : Get list of setting log
	DB: DBCRM.bodb_CRM
	Original:

	Revisions:
		- 20190506@Winnie:  CN88 Permission RedmineID: #112637
		- 20191018@Winnie:  CRM - Support Default Communication Tool RedmineID: #122078
	Param's Explanation:
*/
BEGIN
	SELECT * 
	FROM 
		(
		SELECT lc.LogDate, lc.ActionID, la.ActionNameEN ActionName, ci.username, 'Setting' Entity, lc.SettingID ID, lc.OldValues,lc.Doing NewValues
		FROM crmLogSetting lc WITH (NOLOCK) 
			INNER JOIN crmLogAction la WITH(NOLOCK) ON la.ActionID = lc.ActionID
			INNER JOIN bodb02.dbo.Customer ci WITH (NOLOCK) ON ci.custid = lc.UserID
			INNER JOIN crmSetting s WITH(NOLOCK) ON lc.SettingID=s.SettingID
		WHERE (lc.actionid BETWEEN 300 AND 399 OR lc.actionid BETWEEN 800 AND 899) AND lc.ActionID <> 303
			AND (ISNULL(@username,'')='' OR ci.username = @username) 
			AND (ISNULL(@actionid,0)=0  OR lc.ActionID = @ActionID)
			AND lc.LogDate BETWEEN @FromDate and @Todate
			AND s.SiteOffer = @UserRole
			AND (@UserRole=2 OR(@UserRole=1 AND ISNULL(ExcludedForCn88,0)<>1 ))
		UNION ALL 
		SELECT lc.LogDate, lc.ActionID, la.ActionNameEN ActionName, ci.username, 'Setting' Entity, lc.SettingID ID, lc.OldValues,lc.Doing NewValues
		FROM crmLogSetting lc WITH (NOLOCK) 
			INNER JOIN crmLogAction la WITH(NOLOCK) ON la.ActionID = lc.ActionID
			INNER JOIN bodb02.dbo.Customer ci WITH (NOLOCK) ON ci.custid = lc.UserID
			INNER JOIN crmSetting s WITH(NOLOCK) ON lc.ParentID = s.SettingID
		WHERE lc.actionid = 303 AND lc.SettingID = 0
			AND (ISNULL(@username,'')='' OR ci.username = @username) 
			AND (ISNULL(@actionid,0)=0  OR lc.ActionID = @ActionID)
			AND lc.LogDate BETWEEN @FromDate and @Todate
			AND s.SiteOffer = @UserRole
			AND (@UserRole=2 OR(@UserRole=1 AND ISNULL(ExcludedForCn88,0)<>1 ))
		UNION ALL 
		SELECT lc.LogDate, lc.ActionID, la.ActionNameEN ActionName, ci.username, 'Setting' Entity, lc.SettingID ID, lc.OldValues,lc.Doing NewValues
		FROM crmLogSetting lc WITH (NOLOCK) 
			INNER JOIN crmLogAction la WITH(NOLOCK) ON la.ActionID = lc.ActionID
			INNER JOIN bodb02.dbo.Customer ci WITH (NOLOCK) ON ci.custid = lc.UserID		
		WHERE lc.actionid IN(306,307)
			AND (ISNULL(@username,'')='' OR ci.username = @username) 
			AND (ISNULL(@actionid,0)=0  OR lc.ActionID = @ActionID)
			AND lc.LogDate BETWEEN @FromDate and @Todate
			AND s.SiteOffer = @UserRole
			AND (@UserRole=2 OR(@UserRole=1 AND ISNULL(ExcludedForCn88,0)<>1 ))
		)tmp
	ORDER BY LogDate DESC
END
