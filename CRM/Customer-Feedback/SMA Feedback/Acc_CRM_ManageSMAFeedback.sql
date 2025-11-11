/*<info serverAlias="DBBOT-bodb_Chatbot" executers="wsv_nap" viewers="" isFunction="0"></info>*/

USE bodb_ChatBot
GO

CREATE PROCEDURE [dbo].[Acc_CRM_ManageSMAFeedback] (
		@UserName				VARCHAR(30)		= NULL
	,	@FromDate				DATETIME        = NULL
	,	@ToDate					DATETIME        = NULL
	,	@ListReviewStatusIDs	VARCHAR(MAX)	= NULL
	,	@TestOnly				BIT				= NULL
	--- permission control ---
	,	@UserRole				TINYINT         = 2
	,   @SitePermission			XML				= NULL
	--- paging ---
	,	@PageIndex				INT				= 1
	,	@ItemsPerPage			INT				= 100
	,	@ListRate				VARCHAR(50)		= NULL
	,	@IsGetAllFBs			BIT				= 0
	,	@TotalRows				INT				= 0 OUTPUT
)
AS
/*
	Created: 20250310@Virgil
	Task: CRM - Manage SMA Feedback in effective way [Redmine #196012]
	DB: DBBOT-bodb_Chatbot

	Revisions:
		20250310@Virgil: Initial SP [Redmine #196012]
		20250807@Dave: CRM - Manage SMA Feedback in effective way - Add Rating [Redmine #235385]
		20251010@Helios: Upgrade ExchangeID DataType [Redmine:#242140]
    Param's Explanation:
        - @UserRole = 0: Manager 
                      1: CN88 staff
                      2: Company staff
        - @LicenseeType = -1: None
                           0: Both
                           1: Credit
                           2: Licensee
        - @SitePermission: Value depend on user's permission and maybe NULL
		- @IsGetAllFBs: 1 - Display all feedback:
								regardless of whether the comment is blank. 
								And no need to check for duplicate entries.
		- @ListRate: Comma separated list of rating values to filter feedback (e.g. '1,2,3,4,5').
				NULL = All ratings (no filter by rate).
				Values:
					0 = N/A
					1 = Very Poor
					2 = Poor
					3 = Neutral
					4 = Good
					5 = Excellent
*/

