/*<info serverAlias="DBCRM-bodb_CRM" executers="wsv_nap" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

CREATE PROCEDURE dbo.Acc_CRM_Rpt_RatingFeedbackStatistic
	@Type			INT,
	@FromDate       DATETIME,
	@ToDate         DATETIME,
	@FromDuration   VARCHAR(100),
	@ToDuration     VARCHAR(100),
	@UserRole       TINYINT       = 2,
	@LicenseeType   INT           = 0,
	@SitePermission NVARCHAR(MAX) = NULL
AS
/*
    Created: 20250321@Virgil
    DB: DBCRM-bodb_CRM
    Task: CRM - Rating for Feedback Statistics report [RedmineID: #219594]
	
	Revisions:
		- 20250321@Virgil: Initial SP [RedmineID: #219594]

	Param's Explanation:
		@Type: - 12	By Date and Rating
			   - 13	By Creator and Rating
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

    ---------------------
    -- Deal with duration

    DECLARE @tmp TABLE (ID INT IDENTITY PRIMARY KEY, val INT)
    INSERT INTO @tmp(val) SELECT CONVERT(INT, val) FROM dbo.f_split(@FromDuration,':')
    INSERT INTO @tmp(val) SELECT CONVERT(INT, val) FROM dbo.f_split(@ToDuration,':')

    DECLARE @fDuration INT,
            @tDuration INT
    SELECT @fDuration = SUM(CASE WHEN ID = 1 THEN val*24*60*60 
                                 WHEN ID = 2 THEN val*60*60 
                                 WHEN ID = 3 THEN val*60 
                                 WHEN ID = 4 THEN val
                                 ELSE 0 END),
           @tDuration = SUM(CASE WHEN ID = 5 THEN val*24*60*60 
                                 WHEN ID = 6 THEN val*60*60 
                                 WHEN ID = 7 THEN val*60 
                                 WHEN ID = 8 THEN val
                                 ELSE 0 END)
    FROM @tmp

    IF (@fDuration = 0 AND @tDuration = 0)
    BEGIN
        SET @tDuration = 2100000000
    END

    -----------------------
    -- Deal with permission

    -- #tmpUserSitePermission
    CREATE TABLE #tmpUserSitePermission (SitePermission NVARCHAR(100))
    INSERT INTO  #tmpUserSitePermission (SitePermission)
    SELECT value SitePermission
    FROM STRING_SPLIT(@SitePermission, ',')

    -- #tmpSite
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
         INNER JOIN bodb_CRM.dbo.crmSetting si WITH (NOLOCK) ON si.SettingName = 'Site' AND sr.SettingID = si.SettingID
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

    -- #tmpSitePermission
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

    ---------------
    -- Process data

	-- @Type = 12 - By Date and Rating
	IF (@Type = 12 AND @UserRole = 2)
    BEGIN

		-- Strip the time portion from @FromDate and @ToDate
		DECLARE @FromDateOnly DATE = CAST( DATEADD(HOUR, 12, @FromDate) AS DATE);
		DECLARE @ToDateOnly DATE = CAST( DATEADD(HOUR, 12, @ToDate) AS DATE);

		-- Generate a list of dates between @FromDate and @ToDate
		WITH DateRange AS (
			SELECT @FromDateOnly AS [Date]
			UNION ALL
			SELECT DATEADD(DAY, 1, [Date])
			FROM DateRange
			WHERE DATEADD(DAY, 1, [Date]) <= @ToDateOnly
		),
		FilteredFeedback AS (
			SELECT CAST(DATEADD(HOUR, 12, FeedbackDate)AS DATE) AS FeedbackDate,
					ISNULL(Rating, 0) AS Rating
			FROM crmFeedback fb WITH (NOLOCK)
					LEFT JOIN #tmpSite si ON fb.SiteID = si.SiteID
					LEFT JOIN #tmpSitePermission sp ON si.SiteID = sp.SiteID
					LEFT JOIN #tmpUserSitePermission usp ON sp.SitePermission = usp.SitePermission
			WHERE fb.FeedbackDate BETWEEN @FromDate AND @ToDate
					AND	ISNULL(fb.Rating, 0) <> 0
					AND fb.StatusID NOT IN (11001, 11004, 11019, 11016)
					AND DATEDIFF(s,FeedbackDate, ResolutionDate) >= @fDuration
					AND DATEDIFF(s,FeedbackDate, ResolutionDate) <= @tDuration
					AND (si.SiteOffer = @UserRole OR si.SiteOffer IS NULL)
					AND @LicenseeType <> -1
					AND (si.IsLicensee IS NULL
						OR si.IsLicensee = CASE WHEN @LicenseeType = 0 THEN si.IsLicensee WHEN @LicenseeType = 1 THEN 0 ELSE 1 END)
					AND ((sp.SitePermission IS NULL AND ISNULL(si.IsLicensee, 1) = 1)
						OR sp.SitePermission = usp.SitePermission)
		)
		SELECT dr.[Date],
				ISNULL(SUM(CASE WHEN ff.Rating = 5 THEN 1 ELSE 0 END), 0) AS [5 (Excellent)],
				ISNULL(SUM(CASE WHEN ff.Rating = 4 THEN 1 ELSE 0 END), 0) AS [4 (Good)],
				ISNULL(SUM(CASE WHEN ff.Rating = 3 THEN 1 ELSE 0 END), 0) AS [3 (Neutral)],
				ISNULL(SUM(CASE WHEN ff.Rating = 2 THEN 1 ELSE 0 END), 0) AS [2 (Poor)],
				ISNULL(SUM(CASE WHEN ff.Rating = 1 THEN 1 ELSE 0 END), 0) AS [1 (Very Poor)]
		FROM DateRange dr
		LEFT JOIN FilteredFeedback ff
			ON ff.FeedbackDate = dr.[Date]
		GROUP BY dr.[Date]
		ORDER BY dr.[Date]
		OPTION (MAXRECURSION 0);

    END

	-- @Type= 13 - By Creator and Rating
	IF (@Type = 13 AND @UserRole = 2)
    BEGIN
		CREATE TABLE #Result (
			CustId			INT,
			UserName		VARCHAR(30),
			[5 (Excellent)]	INT,
			[4 (Good)]		INT,
			[3 (Neutral)]	INT,
			[2 (Poor)]		INT,
			[1 (Very Poor)] INT
		)

		;WITH FeedbackData AS (
			SELECT ISNULL(fb.Rating, 0) Rating,
					c.custid	CustId,
					c.username	Username
			FROM bodb_CRM.dbo.crmFeedback fb WITH (NOLOCK) 
					LEFT JOIN bodb02.dbo.customer c WITH (NOLOCK) ON fb.CreatorID = c.CustID
					LEFT JOIN #tmpSite si ON fb.SiteID = si.SiteID
					LEFT JOIN #tmpSitePermission sp ON si.SiteID = sp.SiteID
					LEFT JOIN #tmpUserSitePermission usp ON sp.SitePermission = usp.SitePermission
			WHERE fb.FeedbackDate BETWEEN @FromDate AND @ToDate
					AND	ISNULL(fb.Rating, 0) <> 0
					AND fb.StatusID NOT IN (11001, 11004, 11019, 11016)
					AND DATEDIFF(s,FeedbackDate, ResolutionDate) >= @fDuration
					AND DATEDIFF(s,FeedbackDate, ResolutionDate) <= @tDuration
					AND (si.SiteOffer = @UserRole OR si.SiteOffer IS NULL)
					AND @LicenseeType <> -1
					AND (si.IsLicensee IS NULL
						OR si.IsLicensee = CASE WHEN @LicenseeType = 0 THEN si.IsLicensee WHEN @LicenseeType = 1 THEN 0 ELSE 1 END)
					AND ((sp.SitePermission IS NULL AND ISNULL(si.IsLicensee, 1) = 1)
						OR sp.SitePermission = usp.SitePermission)
		)
		INSERT INTO #Result ([CustId], [UserName], [5 (Excellent)], [4 (Good)], [3 (Neutral)], [2 (Poor)], [1 (Very Poor)])
		SELECT CustId, UserName, [5] AS [5 (Excellent)], [4] AS [4 (Good)], [3] AS [3 (Neutral)], [2] AS [2 (Poor)], [1] AS [1 (Very Poor)]
		FROM FeedbackData
		PIVOT (
			COUNT(Rating) 
			FOR Rating IN ([5], [4], [3], [2], [1])
		) PivotTable

		IF EXISTS (SELECT 1 FROM #Result)
		BEGIN
			SELECT [Username] AS [Creator],
					[5 (Excellent)],
					[4 (Good)],
					[3 (Neutral)],
					[2 (Poor)],
					[1 (Very Poor)]
			FROM #Result
		END
		ELSE
		BEGIN
			SELECT NULL AS [Creator],
				   NULL AS [5 (Excellent)],
				   NULL AS [4 (Good)],
				   NULL AS [3 (Neutral)],
				   NULL AS [2 (Poor)],
				   NULL AS [1 (Very Poor)]
		END

		SELECT [CustId] AS Item FROM #Result

		DROP TABLE #Result;

    END


    -------------------
    -- Drop temp tables

    DROP TABLE #tmpUserSitePermission
    DROP TABLE #tmpSite
    DROP TABLE #tmpSitePermission

END
GO