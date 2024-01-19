/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE dbo.Acc_CRM_CommunicationLogList @CustID         INT,
                                                 @FromDate       DATETIME,
                                                 @ToDate         DATETIME,
                                                 @StatusID       INT           = 0,
                                                 @Handler        VARCHAR(30)   = '',
                                                 @UserRole       TINYINT       = 2,
                                                 @LicenseeType   INT           = 0,
                                                 @SitePermission NVARCHAR(MAX) = NULL
AS

/*
	Created: Dom
	Date: 20140120
	Task : update customer basic info
	DB: DB052.bodb_CRM

    Revisions:
        - 20180529@Vicky: change the query to use index on DBACC [RedmineID: #95024]
        - 20171225@Winnie: Change for support multiple product/categories. [RedmineID: #84714]
        - 20190506@Winnie: CN88 Permission RedmineID: #112637
        - 20190905@Winnie: CRM - Left panel did not show Super, Master, Agent  [RedmineId: #119708]  
        - 20230427@Ned.Le: Database - HA DB061/DB062 (#169643)

	Param's Explanation:
        - @UserRole = 0: Manager 
                      1: CN88 staff
                      2: Company staff
        - @LicenseeType = -1: None
                           0: Both
                           1: Credit
                           2: Licensee
        - @SitePermission: Value depend on user's permission and maybe NULL
*/

BEGIN

    SET NOCOUNT ON

    DECLARE @handlerid int
    SELECT @handlerid = CustID
    FROM bodb02.dbo.Customer WITH (NOLOCK) WHERE UserName = @Handler

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

    -- #temp
	SELECT DISTINCT f.FeedbackID,
			FeedbackDate,
			f.Subject,
			st.Name Status,
			cast(datepart(hour,ResolutionDate - FeedbackDate) as varchar) + ' : ' +cast(datepart(MINUTE,ResolutionDate - FeedbackDate) as varchar) + ' : ' +cast(datepart(second,ResolutionDate - FeedbackDate) as varchar) Duration,
			Creator.username HandleBy,
			Reviewer.username ReviewBy	
	INTO #temp
	FROM crmFeedback f WITH(NOLOCK) 	
		INNER JOIN crmCustomer c WITH(NOLOCK) ON f.CustID=c.CustID	
		INNER JOIN crmStatus st WITH(NOLOCK)  ON st.StatusID = f.StatusID
		INNER JOIN bodb02.dbo.Customer Creator WITH(NOLOCK)  ON Creator.custid = f.CreatorID
		LEFT JOIN bodb02.dbo.Customer Reviewer WITH(NOLOCK)  ON Reviewer.custid = f.ReviewerID
	WHERE (f.custid = @CustID )
		AND f.StatusID <> 11004 -- exclude deleted
		AND f.StatusID <> 11019 -- exclude deleted
		AND f.CreateDate BETWEEN @fromdate and @todate 
		AND (isnull(@handler,'')='' OR f.CreatorID = @handlerid)
		AND (isnull(@StatusID,0)=0 OR f.StatusID = @StatusID)
		AND ((@UserRole=1 AND c.SiteID=33002) OR (@UserRole=2 AND ISNULL(c.SiteID,0)<>33002))
	UNION 
	SELECT DISTINCT f.FeedbackID,
			FeedbackDate,		
			f.Subject,
			st.Name Status,
			cast(datepart(hour,ResolutionDate - FeedbackDate) as varchar) + ' : ' +cast(datepart(MINUTE,ResolutionDate - FeedbackDate) as varchar) + ' : ' +cast(datepart(second,ResolutionDate - FeedbackDate) as varchar) Duration,
			Creator.username HandleBy,
			Reviewer.username ReviewBy

	FROM crmFeedback f WITH(NOLOCK) 	
		INNER JOIN crmCustomer c WITH(NOLOCK) ON f.CustID=c.CustID		
		INNER JOIN crmStatus st WITH(NOLOCK)  ON st.StatusID = f.StatusID
		INNER JOIN bodb02.dbo.Customer Creator WITH(NOLOCK)  ON Creator.custid = f.CreatorID
		LEFT JOIN bodb02.dbo.Customer Reviewer WITH(NOLOCK)  ON Reviewer.custid = f.ReviewerID
		LEFT JOIN crmFeedbackCustomer cf WITH(NOLOCK)  ON cf.FeedbackID = f.FeedbackID
        LEFT JOIN #tmpSite si ON f.SiteID = si.SiteID
        LEFT JOIN #tmpSitePermission sp ON si.SiteID = sp.SiteID
        LEFT JOIN #tmpUserSitePermission usp ON sp.SitePermission = sp.SitePermission
	WHERE cf.CustID = @CustID
		AND f.StatusID <> 11004 -- exclude deleted
		AND f.StatusID <> 11019 -- exclude deleted
		AND f.CreateDate BETWEEN @fromdate and @todate 
		AND (isnull(@handler,'')='' OR f.CreatorID = @handlerid)
		AND (isnull(@StatusID,0)=0 OR f.StatusID = @StatusID)
		AND ((@UserRole=1 AND c.SiteID=33002) OR (@UserRole=2 AND ISNULL(c.SiteID,0)<>33002))
        AND (si.SiteOffer = @UserRole OR si.SiteOffer IS NULL)
        AND @LicenseeType <> -1
        AND (si.IsLicensee IS NULL
             OR si.IsLicensee = CASE WHEN @LicenseeType = 0 THEN si.IsLicensee WHEN @LicenseeType = 1 THEN 0 ELSE 1 END)
        AND ((sp.SitePermission IS NULL AND ISNULL(si.IsLicensee, 1) = 1)
             OR sp.SitePermission = usp.SitePermission)
	ORDER BY f.FeedbackID DESC	

    -- Return data	
	SELECT * FROM #temp
	
	SELECT fs.FeedbackID,fs.SettingID AS MainCategoryID,fs.SubSettingID AS SubCategoryID
		FROM #temp fp
			INNER JOIN crmFeedbackSetting fs WITH(NOLOCK) 
				ON fs.FeedbackID=fp.FeedbackID	
			INNER JOIN crmMainCategory m 
				ON fs.SettingID=m.MainCategoryID

    -- Drop temp tables
    DROP TABLE #tmpUserSitePermission
    DROP TABLE #tmpSite
    DROP TABLE #tmpSitePermission
    DROP TABLE #temp

END
GO
