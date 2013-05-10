
ALTER PROCEDURE [dbo].[Acc_CRM_FeedbackSelTop] 
(
	@top int = 10
)	
AS
/*
	Created: Kevin
	Date: 20110722
	Task : get top 10 feedback info
	DB: DB06.bodb_CRM
	Original:

	Revisions:
	Param's Explanation:
	
*/
BEGIN		
	SET NOCOUNT ON	
	SELECT t.*, l.list AS relatedCustomer
	FROM (	
			SELECT TOP (@top)
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
				fb.StatusID <> 11004
				AND 
				fbc.IsRelated = 0
			ORDER BY FeedbackDate DESC		
		) t CROSS APPLY dbo.f_GetRelatedCustomer(t.FeedbackID) l	
	
END




GO
GRANT EXECUTE ON [dbo].[Acc_CRM_FeedbackSelTop] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_FeedbackSelTop] TO [vnteam]