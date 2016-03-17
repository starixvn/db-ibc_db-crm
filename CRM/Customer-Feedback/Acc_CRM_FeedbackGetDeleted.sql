ALTER PROCEDURE	dbo.Acc_CRM_FeedbackGetDeleted (
					@UserName			NVARCHAR(50)	= NULL
				,	@IsGuest			BIT				= NULL
				,	@FromDate			DATETIME
				,	@ToDate				DATETIME
				,	@CommunicationID	INT				= NULL
				,	@MainCategoryID		INT				= NULL
				,	@SubCategoryID		INT				= NULL
				,	@IsReviewed			BIT				= NULL
				,	@ResponseID			INT				= NULL
				)
AS
/*
	Created:	Kevin
	Date:		20110622
	Task:		get deleted feedback info
	DB:			DB052.bodb_CRM
	Original:

	Revisions:
		- 20110629@Lukas:	support multiple feedback related customer
		- 20120425@Sophia:	remove converting @FromDate, @Todate
		- 20160308@Billy:	Integrate Sub-Product field - [Redmine: #52998]
		
	Param's Explanation:
	
*/
BEGIN		
	SET NOCOUNT ON;

	DECLARE	@CustID			INT
		,	@GuestID		INT
		,	@TotalPages		INT;

	--- get feedback for specific customer
	IF	@UserName IS NOT NULL AND @UserName <> ''
	BEGIN
		IF	@IsGuest IS NULL
		BEGIN
			SELECT	@CustID = CustID
			FROM	crmCustomer WITH (NOLOCK)
			WHERE	UserName = @UserName
				AND	CustID > 0;

			SELECT	@GuestID = CustID
			FROM	crmCustomer WITH (NOLOCK)
			WHERE	UserName = @UserName
				AND	CustID < 0;
		END;
		ELSE IF	@IsGuest = 0
		BEGIN
			SELECT	@CustID = CustID
				,	@GuestID = CustID
			FROM	crmCustomer WITH(NOLOCK)
			WHERE	UserName = @UserName
				AND	CustID > 0;
		END;
		ELSE
		BEGIN
			SELECT	@GuestID = CustID
				,	@CustID = CustID
			FROM	crmCustomer WITH(NOLOCK)
			WHERE	UserName = @UserName
				AND	CustID < 0;
		END;			
		
		SELECT	fb.FeedbackID
			,	fb.CustID
			,	ctm.UserName
			,	fb.TitleID
			,	fb.FirstName
			,	fb.LastName
			,	fb.Phone
			,	fb.MobilePhone
			,	fb.Fax
			,	fb.Email
			,	fb.Skype
			,	fb.msn
			,	fb.LanguageID
			,	fb.CountryID
			,	fb.CreatorID
			,	c.username AS CreatorName
			,	fb.FeedbackDate
			,	fb.ResolutionDate
			,	fb.CreateDate
			,	fb.SolveDate
			,	fb.CommunicationID
			,	fb.StationID
			,	fb.MainCategoryID
			,	fb.SubCategoryID
			,	fb.SiteID
			,	fb.RoleID
			,	fb.ProductID
			,	fb.SubProductID
			,	fb.BetTypeID
			,	fb.ResponseID
			,	fb.StatusID
			,	fb.Description
			,	fb.Solution
			,	fb.IsReviewed
			,	fb.Review
			,	fb.ReviewerID
			,	rv.username AS ReviewerName
			,	fbc.IsRelated
			,	fb.Subject
			,	l.list AS relatedCustomer
		FROM		crmFeedbackCustomer fbc WITH(NOLOCK)
		INNER JOIN	crmFeedback fb WITH(NOLOCK)
				ON	fb.FeedbackID = fbc.FeedbackID						
		INNER JOIN	crmCustomer ctm WITH(NOLOCK)
				ON	ctm.CustID = fb.CustID
		INNER JOIN	bodb02.dbo.custinfo c WITH(NOLOCK)
				ON	fb.CreatorID = c.custID
		LEFT JOIN	bodb02.dbo.custinfo rv WITH(NOLOCK)
				ON	fb.ReviewerID = rv.custID
		CROSS APPLY	dbo.f_GetRelatedCustomer(fb.FeedbackID) l
		WHERE	(fbc.CustID = @CustID OR fbc.CustID = @GuestID)
			AND	FeedbackDate BETWEEN @FromDate AND @ToDate 
			AND	CommunicationID = ISNULL(@CommunicationID, CommunicationID) 
			AND	MainCategoryID = ISNULL(@MainCategoryID, MainCategoryID) 
			AND	SubCategoryID = ISNULL(@SubCategoryID, SubCategoryID) 
			AND	StatusID = 11004
			AND	IsReviewed = ISNULL(@IsReviewed, IsReviewed)
			AND	fbc.IsRelated = 0
			AND	ResponseID = ISNULL(@ResponseID, ResponseID)
		ORDER BY FeedbackDate DESC;
	END;	
	ELSE  
	BEGIN
		IF	@IsGuest IS NULL ------ get feedback for all customer
		BEGIN		
			SELECT	fb.FeedbackID
				,	fb.CustID
				,	ctm.UserName
				,	fb.TitleID
				,	fb.FirstName
				,	fb.LastName
				,	fb.Phone
				,	fb.MobilePhone
				,	fb.Fax
				,	fb.Email
				,	fb.Skype
				,	fb.msn
				,	fb.LanguageID
				,	fb.CountryID
				,	fb.CreatorID
				,	c.username AS CreatorName
				,	fb.FeedbackDate
				,	fb.ResolutionDate
				,	fb.CreateDate
				,	fb.SolveDate
				,	fb.CommunicationID
				,	fb.StationID
				,	fb.MainCategoryID
				,	fb.SubCategoryID
				,	fb.SiteID
				,	fb.RoleID
				,	fb.ProductID
				,	fb.SubProductID
				,	fb.BetTypeID
				,	fb.ResponseID
				,	fb.StatusID
				,	fb.Description
				,	fb.Solution
				,	fb.IsReviewed
				,	fb.Review
				,	fb.ReviewerID
				,	rv.username AS ReviewerName
				,	fbc.IsRelated
				,	fb.Subject
				,	l.list AS relatedCustomer			
			FROM		crmFeedbackCustomer fbc WITH(NOLOCK)
			INNER JOIN	crmFeedback fb WITH(NOLOCK)
					ON	fb.FeedbackID = fbc.FeedbackID							
			INNER JOIN	crmCustomer ctm WITH(NOLOCK)
					ON	ctm.CustID = fb.CustID
			INNER JOIN	bodb02.dbo.custinfo c WITH(NOLOCK)
					ON	fb.CreatorID = c.custID
			LEFT JOIN	bodb02.dbo.custinfo rv WITH(NOLOCK)
					ON	fb.ReviewerID = rv.custID
			CROSS APPLY	dbo.f_GetRelatedCustomer(fb.FeedbackID) l
			WHERE	FeedbackDate BETWEEN @FromDate AND @ToDate 
				AND	CommunicationID = ISNULL(@CommunicationID, CommunicationID) 
				AND	MainCategoryID = ISNULL(@MainCategoryID, MainCategoryID) 
				AND	SubCategoryID = ISNULL(@SubCategoryID, SubCategoryID) 
				AND	StatusID = 11004
				AND	IsReviewed = ISNULL(@IsReviewed, IsReviewed)
				AND	fbc.IsRelated = 0
				AND	ResponseID = ISNULL(@ResponseID, ResponseID) 
			ORDER BY FeedbackDate DESC;
		END;
		-- customer
		ELSE IF	@IsGuest = 0
		BEGIN
			SELECT	fb.FeedbackID
				,	fb.CustID
				,	ctm.UserName
				,	fb.TitleID
				,	fb.FirstName
				,	fb.LastName
				,	fb.Phone
				,	fb.MobilePhone
				,	fb.Fax
				,	fb.Email
				,	fb.Skype
				,	fb.msn
				,	fb.LanguageID
				,	fb.CountryID
				,	fb.CreatorID
				,	c.username AS CreatorName
				,	fb.FeedbackDate
				,	fb.ResolutionDate
				,	fb.CreateDate
				,	fb.SolveDate
				,	fb.CommunicationID
				,	fb.StationID
				,	fb.MainCategoryID
				,	fb.SubCategoryID
				,	fb.SiteID
				,	fb.RoleID
				,	fb.ProductID
				,	fb.SubProductID
				,	fb.BetTypeID
				,	fb.ResponseID
				,	fb.StatusID
				,	fb.Description
				,	fb.Solution
				,	fb.IsReviewed
				,	fb.Review
				,	fb.ReviewerID
				,	rv.username AS ReviewerName				
				,	fbc.IsRelated
				,	fb.Subject
				,	l.list AS relatedCustomer
			FROM		crmFeedbackCustomer fbc WITH(NOLOCK)
			INNER JOIN	crmFeedback fb WITH(NOLOCK)
					ON	fb.FeedbackID = fbc.FeedbackID							
			INNER JOIN	crmCustomer ctm WITH(NOLOCK)
					ON	ctm.CustID = fb.CustID
			INNER JOIN	bodb02.dbo.custinfo c WITH(NOLOCK)
					ON	fb.CreatorID = c.custID
			LEFT JOIN	bodb02.dbo.custinfo rv WITH(NOLOCK)
					ON	fb.ReviewerID = rv.custID	
			CROSS APPLY	dbo.f_GetRelatedCustomer(fb.FeedbackID) l
			WHERE	fbc.CustID > 0
				AND	FeedbackDate BETWEEN @FromDate AND @ToDate 
				AND	CommunicationID = ISNULL(@CommunicationID, CommunicationID) 
				AND	MainCategoryID = ISNULL(@MainCategoryID, MainCategoryID) 
				AND	SubCategoryID = ISNULL(@SubCategoryID, SubCategoryID) 
				AND	StatusID = 11004
				AND	IsReviewed = ISNULL(@IsReviewed, IsReviewed)
				AND	fbc.IsRelated = 0
				AND	ResponseID = ISNULL(@ResponseID, ResponseID) 
			ORDER BY FeedbackDate DESC;

		END;   --- end: get feedback for customer
		ELSE
		-- get feedback for guest
		BEGIN
			SELECT	fb.FeedbackID
				,	fb.CustID
				,	ctm.UserName
				,	fb.TitleID
				,	fb.FirstName
				,	fb.LastName
				,	fb.Phone
				,	fb.MobilePhone
				,	fb.Fax
				,	fb.Email
				,	fb.Skype
				,	fb.msn
				,	fb.LanguageID
				,	fb.CountryID
				,	fb.CreatorID
				,	c.username AS CreatorName
				,	fb.FeedbackDate
				,	fb.ResolutionDate
				,	fb.CreateDate
				,	fb.SolveDate
				,	fb.CommunicationID
				,	fb.StationID
				,	fb.MainCategoryID
				,	fb.SubCategoryID
				,	fb.SiteID
				,	fb.RoleID
				,	fb.ProductID
				,	fb.SubProductID
				,	fb.BetTypeID
				,	fb.ResponseID
				,	fb.StatusID
				,	fb.Description
				,	fb.Solution
				,	fb.IsReviewed
				,	fb.Review
				,	fb.ReviewerID
				,	rv.username AS ReviewerName			
				,	fbc.IsRelated
				,	fb.Subject
				,	l.list AS relatedCustomer
			FROM	crmFeedbackCustomer fbc WITH(NOLOCK)
			INNER JOIN	crmFeedback fb WITH(NOLOCK)
					ON	fb.FeedbackID = fbc.FeedbackID
			INNER JOIN	crmCustomer ctm WITH(NOLOCK)
					ON	ctm.CustID = fb.CustID
			INNER JOIN	bodb02.dbo.custinfo c WITH(NOLOCK)
					ON	fb.CreatorID = c.custID
			LEFT JOIN	bodb02.dbo.custinfo rv WITH(NOLOCK)
					ON	fb.ReviewerID = rv.custID
			CROSS APPLY	dbo.f_GetRelatedCustomer(fb.FeedbackID) l
			WHERE	fbc.CustID < 0
				AND	FeedbackDate BETWEEN @FromDate AND @ToDate 
				AND	CommunicationID = ISNULL(@CommunicationID, CommunicationID) 
				AND	MainCategoryID = ISNULL(@MainCategoryID, MainCategoryID) 
				AND	SubCategoryID = ISNULL(@SubCategoryID, SubCategoryID) 
				AND	StatusID = 11004
				AND	IsReviewed = ISNULL(@IsReviewed, IsReviewed)
				AND	fbc.IsRelated = 0
				AND	ResponseID = ISNULL(@ResponseID, ResponseID) 
			ORDER BY FeedbackDate DESC;

		END; -- end: get feedback for guest
	END;
END;
GO

GRANT EXECUTE ON dbo.Acc_CRM_FeedbackGetDeleted TO bodbAdminNet;
GO
GRANT VIEW DEFINITION ON dbo.Acc_CRM_FeedbackGetDeleted TO vnteam;
GO