/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE dbo.Acc_CRM_Rpt_FeedbackStatisticDetails @Type           INT,
                                                         @MainCategoryID INT,
                                                         @SubCategoryID  INT,
                                                         @ValueID        INT,
                                                         @FromDate       DATETIME,
                                                         @ToDate         DATETIME,
                                                         @FromDuration   VARCHAR(100),
                                                         @ToDuration     VARCHAR(100),
                                                         @UserRole       TINYINT       = 2,
                                                         @LicenseeType   TINYINT       = 0,
                                                         @SitePermission NVARCHAR(MAX) = NULL
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
        @LicenseeType = 0: Both
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
					Subject		
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
					fb.Subject
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
					Subject		
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
					fb.Subject
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
					Subject		
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
					fb.Subject
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
					Subject		
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
					fb.Subject
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
					Subject		
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
					fb.Subject
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
					Subject		
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
					fb.Subject
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
					Subject		
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
					fb.Subject
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
					Subject		
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
					fb.Subject
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
					Subject		
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
					fb.Subject
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
					Subject		
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
					fb.Subject
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
					Subject		
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
					fb.Subject
				FROM	
					crmFeedbackCustomer fbc WITH(NOLOCK)
						INNER JOIN crmFeedback fb WITH(NOLOCK) ON fb.FeedbackID = fbc.FeedbackID						
						INNER JOIN crmCustomer ctm WITH(NOLOCK) ON ctm.CustID = fb.CustID
						INNER JOIN bodb02.dbo.custinfo c WITH(NOLOCK) ON fb.CreatorID = c.custID
						LEFT JOIN bodb02.dbo.custinfo rv WITH(NOLOCK) ON fb.ReviewerID = rv.custID	
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
					Subject		
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
					fb.Subject
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
					Subject		
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
					fb.Subject
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
             LEFT JOIN #tmpUserSitePermission usp ON sp.SitePermission = sp.SitePermission
        WHERE (si.SiteOffer = @UserRole OR si.SiteOffer IS NULL)
              AND
              (
                  si.IsLicensee IS NULL
                  OR si.IsLicensee = CASE WHEN @LicenseeType = 0 THEN si.IsLicensee WHEN @LicenseeType = 1 THEN 0 ELSE 1 END
              )
              AND
              (
                  sp.SitePermission IS NULL
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
		INSERT INTO #tempRelated 
			(
				FeedbackID
			)		
		SELECT DISTINCT t.FeedbackID
		FROM #tempFeedback t 
			INNER JOIN crmFeedbackCustomer fc WITH(NOLOCK)  ON t.FeedbackID=fc.FeedbackID
		WHERE fc.IsRelated = 1
		
		UPDATE #tempRelated
			SET RelatedCustomer=(SELECT list FROM dbo.f_GetRelatedCustomer(FeedbackID))		
		
		SELECT DISTINCT t.*,r.RelatedCustomer
		FROM #tempFeedback t		
		INNER JOIN crmFeedbackSetting fs ON t.FeedbackID=fs.FeedbackID
		LEFT JOIN #tempRelated r ON t.FeedbackID=r.FeedbackID 	
		WHERE fs.SettingID=@MainCategoryID AND (@SubCategoryID=0 OR fs.SubSettingID=@SubCategoryID)
		ORDER BY t.FeedbackDate	DESC
						
		SELECT t.FeedbackID,fs.SettingID AS MainCategory, fs.SubSettingID AS SubCategory
		FROM #tempFeedback t		
		INNER JOIN crmFeedbackSetting fs ON t.FeedbackID=fs.FeedbackID	 	
		WHERE fs.SettingID=@MainCategoryID AND (@SubCategoryID=0 OR fs.SubSettingID=@SubCategoryID)
		ORDER BY t.FeedbackDate	

	END
	ELSE
	BEGIN
		
		INSERT INTO #tempRelated 
			(
				FeedbackID
			)		
		SELECT DISTINCT t.FeedbackID
		FROM #tempFeedback t 
			INNER JOIN crmFeedbackCustomer fc WITH(NOLOCK)  ON t.FeedbackID=fc.FeedbackID
		WHERE fc.IsRelated = 1
		
		UPDATE #tempRelated
			SET RelatedCustomer=(SELECT list FROM dbo.f_GetRelatedCustomer(FeedbackID))
		
		SELECT DISTINCT t.*,r.RelatedCustomer
		FROM #tempFeedback t 		
			LEFT JOIN #tempRelated r ON t.FeedbackID=r.FeedbackID 		
		ORDER BY t.FeedbackDate	DESC
		
		SELECT t.FeedbackID,fm.SettingID AS MainCategory,fm.SubSettingID AS SubCategory
		FROM #tempFeedback t
			INNER JOIN crmFeedbackSetting fm WITH(NOLOCK) ON t.FeedbackID=fm.FeedbackID
			INNER JOIN crmMainCategory mc WITH(NOLOCK) ON fm.SettingID=mc.MainCategoryID	
		
	END
END;

GO 

 GRANT EXECUTE ON dbo.Acc_CRM_Rpt_FeedbackStatisticDetails TO bodbAdminNet;
GO 
