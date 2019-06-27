/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE	dbo.Acc_CRM_FeedbackGetLatest (
					@UserName			NVARCHAR(50)	= NULL
				,	@IsGuest			BIT				= NULL
				,	@FromDate			DATETIME
				,	@ToDate				DATETIME
				,	@CommunicationID	INT				= NULL
				,	@MainCategoryID		INT				= NULL
				,	@SubCategoryID		INT				= NULL
				,	@StatusID			INT				= NULL
				,	@IsReviewed			BIT				= NULL
				,	@ResponseID			INT				= NULL
				,	@FeedbackID			INT				= NULL
				)
AS
/*
	Created:	Lukas
	Date:		20101023
	Task:		get feedback info
	DB:			DB052.bodb_CRM
	Original:

	Revisions:
		- 20110620@Lukas:	remove paging
		- 20110622@Kevin:
						+	add new filter: ResponseId
						+	does not select statusid = 1004
						+	return create date column
		- 20110629@Lukas:	support get multipe related customer
		- 20120425@Sophia:	remove converting @FromDate, @Todate
		- 20140528@Dom:		Fix bug duplicated data
		- 20160308@Billy:	Integrate Sub-Product field - [Redmine: #52998]
		- 20180117@Winnie:	Add Is Related Customer - [Redmine: #88774]
		- 20190506@Winnie: CN88 Permission RedmineID: #112637
	Param's Explanation:
	
*/
BEGIN		
	SET NOCOUNT ON;

	DECLARE	@CustID		INT
		,	@GuestID	INT
		,	@TotalPages INT;

	DECLARE @result TABLE
				(
						FeedbackID INT
					,	CustID INT
					,	UserName NVARCHAR(50)
					,	TitleID INT
					,	FirstName NVARCHAR(50)
					,	LastName NVARCHAR(50)
					,	Phone NVARCHAR(100)
					,	PhoneAreaCode NVARCHAR(20)
					,	PhoneCountryCode NVARCHAR(20)
					,	Phone2 NVARCHAR(100)
					,	Phone2AreaCode NVARCHAR(20)
					,	Phone2CountryCode NVARCHAR(20)
					,	Phone3 NVARCHAR(100)
					,	Phone3AreaCode NVARCHAR(20)
					,	Phone3CountryCode NVARCHAR(20)
					,	MobilePhone NVARCHAR(100)
					,	MobilePhoneAreaCode NVARCHAR(20)
					,	MobilePhoneCountryCode NVARCHAR(20)
					,	Fax  NVARCHAR(50)
					,	FaxAreaCode NVARCHAR(20)
					,	FaxCountryCode NVARCHAR(20)
					,	Email  NVARCHAR(254)
					,	Skype NVARCHAR(100)
					,	msn NVARCHAR(100)
					,	LanguageID INT
					,	CountryID INT
					,	CreatorID INT
					,	CreatorName NVARCHAR(50)
					,	FeedbackDate DATETIME
					,	ResolutionDate DATETIME
					,	CreateDate DATETIME
					,	SolveDate DATETIME
					,	CommunicationID INT
					,	StationID INT
					,	MainCategoryID INT
					,	SubCategoryID INT
					,	SiteID INT
					,	RoleID INT
					,	ProductID INT
					,	SubProductID INT
					,	BetTypeID INT
					,	ResponseID INT
					,	StatusID INT
					,	Description XML
					,	Solution NVARCHAR(MAX)
					,	IsReviewed BIT
					,	Review NVARCHAR(MAX)
					,	ReviewerID INT
					,	ReviewerName NVARCHAR(50)
					,	IsRelated BIT
					,	Subject NVARCHAR(MAX)
					,	RefCode1 NVARCHAR(100)
					,	RefCode2 NVARCHAR(100)
					,	relatedCustomer	NVARCHAR(MAX)
				)		

	IF	ISNULL(@FeedbackID, 0) <> 0
	BEGIN
		DECLARE	@IsRelated INT = 0;
		SELECT TOP 1	@IsRelated = @IsRelated
		FROM	crmFeedbackCustomer WITH (NOLOCK)
		WHERE	FeedbackID = @FeedbackID
			AND	@IsRelated = 1;

			INSERT INTO @result 
				(
						FeedbackID 
					,	CustID 
					,	UserName 
					,	TitleID 
					,	FirstName 
					,	LastName 
					,	Phone
					,	PhoneAreaCode 
					,	PhoneCountryCode 
					,	Phone2
					,	Phone2AreaCode 
					,	Phone2CountryCode 
					,	Phone3 
					,	Phone3AreaCode 
					,	Phone3CountryCode 
					,	MobilePhone
					,	MobilePhoneAreaCode 
					,	MobilePhoneCountryCode
					,	Fax  
					,	FaxAreaCode 
					,	FaxCountryCode
					,	Email
					,	Skype 
					,	msn
					,	LanguageID 
					,	CountryID 
					,	CreatorID 
					,	CreatorName 
					,	FeedbackDate 
					,	ResolutionDate 
					,	CreateDate 
					,	SolveDate 
					,	CommunicationID 
					,	StationID 
					,	MainCategoryID 
					,	SubCategoryID 
					,	SiteID 
					,	RoleID 
					,	ProductID 
					,	SubProductID 
					,	BetTypeID 
					,	ResponseID 
					,	StatusID 
					,	Description 
					,	Solution 
					,	IsReviewed 
					,	Review
					,	ReviewerID 
					,	ReviewerName 
					,	IsRelated 
					,	Subject 
					,	RefCode1 
					,	RefCode2 
					,	relatedCustomer	
				)	
		SELECT DISTINCT	fb.FeedbackID
					,	fb.CustID
					,	ctm.UserName
					,	fb.TitleID
					,	fb.FirstName
					,	fb.LastName
					,	fb.Phone
					,	fb.PhoneAreaCode
					,	fb.PhoneCountryCode
					,	fb.Phone2
					,	fb.Phone2AreaCode
					,	fb.Phone2CountryCode
					,	fb.Phone3
					,	fb.Phone3AreaCode
					,	fb.Phone3CountryCode
					,	fb.MobilePhone
					,	fb.MobilePhoneAreaCode
					,	fb.MobilePhoneCountryCode
					,	fb.Fax
					,	fb.FaxAreaCode
					,	fb.FaxCountryCode
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
					,	@IsRelated AS IsRelated
					,	fb.Subject
					,	fb.RefCode1
					,	fb.RefCode2
					,	l.list AS relatedCustomer			
		FROM		crmFeedback fb WITH (NOLOCK)
		INNER JOIN	crmCustomer ctm WITH (NOLOCK)
				ON	ctm.CustID = fb.CustID
		INNER JOIN	bodb02.dbo.custinfo c WITH (NOLOCK)
				ON	fb.CreatorID = c.custID
		LEFT JOIN	bodb02.dbo.custinfo rv WITH (NOLOCK)
				ON	fb.ReviewerID = rv.custID
		CROSS APPLY	dbo.f_GetRelatedCustomer(fb.FeedbackID) l
		WHERE	fb.FeedbackID = @FeedbackID
		ORDER BY FeedbackDate DESC;

		RETURN;
	END;
		
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
			FROM	crmCustomer WITH (NOLOCK)
			WHERE	UserName = @UserName
				AND	CustID > 0;
		END;
		ELSE
		BEGIN
			SELECT	@GuestID = CustID
				,	@CustID = CustID
			FROM	crmCustomer WITH (NOLOCK)
			WHERE	UserName = @UserName
				AND	CustID < 0;
		END;
			INSERT INTO @result 
				(
						FeedbackID 
					,	CustID 
					,	UserName 
					,	TitleID 
					,	FirstName 
					,	LastName 
					,	Phone
					,	PhoneAreaCode 
					,	PhoneCountryCode 
					,	Phone2
					,	Phone2AreaCode 
					,	Phone2CountryCode 
					,	Phone3 
					,	Phone3AreaCode 
					,	Phone3CountryCode 
					,	MobilePhone
					,	MobilePhoneAreaCode 
					,	MobilePhoneCountryCode
					,	Fax  
					,	FaxAreaCode 
					,	FaxCountryCode
					,	Email
					,	Skype 
					,	msn
					,	LanguageID 
					,	CountryID 
					,	CreatorID 
					,	CreatorName 
					,	FeedbackDate 
					,	ResolutionDate 
					,	CreateDate 
					,	SolveDate 
					,	CommunicationID 
					,	StationID 
					,	MainCategoryID 
					,	SubCategoryID 
					,	SiteID 
					,	RoleID 
					,	ProductID 
					,	SubProductID 
					,	BetTypeID 
					,	ResponseID 
					,	StatusID 
					,	Description 
					,	Solution 
					,	IsReviewed 
					,	Review
					,	ReviewerID 
					,	ReviewerName 
					,	IsRelated 
					,	Subject 
					,	RefCode1 
					,	RefCode2 
					,	relatedCustomer	
				)	
		SELECT	fb.FeedbackID
			,	fb.CustID
			,	ctm.UserName
			,	fb.TitleID
			,	fb.FirstName
			,	fb.LastName
			,	fb.Phone
			,	fb.PhoneAreaCode
			,	fb.PhoneCountryCode
			,	fb.Phone2
			,	fb.Phone2AreaCode
			,	fb.Phone2CountryCode
			,	fb.Phone3
			,	fb.Phone3AreaCode
			,	fb.Phone3CountryCode
			,	fb.MobilePhone
			,	fb.MobilePhoneAreaCode
			,	fb.MobilePhoneCountryCode
			,	fb.Fax
			,	fb.FaxAreaCode
			,	fb.FaxCountryCode
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
			,	CAST(fb.Description AS XML) AS Description
			,	fb.Solution
			,	fb.IsReviewed
			,	fb.Review
			,	fb.ReviewerID
			,	rv.username AS ReviewerName
			,	fbc.IsRelated
			,	fb.Subject
			,	fb.RefCode1
			,	fb.RefCode2
			,	l.list AS relatedCustomer			
		FROM	crmFeedbackCustomer fbc WITH (NOLOCK)
		INNER JOIN	crmFeedback fb WITH (NOLOCK)
				ON	fb.FeedbackID = fbc.FeedbackID						
		INNER JOIN	crmCustomer ctm WITH (NOLOCK)
				ON	ctm.CustID = fb.CustID
		INNER JOIN	bodb02.dbo.custinfo c WITH (NOLOCK)
				ON	fb.CreatorID = c.custID
		LEFT JOIN	bodb02.dbo.custinfo rv WITH (NOLOCK)
				ON	fb.ReviewerID = rv.custID
		CROSS APPLY	dbo.f_GetRelatedCustomer(fb.FeedbackID) l
		WHERE	(fbc.CustID = @CustID OR fbc.CustID = @GuestID)
			AND	FeedbackDate BETWEEN @FromDate AND @ToDate 
			AND	CommunicationID = ISNULL(@CommunicationID, CommunicationID) 
			AND	MainCategoryID = ISNULL(@MainCategoryID, MainCategoryID) 
			AND	SubCategoryID = ISNULL(@SubCategoryID, SubCategoryID) 
			AND	StatusID = ISNULL(@StatusID, StatusID) 
			AND	StatusID <> CASE WHEN ISNULL(@statusID, 0) <> 11004 THEN 11004 ELSE -1 END
			AND	StatusID <> CASE WHEN ISNULL(@statusID, 0) <> 11019 THEN 11019 ELSE -1 END
			AND	IsReviewed = ISNULL(@IsReviewed, IsReviewed)
