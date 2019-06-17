/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE	[dbo].[Acc_CRM_FeedbackGetDeleted] (
					@UserName			NVARCHAR(50)	= NULL
				,	@IsGuest			BIT				= NULL
				,	@FromDate			DATETIME
				,	@ToDate				DATETIME
				,	@CommunicationID	INT				= NULL
				,	@MainCategoryID		INT				= NULL
				,	@SubCategoryID		INT				= NULL
				,	@IsReviewed			BIT				= NULL
				,	@ResponseID			INT				= NULL
				,	@UserRole			TINYINT			= 2
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
		- 20180117@Winnie:	Add Is Related Customer - [Redmine: #88774]
		- 20171225@Winnie:  Change for support multiple product/categories. [RedmineID: #84714]
		- 20190506@Winnie: CN88 Permission RedmineID: #112637
	Param's Explanation:
	
*/
BEGIN		
	SET NOCOUNT ON;

	DECLARE	@CustID			INT
		,	@GuestID		INT
		,	@TotalPages		INT;
	CREATE TABLE #result  (
				FeedbackID INT PRIMARY KEY
			,	CustID INT
			,	UserName NVARCHAR(50)
			,	TitleID INT
			,	FirstName  NVARCHAR(50)
			,	LastName  NVARCHAR(50)
			,	Phone NVARCHAR(100)
			,	MobilePhone NVARCHAR(100)
			,	Fax NVARCHAR(50)
			,	Email NVARCHAR(254)
			,	Skype  NVARCHAR(100)
			,	msn NVARCHAR(100)
			,	LanguageID INT
			,	CountryID INT
			,	CreatorID INT
			,	CreatorName NVARCHAR(50)
			,	FeedbackDate DATETIME
			,	ResolutionDate DATETIME
			,	CreateDate DATETIME
			,	SolveDate DATETIME		
			,	SiteID INT 
			,	RoleID INT		
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
			,	relatedCustomer NVARCHAR(MAX)
			)
		CREATE TABLE #tempresult  (
				FeedbackID INT PRIMARY KEY
			,	CustID INT
			,	UserName NVARCHAR(50)
			,	TitleID INT
			,	FirstName  NVARCHAR(50)
			,	LastName  NVARCHAR(50)
			,	Phone NVARCHAR(100)
			,	MobilePhone NVARCHAR(100)
			,	Fax NVARCHAR(50)
			,	Email NVARCHAR(254)
			,	Skype  NVARCHAR(100)
			,	msn NVARCHAR(100)
			,	LanguageID INT
			,	CountryID INT
			,	CreatorID INT
			,	CreatorName NVARCHAR(50)
			,	FeedbackDate DATETIME
			,	ResolutionDate DATETIME
			,	CreateDate DATETIME
			,	SolveDate DATETIME		
			,	SiteID INT 
			,	RoleID INT		
			,	ResponseID INT
			,	StatusID INT
			,	Description NVARCHAR(MAX)
			,	Solution NVARCHAR(MAX)
			,	IsReviewed BIT
			,	Review NVARCHAR(MAX)
			,	ReviewerID INT
			,	ReviewerName NVARCHAR(50)
			,	IsRelated BIT
			,	Subject NVARCHAR(MAX)
			,	relatedCustomer NVARCHAR(MAX)
			)
	--- get feedback for specific customer
	IF	@UserName IS NOT NULL AND @UserName <> ''
	BEGIN
		IF	@IsGuest IS NULL
		BEGIN
			SELECT	@CustID = CustID
			FROM	crmCustomer WITH (NOLOCK)
			WHERE	UserName = @UserName				
				AND	CustID > 0
				AND ((@UserRole=1 AND SiteID=33002) OR (@UserRole=2 AND SiteID<>33002))

			SELECT	@GuestID = CustID
			FROM	crmCustomer WITH (NOLOCK)
			WHERE	UserName = @UserName
				AND	CustID < 0
				AND ((@UserRole=1 AND SiteID=33002) OR (@UserRole=2 AND SiteID<>33002))
		END;
		ELSE IF	@IsGuest = 0
		BEGIN
			SELECT	@CustID = CustID
				,	@GuestID = CustID
			FROM	crmCustomer WITH(NOLOCK)
			WHERE	UserName = @UserName
				AND	CustID > 0
				AND ((@UserRole=1 AND SiteID=33002) OR (@UserRole=2 AND SiteID<>33002))
		END;
		ELSE
		BEGIN
			SELECT	@GuestID = CustID
				,	@CustID = CustID
			FROM	crmCustomer WITH(NOLOCK)
			WHERE	UserName = @UserName
				AND	CustID < 0
				AND ((@UserRole=1 AND SiteID=33002) OR (@UserRole=2 AND SiteID<>33002))
		END;			
		INSERT INTO #result  (
				FeedbackID 
			,	CustID 
			,	UserName 
			,	TitleID 
			,	FirstName 
			,	LastName  
			,	Phone
			,	MobilePhone 
			,	Fax
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
			,	SiteID  
			,	RoleID 		
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
			,	relatedCustomer 
			)
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
			,	fb.SiteID
			,	fb.RoleID
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
			AND	StatusID IN(11004,11019)
			AND	IsReviewed = ISNULL(@IsReviewed, IsReviewed)
			AND	fbc.IsRelated = 0
			AND	ResponseID = ISNULL(@ResponseID, ResponseID)			
		ORDER BY FeedbackDate DESC;
	END;	
	ELSE  
	BEGIN		
		IF	@IsGuest IS NULL ------ get feedback for all customer
		BEGIN		
			INSERT INTO #result  (
				FeedbackID 
			,	CustID 
			,	UserName 
			,	TitleID 
			,	FirstName 
			,	LastName  
			,	Phone
			,	MobilePhone 
			,	Fax
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
			,	SiteID  
			,	RoleID 		
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
			,	relatedCustomer 
			)
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
				,	fb.SiteID
				,	fb.RoleID				
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
				AND	StatusID IN( 11004,11019)
				AND	IsReviewed = ISNULL(@IsReviewed, IsReviewed)
				AND	fbc.IsRelated = 0
				AND	ResponseID = ISNULL(@ResponseID, ResponseID) 
				AND ((@UserRole=1 AND SiteID=33002) OR (@UserRole=2 AND SiteID<>33002))
			ORDER BY FeedbackDate DESC;
		END;
		-- customer
		ELSE IF	@IsGuest = 0
		BEGIN
			INSERT INTO #result  (
				FeedbackID 
			,	CustID 
			,	UserName 
			,	TitleID 
			,	FirstName 
			,	LastName  
			,	Phone
			,	MobilePhone 
			,	Fax
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
			,	SiteID  
			,	RoleID 		
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
			,	relatedCustomer 
			)
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
				,	fb.SiteID
				,	fb.RoleID
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
				AND	StatusID IN( 11004,11019)
				AND	IsReviewed = ISNULL(@IsReviewed, IsReviewed)
				AND	fbc.IsRelated = 0
				AND	ResponseID = ISNULL(@ResponseID, ResponseID) 
				AND ((@UserRole=1 AND SiteID=33002) OR (@UserRole=2 AND SiteID<>33002))
			ORDER BY FeedbackDate DESC;

		END;   --- end: get feedback for customer
		ELSE
		-- get feedback for guest
		BEGIN
			INSERT INTO #result  (
				FeedbackID 
			,	CustID 
			,	UserName 
			,	TitleID 
			,	FirstName 
			,	LastName  
			,	Phone
			,	MobilePhone 
			,	Fax
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
			,	SiteID  
			,	RoleID 			
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
			,	relatedCustomer 
			)
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
				,	fb.SiteID
				,	fb.RoleID
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
				AND ((@UserRole=1 AND SiteID=33002) OR (@UserRole=2 AND SiteID<>33002))
				AND	StatusID IN( 11004,11019)
				AND	IsReviewed = ISNULL(@IsReviewed, IsReviewed)
				AND	fbc.IsRelated = 0
				AND	ResponseID = ISNULL(@ResponseID, ResponseID) 
			ORDER BY FeedbackDate DESC;

		END; -- end: get feedback for guest
	END;
		IF @MainCategoryID IS NULL AND @CommunicationID IS NULL
		BEGIN
			SELECT		fb.FeedbackID
					,	fb.CustID
					,	fb.UserName
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
					,	fb.username AS CreatorName
					,	fb.FeedbackDate
					,	fb.ResolutionDate
					,	fb.CreateDate
					,	fb.SolveDate				
					,	fb.SiteID
					,	fb.RoleID				
					,	fb.ResponseID
					,	fb.StatusID					
					,	fb.Solution
					,	fb.IsReviewed
					,	fb.Review
					,	fb.ReviewerID
					,	fb.username AS ReviewerName			
					,	fb.IsRelated
					,	fb.Subject
					,	fb.relatedCustomer
					,	nr.value(N'@Remark',N'nvarchar(max)') AS Description
		FROM #result fb
			OUTER APPLY fb.Description.nodes(N'//row') AS A(nr)
			ORDER BY fb.FeedbackDate DESC

			SELECT fs.FeedbackID,fs.SettingID,fs.SubSettingID,fs.SubSettingIDLevel3,
			CASE	WHEN m.MainCategoryID	IS NOT NULL THEN 'Category' 
					WHEN s.StationID		IS NOT NULL THEN 'Station' 
					WHEN p.SettingID		IS NOT NULL THEN 'Product' 
					WHEN c.SettingID		IS NOT NULL THEN 'Communication' 
					END AS SettingType
			FROM #result fp
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
		ELSE IF @MainCategoryID IS NOT NULL AND @CommunicationID IS NULL
		BEGIN	
			INSERT INTO #tempresult  (
				FeedbackID 
			,	CustID 
			,	UserName 
			,	TitleID 
			,	FirstName 
			,	LastName  
			,	Phone
			,	MobilePhone 
			,	Fax
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
			,	SiteID  
			,	RoleID 			
			,	ResponseID 
			,	StatusID 			
			,	Solution 
			,	IsReviewed 
			,	Review
			,	ReviewerID 
			,	ReviewerName 
			,	IsRelated 
			,	Subject 
			,	relatedCustomer 
			,   Description
			)	
			SELECT		fb.FeedbackID
					,	fb.CustID
					,	fb.UserName
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
					,	fb.username AS CreatorName
					,	fb.FeedbackDate
					,	fb.ResolutionDate
					,	fb.CreateDate
					,	fb.SolveDate				
					,	fb.SiteID
					,	fb.RoleID					
					,	fb.ResponseID
					,	fb.StatusID					
					,	fb.Solution
					,	fb.IsReviewed
					,	fb.Review
					,	fb.ReviewerID
					,	fb.username AS ReviewerName			
					,	fb.IsRelated
					,	fb.Subject
					,	fb.relatedCustomer
					,	nr.value(N'@Remark',N'nvarchar(max)') AS Description		
			FROM #result fb				
				INNER JOIN  dbo.f_GetFeedbackSetting(0,@MainCategoryID,ISNULL(@SubCategoryID,0),2) fm 
						ON fb.FeedbackID=fm.FeedbackID
				OUTER APPLY fb.Description.nodes(N'//row') AS A(nr)
				ORDER BY fb.FeedbackDate DESC
			
			SELECT * FROM #tempresult
			SELECT fs.FeedbackID,fs.SettingID,fs.SubSettingID,fs.SubSettingIDLevel3,
			CASE	WHEN m.MainCategoryID	IS NOT NULL THEN 'Category' 
					WHEN s.StationID		IS NOT NULL THEN 'Station' 
					WHEN p.SettingID		IS NOT NULL THEN 'Product' 
					WHEN c.SettingID		IS NOT NULL THEN 'Communication' 
					END AS SettingType
			FROM #tempresult fp
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
		ELSE IF @MainCategoryID IS NULL AND @CommunicationID IS NOT NULL
		BEGIN	
			INSERT INTO #tempresult  (
				FeedbackID 
			,	CustID 
			,	UserName 
			,	TitleID 
			,	FirstName 
			,	LastName  
			,	Phone
			,	MobilePhone 
			,	Fax
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
			,	SiteID  
			,	RoleID 			
			,	ResponseID 
			,	StatusID 			
			,	Solution 
			,	IsReviewed 
			,	Review
			,	ReviewerID 
			,	ReviewerName 
			,	IsRelated 
			,	Subject 
			,	relatedCustomer 
			,   Description
			)		
			SELECT		fb.FeedbackID
					,	fb.CustID
					,	fb.UserName
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
					,	fb.username AS CreatorName
					,	fb.FeedbackDate
					,	fb.ResolutionDate
					,	fb.CreateDate
					,	fb.SolveDate				
					,	fb.SiteID
					,	fb.RoleID					
					,	fb.ResponseID
					,	fb.StatusID					
					,	fb.Solution
					,	fb.IsReviewed
					,	fb.Review
					,	fb.ReviewerID
					,	fb.username AS ReviewerName			
					,	fb.IsRelated
					,	fb.Subject
					,	fb.relatedCustomer
					,	nr.value(N'@Remark',N'nvarchar(max)') AS Description			
			FROM #result fb				
				INNER JOIN  dbo.f_GetFeedbackSetting(0,@CommunicationID,0,1) fm 
						ON fb.FeedbackID=fm.FeedbackID
				OUTER APPLY fb.Description.nodes(N'//row') AS A(nr)
				ORDER BY fb.FeedbackDate DESC
		
			SELECT * FROM #tempresult
			SELECT fs.FeedbackID,fs.SettingID,fs.SubSettingID,fs.SubSettingIDLevel3,
			CASE	WHEN m.MainCategoryID	IS NOT NULL THEN 'Category' 
					WHEN s.StationID		IS NOT NULL THEN 'Station' 
					WHEN p.SettingID		IS NOT NULL THEN 'Product' 
					WHEN c.SettingID		IS NOT NULL THEN 'Communication' 
					END AS SettingType
			FROM #tempresult fp
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
		ELSE
		BEGIN	
			INSERT INTO #tempresult  (
				FeedbackID 
			,	CustID 
			,	UserName 
			,	TitleID 
			,	FirstName 
			,	LastName  
			,	Phone
			,	MobilePhone 
			,	Fax
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
			,	SiteID  
			,	RoleID 			
			,	ResponseID 
			,	StatusID 			
			,	Solution 
			,	IsReviewed 
			,	Review
			,	ReviewerID 
			,	ReviewerName 
			,	IsRelated 
			,	Subject 
			,	relatedCustomer 
			,   Description
			)		
			SELECT		fb.FeedbackID
					,	fb.CustID
					,	fb.UserName
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
					,	fb.username AS CreatorName
					,	fb.FeedbackDate
					,	fb.ResolutionDate
					,	fb.CreateDate
					,	fb.SolveDate				
					,	fb.SiteID
					,	fb.RoleID					
					,	fb.ResponseID
					,	fb.StatusID					
					,	fb.Solution
					,	fb.IsReviewed
					,	fb.Review
					,	fb.ReviewerID
					,	fb.username AS ReviewerName			
					,	fb.IsRelated
					,	fb.Subject
					,	fb.relatedCustomer
					,	nr.value(N'@Remark',N'nvarchar(max)') AS Description			
			FROM #result fb				
				INNER JOIN  dbo.f_GetFeedbackSetting(0,@MainCategoryID,ISNULL(@SubCategoryID,0),2) fm 
						ON fb.FeedbackID=fm.FeedbackID
				INNER JOIN  dbo.f_GetFeedbackSetting(0,@CommunicationID,0,1) fc
						ON fb.FeedbackID=fc.FeedbackID
				OUTER APPLY fb.Description.nodes(N'//row') AS A(nr)
				ORDER BY fb.FeedbackDate DESC
					
			SELECT * FROM #tempresult	
			SELECT fs.FeedbackID,fs.SettingID,fs.SubSettingID,fs.SubSettingIDLevel3,
			CASE	WHEN m.MainCategoryID	IS NOT NULL THEN 'Category' 
					WHEN s.StationID		IS NOT NULL THEN 'Station' 
					WHEN p.SettingID		IS NOT NULL THEN 'Product' 
					WHEN c.SettingID		IS NOT NULL THEN 'Communication' 
					END AS SettingType
			FROM #tempresult fp
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
END;

GO

GRANT EXECUTE ON dbo.Acc_CRM_FeedbackGetDeleted TO bodbAdminNet;
GO
