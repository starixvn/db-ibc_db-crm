/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet,vnteam" viewers="vnteam" isFunction="0"></info>*/

ALTER PROCEDURE	[dbo].[Acc_CRM_Rpt_FeedbackStatisticDetails] (
					@Type			INT
				,	@MainCategoryID	INT
				,	@SubCategoryID	INT
				,	@ValueID		INT
				,	@FromDate		DATETIME
				,	@ToDate			DATETIME
				,	@FromDuration	VARCHAR(100)
				,	@ToDuration		VARCHAR(100)
				)
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
*/
BEGIN
	SET NOCOUNT ON;

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
		RelatedCustomer			NVARCHAR(200)
	)
	CREATE TABLE #tempFeedbackCategory
	(
		FeedbackID				INT, 
		MainCategory			INT,
		SubCategory				INT
		PRIMARY KEY(FeedbackID,MainCategory,SubCategory)
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
				SELECT 			
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
					(@ValueID=0 OR fb.CreatorID = @ValueID)
					AND		
					fbc.IsRelated = 0	
					AND 
					statusID <> 11004
					AND 
					DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
					AND
					DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration
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
				SELECT 			
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
					AND (@ValueID=0 OR fb.CountryID = @ValueID)		
					AND
					fbc.IsRelated = 0
					AND 
					statusID <> 11004
					AND 
					DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
					AND
					DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration
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
				SELECT 			
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
					(@ValueID=0 OR fb.RoleID = @ValueID)
					AND		
					fbc.IsRelated = 0
					AND 
					statusID <> 11004
					AND 
					DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
					AND
					DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration

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
				SELECT 			
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
					(@ValueID=0 OR fb.SiteID = @ValueID)
					AND		
					fbc.IsRelated = 0
					AND 
					statusID <> 11004
					AND 
					DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
					AND
					DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration			
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
				SELECT 			
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
					(@ValueID=0 OR fb.StatusID = @ValueID)
					AND		
					fbc.IsRelated = 0	
					AND 
					statusID <> 11004	
					AND 
					DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
					AND
					DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration			
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
				SELECT 			
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
					statusID <> 11004	
					AND
					fb.ResponseID = @ValueID
					AND		
					fbc.IsRelated = 0					
					AND 
					DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
					AND
					DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration			
	END;
	ELSE IF @Type = 7 AND (@ValueID=0)   --- Product
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
					statusID <> 11004		
					AND 
					DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
					AND
					DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration			
	END;
	ELSE IF @Type = 7 AND (@ValueID<>0)   --- Product
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
						INNER JOIN dbo.f_GetFeedbackSetting(0,@ValueID,0,1) fm ON fb.FeedbackID=fm.FeedbackID	
				WHERE					
					fb.FeedbackDate BETWEEN @FromDate AND @ToDate
					AND
					fbc.IsRelated = 0
					AND 
					statusID <> 11004		
					AND 
					DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
					AND
					DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration			
	END;
	ELSE IF @Type = 8 AND (@ValueID=0)   --- Category
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
					statusID <> 11004	
					AND 
					DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
					AND
					DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration			
	END;
	ELSE IF @Type = 8 AND (@ValueID<>0)   --- Category
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
						INNER JOIN dbo.f_GetFeedbackSetting(0,@ValueID,0,1) fm ON fb.FeedbackID=fm.FeedbackID	
				WHERE					
					fb.FeedbackDate BETWEEN @FromDate AND @ToDate	
					AND 
					fbc.IsRelated = 0
					AND 
					statusID <> 11004	
					AND 
					DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
					AND
					DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration			
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
					(@ValueID=0 OR fb.siteID = @ValueID)
					AND		
					fbc.IsRelated = 0
					AND 
					statusID <> 11004		
					AND 
					DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
					AND
					DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration		

	END;
	ELSE IF @Type = 10 AND @ValueID<>0   --- communication
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
						INNER JOIN dbo.f_GetFeedbackSetting(0,@ValueID,0,1) fm ON fb.FeedbackID=fm.FeedbackID	
				WHERE					
					fb.FeedbackDate BETWEEN @FromDate AND @ToDate	
					AND		
					fbc.IsRelated = 0
					AND 
					statusID <> 11004		
					AND 
					DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
					AND
					DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration
	END			
	ELSE IF @Type = 10 AND (@ValueID=0)   --- communication
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
					statusID <> 11004		
					AND 
					DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
					AND
					DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration		
	END; 
	
	
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
		
		INSERT INTO #tempFeedbackCategory 
			(
				FeedbackID,MainCategory,SubCategory
			)					
		SELECT t.FeedbackID,fm.SettingID ,fm.SubSettingID	
		FROM #tempFeedback t
			INNER JOIN dbo.f_GetFeedbackSetting(0,@MainCategoryID,@SubCategoryID,2) fm ON t.FeedbackID=fm.FeedbackID	
				
		SELECT t.*,r.RelatedCustomer
		FROM #tempFeedback t		
		INNER JOIN #tempFeedbackCategory c ON t.FeedbackID=c.FeedbackID
			LEFT JOIN #tempRelated r ON t.FeedbackID=r.FeedbackID 	
		ORDER BY t.FeedbackDate	
		
		SELECT * FROM #tempFeedbackCategory	
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
		
		SELECT t.*,r.RelatedCustomer
		FROM #tempFeedback t 
			LEFT JOIN #tempRelated r ON t.FeedbackID=r.FeedbackID 		
		ORDER BY t.FeedbackDate	
		
		SELECT t.FeedbackID,fm.SettingID AS MainCategory,fm.SubSettingID AS SubCategory
		FROM #tempFeedback t
			INNER JOIN crmFeedbackSetting fm WITH(NOLOCK) ON t.FeedbackID=fm.FeedbackID
			INNER JOIN crmMainCategory mc WITH(NOLOCK) ON fm.SettingID=mc.MainCategoryID	
	END
END;

GO 

 GRANT EXECUTE ON dbo.Acc_CRM_Rpt_FeedbackStatisticDetails TO bodbAdminNet;
GO 
 GRANT VIEW DEFINITION ON dbo.Acc_CRM_Rpt_FeedbackStatisticDetails TO vnteam;
GO 
