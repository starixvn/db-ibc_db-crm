

ALTER PROCEDURE [dbo].[Acc_CRM_Rpt_CasinoStatisticsDetail]
(
	@fromdate	DATETIME,
	@todate		DATETIME
)
AS
/*
	Created: 20110830@Lukas	
	Task :  related casino feedback detail report
	DB: DB052.bodb_CRM
	Original:

	Revisions:
		- 20120420@Sophia: Add ProductID = 8014 for Live Casino 
		- 20120425@Sophia: remove converting @FromDate, @Todate
		- 20120710@Sophia: Add ProductID = 8013 for Mini Game
		- 20120730@Sophia: Add ProductID = 8017 for Poker
		
	Param's Explanation:
		@Type:	- 1	Daily
				- 2	Weekly					
*/
BEGIN
	SET NOCOUNT ON	

	
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
	WHERE ProductID IN (8003,8008,8011,8013,8014,8017) 
			AND fb.feedbackdate BETWEEN @fromdate AND @todate
			AND fb.StatusID <> 11004	
	ORDER BY fb.feedbackdate DESC
END



GO
GRANT EXECUTE ON [dbo].[Acc_CRM_Rpt_CasinoStatisticsDetail] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_Rpt_CasinoStatisticsDetail] TO [vnteam]
