
ALTER PROCEDURE [dbo].[Acc_CRM_FeedbackSelTopByCustId] 
(
	@CustID		INT,
	@top int = 10
)	
AS
/*
	Created: Kevin
	Date: 20110624
	Task : get top 10 feedback info by custid
	DB: DB06.bodb_CRM
	Original:

	Revisions:
		- 20110629@Lukas: support get multipe related customer
	    - 20110722@Kevin: add @top param
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
				fb.CreateDate,
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
				fb.StatusID <> 11004				
				
			ORDER BY FeedbackDate DESC		
		) t CROSS APPLY dbo.f_GetRelatedCustomer(t.FeedbackID) l	
END






GO
GRANT EXECUTE ON [dbo].[Acc_CRM_FeedbackSelTopByCustId] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_FeedbackSelTopByCustId] TO [vnteam]