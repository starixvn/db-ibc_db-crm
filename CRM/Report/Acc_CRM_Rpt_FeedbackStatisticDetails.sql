/*<info serverAlias="DBCRM-bodb_CRM" executers="wsv_nap" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE dbo.Acc_CRM_Rpt_FeedbackStatisticDetails 
	@Type				INT,
	@MainCategoryID		INT,
	@SubCategoryID		INT,
	@FromFeedbackDate	DATETIME	= NULL,
	@ToFeedbackDate		DATETIME	= NULL,
	@CreatorId			INT			= -1,
	@ValueID			INT,
	@FromDate			DATETIME,
	@ToDate				DATETIME,
	@FromDuration		VARCHAR(100),
	@ToDuration			VARCHAR(100),
	@UserRole			TINYINT       = 2,
	@LicenseeType		INT           = 0,
	@SitePermission		NVARCHAR(MAX) = NULL
AS

/*
	Created:	Lukas
	Date:		20101204
	Task:		feedback statistics report
	DB:			DB052/bodb_CRM
	Original:
	
	Revisions:
		- 20110622@Kevin:	add new filter: Status, Response, Product, Category
		- 20111011@Lukas:	Add filter duration
		- 20120425@Sophia:	remove converting @FromDate, @Todate
		- 20140303@Dom:		Modify for new structure
		- 20171225@Winnie: Change for support multiple product/categories. [RedmineID: #84714]		
		- 20190506@Winnie:  CN88 Permission RedmineID: #112637
        - 20231128@Ned.Le: CRM - Security improvement - Separate accessible data for Credit Sites (#197343)
        - 20240131@Ned.Le: Turning performance
        - 20240829@Ned.Le: CRM - When clicking Latest Feedback not found the feedback Due to permission limitations for account P5S (#210055)
		- 20250318@Virgil: CRM - Rating for Feedback Statistics report [RedmineID: #219594]

	Param's Explanation:
		@Type:	- 1		Creator
				- 2		Country
				- 3		Role
				- 4		Site
				- 5		Status
				- 6		Customer Response
				- 7		Product
				- 8		Category
				- 9		Licensee
				- 10	Communication
				- 11	Rating
				- 12	Date and Rating
				- 13	Creator and Rating
        @UserRole = 0: Manager 
                    1: CN88 staff
                    2: Company staff
        @LicenseeType = -1: None
                         0: Both
                         1: Credit
                         2: Licensee
        @SitePermission: Value depend on user's permission and maybe NULL
*/

