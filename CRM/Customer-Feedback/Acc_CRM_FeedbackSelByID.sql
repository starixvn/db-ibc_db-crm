

ALTER PROCEDURE [dbo].[Acc_CRM_FeedbackSelByID]
(
	@FeedbackID INT
)
AS
/*
	Created: Lukas
	Date: 20101023
	Task : get feedback info
	DB: DB052.bodb_CRM
	Original:

	Revisions:
		- 20110629@Lukas: support get multipe related customer
		- 20120307@Elodie: get more 3 values Pic1, Pic2, Pic3
		- 20120319@Elodie: change DB06 to DB052
	Param's Explanation:
		
*/
BEGIN	
	SET NOCOUNT ON

	DECLARE @RelatedCustID	INT, 
			@RelatedUserName NVARCHAR(30)

		
	--- get feedback info
	SELECT 
		fb.FeedbackID, 
		fb.CustID, 
		ctm.UserName,
		ISNULL(fb.TitleID,0) TitleID, 
		fb.FirstName, 
		fb.LastName, 
		fb.Phone, 
		fb.MobilePhone, 
		fb.Fax, 
		fb.Email, 
		fb.Skype,
		fb.msn,
		ISNULL(fb.LanguageID,0) LanguageID, 
		ISNULL(fb.CountryID,0) CountryID,
		fb.CreatorID, 
		c.username AS CreatorName,
		fb.FeedbackDate,
		fb.ResolutionDate,
		fb.CreateDate,
		fb.SolveDate,
		ISNULL(fb.CommunicationID,0) CommunicationID, 
		ISNULL(fb.StationID,0) StationID, 
		ISNULL(fb.MainCategoryID,0) MainCategoryID,
		ISNULL(fb.SubCategoryID,0) SubCategoryID, 
		ISNULL(fb.SiteID,0) SiteID, 
		ISNULL(fb.RoleID,0) RoleID, 
		ISNULL(fb.ProductID,0)ProductID, 
		ISNULL(fb.BetTypeID,0) BettypeID, 
		ISNULL(fb.ResponseID,0) ResponseID, 
		ISNULL(fb.StatusID,0) StatusID, 
		fb.Description, 
		fb.Solution, 
		fb.IsReviewed, 
		fb.Review, 
		ISNULL(fb.ReviewerID,0) ReviewerID,
		rv.username AS ReviewerName,		
		fb.Subject,
		l.list relatedCustomer,
		ISNULL(fb.Pic1,'') Pic1,
		ISNULL(fb.Pic2,'') Pic2,
		ISNULL(fb.Pic3,'') Pic3
	FROM 
		crmFeedback fb WITH(NOLOCK) 
			CROSS APPLY dbo.f_GetRelatedCustomer(fb.FeedbackID) l
			INNER JOIN crmCustomer ctm WITH(NOLOCK) ON fb.CustID = ctm.CustID
			INNER JOIN bodb02.dbo.custinfo c WITH(NOLOCK) ON fb.CreatorID = c.custID
			LEFT JOIN bodb02.dbo.custinfo rv WITH(NOLOCK) ON fb.ReviewerID = rv.custID
										
	WHERE 
		fb.FeedbackID = @FeedbackID	
END

GO
GRANT EXECUTE ON [dbo].[Acc_CRM_FeedbackSelByID] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_FeedbackSelByID] TO [vnteam]