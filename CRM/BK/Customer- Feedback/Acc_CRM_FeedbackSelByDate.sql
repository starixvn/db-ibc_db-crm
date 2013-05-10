 

ALTER PROCEDURE [dbo].[Acc_CRM_FeedbackSelByDate]
(
	@CustID		INT,
	@FromDate	DATETIME,
	@ToDate		DATETIME
)	
AS
/*
	Created: Lukas
	Date: 20101023
	Task : get feedback info
	DB: DB06.bodb_CRM
	Original:

	Revisions:
		- 20110622@Kevin: remove paging
		- 20110629@Lukas: support get multipe related customer
	Param's Explanation:
	
*/
BEGIN		
	SET NOCOUNT ON
		
	SELECT	@FromDate	= DATEADD(d,0,CONVERT(CHAR(12),@FromDate, 101)),
			@ToDate		= DATEADD(ms,-2,DATEADD(d,1,CONVERT(CHAR(12),@ToDate, 101)))

	SELECT t.*, l.list AS relatedCustomer
	FROM (
			SELECT 				
				fb.FeedbackID, 
				fb.CustID, 
				ctm.UserName,
				fb.TitleID, 
				fb.FirstName, 
				fb.LastName, 
				fb.Phone, 
				fb.MobilePhone, 
				fb.Fax, 
				fb.Email, 
				fb.Skype,
				fb.msn,
				fb.LanguageID, 
				fb.CountryID,
				fb.CreatorID, 
				c.username AS CreatorName,
				fb.FeedbackDate,
				fb.ResolutionDate,
				fb.CreateDate,
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
				rv.username AS ReviewerName,		
				fbc.IsRelated,
				fb.Subject
			FROM 
				crmFeedbackCustomer fbc WITH(NOLOCK)
					INNER JOIN crmFeedback fb WITH(NOLOCK) ON fb.FeedbackID = fbc.FeedbackID
					INNER JOIN crmCustomer ctm WITH(NOLOCK) ON ctm.CustID = fb.CustID
					INNER JOIN bodb02.dbo.custinfo c WITH(NOLOCK) ON fb.CreatorID = c.custID
					LEFT JOIN bodb02.dbo.custinfo rv WITH(NOLOCK) ON fb.ReviewerID = rv.custID			
			WHERE
				fbc.CustID = @CustID 
				AND 
				fb.FeedbackDate BETWEEN @FromDate AND @ToDate
				AND fb.StatusID <> 11004
		) t CROSS APPLY dbo.f_GetRelatedCustomer(t.FeedbackID) l
	ORDER BY t.feedbackdate DESC
END







GO
GRANT EXECUTE ON [dbo].[Acc_CRM_FeedbackSelByDate] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_FeedbackSelByDate] TO [vnteam]