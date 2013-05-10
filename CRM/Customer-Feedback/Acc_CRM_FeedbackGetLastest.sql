
ALTER PROCEDURE [dbo].[Acc_CRM_FeedbackGetLatest]
(
	@UserName			NVARCHAR(50)= NULL,
	@IsGuest			BIT			= NULL,
	@FromDate			DATETIME,
	@ToDate				DATETIME,
	@CommunicationID	INT			= NULL,
	@MainCategoryID		INT			= NULL,
	@SubCategoryID		INT			= NULL,
	@StatusID			INT			= NULL,
	@IsReviewed			BIT			= NULL,
	@ResponseID			INT			= NULL
)
AS
/*
Created: Lukas
Date: 20101023
Task : get feedback info
DB: DB052.bodb_CRM
Original:

Revisions:
	- 20110620@Lukas: remove paging
	- 20110622@Kevin:
					+ add new filter: ResponseId
					+ does not select statusid = 1004
					+ return create date column
	- 20110629@Lukas: support get multipe related customer
	- 20120425@Sophia: remove converting @FromDate, @Todate
	
Param's Explanation:
	
*/
BEGIN		
	SET NOCOUNT ON

	DECLARE @CustID		INT,
			@GuestID	INT,
			@TotalPages INT

	
	--- get feedback for specific customer
	IF @UserName IS NOT NULL AND @UserName <> ''
	BEGIN
		IF @IsGuest IS NULL
		BEGIN
			SELECT @CustID = CustID
			FROM	crmCustomer WITH(NOLOCK)
			WHERE UserName = @UserName AND CustID > 0

			SELECT @GuestID = CustID
			FROM	crmCustomer WITH(NOLOCK)
			WHERE UserName = @UserName AND CustID < 0
		END
		ELSE IF @IsGuest = 0
		BEGIN
			SELECT @CustID = CustID, @GuestID = CustID
			FROM	crmCustomer WITH(NOLOCK)
			WHERE UserName = @UserName AND CustID > 0
		END
		ELSE
		BEGIN
			SELECT @GuestID = CustID, @CustID = CustID
			FROM	crmCustomer WITH(NOLOCK)
			WHERE UserName = @UserName AND CustID < 0
		END			
		
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
					( fbc.CustID = @CustID OR fbc.CustID = @GuestID)
					AND 
					FeedbackDate BETWEEN @FromDate AND @ToDate 
					AND 
					CommunicationID = ISNULL(@CommunicationID, CommunicationID) 
					AND 
					MainCategoryID = ISNULL(@MainCategoryID, MainCategoryID) 
					AND 
					SubCategoryID = ISNULL(@SubCategoryID, SubCategoryID) 
					AND 
					StatusID = ISNULL(@StatusID, StatusID) 
					AND 
					StatusID <> CASE WHEN ISNULL(@statusID,0) <> 11004 THEN 11004 ELSE -1 END
					AND 
					IsReviewed = ISNULL(@IsReviewed, IsReviewed)
--					AND
--					fbc.IsRelated = 0
					AND 
					ResponseID = ISNULL(@ResponseID, ResponseID) 
				) t
				CROSS APPLY dbo.f_GetRelatedCustomer(t.FeedbackID) l
		ORDER BY FeedbackDate DESC
	END	
	ELSE  
	BEGIN		
		IF @IsGuest IS NULL    ------ get feedback for all customer
		BEGIN		
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
						FeedbackDate BETWEEN @FromDate AND @ToDate 
						AND 
						CommunicationID = ISNULL(@CommunicationID, CommunicationID) 
						AND 
						MainCategoryID = ISNULL(@MainCategoryID, MainCategoryID) 
						AND 
						SubCategoryID = ISNULL(@SubCategoryID, SubCategoryID) 
						AND 
						StatusID = ISNULL(@StatusID, StatusID) 
						AND 
						StatusID <> CASE WHEN ISNULL(@statusID,0) <> 11004 THEN 11004 ELSE -1 END
						AND 
						IsReviewed = ISNULL(@IsReviewed, IsReviewed)
						AND
						fbc.IsRelated = 0
						AND 
						ResponseID = ISNULL(@ResponseID, ResponseID) 
					
				) t CROSS APPLY dbo.f_GetRelatedCustomer(t.FeedbackID) l
			ORDER BY FeedbackDate DESC
		END		
		ELSE IF @IsGuest = 0 -- get feedback for only customer
		BEGIN		
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
						fbc.CustID > 0
						AND 
						FeedbackDate BETWEEN @FromDate AND @ToDate 
						AND 
						CommunicationID = ISNULL(@CommunicationID, CommunicationID) 
						AND 
						MainCategoryID = ISNULL(@MainCategoryID, MainCategoryID) 
						AND 
						SubCategoryID = ISNULL(@SubCategoryID, SubCategoryID) 
						AND 
						StatusID = ISNULL(@StatusID, StatusID) 
						AND 
						StatusID <> CASE WHEN ISNULL(@statusID,0) <> 11004 THEN 11004 ELSE -1 END
						AND 
						IsReviewed = ISNULL(@IsReviewed, IsReviewed)
						AND
						fbc.IsRelated = 0
						AND 
						ResponseID = ISNULL(@ResponseID, ResponseID)					
				) t CROSS APPLY dbo.f_GetRelatedCustomer(t.FeedbackID) l
			ORDER BY FeedbackDate DESC

		END   --- end: get feedback for customer
		ELSE		
		BEGIN  -- get feedback for guest
			SELECT t.*, l.list relatedCustomer
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
						fbc.CustID < 0
						AND 
						FeedbackDate BETWEEN @FromDate AND @ToDate 
						AND 
						CommunicationID = ISNULL(@CommunicationID, CommunicationID) 
						AND 
						MainCategoryID = ISNULL(@MainCategoryID, MainCategoryID) 
						AND 
						SubCategoryID = ISNULL(@SubCategoryID, SubCategoryID) 
						AND 
						StatusID = ISNULL(@StatusID, StatusID) 
						AND 
						StatusID <> CASE WHEN ISNULL(@statusID,0) <> 11004 THEN 11004 ELSE -1 END
						AND 
						IsReviewed = ISNULL(@IsReviewed, IsReviewed)
						AND
						fbc.IsRelated = 0
						AND 
						ResponseID = ISNULL(@ResponseID, ResponseID) 					
				) t CROSS APPLY dbo.f_GetRelatedCustomer(t.FeedbackID) l
			ORDER BY FeedbackDate DESC
		END -- end: get feedback for guest
	END
END








GO
GRANT EXECUTE ON [dbo].[Acc_CRM_FeedbackGetLastest] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_FeedbackGetLastest] TO [vnteam]  