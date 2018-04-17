/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet,vnteam" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_Rpt_FeedbackSelByLincensee]
(
	@FromDate datetime,
	@ToDate datetime
)	
AS
/*
	Created: Kevin
	Date: 20110818
	Task : get feedbacks report by licensee
	DB: DB06.bodb_CRM
	Original:
	Revisions:
		- 20111126@Sophia: Not to show Status is Pending (StatusID = 11001)		
		- 20140523@Dom: modify site condition
		- 20180117@Winnie:	Add Is Related Customer - [Redmine: #88774]
		- 20171225@Winnie: Change for support multiple product/categories. [RedmineID: #84714]
	Param's Explanation:
	
*/
BEGIN		
	SET NOCOUNT ON	
	SELECT	@FromDate	= DATEADD(d,0,CONVERT(CHAR(12),@FromDate, 101)),
			@ToDate		= DATEADD(ms,-2,DATEADD(d,1,CONVERT(CHAR(12),@ToDate, 101)))
	
		SELECT t.*, l.list AS relatedCustomer
		INTO #temp
		FROM (	
				SELECT 
					fb.FeedbackID, 
					fb.CustID, 
					fb.SiteID as LicenseeID,
					ctm.UserName,
					fb.FirstName, 
					fb.LastName, 
					fb.Phone, 
					fb.MobilePhone, 
					fb.Fax, 
					fb.Email, 
					fb.Skype,
					fb.msn,
					fb.CreatorID, 
					c.username AS CreatorName,
					fb.FeedbackDate,
					fb.ResolutionDate,
					fb.CreateDate,
					fb.SolveDate,
					fb.CommunicationID, 
					fb.MainCategoryID,
					fb.SubCategoryID, 
					fb.ProductID, 
					fb.ResponseID, 
					fb.StatusID, 
					CAST(fb.Description AS XML) AS Description,
					fb.Solution, 
					fb.IsReviewed, 
					rv.username AS ReviewerName,
					fb.Subject
				FROM 
					crmFeedbackCustomer fbc WITH(NOLOCK)
						INNER JOIN crmFeedback fb WITH(NOLOCK) ON fb.FeedbackID = fbc.FeedbackID
						INNER JOIN crmCustomer ctm WITH(NOLOCK) ON ctm.CustID = fb.CustID
						INNER JOIN bodb02.dbo.custinfo c WITH(NOLOCK) ON fb.CreatorID = c.custID
						INNER JOIN crmSite s WITH(NOLOCK) ON s.SiteID = fb.SiteID
						LEFT JOIN bodb02.dbo.custinfo rv WITH(NOLOCK) ON fb.ReviewerID = rv.custID
				WHERE
				
					fbc.IsRelated = 0
					AND fb.FeedbackDate BETWEEN @FromDate AND @ToDate	
					AND s.IsLicensee=1
					AND fb.StatusID NOT IN (11004, 11001)
			) t CROSS APPLY dbo.f_GetRelatedCustomer(t.FeedbackID) l
		
		SELECT 
					fb.FeedbackID, 
					fb.CustID, 
					fb.LicenseeID,
					fb.UserName,
					fb.FirstName, 
					fb.LastName, 
					fb.Phone, 
					fb.MobilePhone, 
					fb.Fax, 
					fb.Email, 
					fb.Skype,
					fb.msn,
					fb.CreatorID, 
					fb.username AS CreatorName,
					fb.FeedbackDate,
					fb.ResolutionDate,
					fb.CreateDate,
					fb.SolveDate,
					fb.CommunicationID, 
					fb.MainCategoryID,
					fb.SubCategoryID, 
					fb.ProductID, 
					fb.ResponseID, 
					fb.StatusID, 					
					fb.Solution, 
					fb.IsReviewed, 
					fb.username AS ReviewerName,
					fb.Subject,
					fb.relatedCustomer,
					nr.value(N'@Remark',N'nvarchar(max)') AS Description
		FROM #temp fb
		OUTER APPLY fb.Description.nodes(N'//row') AS A(nr)
		
		SELECT fs.FeedbackID,fs.SettingID,fs.SubSettingID,fs.SubSettingIDLevel3,
		CASE	WHEN m.MainCategoryID	IS NOT NULL THEN 'Category' 
				WHEN s.StationID		IS NOT NULL THEN 'Station' 
				WHEN p.SettingID		IS NOT NULL THEN 'Product' 
				WHEN c.SettingID		IS NOT NULL THEN 'Communication' 
				END AS SettingType
		FROM #temp fp
			INNER JOIN crmFeedbackSetting fs WITH(NOLOCK) 
				ON fs.FeedbackID=fp.FeedbackID	
			LEFT JOIN crmMainCategory m 
				ON fs.SettingID=m.MainCategoryID
			LEFT JOIN crmStation s 
				ON fs.SettingID=s.StationID
			LEFT JOIN crmSetting p
				ON fs.SettingID=p.SettingID AND p.SettingName='Product'
			LEFT JOIN crmSetting c
				ON fs.SettingID=c.SettingID AND c.SettingName='Communication'
END


GO
GRANT EXECUTE ON [dbo].[Acc_CRM_Rpt_FeedbackSelByLincensee] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_Rpt_FeedbackSelByLincensee] TO [vnteam]