--			AND	fbc.IsRelated = 0
			AND	ResponseID = ISNULL(@ResponseID, ResponseID) 
			AND	fb.FeedbackID = ISNULL(@FeedbackID, fb.FeedbackID)
		ORDER BY FeedbackDate DESC;
	END;	
	ELSE  
	BEGIN		
		IF	@IsGuest IS NULL    ------ get feedback for all customer
		BEGIN
				INSERT INTO @result 
				(
						FeedbackID 
					,	CustID 
					,	UserName 
					,	TitleID 
					,	FirstName 
					,	LastName 
					,	Phone
					,	PhoneAreaCode 
					,	PhoneCountryCode 
					,	Phone2
					,	Phone2AreaCode 
					,	Phone2CountryCode 
					,	Phone3 
					,	Phone3AreaCode 
					,	Phone3CountryCode 
					,	MobilePhone
					,	MobilePhoneAreaCode 
					,	MobilePhoneCountryCode
					,	Fax  
					,	FaxAreaCode 
					,	FaxCountryCode
					,	Email
					,	Skype 
					,	msn
					,	LanguageID 
					,	CountryID 
					,	CreatorID 
					,	CreatorName 
					,	FeedbackDate 
					,	ResolutionDate 
					,	CreateDate 
					,	SolveDate 
					,	CommunicationID 
					,	StationID 
					,	MainCategoryID 
					,	SubCategoryID 
					,	SiteID 
					,	RoleID 
					,	ProductID 
					,	SubProductID 
					,	BetTypeID 
					,	ResponseID 
					,	StatusID 
					,	Description 
					,	Solution 
					,	IsReviewed 
					,	Review
					,	ReviewerID 
					,	ReviewerName 
					,	IsRelated 
					,	Subject 
					,	RefCode1 
					,	RefCode2 
					,	relatedCustomer	
				)	
			SELECT	fb.FeedbackID
				,	fb.CustID
				,	ctm.UserName
				,	fb.TitleID				
				,	fb.FirstName
				,	fb.LastName
				,	fb.Phone
				,	fb.PhoneAreaCode
				,	fb.PhoneCountryCode
				,	fb.Phone2
				,	fb.Phone2AreaCode
				,	fb.Phone2CountryCode
				,	fb.Phone3
				,	fb.Phone3AreaCode
				,	fb.Phone3CountryCode
				,	fb.MobilePhone
				,	fb.MobilePhoneAreaCode
				,	fb.MobilePhoneCountryCode
				,	fb.Fax
				,	fb.FaxAreaCode
				,	fb.FaxCountryCode
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
				,	CAST(fb.Description AS XML) AS Description
				,	fb.Solution
				,	fb.IsReviewed
				,	fb.Review
				,	fb.ReviewerID
				,	rv.username AS ReviewerName
				,	fbc.IsRelated
				,	fb.Subject
				,	fb.RefCode1
				,	fb.RefCode2
				,	l.list AS relatedCustomer			
			FROM		crmFeedbackCustomer fbc WITH (NOLOCK)
			INNER JOIN	crmFeedback fb WITH (NOLOCK)
					ON	fb.FeedbackID = fbc.FeedbackID							
			INNER JOIN	crmCustomer ctm WITH (NOLOCK)
					ON	ctm.CustID = fb.CustID
			INNER JOIN	bodb02.dbo.custinfo c WITH (NOLOCK)
					ON	fb.CreatorID = c.custID
			LEFT JOIN	bodb02.dbo.custinfo rv WITH (NOLOCK)
					ON	fb.ReviewerID = rv.custID
			CROSS APPLY	dbo.f_GetRelatedCustomer(fb.FeedbackID) l
			WHERE	FeedbackDate BETWEEN @FromDate AND @ToDate 
				AND	CommunicationID = ISNULL(@CommunicationID, CommunicationID) 
				AND	MainCategoryID = ISNULL(@MainCategoryID, MainCategoryID) 
				AND	SubCategoryID = ISNULL(@SubCategoryID, SubCategoryID) 
				AND	StatusID = ISNULL(@StatusID, StatusID) 
				AND	StatusID <> CASE WHEN ISNULL(@statusID, 0) <> 11004 THEN 11004 ELSE -1 END
				AND	StatusID <> CASE WHEN ISNULL(@statusID, 0) <> 11019 THEN 11019 ELSE -1 END
				AND	IsReviewed = ISNULL(@IsReviewed, IsReviewed)
				AND	fbc.IsRelated = 0
				AND	ResponseID = ISNULL(@ResponseID, ResponseID) 
				AND	fb.FeedbackID = ISNULL(@FeedbackID, fb.FeedbackID)
			ORDER BY FeedbackDate DESC;
		END;		
		ELSE IF	@IsGuest = 0 -- get feedback for only customer
		BEGIN	
				INSERT INTO @result 
				(
						FeedbackID 
					,	CustID 
					,	UserName 
					,	TitleID 
					,	FirstName 
					,	LastName 
					,	Phone
					,	PhoneAreaCode 
					,	PhoneCountryCode 
					,	Phone2
					,	Phone2AreaCode 
					,	Phone2CountryCode 
					,	Phone3 
					,	Phone3AreaCode 
					,	Phone3CountryCode 
					,	MobilePhone
					,	MobilePhoneAreaCode 
					,	MobilePhoneCountryCode
					,	Fax  
					,	FaxAreaCode 
					,	FaxCountryCode
					,	Email
					,	Skype 
					,	msn
					,	LanguageID 
					,	CountryID 
					,	CreatorID 
					,	CreatorName 
					,	FeedbackDate 
					,	ResolutionDate 
					,	CreateDate 
					,	SolveDate 
					,	CommunicationID 
					,	StationID 
					,	MainCategoryID 
					,	SubCategoryID 
					,	SiteID 
					,	RoleID 
					,	ProductID 
					,	SubProductID 
					,	BetTypeID 
					,	ResponseID 
					,	StatusID 
					,	Description 
					,	Solution 
					,	IsReviewed 
					,	Review
					,	ReviewerID 
					,	ReviewerName 
					,	IsRelated 
					,	Subject 
					,	RefCode1 
					,	RefCode2 
					,	relatedCustomer	
				)	
			SELECT	fb.FeedbackID
				,	fb.CustID
				,	ctm.UserName
				,	fb.TitleID				
				,	fb.FirstName
				,	fb.LastName
				,	fb.Phone
				,	fb.PhoneAreaCode
				,	fb.PhoneCountryCode
				,	fb.Phone2
				,	fb.Phone2AreaCode
				,	fb.Phone2CountryCode
				,	fb.Phone3
				,	fb.Phone3AreaCode
				,	fb.Phone3CountryCode
				,	fb.MobilePhone
				,	fb.MobilePhoneAreaCode
				,	fb.MobilePhoneCountryCode
				,	fb.Fax
				,	fb.FaxAreaCode
				,	fb.FaxCountryCode
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
				,	CAST(fb.Description AS XML) AS Description
				,	fb.Solution
				,	fb.IsReviewed
				,	fb.Review
				,	fb.ReviewerID
				,	rv.username AS ReviewerName			
				,	fbc.IsRelated
				,	fb.Subject
				,	fb.RefCode1
				,	fb.RefCode2
				,	l.list AS relatedCustomer
			FROM		crmFeedbackCustomer fbc WITH (NOLOCK)
			INNER JOIN	crmFeedback fb WITH (NOLOCK)
					ON	fb.FeedbackID = fbc.FeedbackID							
			INNER JOIN	crmCustomer ctm WITH (NOLOCK)
					ON	ctm.CustID = fb.CustID
			INNER JOIN	bodb02.dbo.custinfo c WITH (NOLOCK)
					ON	fb.CreatorID = c.custID
			LEFT JOIN	bodb02.dbo.custinfo rv WITH (NOLOCK)
					ON	fb.ReviewerID = rv.custID
			CROSS APPLY	dbo.f_GetRelatedCustomer(fb.FeedbackID) l
			WHERE	fbc.CustID > 0
				AND	FeedbackDate BETWEEN @FromDate AND @ToDate 
				AND	CommunicationID = ISNULL(@CommunicationID, CommunicationID) 
				AND	MainCategoryID = ISNULL(@MainCategoryID, MainCategoryID) 
				AND	SubCategoryID = ISNULL(@SubCategoryID, SubCategoryID) 
				AND	StatusID = ISNULL(@StatusID, StatusID) 
				AND	StatusID <> CASE WHEN ISNULL(@statusID, 0) <> 11004 THEN 11004 ELSE -1 END
				AND	StatusID <> CASE WHEN ISNULL(@statusID, 0) <> 11019 THEN 11019 ELSE -1 END
				AND	IsReviewed = ISNULL(@IsReviewed, IsReviewed)
				AND	fbc.IsRelated = 0
				AND	ResponseID = ISNULL(@ResponseID, ResponseID)
				AND	fb.FeedbackID = ISNULL(@FeedbackID, fb.FeedbackID)
			ORDER BY FeedbackDate DESC;
		END;   --- end: get feedback for customer
		ELSE		
		BEGIN  -- get feedback for guest	
				INSERT INTO @result 
				(
						FeedbackID 
					,	CustID 
					,	UserName 
					,	TitleID 
					,	FirstName 
					,	LastName 
					,	Phone
					,	PhoneAreaCode 
					,	PhoneCountryCode 
					,	Phone2
					,	Phone2AreaCode 
					,	Phone2CountryCode 
					,	Phone3 
					,	Phone3AreaCode 
					,	Phone3CountryCode 
					,	MobilePhone
					,	MobilePhoneAreaCode 
					,	MobilePhoneCountryCode
					,	Fax  
					,	FaxAreaCode 
					,	FaxCountryCode
					,	Email
					,	Skype 
					,	msn
					,	LanguageID 
					,	CountryID 
					,	CreatorID 
					,	CreatorName 
					,	FeedbackDate 
					,	ResolutionDate 
					,	CreateDate 
					,	SolveDate 
					,	CommunicationID 
					,	StationID 
					,	MainCategoryID 
					,	SubCategoryID 
					,	SiteID 
					,	RoleID 
					,	ProductID 
					,	SubProductID 
					,	BetTypeID 
					,	ResponseID 
					,	StatusID 
					,	Description 
					,	Solution 
					,	IsReviewed 
					,	Review
					,	ReviewerID 
					,	ReviewerName 
					,	IsRelated 
					,	Subject 
					,	RefCode1 
					,	RefCode2 
					,	relatedCustomer	
				)	
			SELECT	fb.FeedbackID
				,	fb.CustID
				,	ctm.UserName
				,	fb.TitleID
				,	fb.FirstName
				,	fb.LastName
				,	fb.Phone
				,	fb.PhoneAreaCode
				,	fb.PhoneCountryCode
				,	fb.Phone2
				,	fb.Phone2AreaCode
				,	fb.Phone2CountryCode
				,	fb.Phone3
				,	fb.Phone3AreaCode
				,	fb.Phone3CountryCode
				,	fb.MobilePhone
				,	fb.MobilePhoneAreaCode
				,	fb.MobilePhoneCountryCode
				,	fb.Fax
				,	fb.FaxAreaCode
				,	fb.FaxCountryCode
				,	fb.Email
				,	fb.Skype
				,	fb.MSN
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
				,	CAST(fb.Description AS XML) AS Description
				,	fb.Solution
				,	fb.IsReviewed
				,	fb.Review
				,	fb.ReviewerID
				,	rv.username AS ReviewerName
				,	CAST(0 AS BIT) AS  IsRelated
				,	fb.Subject
				,	fb.RefCode1
				,	fb.RefCode2
				,	l.list relatedCustomer
			FROM		crmFeedbackCustomer fbc WITH (NOLOCK)
			INNER JOIN	crmFeedback fb WITH (NOLOCK)
					ON	fb.FeedbackID = fbc.FeedbackID							
			INNER JOIN	crmCustomer ctm WITH (NOLOCK)
					ON	ctm.CustID = fb.CustID
			INNER JOIN	bodb02.dbo.custinfo c WITH (NOLOCK)
					ON	fb.CreatorID = c.custID
			LEFT JOIN	bodb02.dbo.custinfo rv WITH (NOLOCK)
					ON	fb.ReviewerID = rv.custID
			CROSS APPLY	dbo.f_GetRelatedCustomer(fb.FeedbackID) l
			WHERE	fbc.CustID < 0
				AND	FeedbackDate BETWEEN @FromDate AND @ToDate 
				AND	CommunicationID = ISNULL(@CommunicationID, CommunicationID) 
				AND	MainCategoryID = ISNULL(@MainCategoryID, MainCategoryID) 
				AND	SubCategoryID = ISNULL(@SubCategoryID, SubCategoryID) 
				AND	StatusID = ISNULL(@StatusID, StatusID) 
				AND	StatusID <> CASE WHEN ISNULL(@statusID, 0) <> 11004 THEN 11004 ELSE -1 END
				AND	StatusID <> CASE WHEN ISNULL(@statusID, 0) <> 11019 THEN 11019 ELSE -1 END
				AND	IsReviewed = ISNULL(@IsReviewed, IsReviewed)
				AND	fbc.IsRelated = 0
				AND	ResponseID = ISNULL(@ResponseID, ResponseID) 				
				AND	fb.FeedbackID = ISNULL(@FeedbackID, fb.FeedbackID)
			ORDER BY FeedbackDate DESC;
		END; -- end: get feedback for guest
	END;

	SELECT
				fb.FeedbackID
				,	fb.CustID
				,	fb.UserName
				,	fb.TitleID
				,	fb.FirstName
				,	fb.LastName
				,	fb.Phone
				,	fb.PhoneAreaCode
				,	fb.PhoneCountryCode
				,	fb.Phone2
				,	fb.Phone2AreaCode
				,	fb.Phone2CountryCode
				,	fb.Phone3
				,	fb.Phone3AreaCode
				,	fb.Phone3CountryCode
				,	fb.MobilePhone
				,	fb.MobilePhoneAreaCode
				,	fb.MobilePhoneCountryCode
				,	fb.Fax
				,	fb.FaxAreaCode
				,	fb.FaxCountryCode
				,	fb.Email
				,	fb.Skype
				,	fb.MSN
				,	fb.LanguageID
				,	fb.CountryID
				,	fb.CreatorID
				,	fb.CreatorName
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
				,	fb.Solution
				,	fb.IsReviewed
				,	fb.Review
				,	fb.ReviewerID
				,	fb.ReviewerName
				,	fb.IsRelated 
				,	fb.Subject
				,	fb.RefCode1
				,	fb.RefCode2
				,	fb.relatedCustomer
				, nr.value(N'@Remark',N'nvarchar(max)') AS Description
	FROM @result fb
		OUTER APPLY fb.Description.nodes(N'//row') AS A(nr)
		
END;
GO

GRANT EXECUTE ON dbo.Acc_CRM_FeedbackGetLatest TO bodbAdminNet;
GO 
