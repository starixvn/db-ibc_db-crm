/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
					@FromDate			DATETIME
				,	@ToDate				DATETIME
				,	@ProductID			INT				= NULL
				,	@SubProductID		INT				= NULL
				,	@StatusID			INT				= NULL
				,	@RoleID				INT				= NULL
				,	@MainCategoryID		INT				= NULL
				,	@HandledBy			NVARCHAR(30)	= NULL
				,	@Extension			INT				= NULL
				,	@SiteID				INT				= NULL
				,	@ResponseID			INT				= NULL
				,	@CommunicationID	INT				= NULL
				,	@SubCategoryID		INT				= NULL
				,	@ReviewedBy			NVARCHAR(30)	= NULL
				,	@Subject			NVARCHAR(1000)	= NULL
AS 
/*
	Created:	DOM
	Date:		20140228
	Task:		Dynamic Report
	DB:			DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20160318@Billy:	Integrate Sub-Product Setting - [Redmine: #52998]
		- 20180529@Vicky: change the query to use index on DBACC [RedmineID: #95024]
		- 20171225@Winnie: Change for support multiple product/categories. [RedmineID: #84714]		
	Param's Explanation:
		
*/
BEGIN
	SELECT	@Subject = REPLACE(@Subject, '[', '%');
	SELECT	@Subject = REPLACE(@Subject,']','%');

	DECLARE	@HandledID		INT
		,	@ReviewedID		INT;

	SELECT	@HandledID = CustID 
FROM	DBACC.bodb02.dbo.Customer WITH (NOLOCK)
	WHERE	UserName = @HandledBy;

	SELECT	@ReviewedID = CustID
