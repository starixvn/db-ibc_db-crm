  

ALTER PROCEDURE [dbo].[Acc_CRM_Rpt_LicenseeStatisticsDetail] 
(
	@fromdate	DATETIME,
	@todate		DATETIME
)
AS
/*
	Created: 20110830@Lukas	
	Task :  Licensee feedback detail report
	DB: DB06.bodb_CRM
	Original:

	Revisions:
			
	Param's Explanation:
			
*/
BEGIN
	SET NOCOUNT ON	

	SELECT	@fromdate	= DATEADD(DAY,0,CONVERT(CHAR(12),@FromDate, 101)),
			@todate		= DATEADD(ms,-2,DATEADD(DAY,1,CONVERT(CHAR(12),@ToDate, 101)))
	
	SELECT	FeedbackID, 
			fb.CustID, 
			fb.TitleID, 
			c.UserName, 
			fb.FirstName, 
			fb.LastName, 
			fb.Phone, 		
			fb.MobilePhone, 
			fb.Fax, 
			fb.Email, 
			fb.Skype, 
			fb.MSN, 
			fb.LanguageID, 
			fb.CountryID, 
			fb.CreateDate, 		
			fb.CreatorID, 
			ci.UserName as CreatorName, 
			fb.FeedbackDate, 
			fb.ResolutionDate,
			fb.SolveDate, 
			fb.CommunicationID, 
			fb.StationID, 
			fb.MainCategoryID,		
			fb.SubCategoryID, 
			fb.SiteID, 
			fb.RoleID, 
			fb.ProductID, 
			fb.BetTypeID, 
			fb.ResponseID, 
			fb.StatusID, 		
			fb.Description, 
			fb.Solution, 
			fb.IsReviewed, 
			fb.Review, 
			fb.ReviewerID, 
			fb.Subject
	FROM crmFeedback fb WITH(NOLOCK)
		INNER JOIN crmCustomer c WITH(NOLOCK) ON fb.CustID = c.CustID		
		LEFT JOIN bodb02.dbo.custinfo ci WITH(NOLOCK) ON fb.CreatorID = ci.custID
	WHERE fb.feedbackdate BETWEEN @fromdate AND @todate	
		AND fb.SiteID >= 6200
		AND fb.StatusID <> 11004
	ORDER BY fb.feedbackdate DESC
END



GO
GRANT EXECUTE ON [dbo].[Acc_CRM_Rpt_LicenseeStatisticsDetail] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_Rpt_LicenseeStatisticsDetail] TO [vnteam]