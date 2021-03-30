/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_ManageFeedbackList] (
					@UserName			NVARCHAR(50)	= NULL
				,	@IsGuest			BIT				= NULL
				,	@FromDate			DATETIME
				,	@ToDate				DATETIME
				,	@CommunicationID	INT				= NULL
				,	@MainCategoryID		INT				= NULL
				,	@SubCategoryID		INT				= NULL
				,	@StatusID			INT				= NULL
				,	@IsReviewed			BIT				= NULL
				,	@Reviewer			VARCHAR(30)		= NULL
				,	@ResponseID			INT				= NULL
				,	@FeedbackID			INT				= NULL
				,	@TotalRows			INT				= 0 OUTPUT
				,	@PageIndex			INT				= 1
				,	@ItemsPerPage		INT				= 2
				,	@HandledBy			VARCHAR(30)	= ''
				,	@UserRole			TINYINT
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
		- 20151223@Elodie:	Get all data in case of @PageIndex = 0
		- 20160308@Billy:	Integrate Sub-Product field - [Redmine: #52998]
		- 20170919@Winnie:	CRM - Improve load speed of feedback [Redmine: #79450]
		- 20180529@Vicky: change the query to use index on DBACC [RedmineID: #95024]
		- 20180404@Winnie: Change for support multiple product/categories. [RedmineID: #84714] 
		- 20180910@Winnie: Filter by Reviewer [RedmineID: #99982]
		- 20190506@Winnie: CN88 Permission RedmineID: #112637
		- 20190614@Helen: CN88 - Performance Tuning [Redmine: #112637]
		- 20201027@Johnson: - get Description to show tooltip for fb 
							- show inactive setting [redmine: #142194]
		- 202010315@Winfred: Related Customer displayed properly when search Username in Manage Feedback [redmine:#138771]							
Param's Explanation:
	
*/
BEGIN		
	SET NOCOUNT ON;

	DECLARE	@CustID			INT
		,	@GuestID		INT
		,	@TotalPages		INT;

	CREATE TABLE #Feedback( FeedbackID INT, IsRelated BIT,FeedbackDate DATETIME);
				
	DECLARE	@HandledID		INT
		,	@ReviewerID		INT;
	
	SELECT	@HandledID = CustID
	FROM	bodb02.dbo.Customer WITH (NOLOCK)
	WHERE	UserName = @HandledBy;

	SELECT	@ReviewerID = CustID
	FROM	bodb02.dbo.Customer WITH (NOLOCK)
	WHERE	UserName = @Reviewer;
	
	IF	ISNULL(@FeedbackID, 0) <> 0
	BEGIN
		DECLARE	@IsRelated INT = 0;

		SELECT TOP 1 @IsRelated = IsRelated
		FROM	crmFeedbackCustomer WITH (NOLOCK)
		WHERE	FeedbackID = @FeedbackID
			AND	IsRelated = 1;

		IF	EXISTS(SELECT 1 FROM crmFeedback WITH(NOLOCK) WHERE FeedbackID = @FeedbackID)
			SELECT	@TotalRows = 1;
		
		;WITH fb AS
		(SELECT *,CAST(Description as XML) as Description2
		FROM crmFeedback WITH(NOLOCK)
		WHERE FeedbackID = @FeedbackID
		)
		SELECT fb.FeedbackID
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
					,	fb.SiteID
					,	fb.RoleID					
					,	fb.ResponseID
					,	fb.StatusID
					, 	nr.value(N'@Remark',N'nvarchar(max)') AS Description
					,	fb.Solution
					,	fb.IsReviewed
					,	fb.Review
					,	fb.ReviewerID
					,	rv.username AS ReviewerName
					,	IsRelated = @IsRelated
					,	fb.Subject
					,	fb.RefCode1
					,	fb.RefCode2					
					,	st.Name Status
					,	l.list AS relatedCustomer
		FROM	fb
			INNER JOIN	crmCustomer ctm WITH (NOLOCK) ON	ctm.CustID = fb.CustID
			INNER JOIN	bodb02.dbo.custInfo c WITH (NOLOCK)	ON	fb.CreatorID = c.custid
			LEFT JOIN	bodb02.dbo.custInfo rv WITH (NOLOCK) ON	fb.ReviewerID = rv.custid	
			INNER JOIN	crmStatus st WITH (NOLOCK)	ON	st.StatusID = fb.StatusID
			CROSS APPLY	dbo.f_GetRelatedCustomer(fb.FeedbackID) l
			OUTER APPLY fb.Description2.nodes(N'//row') AS A(nr)
		WHERE	fb.FeedbackID = @FeedbackID AND((@UserRole=1 AND ctm.SiteID=33002) OR(@UserRole=2 AND ctm.SiteID<>33002) )
		ORDER BY FeedbackDate DESC, FeedbackID DESC;
			
		SELECT fs.FeedbackID,fs.SettingID,fs.SubSettingID,fs.SubSettingIDLevel3,
		CASE	WHEN m.MainCategoryID	IS NOT NULL THEN 'Category' 
				WHEN s.StationID		IS NOT NULL THEN 'Station' 
				WHEN p.SettingID		IS NOT NULL THEN 'Product' 
				WHEN c.SettingID		IS NOT NULL THEN 'Communication' 
				END AS SettingType
		FROM dbo.crmFeedbackSetting fs WITH(NOLOCK)
			LEFT JOIN crmMainCategory m WITH (NOLOCK) ON fs.SettingID=m.MainCategoryID
			LEFT JOIN crmStation s WITH (NOLOCK) ON fs.SettingID=s.StationID
			LEFT JOIN crmSetting p WITH (NOLOCK) ON fs.SettingID=p.SettingID AND p.SettingName='Product'
			LEFT JOIN crmSetting c WITH (NOLOCK) ON fs.SettingID=c.SettingID AND c.SettingName='Communication'
		WHERE FeedbackID = @feedbackID
		
		RETURN;
	END;
	
	--- get feedback for specific customer
	IF @UserName IS NOT NULL AND @UserName <> ''
	BEGIN
		PRINT 'get feedback for specific customer';
		IF	@IsGuest IS NULL
		BEGIN
			SELECT	@CustID = CustID
			FROM	crmCustomer WITH (NOLOCK)
			WHERE	UserName = @UserName
				AND((@UserRole=1 AND SiteID=33002) OR(@UserRole=2 AND SiteID<>33002) )
				AND	CustID > 0;

			SELECT	@GuestID = CustID
			FROM	crmCustomer WITH (NOLOCK)
			WHERE	UserName = @UserName
				AND((@UserRole=1 AND SiteID=33002) OR(@UserRole=2 AND SiteID<>33002) )
				AND	CustID < 0;
		END;
		ELSE IF @IsGuest = 0
		BEGIN
			SELECT	@CustID = CustID
				,	@GuestID = CustID
			FROM	crmCustomer WITH (NOLOCK)
			WHERE	UserName = @UserName
				AND((@UserRole=1 AND SiteID=33002) OR(@UserRole=2 AND SiteID<>33002) )
				AND	CustID > 0;
		END;
		ELSE
		BEGIN
			SELECT	@GuestID = CustID
				,	@CustID = CustID
			FROM	crmCustomer WITH (NOLOCK)
			WHERE	UserName = @UserName
				AND((@UserRole=1 AND SiteID=33002) OR(@UserRole=2 AND SiteID<>33002) )
				AND	CustID < 0;
		END;			
		
		INSERT INTO #Feedback(FeedbackID, IsRelated,FeedbackDate)
		SELECT	DISTINCT fb.FeedbackID
			,	fbc.IsRelated
			,	fb.FeedbackDate
		FROM	crmFeedbackCustomer fbc WITH (NOLOCK)
			INNER JOIN	crmFeedback fb WITH (NOLOCK) ON	fb.FeedbackID=fbc.FeedbackID
			INNER JOIN  crmCustomer ctm WITH(NOLOCK) ON fbc.CustID=ctm.CustID
			INNER JOIN crmFeedbackSetting fm WITH(NOLOCK) ON fb.FeedbackID=fm.FeedbackID
			INNER JOIN crmFeedbackSetting fc WITH(NOLOCK) ON fb.FeedbackID=fc.FeedbackID
		WHERE	(fbc.CustID = @CustID OR fbc.CustID = @GuestID)
			AND	FeedbackDate BETWEEN @FromDate AND @ToDate 
			AND (@CommunicationID IS NULL	OR fc.SettingID =  @CommunicationID)
			AND (@MainCategoryID IS NULL OR fm.SettingID = @MainCategoryID)	
			AND (@SubCategoryID IS NULL OR fm.SubSettingID = @SubCategoryID)
			AND	(@StatusID IS NULL OR Statusid=@StatusID)
			AND	StatusID <> CASE WHEN ISNULL(@statusID, 0) <> 11004 AND @UserRole=2  THEN 11004
							 WHEN ISNULL(@statusID, 0) <> 11019 AND @UserRole=1  THEN 11019 ELSE -1 END
			AND	(@IsReviewed IS  NULL OR IsReviewed = @IsReviewed)
			AND	(ISNULL(@HandledBy, '') = '' OR fb.CreatorID = @HandledID)
			AND	(ISNULL(@Reviewer, '') = '' OR fb.ReviewerID = @ReviewerID)
			AND	(@ResponseID IS NULL OR ResponseID = @ResponseID) 
			AND((@UserRole=1 AND ctm.SiteID=33002) OR(@UserRole=2 AND ctm.SiteID<>33002) ) 
		ORDER BY fb.FeedbackDate DESC,fb.FeedbackID DESC;
		
	END;	
	ELSE  
	BEGIN	
		IF	@IsGuest IS NULL    ------ get feedback for all customer: Guest and our customer MBC
		BEGIN
			
			INSERT INTO #Feedback(FeedbackID, IsRelated,FeedbackDate)	
			SELECT 	fb.FeedbackID, 0,fb.FeedbackDate
			FROM	dbo.crmFeedback fb WITH (NOLOCK)
				CROSS APPLY (SELECT TOP 1 CustID 
							FROM	dbo.crmFeedbackCustomer fbc_t WITH (NOLOCK)
							WHERE fb.FeedbackID = fbc_t.FeedbackID AND fbc_t.IsRelated = 0) AS fbc
								
				INNER JOIN  dbo.crmCustomer ctm WITH(NOLOCK) ON fbc.CustID=ctm.CustID

				CROSS APPLY (SELECT TOP 1 FeedbackID
							 FROM dbo.crmFeedbackSetting fm WITH(NOLOCK) 
							 WHERE fb.FeedbackID=fm.FeedbackID 
								AND (@MainCategoryID IS NULL OR fm.SettingID = @MainCategoryID)		
								AND (@SubCategoryID IS NULL OR fm.SubSettingID = @SubCategoryID) 
							) AS Temp1
				CROSS APPLY (SELECT TOP 1 FeedbackID
							 FROM dbo.crmFeedbackSetting fc WITH(NOLOCK) 
							 WHERE fb.FeedbackID=fc.FeedbackID
								AND (@CommunicationID IS NULL OR fc.SettingID =  @CommunicationID)
							
							) AS Temp2	
			WHERE	fb.FeedbackDate BETWEEN @FromDate AND @ToDate 
				AND	(@StatusID IS NULL OR fb.StatusID=@StatusID)
				AND	fb.StatusID <> CASE WHEN ISNULL(@statusID, 0) <> 11004 AND @UserRole=2  THEN 11004
							 WHEN ISNULL(@statusID, 0) <> 11019 AND @UserRole=1  THEN 11019 ELSE -1 END
				AND((@UserRole=1 AND ctm.SiteID=33002) OR(@UserRole=2 AND ctm.SiteID<>33002) ) 
			
				AND	(@IsReviewed IS  NULL OR IsReviewed = @IsReviewed)
				AND	(ISNULL(@HandledBy, '') = '' OR fb.CreatorID = @HandledID)
				AND	(ISNULL(@Reviewer, '') = '' OR fb.ReviewerID = @ReviewerID)
				AND	(@ResponseID IS NULL OR fb.ResponseID = @ResponseID) 
		ORDER BY fb.FeedbackDate DESC,fb.FeedbackID DESC				
		OPTION (OPTIMIZE  FOR (@FromDate = '2017-10-31 12:00:00', @ToDate = '2018-10-31 11:59:59') )
			
		END;		
		ELSE IF	@IsGuest = 0 -- get feedback for only customer: account of our system MBC
		BEGIN
		
			INSERT INTO #Feedback(FeedbackID, IsRelated,FeedbackDate)			
			SELECT  fb.FeedbackID, 0 AS IsRelated,fb.FeedbackDate
			FROM	dbo.crmFeedback fb WITH (NOLOCK)
				CROSS APPLY (SELECT TOP 1 CustID 
							FROM	dbo.crmFeedbackCustomer fbc_t WITH (NOLOCK)
							WHERE fb.FeedbackID = fbc_t.FeedbackID AND fbc_t.IsRelated = 0) AS fbc
							
				INNER JOIN  dbo.crmCustomer ctm WITH(NOLOCK) ON fbc.CustID=ctm.CustID
				
				CROSS APPLY (SELECT TOP 1 FeedbackID
							 FROM dbo.crmFeedbackSetting fm WITH(NOLOCK) 
							 WHERE fb.FeedbackID=fm.FeedbackID 
								AND (@MainCategoryID IS NULL OR fm.SettingID = @MainCategoryID)		
								AND (@SubCategoryID IS NULL OR fm.SubSettingID = @SubCategoryID) 
							) AS Temp1
				CROSS APPLY (SELECT TOP 1 FeedbackID
							 FROM dbo.crmFeedbackSetting fc WITH(NOLOCK) 
							 WHERE fb.FeedbackID=fc.FeedbackID
								AND (@CommunicationID IS NULL	OR fc.SettingID =  @CommunicationID)
							
							) AS Temp2						
			WHERE fbc.CustID > 0 
				AND fb.FeedbackDate BETWEEN @FromDate AND @ToDate
				AND	(@StatusID IS NULL OR fb.StatusID=@StatusID)
				AND	StatusID <> CASE WHEN ISNULL(@statusID, 0) <> 11004 AND @UserRole=2  THEN 11004
							 WHEN ISNULL(@statusID, 0) <> 11019 AND @UserRole=1  THEN 11019 ELSE -1 END
				AND	(@IsReviewed IS  NULL OR IsReviewed = @IsReviewed)
				AND	(ISNULL(@HandledBy, '') = '' OR fb.CreatorID = @HandledID)
				AND	(ISNULL(@Reviewer, '') = '' OR fb.ReviewerID = @ReviewerID)
				AND	(@ResponseID IS NULL OR fb.ResponseID = @ResponseID) 
				AND((@UserRole=1 AND ctm.SiteID=33002) OR(@UserRole=2 AND ctm.SiteID<>33002) )

			ORDER BY fb.FeedbackDate DESC,fb.FeedbackID DESC
			OPTION (OPTIMIZE  FOR (@FromDate = '2017-10-31 12:00:00', @ToDate = '2018-10-31 11:59:59') )
			
		END;   --- end: get feedback for customer
		ELSE		
		BEGIN  -- get feedback for guest
			INSERT INTO #Feedback(FeedbackID, IsRelated,FeedbackDate)			
			SELECT fb.FeedbackID, 0 AS IsRelated,fb.FeedbackDate
			FROM	dbo.crmFeedback fb WITH (NOLOCK)
				CROSS APPLY (SELECT TOP 1 CustID 
							FROM	dbo.crmFeedbackCustomer fbc_t WITH (NOLOCK)
							WHERE fb.FeedbackID = fbc_t.FeedbackID AND fbc_t.IsRelated = 0) AS fbc
							
				INNER JOIN  crmCustomer ctm WITH(NOLOCK) ON fbc.CustID=ctm.CustID
				CROSS APPLY (SELECT TOP 1 FeedbackID
							 FROM dbo.crmFeedbackSetting fm WITH(NOLOCK) 
							 WHERE fb.FeedbackID=fm.FeedbackID 
								AND (@MainCategoryID IS NULL OR fm.SettingID = @MainCategoryID)		
								AND (@SubCategoryID IS NULL OR fm.SubSettingID = @SubCategoryID) 
							) AS Temp1
				CROSS APPLY (SELECT TOP 1 FeedbackID
							 FROM dbo.crmFeedbackSetting fc WITH(NOLOCK) 
							 WHERE fb.FeedbackID=fc.FeedbackID
								AND (@CommunicationID IS NULL	OR fc.SettingID =  @CommunicationID)
							
							) AS Temp2					
			WHERE fbc.CustID < 0
				AND fb.FeedbackDate BETWEEN @FromDate AND @ToDate
				AND	(@StatusID IS NULL OR fb.StatusID=@StatusID)
				AND	StatusID <> CASE WHEN ISNULL(@statusID, 0) <> 11004 AND @UserRole=2  THEN 11004
							 WHEN ISNULL(@statusID, 0) <> 11019 AND @UserRole=1  THEN 11019 ELSE -1 END
				AND	(@IsReviewed IS  NULL OR IsReviewed = @IsReviewed)
				AND	(ISNULL(@HandledBy, '') = '' OR fb.CreatorID = @HandledID)
				AND	(ISNULL(@Reviewer, '') = '' OR fb.ReviewerID = @ReviewerID)
				AND	(@ResponseID IS NULL OR fb.ResponseID = @ResponseID) 
				AND((@UserRole=1 AND ctm.SiteID=33002) OR(@UserRole=2 AND ctm.SiteID<>33002) )

			ORDER BY fb.FeedbackDate DESC,fb.FeedbackID DESC
			OPTION (OPTIMIZE  FOR (@FromDate = '2017-10-31 12:00:00', @ToDate = '2018-10-31 11:59:59') )	
			
		END; -- end: get feedback for guest
	END;

	--SELECT	@TotalRows = MAX(ID)
	--FROM	#Feedback;
	
	SET @TotalRows = ISNULL((SELECT	COUNT(DISTINCT FeedbackID) AS ITEM	FROM #Feedback),0);
	
	SELECT	fb.FeedbackID
		,	fb.CustID
		,	ctm.UserName
		,	fb.CreatorID
		,	c.username AS CreatorName
		,	fb.FeedbackDate
		,	fb.ResolutionDate
		,	fb.CreateDate
		,	fb.SolveDate	
		,	fb.StatusID
		,	nr.value(N'@Remark',N'nvarchar(max)') AS Description
		,	fb.Solution
		,	fb.IsReviewed
		,	fb.Review
		,	fb.ReviewerID
		,	rv.username AS ReviewerName
		,	fbc.IsRelated
		,	fb.Subject
		,	l.list relatedCustomer		
		,	st.Name Status
	INTO #tempResult
	FROM	#Feedback fbc
		CROSS APPLY (SELECT 
							fb.FeedbackID
							,fb.CustID
							,fb.CreatorID
							,fb.FeedbackDate
							,fb.ResolutionDate
							,fb.CreateDate
							,fb.SolveDate	
							,fb.StatusID
							,fb.Solution
							,fb.IsReviewed
							,fb.Review
							,fb.ReviewerID
							,fb.Subject
							,CAST (fb.Description as XML) Description
					FROM dbo.crmFeedback fb WITH (NOLOCK)						
					WHERE fbc.FeedbackID = fb.FeedbackID
					) AS fb
		LEFT JOIN dbo.crmCustomer ctm WITH (NOLOCK)	ON	ctm.CustID = fb.CustID
		LEFT JOIN bodb02.dbo.custInfo c WITH (NOLOCK)ON	fb.CreatorID = c.custid
		LEFT JOIN bodb02.dbo.custInfo rv WITH (NOLOCK) ON	fb.ReviewerID = rv.custid
		LEFT JOIN crmStatus st WITH (NOLOCK) ON	st.StatusID = fb.StatusID
		CROSS APPLY dbo.f_GetRelatedCustomer(fbc.FeedbackID) l
		OUTER APPLY fb.Description.nodes(N'//row') AS A(nr)
	WHERE	fbc.ID BETWEEN @PageIndex * @ItemsPerPage - @ItemsPerPage + 1
				   AND	   @PageIndex * @ItemsPerPage OR @PageIndex = 0
		
	ORDER BY fb.FeedbackDate DESC,fb.FeedbackID DESC

	SELECT * FROM #tempResult

	SELECT fs.FeedbackID,fs.SettingID,fs.SubSettingID,fs.SubSettingIDLevel3,
			'Category' AS SettingType
	FROM #tempResult t
		INNER JOIN crmFeedbackSetting fs WITH(NOLOCK) ON t.FeedbackID= fs.FeedbackID
		INNER JOIN crmMainCategory m WITH (NOLOCK) ON fs.SettingID=m.MainCategoryID
	
	DROP TABLE #Feedback
	
END
GO


