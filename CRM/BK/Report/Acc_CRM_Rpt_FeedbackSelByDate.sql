/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet,vnteam" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_Rpt_FeedbackSelByDate]
(
	@FromDate datetime,
	@ToDate datetime
)	
AS
/*
	Created: Kevin
	Date: 20110818
	Task : get feedbacks report by date
	DB: DB06.bodb_CRM
	Original:
	Revisions:
		- 20111126@Sophia: Not to show Status is Pending (StatusID = 11001)		
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
				ctm.UserName,
				fb.FirstName, 
				fb.LastName, 
				fb.Phone, 
				fb.MobilePhone, 
				fb.Fax, 
				fb.Email, 
				fb.Skype,
				fb.msn,
				fb.CountryID,
				ct.CountryName,
				fb.CreatorID, 
				c.username AS CreatorName,
				fb.FeedbackDate,
				fb.ResolutionDate,
				fb.CreateDate,
				fb.SolveDate,				
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
					LEFT JOIN bodb02.dbo.custinfo rv WITH(NOLOCK) ON fb.ReviewerID = rv.custID
					left join crmCountry ct with(nolock) on fb.CountryID = ct.CountryId
			WHERE
				fbc.IsRelated = 0
				AND fb.FeedbackDate BETWEEN @FromDate AND @ToDate
				AND fb.StatusID NOT IN (11004, 11001)
		) t CROSS APPLY dbo.f_GetRelatedCustomer(t.FeedbackID) l
		
	
	SELECT 
		t.FeedbackID, 
		t.CustID, 
		t.UserName,
		t.FirstName, 
		t.LastName, 
		t.Phone, 
		t.MobilePhone, 
		t.Fax, 
		t.Email, 
		t.Skype,
		t.msn,
		t.CountryID,
		t.CountryName,
		t.CreatorID, 
		t.CreatorName,
		t.FeedbackDate,
		t.ResolutionDate,
		t.CreateDate,
		t.SolveDate,		
		t.ResponseID, 					
		t.StatusID, 					
		t.Solution, 
		t.IsReviewed, 
		t.ReviewerName,
		t.Subject,
		nr.value(N'@Remark',N'nvarchar(max)') AS Description
	FROM #temp t
	OUTER APPLY t.Description.nodes(N'//row') AS A(nr)
	ORDER BY t.FeedbackDate DESC

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
GRANT EXECUTE ON [dbo].[Acc_CRM_Rpt_FeedbackSelByDate] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_Rpt_FeedbackSelByDate] TO [vnteam]