BEGIN

	SET NOCOUNT ON

	DECLARE	@fDuration			INT,
			@tDuration			INT;

	DECLARE	@tmp TABLE (ID INT IDENTITY PRIMARY KEY, val INT);
	CREATE TABLE #tempFeedback (
					FeedbackID				INT, 
					UserName				NVARCHAR(50),				
					FirstName				NVARCHAR(50), 
					LastName				NVARCHAR(50), 				
					Creator					NVARCHAR(50),
					FeedbackDate			DATETIME,
					ResolutionDate			DATETIME,
					CreateDate				DATETIME,
					SolveDate				DATETIME,	
					StatusID				INT, 
					ReviewerName			NVARCHAR(50),	
					Subject					NVARCHAR(200),
					Rating					TINYINT
					PRIMARY KEY(FeedbackID)					
	)
	CREATE TABLE #tempRelated 
	(
		FeedbackID				INT PRIMARY KEY,
		RelatedCustomer			NVARCHAR(MAX)
	)

	INSERT INTO	@tmp(val)
	SELECT	CONVERT(INT, val)
	FROM	dbo.f_split(@FromDuration,':');

	INSERT INTO	@tmp(val)
	SELECT	CONVERT(INT, val)
	FROM	dbo.f_split(@ToDuration, ':');

	SELECT @fDuration = SUM(CASE WHEN ID = 1 THEN val*24*60*60 
								WHEN ID = 2 THEN val*60*60 
								WHEN ID = 3 THEN val*60 
								WHEN ID = 4 THEN val
								ELSE 0
							END),
		   @tDuration = SUM(CASE WHEN ID = 5 THEN val*24*60*60 
								WHEN ID = 6 THEN val*60*60 
								WHEN ID = 7 THEN val*60 
								WHEN ID = 8 THEN val
								ELSE 0
							END)
	FROM @tmp;
	
	IF @fDuration = 0 AND @tDuration = 0
	BEGIN
		SET @tDuration = 2100000000;
	END;

	IF @Type = 1	--- creator
	BEGIN
			INSERT INTO #tempFeedback (
					FeedbackID,	
					UserName,	
					FirstName,
					LastName,
					Creator,					
					FeedbackDate,			
					ResolutionDate,			
					CreateDate,				
					SolveDate,	
					StatusID,
					ReviewerName,	
					Subject,
					Rating
			)	
				SELECT 	DISTINCT		
					fb.FeedbackID, 
					ctm.Username AS Username,
					fb.FirstName,
					fb.LastName,
					c.username AS CreatorName,
					fb.FeedbackDate,
					fb.ResolutionDate,
					fb.CreateDate,
					fb.SolveDate,
					fb.StatusID, 				
					rv.username AS ReviewerName,
					fb.Subject,
					fb.Rating
				FROM
					crmFeedbackCustomer fbc WITH(NOLOCK)
						INNER JOIN crmFeedback fb WITH(NOLOCK) ON fb.FeedbackID = fbc.FeedbackID	
						INNER JOIN crmCustomer ctm WITH(NOLOCK) ON ctm.CustID = fb.CustID
						INNER JOIN bodb02.dbo.custinfo c WITH(NOLOCK) ON fb.CreatorID = c.custID
						LEFT JOIN bodb02.dbo.custinfo rv WITH(NOLOCK) ON fb.ReviewerID = rv.custID
				WHERE					
					fb.FeedbackDate BETWEEN @FromDate AND @ToDate
					AND 			
					(@ValueID=-1 OR fb.CreatorID = @ValueID)
					AND		
					fbc.IsRelated = 0	
					AND 
					statusID NOT IN( 11004,11019)
					AND 
					DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
					AND
					DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration
					AND ((@UserRole=1 AND ctm.siteID=33002) OR (@UserRole=2 AND ctm.siteID<>33002))
	END;
	ELSE IF @Type = 2    --- Country
	BEGIN
				INSERT INTO #tempFeedback (
					FeedbackID,	
					UserName,
					FirstName,
					LastName,	
					Creator,					
					FeedbackDate,			
					ResolutionDate,			
					CreateDate,				
					SolveDate,	
					StatusID,
					ReviewerName,	
					Subject,
					Rating
			)	
				SELECT DISTINCT			
					fb.FeedbackID, 
					ctm.Username AS Username,
					fb.FirstName,
					fb.LastName,
					c.username AS CreatorName,
					fb.FeedbackDate,
					fb.ResolutionDate,
					fb.CreateDate,
					fb.SolveDate,
					fb.StatusID, 				
					rv.username AS ReviewerName,
					fb.Subject,
					fb.Rating
				FROM	
						crmFeedback fb WITH(NOLOCK)	
						INNER JOIN crmFeedbackCustomer fbc WITH(NOLOCK) ON fb.FeedbackID = fbc.FeedbackID	
						INNER JOIN crmCustomer ctm WITH(NOLOCK) ON ctm.CustID = fb.CustID								
						INNER JOIN bodb02.dbo.custinfo c WITH(NOLOCK) ON fb.CreatorID = c.custID
						LEFT JOIN bodb02.dbo.custinfo rv WITH(NOLOCK) ON fb.ReviewerID = rv.custID	
				WHERE					
					fb.FeedbackDate BETWEEN @FromDate AND @ToDate				
					AND (fb.CountryID = @ValueID OR @ValueID=-1)		
					AND
					fbc.IsRelated = 0
					AND 
					statusID NOT IN( 11004,11019)
					AND 
					DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
					AND
					DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration
					AND ((@UserRole=1 AND ctm.siteID=33002) OR (@UserRole=2 AND ctm.siteID<>33002))
	END;
	ELSE IF @Type = 3    --- Role
	BEGIN
				INSERT INTO #tempFeedback (
					FeedbackID,	
					UserName,	
					FirstName,
					LastName,
					Creator,					
					FeedbackDate,			
					ResolutionDate,			
					CreateDate,				
					SolveDate,	
					StatusID,
					ReviewerName,	
					Subject,
					Rating
			)	
				SELECT 	DISTINCT		
					fb.FeedbackID, 
					ctm.Username AS Username,
					fb.FirstName,
					fb.LastName,
					c.username AS CreatorName,
					fb.FeedbackDate,
					fb.ResolutionDate,
					fb.CreateDate,
					fb.SolveDate,
					fb.StatusID, 				
					rv.username AS ReviewerName,
					fb.Subject,
					fb.Rating
				FROM					
						crmFeedback fb WITH(NOLOCK)		
						INNER JOIN crmFeedbackCustomer fbc WITH(NOLOCK) ON fb.FeedbackID = fbc.FeedbackID	
						INNER JOIN crmCustomer ctm WITH(NOLOCK) ON  fb.CustID=ctm.CustID								
						INNER JOIN bodb02.dbo.custinfo c WITH(NOLOCK) ON fb.CreatorID = c.custID
						LEFT JOIN bodb02.dbo.custinfo rv WITH(NOLOCK) ON fb.ReviewerID = rv.custID	
						
				WHERE					
					fb.FeedbackDate BETWEEN @FromDate AND @ToDate
					AND
					(@ValueID=-1 OR fb.RoleID = @ValueID)
					AND		
					fbc.IsRelated = 0
					AND 
					statusID NOT IN( 11004,11019)
					AND 
					DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
					AND
					DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration
					AND ((@UserRole=1 AND ctm.siteID=33002) OR (@UserRole=2 AND ctm.siteID<>33002))

	END;
	ELSE IF @Type = 4    --- Site
	BEGIN
				INSERT INTO #tempFeedback (
					FeedbackID,	
					UserName,	
					FirstName,
					LastName,
					Creator,					
					FeedbackDate,			
					ResolutionDate,			
					CreateDate,				
					SolveDate,	
					StatusID,
					ReviewerName,	
					Subject,
					Rating
				)	
				SELECT DISTINCT			
					fb.FeedbackID, 
					ctm.Username AS Username,
					fb.FirstName,
					fb.LastName,
					c.username AS CreatorName,
					fb.FeedbackDate,
					fb.ResolutionDate,
					fb.CreateDate,
					fb.SolveDate,
					fb.StatusID, 				
					rv.username AS ReviewerName,
					fb.Subject,
					fb.Rating
				FROM					
					crmFeedbackCustomer fbc WITH(NOLOCK)
						INNER JOIN crmFeedback fb WITH(NOLOCK) ON fb.FeedbackID = fbc.FeedbackID						
						INNER JOIN crmCustomer ctm WITH(NOLOCK) ON ctm.CustID = fb.CustID
						INNER JOIN bodb02.dbo.custinfo c WITH(NOLOCK) ON fb.CreatorID = c.custID
						LEFT JOIN bodb02.dbo.custinfo rv WITH(NOLOCK) ON fb.ReviewerID = rv.custID
				WHERE					
					fb.FeedbackDate BETWEEN @FromDate AND @ToDate
					AND 				
					(fb.SiteID = @ValueID OR @ValueID=-1)
					AND		
					fbc.IsRelated = 0
					AND 
					statusID NOT IN( 11004,11019)
					AND 
					DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
					AND
					DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration	
					AND ((@UserRole=1 AND ctm.siteID=33002) OR (@UserRole=2 AND ctm.siteID<>33002))		
	END;
	ELSE IF @Type = 5    --- Status
	BEGIN
				INSERT INTO #tempFeedback (
					FeedbackID,	
					UserName,	
					FirstName,
					LastName,
					Creator,					
					FeedbackDate,			
					ResolutionDate,			
					CreateDate,				
					SolveDate,	
					StatusID,
					ReviewerName,	
					Subject,
					Rating
				)	
				SELECT 	DISTINCT		
					fb.FeedbackID, 
					ctm.Username AS Username,
					fb.FirstName,
					fb.LastName,
					c.username AS CreatorName,
					fb.FeedbackDate,
					fb.ResolutionDate,
					fb.CreateDate,
					fb.SolveDate,
					fb.StatusID, 				
					rv.username AS ReviewerName,
					fb.Subject,
					fb.Rating
				FROM	
					crmFeedbackCustomer fbc WITH(NOLOCK)
						INNER JOIN crmFeedback fb WITH(NOLOCK) ON fb.FeedbackID = fbc.FeedbackID
						INNER JOIN crmCustomer ctm WITH(NOLOCK) ON ctm.CustID = fb.CustID
						INNER JOIN bodb02.dbo.custinfo c WITH(NOLOCK) ON fb.CreatorID = c.custID
						LEFT JOIN bodb02.dbo.custinfo rv WITH(NOLOCK) ON fb.ReviewerID = rv.custID
				WHERE					
					fb.FeedbackDate BETWEEN @FromDate AND @ToDate	
					AND
					(@ValueID=-1 OR fb.StatusID = @ValueID)
					AND		
					fbc.IsRelated = 0	
					AND 
					statusID NOT IN( 11004,11019)
					AND 
					DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
					AND
					DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration	
					AND ((@UserRole=1 AND ctm.siteID=33002) OR (@UserRole=2 AND ctm.siteID<>33002))		
	END;
	ELSE IF @Type = 6    --- Customer Response
	BEGIN
		INSERT INTO #tempFeedback (
					FeedbackID,	
					UserName,	
					FirstName,
					LastName,
					Creator,					
					FeedbackDate,			
					ResolutionDate,			
					CreateDate,				
					SolveDate,	
					StatusID,
					ReviewerName,	
					Subject,
					Rating
				)	
				SELECT 	DISTINCT		
					fb.FeedbackID, 				
					ctm.Username AS Username,
					fb.FirstName,
					fb.LastName,
					c.username AS CreatorName,
					fb.FeedbackDate,
					fb.ResolutionDate,
					fb.CreateDate,
					fb.SolveDate,
					fb.StatusID, 				
					rv.username AS ReviewerName,
					fb.Subject,
					fb.Rating
				FROM	
					crmFeedbackCustomer fbc WITH(NOLOCK)
						INNER JOIN crmFeedback fb WITH(NOLOCK) ON fb.FeedbackID = fbc.FeedbackID						
						INNER JOIN crmCustomer ctm WITH(NOLOCK) ON ctm.CustID = fb.CustID
						INNER JOIN bodb02.dbo.custinfo c WITH(NOLOCK) ON fb.CreatorID = c.custID
						LEFT JOIN bodb02.dbo.custinfo rv WITH(NOLOCK) ON fb.ReviewerID = rv.custID
				WHERE					
					fb.FeedbackDate BETWEEN @FromDate AND @ToDate			
					AND 
					statusID NOT IN( 11004,11019)
					AND
					(fb.ResponseID = @ValueID OR @ValueID=-1)
					AND		
					fbc.IsRelated = 0					
					AND 
					DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
					AND
					DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration	
					AND ((@UserRole=1 AND ctm.siteID=33002) OR (@UserRole=2 AND ctm.siteID<>33002))		
	END;
	ELSE IF @Type = 7 AND (@ValueID=-1)   --- Product
	BEGIN
		INSERT INTO #tempFeedback (
					FeedbackID,	
					UserName,	
					FirstName,
					LastName,
					Creator,					
					FeedbackDate,			
					ResolutionDate,			
					CreateDate,				
					SolveDate,	
					StatusID,
					ReviewerName,	
					Subject,
					Rating
				)	
				SELECT 	DISTINCT		
					fb.FeedbackID, 
					ctm.Username AS Username,
					fb.FirstName,
					fb.LastName,
					c.username AS CreatorName,
					fb.FeedbackDate,
					fb.ResolutionDate,
					fb.CreateDate,
					fb.SolveDate,
					fb.StatusID, 				
					rv.username AS ReviewerName,
					fb.Subject,
					fb.Rating
				FROM	
					crmFeedbackCustomer fbc WITH(NOLOCK)
						INNER JOIN crmFeedback fb WITH(NOLOCK) ON fb.FeedbackID = fbc.FeedbackID						
						INNER JOIN crmCustomer ctm WITH(NOLOCK) ON ctm.CustID = fb.CustID
						INNER JOIN bodb02.dbo.custinfo c WITH(NOLOCK) ON fb.CreatorID = c.custID
						LEFT JOIN bodb02.dbo.custinfo rv WITH(NOLOCK) ON fb.ReviewerID = rv.custID						
				WHERE					
					fb.FeedbackDate BETWEEN @FromDate AND @ToDate					
					AND		
					fbc.IsRelated = 0
					AND 
					statusID NOT IN( 11004,11019)		
					AND 
					DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
					AND
					DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration		
					AND ((@UserRole=1 AND ctm.siteID=33002) OR (@UserRole=2 AND ctm.siteID<>33002))	
	END;
	ELSE IF @Type = 7 AND (@ValueID<>-1)   --- Product
	BEGIN
		INSERT INTO #tempFeedback (
					FeedbackID,	
					UserName,	
					FirstName,
					LastName,
					Creator,					
					FeedbackDate,			
					ResolutionDate,			
					CreateDate,				
					SolveDate,	
					StatusID,
					ReviewerName,	
					Subject,
					Rating
				)	
				SELECT 	DISTINCT		
					fb.FeedbackID, 
					ctm.Username AS Username,
					fb.FirstName,
					fb.LastName,
					c.username AS CreatorName,
					fb.FeedbackDate,
					fb.ResolutionDate,
					fb.CreateDate,
					fb.SolveDate,
					fb.StatusID, 				
					rv.username AS ReviewerName,
					fb.Subject,
					fb.Rating
				FROM	
					crmFeedbackCustomer fbc WITH(NOLOCK)
						INNER JOIN crmFeedback fb WITH(NOLOCK) ON fb.FeedbackID = fbc.FeedbackID						
						INNER JOIN crmCustomer ctm WITH(NOLOCK) ON ctm.CustID = fb.CustID
						INNER JOIN bodb02.dbo.custinfo c WITH(NOLOCK) ON fb.CreatorID = c.custID
						LEFT JOIN bodb02.dbo.custinfo rv WITH(NOLOCK) ON fb.ReviewerID = rv.custID
						INNER JOIN crmfeedbacksetting fs WITH(NOLOCK) ON fb.feedbackID=fs.feedbackID						
				WHERE					
					fb.FeedbackDate BETWEEN @FromDate AND @ToDate
					AND
					fbc.IsRelated = 0
					AND 
					statusID NOT IN( 11004,11019)		
					AND 
					DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
					AND
					DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration	
					AND fs.settingID=@ValueID
					
					
	END;
	ELSE IF @Type = 8 AND (@ValueID=-1)   --- Category
	BEGIN
		INSERT INTO #tempFeedback (
					FeedbackID,	
					UserName,	
					FirstName,
					LastName,
					Creator,					
					FeedbackDate,			
					ResolutionDate,			
					CreateDate,				
					SolveDate,	
					StatusID,
					ReviewerName,	
					Subject,
					Rating
				)	
				SELECT 	
					DISTINCT		
					fb.FeedbackID, 
					ctm.Username AS Username,
					fb.FirstName,
					fb.LastName,
					c.username AS CreatorName,
					fb.FeedbackDate,
					fb.ResolutionDate,
					fb.CreateDate,
					fb.SolveDate,
					fb.StatusID, 				
					rv.username AS ReviewerName,
					fb.Subject,
					fb.Rating
				FROM	
					crmFeedbackCustomer fbc WITH(NOLOCK)
						INNER JOIN crmFeedback fb WITH(NOLOCK) ON fb.FeedbackID = fbc.FeedbackID
						INNER JOIN crmCustomer ctm WITH(NOLOCK) ON ctm.CustID = fb.CustID
						INNER JOIN bodb02.dbo.custinfo c WITH(NOLOCK) ON fb.CreatorID = c.custID
						LEFT JOIN bodb02.dbo.custinfo rv WITH(NOLOCK) ON fb.ReviewerID = rv.custID						
				WHERE					
					fb.FeedbackDate BETWEEN @FromDate AND @ToDate		
					AND
					fbc.IsRelated = 0
					AND 
					statusID NOT IN( 11004,11019)	
					AND 
					DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
					AND
					DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration
					AND ((@UserRole=1 AND ctm.siteID=33002) OR (@UserRole=2 AND ctm.siteID<>33002))			
	END;
	ELSE IF @Type = 8 AND (@ValueID<>-1)   --- Category
	BEGIN
		INSERT INTO #tempFeedback (
					FeedbackID,	
					UserName,	
					FirstName,
					LastName,
					Creator,					
					FeedbackDate,			
					ResolutionDate,			
					CreateDate,				
					SolveDate,	
					StatusID,
					ReviewerName,	
					Subject,
					Rating
				)	
				SELECT 	
					DISTINCT		
					fb.FeedbackID, 
					ctm.Username AS Username,
					fb.FirstName,
					fb.LastName,
					c.username AS CreatorName,
					fb.FeedbackDate,
					fb.ResolutionDate,
					fb.CreateDate,
					fb.SolveDate,
					fb.StatusID, 				
					rv.username AS ReviewerName,
					fb.Subject,
					fb.Rating
				FROM	
					crmFeedbackCustomer fbc WITH(NOLOCK)
						INNER JOIN crmFeedback fb WITH(NOLOCK) ON fb.FeedbackID = fbc.FeedbackID
						INNER JOIN crmCustomer ctm WITH(NOLOCK) ON ctm.CustID = fb.CustID
						INNER JOIN bodb02.dbo.custinfo c WITH(NOLOCK) ON fb.CreatorID = c.custID
						LEFT JOIN bodb02.dbo.custinfo rv WITH(NOLOCK) ON fb.ReviewerID = rv.custID
						INNER JOIN crmfeedbacksetting fs WITH(NOLOCK) ON fb.feedbackID=fs.feedbackID						
				WHERE					
					fb.FeedbackDate BETWEEN @FromDate AND @ToDate	
					AND 
					fbc.IsRelated = 0
					AND 
					statusID NOT IN( 11004,11019)
					AND 
					DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
					AND
					DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration		
					AND fs.settingID=@ValueID						
	END;
	ELSE IF @Type = 9    --- Licensee
	BEGIN
			INSERT INTO #tempFeedback (
					FeedbackID,	
					UserName,	
					FirstName,
					LastName,
					Creator,					
					FeedbackDate,			
					ResolutionDate,			
					CreateDate,				
					SolveDate,	
					StatusID,
					ReviewerName,	
					Subject,
					Rating
				)	
				SELECT 			
					DISTINCT
					fb.FeedbackID, 
					ctm.Username AS Username,
					fb.FirstName,
					fb.LastName,
					c.username AS CreatorName,
					fb.FeedbackDate,
					fb.ResolutionDate,
					fb.CreateDate,
					fb.SolveDate,
					fb.StatusID, 				
					rv.username AS ReviewerName,
					fb.Subject,
					fb.Rating
				FROM	
					crmFeedbackCustomer fbc WITH(NOLOCK)
						INNER JOIN crmFeedback fb WITH(NOLOCK) ON fb.FeedbackID = fbc.FeedbackID						
						INNER JOIN crmCustomer ctm WITH(NOLOCK) ON ctm.CustID = fb.CustID
						INNER JOIN bodb02.dbo.custinfo c WITH(NOLOCK) ON fb.CreatorID = c.custID
						LEFT JOIN bodb02.dbo.custinfo rv WITH(NOLOCK) ON fb.ReviewerID = rv.custID	
                        LEFT JOIN crmSite si WITH(NOLOCK) ON fb.SiteID = si.SiteID
				WHERE					
					fb.FeedbackDate BETWEEN @FromDate AND @ToDate				
					AND
					(@ValueID=-1 OR fb.siteID = @ValueID)
					AND		
					fbc.IsRelated = 0
					AND 
					statusID NOT IN( 11004,11019)	
					AND 
					DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
					AND
					DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration		
					AND ((@UserRole=1 AND ctm.siteID=33002) OR (@UserRole=2 AND ctm.siteID<>33002))
                    AND (si.IsLicensee=1 OR ISNULL(fb.SiteID, 0) = 0)

	END;
	ELSE IF @Type = 10 AND @ValueID<>-1   --- communication
	BEGIN
		INSERT INTO #tempFeedback (
					FeedbackID,	
					UserName,	
					FirstName,
					LastName,
					Creator,					
					FeedbackDate,			
					ResolutionDate,			
					CreateDate,				
					SolveDate,	
					StatusID,
					ReviewerName,	
					Subject,
					Rating
				)	
				SELECT 		
					DISTINCT	
					fb.FeedbackID, 
					ctm.Username AS Username,
					fb.FirstName,
					fb.LastName,
					c.username AS CreatorName,
					fb.FeedbackDate,
					fb.ResolutionDate,
					fb.CreateDate,
					fb.SolveDate,
					fb.StatusID, 				
					rv.username AS ReviewerName,
					fb.Subject,
					fb.Rating
				FROM	
					crmFeedbackCustomer fbc WITH(NOLOCK)
						INNER JOIN crmFeedback fb WITH(NOLOCK) ON fb.FeedbackID = fbc.FeedbackID						
						INNER JOIN crmCustomer ctm WITH(NOLOCK) ON ctm.CustID = fb.CustID
						INNER JOIN bodb02.dbo.custinfo c WITH(NOLOCK) ON fb.CreatorID = c.custID
						LEFT JOIN bodb02.dbo.custinfo rv WITH(NOLOCK) ON fb.ReviewerID = rv.custID	
						INNER JOIN crmfeedbacksetting fs WITH(NOLOCK) ON fb.feedbackID=fs.feedbackID						
				WHERE					
					fb.FeedbackDate BETWEEN @FromDate AND @ToDate	
					AND		
					fbc.IsRelated = 0
					AND 
					statusID NOT IN( 11004,11019)	
					AND 
					DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
					AND
					DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration
					AND fs.settingID=@ValueID		
	END			
	ELSE IF @Type = 10 AND (@ValueID=-1)   --- communication
	BEGIN
			INSERT INTO #tempFeedback (
					FeedbackID,	
					UserName,	
					FirstName,
					LastName,
					Creator,					
					FeedbackDate,			
					ResolutionDate,			
					CreateDate,				
					SolveDate,	
					StatusID,
					ReviewerName,	
					Subject,
					Rating
				)	
				SELECT 	DISTINCT		
					fb.FeedbackID, 
					ctm.Username AS Username,
					fb.FirstName,
					fb.LastName,
					c.username AS CreatorName,
					fb.FeedbackDate,
					fb.ResolutionDate,
					fb.CreateDate,
					fb.SolveDate,
					fb.StatusID, 				
					rv.username AS ReviewerName,
					fb.Subject,
					fb.Rating
				FROM	
					crmFeedbackCustomer fbc WITH(NOLOCK)
						INNER JOIN crmFeedback fb WITH(NOLOCK) ON fb.FeedbackID = fbc.FeedbackID						
						INNER JOIN crmCustomer ctm WITH(NOLOCK) ON ctm.CustID = fb.CustID
						INNER JOIN bodb02.dbo.custinfo c WITH(NOLOCK) ON fb.CreatorID = c.custID
						LEFT JOIN bodb02.dbo.custinfo rv WITH(NOLOCK) ON fb.ReviewerID = rv.custID	
				WHERE					
					fb.FeedbackDate BETWEEN @FromDate AND @ToDate	
					AND		
					fbc.IsRelated = 0
					AND 
					statusID NOT IN( 11004,11019)
					AND 
					DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
					AND
					DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration		
					AND ((@UserRole=1 AND ctm.siteID=33002) OR (@UserRole=2 AND ctm.siteID<>33002))
	END
	ELSE IF @Type IN (11,13)    --- Rating & Creator and Rating
	BEGIN
			INSERT INTO #tempFeedback (
					FeedbackID,	
					UserName,	
					FirstName,
					LastName,
					Creator,					
					FeedbackDate,			
					ResolutionDate,			
					CreateDate,				
					SolveDate,	
					StatusID,
					ReviewerName,	
					Subject,
					Rating
				)	
				SELECT 	DISTINCT		
					fb.FeedbackID, 
					ctm.Username AS Username,
					fb.FirstName,
					fb.LastName,
					c.username AS CreatorName,
					fb.FeedbackDate,
					fb.ResolutionDate,
					fb.CreateDate,
					fb.SolveDate,
					fb.StatusID, 				
					rv.username AS ReviewerName,
					fb.Subject,
					fb.Rating
				FROM					
						crmFeedback fb WITH(NOLOCK)		
						INNER JOIN crmFeedbackCustomer fbc WITH(NOLOCK) ON fb.FeedbackID = fbc.FeedbackID	
						INNER JOIN crmCustomer ctm WITH(NOLOCK) ON  fb.CustID=ctm.CustID								
						INNER JOIN bodb02.dbo.custinfo c WITH(NOLOCK) ON fb.CreatorID = c.custID
						LEFT JOIN bodb02.dbo.custinfo rv WITH(NOLOCK) ON fb.ReviewerID = rv.custID					
				WHERE					
					fb.FeedbackDate BETWEEN @FromDate AND @ToDate
					AND
					ISNULL(fb.Rating, 0) <> 0
					AND
					(@ValueID=-1 OR ISNULL(fb.Rating,0) = @ValueID)
					AND
					(@CreatorId=-1 OR fb.CreatorID = @CreatorId)
					AND 
					fbc.IsRelated = 0
					AND 
					statusID NOT IN( 11004,11019)
					AND 
					DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
					AND
					DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration
					AND ((@UserRole=1 AND ctm.siteID=33002) OR (@UserRole=2 AND ctm.siteID<>33002))

	END; 
	IF @Type = 12	--- By Date and Rating
	BEGIN
			INSERT INTO #tempFeedback (
					FeedbackID,	
					UserName,	
					FirstName,
					LastName,
					Creator,					
					FeedbackDate,			
					ResolutionDate,			
					CreateDate,				
					SolveDate,	
					StatusID,
					ReviewerName,	
					Subject,
					Rating
			)	
			SELECT 	DISTINCT		
					fb.FeedbackID, 
					ctm.Username AS Username,
					fb.FirstName,
					fb.LastName,
					c.username AS CreatorName,
					fb.FeedbackDate,
					fb.ResolutionDate,
					fb.CreateDate,
					fb.SolveDate,
					fb.StatusID, 				
					rv.username AS ReviewerName,
					fb.Subject,
					fb.Rating
			FROM
				crmFeedbackCustomer fbc WITH(NOLOCK)
					INNER JOIN crmFeedback fb WITH(NOLOCK) ON fb.FeedbackID = fbc.FeedbackID	
					INNER JOIN crmCustomer ctm WITH(NOLOCK) ON ctm.CustID = fb.CustID
					INNER JOIN bodb02.dbo.custinfo c WITH(NOLOCK) ON fb.CreatorID = c.custID
					LEFT JOIN bodb02.dbo.custinfo rv WITH(NOLOCK) ON fb.ReviewerID = rv.custID
			WHERE fb.FeedbackDate BETWEEN @FromDate AND @ToDate
				AND 
				((@FromFeedbackDate IS NULL AND @ToFeedbackDate IS NULL) OR fb.FeedbackDate BETWEEN @FromFeedbackDate AND @ToFeedbackDate)
				AND
				ISNULL(fb.Rating, 0) <> 0
				AND
				(@ValueID=-1 OR ISNULL(fb.Rating,0) = @ValueID)
				AND		
				fbc.IsRelated = 0	
				AND 
				statusID NOT IN( 11004,11019)
				AND 
				DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
				AND
				DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration
				AND ((@UserRole=1 AND ctm.siteID=33002) OR (@UserRole=2 AND ctm.siteID<>33002))
	END;


    ------------------------------
    -- BEGIN - Apply permission --

    CREATE TABLE #tmpUserSitePermission (SitePermission NVARCHAR(100))
    INSERT INTO #tmpUserSitePermission (SitePermission)
    SELECT value SitePermission
    FROM STRING_SPLIT(@SitePermission, ',')

    CREATE TABLE #tmpSite (
        SiteID     INT,
        SiteName   NVARCHAR(100),
        IsLicensee INT,
        IsActive   BIT,
        SiteLabel  VARCHAR(50),
        SiteOffer  INT
    )
    INSERT INTO #tmpSite (
        SiteID,
        SiteName,
        IsLicensee,
        IsActive,
        SiteLabel,
        SiteOffer
    )
    SELECT si.SettingID SiteID,
           si.SettingValue SiteName,
           CASE WHEN sr.ParentID = 33000 THEN 1
                WHEN sr.ParentID = 33001 THEN 0
                ELSE -1 END IsLicensee,
           si.IsActive IsActive,
           si.ExtraInfo SiteLabel,
           sc.SiteOffer SiteOffer
    FROM bodb_CRM.dbo.crmSettingRelation sr WITH (NOLOCK)
         INNER JOIN bodb_CRM.dbo.crmSetting sc WITH (NOLOCK) ON sc.SettingName = 'SiteCategory' AND sr.ParentID = sc.SettingID
         INNER JOIN	bodb_CRM.dbo.crmSetting si WITH (NOLOCK) ON si.SettingName = 'Site' AND sr.SettingID = si.SettingID
    WHERE sr.ParentID IN (33000, 33001)
    UNION ALL
    SELECT sc.SettingID SiteID,
           sc.SettingValue SiteName,
           0 IsLicensee,
           sc.IsActive IsActive,
           NULL SiteLabel,
           sc.SiteOffer SiteOffer
    FROM bodb_CRM.dbo.crmSetting sc WITH (NOLOCK)
    WHERE sc.SettingName = 'SiteCategory' AND sc.SettingID = 33002

    CREATE TABLE #tmpSitePermission (
        SiteID         INT,
        SiteName       NVARCHAR(100),
        SitePermission NVARCHAR(100)
    )
    INSERT INTO #tmpSitePermission (
        SiteID,
        SiteName,
        SitePermission
    )
    SELECT sr.SettingID    SiteID,
           si.SettingValue SiteName,
           sp.SettingValue SitePermission
    FROM bodb_CRM.dbo.crmSettingRelation sr WITH (NOLOCK)
         INNER JOIN bodb_CRM.dbo.crmSetting sp WITH (NOLOCK) ON sp.SettingName = 'SitePermission' AND sr.ParentID = sp.SettingID
         INNER JOIN bodb_CRM.dbo.crmSetting si WITH (NOLOCK) ON si.SettingName = 'Site' AND sr.SettingID = si.SettingID

    ;WITH
    CTE_feedback AS (
        SELECT tmp.FeedbackID
        FROM #tempFeedback tmp
             LEFT JOIN bodb_CRM.dbo.crmFeedback fb WITH (NOLOCK) ON tmp.FeedbackID = fb.FeedbackID
             LEFT JOIN #tmpSite si ON fb.SiteID = si.SiteID
             LEFT JOIN #tmpSitePermission sp ON si.SiteID = sp.SiteID
             LEFT JOIN #tmpUserSitePermission usp ON sp.SitePermission = usp.SitePermission
        WHERE (si.SiteOffer = @UserRole OR si.SiteOffer IS NULL)
              AND @LicenseeType <> -1
              AND
              (
                  si.IsLicensee IS NULL
                  OR si.IsLicensee = CASE WHEN @LicenseeType = 0 THEN si.IsLicensee WHEN @LicenseeType = 1 THEN 0 ELSE 1 END
              )
              AND
              (
                  (sp.SitePermission IS NULL AND ISNULL(si.IsLicensee, 1) = 1)
                  OR sp.SitePermission = usp.SitePermission
              )
    )
    DELETE tmp
    FROM #tempFeedback tmp
    WHERE tmp.FeedbackID NOT IN (SELECT FeedbackID FROM CTE_feedback)

    DROP TABLE #tmpUserSitePermission
    DROP TABLE #tmpSite
    DROP TABLE #tmpSitePermission

    -- END - Apply permission --
    ----------------------------

	
	IF (@MainCategoryID<>0)
	BEGIN
		INSERT INTO #tempRelated (FeedbackID)		
		SELECT DISTINCT t.FeedbackID
		FROM #tempFeedback t 
			INNER JOIN crmFeedbackCustomer fc WITH(NOLOCK) ON t.FeedbackID=fc.FeedbackID
		WHERE fc.IsRelated = 1
		
		UPDATE #tempRelated
			SET RelatedCustomer=(SELECT list FROM dbo.f_GetRelatedCustomer(FeedbackID))		
		
		SELECT DISTINCT t.*, r.RelatedCustomer
		FROM #tempFeedback t		
		INNER JOIN crmFeedbackSetting fs ON t.FeedbackID=fs.FeedbackID
		LEFT JOIN #tempRelated r ON t.FeedbackID=r.FeedbackID 	
		WHERE fs.SettingID=@MainCategoryID AND (@SubCategoryID=0 OR fs.SubSettingID=@SubCategoryID)
		ORDER BY t.FeedbackDate	DESC
						
		SELECT t.FeedbackID, fs.SettingID AS MainCategory, fs.SubSettingID AS SubCategory
		FROM #tempFeedback t		
		INNER JOIN crmFeedbackSetting fs ON t.FeedbackID=fs.FeedbackID	 	
		WHERE fs.SettingID=@MainCategoryID AND (@SubCategoryID=0 OR fs.SubSettingID=@SubCategoryID)
		ORDER BY t.FeedbackDate	

	END
	ELSE
	BEGIN
		
        -- Dataset 01
        CREATE TABLE #tmpcrmFeedbackCustomer (FeedbackID INT, CustID INT)

        INSERT INTO  #tmpcrmFeedbackCustomer (FeedbackID, CustID)
        SELECT FeedbackID, CustID
        FROM bodb_CRM.dbo.crmFeedbackCustomer WITH (NOLOCK)
        WHERE FeedbackID IN (SELECT FeedbackID FROM #tempFeedback)
              AND IsRelated = 1

        CREATE CLUSTERED INDEX CIX_FeedbackID ON #tmpcrmFeedbackCustomer(FeedbackID)

        INSERT INTO #tempRelated (FeedbackID, RelatedCustomer)
        SELECT FeedbackID, STRING_AGG(CAST(ISNULL(c.Username,d.UserName) AS NVARCHAR(MAX)), ',') RelatedCustomer
        FROM #tmpcrmFeedbackCustomer fc WITH(NOLOCK)
             LEFT JOIN bodb02.dbo.customer c WITH(NOLOCK) ON fc.CustID = c.CustID
		     LEFT JOIN DBLIC.bodb_CRM.dbo.crmcustomer d WITH(NOLOCK) ON fc.CustID = d.CustID
        GROUP BY FeedbackID
		
		SELECT DISTINCT t.*, r.RelatedCustomer
		FROM #tempFeedback t 		
			 LEFT JOIN #tempRelated r ON t.FeedbackID=r.FeedbackID 		
		ORDER BY t.FeedbackDate	DESC

        DROP TABLE #tmpcrmFeedbackCustomer

        -- Dataset 02
        CREATE TABLE #tmpcrmFeedbackSetting (FeedbackID INT, SettingID INT, SubSettingID INT)

        INSERT INTO  #tmpcrmFeedbackSetting (FeedbackID, SettingID, SubSettingID)
        SELECT FeedbackID, SettingID, SubSettingID
        FROM bodb_CRM.dbo.crmFeedbackSetting WITH (NOLOCK)
        WHERE FeedbackID IN (SELECT FeedbackID FROM #tempFeedback)

        CREATE CLUSTERED INDEX CIX_FeedbackID ON #tmpcrmFeedbackSetting(FeedbackID)

		SELECT t.FeedbackID,fm.SettingID AS MainCategory,fm.SubSettingID AS SubCategory
		FROM #tempFeedback t
			INNER JOIN #tmpcrmFeedbackSetting fm WITH(NOLOCK) ON t.FeedbackID=fm.FeedbackID
			INNER JOIN crmMainCategory mc WITH(NOLOCK) ON fm.SettingID=mc.MainCategoryID

        DROP TABLE #tmpcrmFeedbackSetting
		
	END

	DROP TABLE #tempRelated;
	DROP TABLE #tempFeedback;
END
GO