BEGIN		
	SET NOCOUNT ON;

    -- Declare variables
	DECLARE	@TotalPages		INT;

	CREATE TABLE #Feedback(
		[CustID]			INT,
		[UserName]			NVARCHAR(50),
		[Level]				VARCHAR(10),
		[Site]				NVARCHAR(100),
		[currency]			SMALLINT,
		[Comment]			NVARCHAR(4000),
		[FuncID]			INT,
		[FuncName]			NVARCHAR(50),
		[CreatedDate]		SMALLDATETIME,
		[ReviewStatusID]	VARCHAR(50),
		[Discussion]		NVARCHAR(4000),
		[RowNum]			SMALLINT,
		[Rate]				TINYINT
	);

    -- #listSitePermission
    CREATE TABLE #listSitePermission (
        SiteID     INT,
        SiteName   NVARCHAR(100),
        IsLicensee INT,
        IsActive   BIT,
        SiteLabel  VARCHAR(50),
        SiteOffer  INT
    )

    INSERT INTO #listSitePermission (
        SiteID,
        SiteName,
        IsLicensee,
        IsActive,
        SiteLabel,
        SiteOffer
    )
    SELECT
		t.c.value('@SiteID',	'INT')			AS SiteID,
        t.c.value('@SiteName',	'NVARCHAR(100)')AS SiteName,
        t.c.value('@IsLicensee','BIT')			AS IsLicensee,
        t.c.value('@IsActive',	'BIT')			AS IsActive,
        t.c.value('@SiteLabel',	'VARCHAR(50)')	AS SiteLabel,
        t.c.value('@SiteOffer',	'INT') AS SiteOffer
	FROM @SitePermission.nodes('ROOT/r') t(c)
    OPTION (OPTIMIZE FOR (@SitePermission = NULL))

	--- get feedback for specific customer
	IF @UserName IS NOT NULL AND @UserName <> ''
	BEGIN
		CREATE TABLE #tmpCustList (CustID INT PRIMARY KEY)
		
		INSERT INTO #tmpCustList (CustID)
		SELECT	CustID
		FROM	bodb02.dbo.Customer WITH (NOLOCK)
		WHERE	UserName LIKE @UserName + '%'
			AND	CustID > 0;		
		
		INSERT INTO #Feedback([CustID], [UserName], [Level], [Site], [currency], [Comment], [FuncID], [FuncName], [CreatedDate], [ReviewStatusID], [Discussion], [Rate], [RowNum])
		SELECT 
				ci.custid	AS [CustID],
				ci.username AS [UserName],
				CASE
					WHEN ci.roleid = 4 THEN 'Super'
					WHEN ci.roleid = 3 THEN 'Master'
					WHEN ci.roleid = 2 THEN 'Agent'
					ELSE 'Others'
				END	AS [Level],
				ci.site		AS [Site],
				ci.currency	AS [currency],
				fb.comment	AS [Comment],
				fb.FuncId,
				CASE 
					WHEN fb.FuncID IS NULL THEN 'N/A' 
					ELSE fc.FuncNameEN 
				END	AS [FuncName],
				fb.createddate		AS [CreatedDate],
				fb.ReviewStatusID	AS [ReviewStatusID],
				fb.Discussion		AS [Discussion],
				fb.Rate				AS [Rate],
				CASE WHEN @IsGetAllFBs = 0
					THEN ROW_NUMBER() OVER (PARTITION BY fb.comment, ci.username, fb.FuncID ORDER BY fb.createddate DESC)
					ELSE 1
				END AS RowNum
		FROM CustFeedback fb WITH (NOLOCK)
			INNER JOIN bodb02.dbo.Customer ci with (Nolock) ON ci.CustID = fb.CustID
			LEFT JOIN Age_FeedbackFunc fc with (Nolock) on fb.FuncID = fc.FuncID
            INNER JOIN #listSitePermission si ON ci.site = si.SiteName
		WHERE fb.CustID IN (SELECT CustID FROM #tmpCustList)
			AND (@IsGetAllFBs = 1 OR LEN(TRIM(fb.Comment)) > 0)
			AND (fb.FuncID NOT IN (12) OR fb.FuncID IS NULL)
			AND	fb.CreatedDate BETWEEN @FromDate AND @ToDate
			AND (@ListReviewStatusIDs IS NULL OR fb.ReviewStatusID IN (SELECT value FROM STRING_SPLIT(@ListReviewStatusIDs,',')))
		    AND (si.SiteOffer = @UserRole OR si.SiteOffer IS NULL)
			AND (@ListRate IS NULL OR fb.Rate IN (SELECT CAST(value AS TINYINT) FROM STRING_SPLIT(@ListRate,',')))
		ORDER BY fb.CreatedDate DESC;
		
		DROP TABLE #tmpCustList;
	END;
    -- Get list of Feedback
	ELSE  
	BEGIN	

		INSERT INTO #Feedback([CustID], [UserName], [Level], [Site], [currency], [Comment], [FuncID], [FuncName], [CreatedDate], [ReviewStatusID], [Discussion], [Rate], [RowNum])
		SELECT 
				ci.custid	AS [CustId],
				ci.username AS [UserName],
				CASE
					WHEN ci.roleid = 4 THEN 'Super'
					WHEN ci.roleid = 3 THEN 'Master'
					WHEN ci.roleid = 2 THEN 'Agent'
					ELSE 'Others'
				END	AS [Level],
				ci.site		AS [Site],
				ci.currency	AS [currency],
				fb.comment	AS [Comment],
				fb.FuncId,
				CASE 
					WHEN fb.FuncID IS NULL THEN 'N/A' 
					ELSE fc.FuncNameEN 
				END	AS [FuncName],
				fb.createddate		AS [CreatedDate],
				fb.ReviewStatusID	AS [ReviewStatusID],
				fb.Discussion		AS [Discussion],
				fb.Rate				AS [Rate],
				CASE WHEN @IsGetAllFBs = 0
					THEN ROW_NUMBER() OVER (PARTITION BY fb.comment, ci.username, fb.FuncID ORDER BY fb.createddate DESC)
					ELSE 1
				END AS RowNum
		FROM CustFeedback fb WITH (NOLOCK)
			INNER JOIN bodb02.dbo.Customer ci with (Nolock) ON ci.CustID = fb.CustID
			LEFT JOIN Age_FeedbackFunc fc with (Nolock) on fb.FuncID = fc.FuncID
            INNER JOIN #listSitePermission si ON ci.site = si.SiteName
		WHERE fb.CreatedDate BETWEEN @FromDate AND @ToDate
			AND (@IsGetAllFBs = 1 OR LEN(TRIM(fb.Comment)) > 0)
			AND (fb.FuncID NOT IN (12) OR fb.FuncID IS NULL)
			AND (@ListReviewStatusIDs IS NULL OR fb.ReviewStatusID IN (SELECT value FROM STRING_SPLIT(@ListReviewStatusIDs,',')))
			AND (si.SiteOffer = @UserRole OR si.SiteOffer IS NULL)
			AND (@ListRate IS NULL OR fb.Rate IN (SELECT CAST(value AS TINYINT) FROM STRING_SPLIT(@ListRate,',')))

	END;

	-- Filter by @TestOnly
	IF @TestOnly IS NOT NULL
	BEGIN
		DELETE i
		FROM #Feedback AS i
		WHERE (@TestOnly = 0 AND i.currency = 20)	--@TestOnly = 0 => Keep Real, DELETE currency = 20
			OR (@TestOnly = 1 AND i.currency != 20)	--@TestOnly = 1 => Keep Test, DELETE currency != 20

	END

	SET @TotalRows = ISNULL((SELECT	COUNT(1) AS total FROM #Feedback WHERE RowNum = 1), 0);
	
	SELECT [CustID],
			[UserName],
			[Level],
			[Site],
			[Comment],
			[FuncID],
			[FuncName],
			[CreatedDate],
			[ReviewStatusID],
			ISNULL([Discussion],'') AS [Discussion],
			[Rate],
			CASE [Rate]
				WHEN 0 THEN 'N/A'
				WHEN 1 THEN 'Very Poor'
				WHEN 2 THEN 'Poor'
				WHEN 3 THEN 'Neutral'
				WHEN 4 THEN 'Good'
				WHEN 5 THEN 'Excellent'
			END AS [RateInfo]
	FROM #Feedback fb
	WHERE RowNum = 1
	ORDER BY fb.CreatedDate DESC
	OFFSET (@PageIndex-1)*@ItemsPerPage ROWS 
	FETCH NEXT @ItemsPerPage ROWS ONLY


    -- DROP temp tables	
	DROP TABLE #Feedback
    DROP TABLE #listSitePermission

	
END
GO