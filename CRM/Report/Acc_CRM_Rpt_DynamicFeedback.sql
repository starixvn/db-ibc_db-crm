/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE [dbo].[Acc_CRM_Rpt_DynamicFeedback]
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
				,	@Userrole			TINYINT			= 2
                ,   @LicenseeType       TINYINT         = 0
                ,   @SitePermission     NVARCHAR(MAX)   = NULL
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
		- 20190506@Winnie:  CN88 Permission RedmineID: #112637        
        - 20230427@Ned.Le: Database - HA DB061/DB062 (#169643)
        - 20231128@Ned.Le: CRM - Security improvement - Separate accessible data for Credit Sites (#197343)

	Param's Explanation:
        - @LicenseeType = 0: Both
                          1: Credit
                          2: Licensee
        - @SitePermission: Value depend on user's permission and maybe NULL
*/

BEGIN

	SET NOCOUNT ON

    SELECT	@Subject = REPLACE(@Subject, '[', '%');
    SELECT	@Subject = REPLACE(@Subject,']','%');

    DECLARE	@HandledID		INT
	    ,	@ReviewedID		INT;

    SELECT	@HandledID = CustID 
    FROM	bodb02.dbo.Customer WITH (NOLOCK)
    WHERE	UserName = @HandledBy;

    SELECT	@ReviewedID = CustID
    FROM	bodb02.dbo.Customer WITH (NOLOCK)
    WHERE	UserName = @ReviewedBy;


    -- #tmpUserSitePermission
    CREATE TABLE #tmpUserSitePermission (SitePermission NVARCHAR(100))

    INSERT INTO #tmpUserSitePermission (SitePermission)
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

    CREATE CLUSTERED INDEX CIX_tmpSite ON #tmpSite(SiteID)

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

    CREATE CLUSTERED INDEX CIX_tmpSitePermission ON #tmpSitePermission(SiteID)

    -- #Feedback
    CREATE TABLE	#Feedback (FeedbackID		INT PRIMARY KEY);
    CREATE TABLE	#Feedbackm (FeedbackID		INT PRIMARY KEY);
    CREATE TABLE	#Feedbackp (FeedbackID		INT PRIMARY KEY);
    CREATE TABLE	#Feedbackc (FeedbackID		INT PRIMARY KEY);
    CREATE TABLE	#Feedbacks (FeedbackID		INT PRIMARY KEY);

    INSERT INTO #Feedback
    SELECT DISTINCT	f.FeedbackID
    FROM		crmFeedback f WITH (NOLOCK)
                LEFT JOIN #tmpSite si ON f.SiteID = si.SiteID
                LEFT JOIN #tmpSitePermission sp ON si.SiteID = sp.SiteID
                LEFT JOIN #tmpUserSitePermission usp ON sp.SitePermission = sp.SitePermission
    WHERE	FeedbackDate BETWEEN @FromDate AND @ToDate	
	    AND	(ISNULL(@StatusID, 0) = 0 OR f.StatusID = @StatusID) 
	    AND	(ISNULL(@RoleID, 0) = 0 OR f.RoleID = @RoleID) 	
	    AND	(ISNULL(@HandledBy, '') = '' OR f.CreatorID = @HandledID) 
	    AND	(ISNULL(@SiteID, -1) = -1 OR f.SiteID = @SiteID) 
	    AND	(ISNULL(@ResponseID, 0) = 0 OR f.ResponseID = @ResponseID) 	
	    AND	(ISNULL(@ReviewedBy, '') = '' OR f.ReviewerID = @ReviewedID) 
	    AND	(ISNULL(@Subject, '') = '' OR f.Subject LIKE '%' + @Subject + '%') 
	    AND	f.StatusID NOT IN( 11004,11019)
        AND (si.SiteOffer = @UserRole OR si.SiteOffer IS NULL)
        AND (si.IsLicensee IS NULL
             OR si.IsLicensee = CASE WHEN @LicenseeType = 0 THEN si.IsLicensee WHEN @LicenseeType = 1 THEN 0 ELSE 1 END)
        AND (sp.SitePermission IS NULL
             OR sp.SitePermission = usp.SitePermission)

    INSERT INTO #Feedbackm
    SELECT DISTINCT	f.FeedbackID
    FROM #Feedback f
	    INNER JOIN	crmfeedbacksetting fm WITH(NOLOCK) ON f.feedbackID=fm.feedbackID
    WHERE (ISNULL(@MainCategoryID, 0) = 0 OR fm.settingID = @MainCategoryID) 
	    AND (ISNULL(@SubCategoryID, 0) = 0 OR fm.SubsettingID = @SubCategoryID) 

    INSERT INTO #Feedbackp
    SELECT DISTINCT	f.FeedbackID
    FROM #Feedbackm f
	    INNER JOIN	crmfeedbacksetting fp WITH(NOLOCK) ON f.feedbackID=fp.feedbackID
    WHERE (ISNULL(@ProductID, 0) = 0 OR fp.settingID = @ProductID)
	    AND	(ISNULL(@SubProductID, 0) = 0 OR fp.SubsettingID = @SubProductID)

    INSERT INTO #Feedbackc
    SELECT DISTINCT	f.FeedbackID
    FROM #Feedbackp f
	    INNER JOIN	crmfeedbacksetting fc WITH(NOLOCK) ON f.feedbackID=fc.feedbackID
    WHERE (ISNULL(@CommunicationID, 0) = 0 OR fc.settingID = @CommunicationID) 

    INSERT INTO #Feedbacks
    SELECT DISTINCT	f.FeedbackID
    FROM #Feedbackc f
	    INNER JOIN	crmfeedbacksetting fs WITH(NOLOCK) ON f.feedbackID=fs.feedbackID
    WHERE (ISNULL(@Extension, 0) = 0 OR fs.settingID = @Extension ) 		

    SELECT	f.FeedbackID
	    ,	f.FeedbackDate
	    ,	CAST(DATEPART(HOUR, ResolutionDate - FeedbackDate) AS VARCHAR)
	    +	' : ' + CAST(DATEPART(MINUTE, ResolutionDate - FeedbackDate) AS VARCHAR)
	    +	' : ' + CAST(DATEPART(SECOND, ResolutionDate - FeedbackDate) AS VARCHAR) Duration
	    ,	f.Subject
	    ,	st.Name Status
	    ,	c.username HandledBy
	    ,	rv.username ReviewedBy
	    ,	cust.UserName
    FROM		crmFeedback f WITH (NOLOCK) 
    LEFT JOIN	crmStatus st WITH (NOLOCK)
		    ON	st.StatusID = f.StatusID
    INNER JOIN	bodb02.dbo.Customer c WITH (NOLOCK)
		    ON	c.custid = f.CreatorID
    LEFT JOIN	bodb02.dbo.Customer rv WITH (NOLOCK)
		    ON	rv.custid = f.ReviewerID
    INNER JOIN	crmCustomer cust WITH(NOLOCK)
		    ON	cust.CustID = f.CustID
    WHERE	f.FeedbackID IN (SELECT feedbackid FROM #Feedbacks)
	    AND ((@userrole=1 AND cust.siteID=33002)OR(@userrole=2 AND cust.siteID<>33002))
    ORDER BY f.FeedbackDate DESC, f.FeedbackID DESC;

    SELECT fs.FeedbackID,fs.SettingID AS MainCategoryID,fs.SubSettingID AS SubCategoryID
    FROM #Feedbacks fp
    INNER JOIN crmFeedbackSetting fs WITH(NOLOCK) 
	    ON fs.FeedbackID=fp.FeedbackID	
    INNER JOIN crmMainCategory m 
	    ON fs.SettingID=m.MainCategoryID
    WHERE m.siteoffer=@Userrole

    -- DROP temp table
    DROP TABLE #tmpUserSitePermission
    DROP TABLE #tmpSite
    DROP TABLE #tmpSitePermission
    DROP TABLE #Feedback
    DROP TABLE #Feedbackm
    DROP TABLE #Feedbackc
    DROP TABLE #Feedbackp
    DROP TABLE #Feedbacks

END
GO