FROM	DBACC.bodb02.dbo.Customer WITH (NOLOCK)
	WHERE	UserName = @ReviewedBy;


	CREATE TABLE	#Feedback (
						FeedbackID		INT PRIMARY KEY
					);

	IF (ISNULL(@ProductID, 0) <> 0 AND ISNULL(@CommunicationID, 0)<>0 AND ISNULL(@Extension, 0)<>0)
	BEGIN
		INSERT INTO #Feedback
			SELECT DISTINCT	f.FeedbackID
			FROM	crmFeedback f WITH (NOLOCK)
			INNER JOIN dbo.f_GetFeedbackSetting(0,@ProductID,@SubProductID,2) fp ON f.FeedbackID=fp.FeedbackID	
			INNER JOIN dbo.f_GetFeedbackSetting(0,@CommunicationID,0,1) fc ON f.FeedbackID=fc.FeedbackID	
			INNER JOIN dbo.f_GetFeedbackSetting(0,@Extension,0,1) fe ON f.FeedbackID=fe.FeedbackID	
			WHERE	FeedbackDate BETWEEN @FromDate AND @ToDate		
				AND	(ISNULL(@StatusID, 0) = 0 OR f.StatusID = @StatusID) 
				AND	(ISNULL(@RoleID, 0) = 0 OR f.RoleID = @RoleID) 
				AND	(ISNULL(@HandledBy, '') = '' OR f.CreatorID = @HandledID) 
				AND	(ISNULL(@SiteID, 0) = 0 OR f.SiteID = @SiteID) 
				AND	(ISNULL(@ResponseID, 0) = 0 OR f.ResponseID = @ResponseID) 
				AND	(ISNULL(@ReviewedBy, '') = '' OR f.ReviewerID = @ReviewedID) 
				AND	(ISNULL(@Subject, '') = '' OR f.Subject LIKE '%' + @Subject + '%') 
				AND	f.StatusID <> 11004; 
	END
	ELSE IF(ISNULL(@ProductID, 0) <> 0 AND ISNULL(@CommunicationID, 0)<>0 AND ISNULL(@Extension, 0)=0)
	BEGIN
		INSERT INTO #Feedback
			SELECT DISTINCT	f.FeedbackID
			FROM	crmFeedback f WITH (NOLOCK)
			INNER JOIN dbo.f_GetFeedbackSetting(0,@ProductID,@SubProductID,2) fp ON f.FeedbackID=fp.FeedbackID	
			INNER JOIN dbo.f_GetFeedbackSetting(0,@CommunicationID,0,1) fc ON f.FeedbackID=fc.FeedbackID			
			WHERE	FeedbackDate BETWEEN @FromDate AND @ToDate		
				AND	(ISNULL(@StatusID, 0) = 0 OR f.StatusID = @StatusID) 
				AND	(ISNULL(@RoleID, 0) = 0 OR f.RoleID = @RoleID) 
				AND	(ISNULL(@HandledBy, '') = '' OR f.CreatorID = @HandledID) 
				AND	(ISNULL(@SiteID, 0) = 0 OR f.SiteID = @SiteID) 
				AND	(ISNULL(@ResponseID, 0) = 0 OR f.ResponseID = @ResponseID) 
				AND	(ISNULL(@ReviewedBy, '') = '' OR f.ReviewerID = @ReviewedID) 
				AND	(ISNULL(@Subject, '') = '' OR f.Subject LIKE '%' + @Subject + '%') 
				AND	f.StatusID <> 11004; 
	END
	ELSE IF(ISNULL(@ProductID, 0) <> 0 AND ISNULL(@CommunicationID, 0)=0 AND ISNULL(@Extension, 0)<>0)
	BEGIN
		INSERT INTO #Feedback
			SELECT DISTINCT	f.FeedbackID
			FROM	crmFeedback f WITH (NOLOCK)
			INNER JOIN dbo.f_GetFeedbackSetting(0,@ProductID,@SubProductID,2) fp ON f.FeedbackID=fp.FeedbackID	
			INNER JOIN dbo.f_GetFeedbackSetting(0,@Extension,0,1) fe ON f.FeedbackID=fe.FeedbackID			
			WHERE	FeedbackDate BETWEEN @FromDate AND @ToDate		
				AND	(ISNULL(@StatusID, 0) = 0 OR f.StatusID = @StatusID) 
				AND	(ISNULL(@RoleID, 0) = 0 OR f.RoleID = @RoleID) 
				AND	(ISNULL(@HandledBy, '') = '' OR f.CreatorID = @HandledID) 
				AND	(ISNULL(@SiteID, 0) = 0 OR f.SiteID = @SiteID) 
				AND	(ISNULL(@ResponseID, 0) = 0 OR f.ResponseID = @ResponseID) 
				AND	(ISNULL(@ReviewedBy, '') = '' OR f.ReviewerID = @ReviewedID) 
				AND	(ISNULL(@Subject, '') = '' OR f.Subject LIKE '%' + @Subject + '%') 
				AND	f.StatusID <> 11004; 
	END
	ELSE IF(ISNULL(@ProductID, 0) = 0 AND ISNULL(@CommunicationID, 0)<>0 AND ISNULL(@Extension, 0)<>0)
	BEGIN
		INSERT INTO #Feedback
			SELECT DISTINCT	f.FeedbackID
			FROM	crmFeedback f WITH (NOLOCK)
			INNER JOIN dbo.f_GetFeedbackSetting(0,@CommunicationID,0,1) fc ON f.FeedbackID=fc.FeedbackID			
			INNER JOIN dbo.f_GetFeedbackSetting(0,@Extension,0,1) fe ON f.FeedbackID=fe.FeedbackID			
			WHERE	FeedbackDate BETWEEN @FromDate AND @ToDate		
				AND	(ISNULL(@StatusID, 0) = 0 OR f.StatusID = @StatusID) 
				AND	(ISNULL(@RoleID, 0) = 0 OR f.RoleID = @RoleID) 
				AND	(ISNULL(@HandledBy, '') = '' OR f.CreatorID = @HandledID) 
				AND	(ISNULL(@SiteID, 0) = 0 OR f.SiteID = @SiteID) 
				AND	(ISNULL(@ResponseID, 0) = 0 OR f.ResponseID = @ResponseID) 
				AND	(ISNULL(@ReviewedBy, '') = '' OR f.ReviewerID = @ReviewedID) 
				AND	(ISNULL(@Subject, '') = '' OR f.Subject LIKE '%' + @Subject + '%') 
				AND	f.StatusID <> 11004; 
	END
	ELSE IF(ISNULL(@ProductID, 0) = 0 AND ISNULL(@CommunicationID, 0)=0 AND ISNULL(@Extension, 0)<>0)
	BEGIN
		INSERT INTO #Feedback
			SELECT DISTINCT	f.FeedbackID
			FROM	crmFeedback f WITH (NOLOCK)		
			INNER JOIN dbo.f_GetFeedbackSetting(0,@Extension,0,1) fe ON f.FeedbackID=fe.FeedbackID			
			WHERE	FeedbackDate BETWEEN @FromDate AND @ToDate		
				AND	(ISNULL(@StatusID, 0) = 0 OR f.StatusID = @StatusID) 
				AND	(ISNULL(@RoleID, 0) = 0 OR f.RoleID = @RoleID) 
				AND	(ISNULL(@HandledBy, '') = '' OR f.CreatorID = @HandledID) 
				AND	(ISNULL(@SiteID, 0) = 0 OR f.SiteID = @SiteID) 
				AND	(ISNULL(@ResponseID, 0) = 0 OR f.ResponseID = @ResponseID) 
				AND	(ISNULL(@ReviewedBy, '') = '' OR f.ReviewerID = @ReviewedID) 
				AND	(ISNULL(@Subject, '') = '' OR f.Subject LIKE '%' + @Subject + '%') 
				AND	f.StatusID <> 11004; 
	END
	ELSE IF(ISNULL(@ProductID, 0) <> 0 AND ISNULL(@CommunicationID, 0)=0 AND ISNULL(@Extension, 0)=0)
	BEGIN
		INSERT INTO #Feedback
			SELECT DISTINCT	f.FeedbackID
			FROM	crmFeedback f WITH (NOLOCK)		
			INNER JOIN dbo.f_GetFeedbackSetting(0,@ProductID,@SubProductID,2) fp ON f.FeedbackID=fp.FeedbackID		
			WHERE	FeedbackDate BETWEEN @FromDate AND @ToDate		
				AND	(ISNULL(@StatusID, 0) = 0 OR f.StatusID = @StatusID) 
				AND	(ISNULL(@RoleID, 0) = 0 OR f.RoleID = @RoleID) 
				AND	(ISNULL(@HandledBy, '') = '' OR f.CreatorID = @HandledID) 
				AND	(ISNULL(@SiteID, 0) = 0 OR f.SiteID = @SiteID) 
				AND	(ISNULL(@ResponseID, 0) = 0 OR f.ResponseID = @ResponseID) 
				AND	(ISNULL(@ReviewedBy, '') = '' OR f.ReviewerID = @ReviewedID) 
				AND	(ISNULL(@Subject, '') = '' OR f.Subject LIKE '%' + @Subject + '%') 
				AND	f.StatusID <> 11004; 
	END
	ELSE IF(ISNULL(@ProductID, 0) = 0 AND ISNULL(@CommunicationID, 0)<>0 AND ISNULL(@Extension, 0)=0)
	BEGIN
		INSERT INTO #Feedback
			SELECT DISTINCT	f.FeedbackID
			FROM	crmFeedback f WITH (NOLOCK)		
			INNER JOIN dbo.f_GetFeedbackSetting(0,@CommunicationID,0,1) fc ON f.FeedbackID=fc.FeedbackID	
			WHERE	FeedbackDate BETWEEN @FromDate AND @ToDate		
				AND	(ISNULL(@StatusID, 0) = 0 OR f.StatusID = @StatusID) 
				AND	(ISNULL(@RoleID, 0) = 0 OR f.RoleID = @RoleID) 
				AND	(ISNULL(@HandledBy, '') = '' OR f.CreatorID = @HandledID) 
				AND	(ISNULL(@SiteID, 0) = 0 OR f.SiteID = @SiteID) 
				AND	(ISNULL(@ResponseID, 0) = 0 OR f.ResponseID = @ResponseID) 
				AND	(ISNULL(@ReviewedBy, '') = '' OR f.ReviewerID = @ReviewedID) 
				AND	(ISNULL(@Subject, '') = '' OR f.Subject LIKE '%' + @Subject + '%') 
				AND	f.StatusID <> 11004; 
	END
	ELSE
	BEGIN
		INSERT INTO #Feedback
		SELECT DISTINCT	FeedbackID
		FROM	crmFeedback f WITH (NOLOCK)
		WHERE	FeedbackDate BETWEEN @FromDate AND @ToDate			
			AND	(ISNULL(@StatusID, 0) = 0 OR f.StatusID = @StatusID) 
			AND	(ISNULL(@RoleID, 0) = 0 OR f.RoleID = @RoleID) 		
			AND	(ISNULL(@HandledBy, '') = '' OR f.CreatorID = @HandledID) 
			AND	(ISNULL(@SiteID, 0) = 0 OR f.SiteID = @SiteID) 
			AND	(ISNULL(@ResponseID, 0) = 0 OR f.ResponseID = @ResponseID) 				
			AND	(ISNULL(@ReviewedBy, '') = '' OR f.ReviewerID = @ReviewedID) 		
			AND	(ISNULL(@Subject, '') = '' OR f.Subject LIKE '%' + @Subject + '%') 
			AND	f.StatusID <> 11004; 
	END

	IF(ISNULL(@MainCategoryID, 0) <> 0)
	BEGIN
		SELECT	f.FeedbackID
			,	f.FeedbackDate
			,	mc.Name MainCategory
			,	sc.Name SubCategory
			,	CAST(DATEPART(HOUR, ResolutionDate - FeedbackDate) AS VARCHAR)
			+	' : ' + CAST(DATEPART(MINUTE, ResolutionDate - FeedbackDate) AS VARCHAR)
			+	' : ' + CAST(DATEPART(SECOND, ResolutionDate - FeedbackDate) AS VARCHAR) Duration
			,	f.Subject
			,	st.Name Status
			,	c.username HandledBy
			,	rv.username ReviewedBy
			,	cust.UserName
		FROM		crmFeedback f WITH (NOLOCK) 
		INNER JOIN dbo.f_GetFeedbackSetting(0,@MainCategoryID,@SubCategoryID,2) fc ON f.FeedbackID=fc.FeedbackID		
		LEFT JOIN	crmMainCategory mc WITH (NOLOCK)
				ON	mc.MainCategoryID = fc.SettingID
		LEFT JOIN	crmSubCategory sc WITH (NOLOCK)
				ON	sc.MainCategoryID= mc.MainCategoryID
				AND	sc.SubCategoryID = fc.SubSettingID
		LEFT JOIN	crmStatus st WITH (NOLOCK)
				ON	st.StatusID = f.StatusID
		INNER JOIN	bodb02.dbo.Customer c WITH (NOLOCK)
				ON	c.custid = f.CreatorID
		LEFT JOIN	bodb02.dbo.Customer rv WITH (NOLOCK)
				ON	rv.custid = f.ReviewerID
		INNER JOIN	crmCustomer cust WITH(NOLOCK)
				ON	cust.CustID = f.CustID
		WHERE	f.FeedbackID IN (SELECT feedbackid FROM #Feedback)
		ORDER BY f.FeedbackDate DESC, f.FeedbackID DESC;
	END
	ELSE 
	BEGIN
		SELECT	f.FeedbackID
			,	f.FeedbackDate
			,	mc.Name MainCategory
			,	sc.Name SubCategory
			,	CAST(DATEPART(HOUR, ResolutionDate - FeedbackDate) AS VARCHAR)
			+	' : ' + CAST(DATEPART(MINUTE, ResolutionDate - FeedbackDate) AS VARCHAR)
			+	' : ' + CAST(DATEPART(SECOND, ResolutionDate - FeedbackDate) AS VARCHAR) Duration
			,	f.Subject
			,	st.Name Status
			,	c.username HandledBy
			,	rv.username ReviewedBy
			,	cust.UserName
		FROM		crmFeedback f WITH (NOLOCK) 
		INNER JOIN crmFeedbackSetting fc ON f.FeedbackID=fc.FeedbackID		
		INNER JOIN	crmMainCategory mc WITH (NOLOCK)
				ON	mc.MainCategoryID = fc.SettingID
		INNER JOIN	crmSubCategory sc WITH (NOLOCK)
				ON	sc.MainCategoryID= mc.MainCategoryID
				AND	sc.SubCategoryID = fc.SubSettingID
		LEFT JOIN	crmStatus st WITH (NOLOCK)
				ON	st.StatusID = f.StatusID
		INNER JOIN	bodb02.dbo.Customer c WITH (NOLOCK)
				ON	c.custid = f.CreatorID
		LEFT JOIN	bodb02.dbo.Customer rv WITH (NOLOCK)
				ON	rv.custid = f.ReviewerID
		INNER JOIN	crmCustomer cust WITH(NOLOCK)
				ON	cust.CustID = f.CustID
		WHERE	f.FeedbackID IN (SELECT feedbackid FROM #Feedback) 
		ORDER BY f.FeedbackDate DESC, f.FeedbackID DESC;
	END
	DROP TABLE #Feedback;
END
GO
