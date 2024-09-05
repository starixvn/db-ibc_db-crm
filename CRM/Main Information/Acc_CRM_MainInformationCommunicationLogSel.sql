/*<info serverAlias="DBCRM-bodb_CRM" executers="wsv_nap" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE dbo.Acc_CRM_MainInformationCommunicationLogSel @CustID         INT,
                                                               @UserRole       TINYINT       = 2,
                                                               @LicenseeType   INT           = 0,
                                                               @SitePermission NVARCHAR(MAX) = NULL
AS

/*
    Created: Dom
    Date: 20140212
    Task : Get data for main tab
    DB: DBCRM.bodb_CRM

    Revisions:
        - 20171225@Winnie:  Change for support multiple product/categories. [RedmineID: #84714]
        - 20190506@Winnie: CN88 Permission RedmineID: #112637
        - 20230929@Ned.Le: Fix bug that return not correct the total row
        - 20231128@Ned.Le: CRM - Security improvement - Separate accessible data for Credit Sites (#197343)
        - 20240829@Ned.Le: CRM - When clicking Latest Feedback not found the feedback Due to permission limitations for account P5S (#210055)

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

    -- Variables
	SELECT @CustID=b.CustID
	FROM  crmCustomer b WITH(NOLOCK) 
	WHERE b.CustID = @CustID
		AND((@UserRole=1 AND b.SiteID=33002) OR(@UserRole=2 AND b.SiteID<>33002))

    DECLARE @totalreturn  INT = 10

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

    -- #FeedbackBuffer
	CREATE TABLE #FeedbackBuffer (FeedbackID INT)

	INSERT INTO #FeedbackBuffer (FeedbackID)
	SELECT DISTINCT TOP (@totalreturn) f.FeedbackID	
	FROM crmFeedback f WITH(NOLOCK)
         LEFT JOIN #tmpSite si ON f.SiteID = si.SiteID
         LEFT JOIN #tmpSitePermission sp ON si.SiteID = sp.SiteID
         LEFT JOIN #tmpUserSitePermission usp ON sp.SitePermission = usp.SitePermission
	WHERE f.custid = @CustID
		AND f.StatusID <> 11004 -- exclude deleted
		AND f.StatusID <> 11019 -- exclude deleted
        AND (si.SiteOffer = @UserRole OR si.SiteOffer IS NULL)
        AND @LicenseeType <> -1
        AND (si.IsLicensee IS NULL
             OR si.IsLicensee = CASE WHEN @LicenseeType = 0 THEN si.IsLicensee WHEN @LicenseeType = 1 THEN 0 ELSE 1 END)
        AND ((sp.SitePermission IS NULL AND ISNULL(si.IsLicensee, 1) = 1)
             OR sp.SitePermission = usp.SitePermission)
	ORDER BY f.FeedbackID DESC

    INSERT INTO #FeedbackBuffer (FeedbackID)
    SELECT DISTINCT TOP (@totalreturn) f.FeedbackID
    FROM crmFeedback f WITH (NOLOCK)
         INNER JOIN crmFeedbackCustomer cf WITH(NOLOCK) ON cf.FeedbackID = f.FeedbackID
         LEFT JOIN #tmpSite si ON f.SiteID = si.SiteID
         LEFT JOIN #tmpSitePermission sp ON si.SiteID = sp.SiteID
         LEFT JOIN #tmpUserSitePermission usp ON sp.SitePermission = usp.SitePermission
	WHERE cf.CustID = @CustID
          AND cf.IsRelated = 1
          AND f.StatusID <> 11004 -- exclude deleted
          AND f.StatusID <> 11019 -- exclude deleted
		  AND (si.SiteOffer = @UserRole OR si.SiteOffer IS NULL)
          AND @LicenseeType <> -1
          AND (si.IsLicensee IS NULL
               OR si.IsLicensee = CASE WHEN @LicenseeType = 0 THEN si.IsLicensee WHEN @LicenseeType = 1 THEN 0 ELSE 1 END)
          AND ((sp.SitePermission IS NULL AND ISNULL(si.IsLicensee, 1) = 1)
               OR sp.SitePermission = usp.SitePermission)
	ORDER BY f.FeedbackID DESC

    -- #FeedbackFinal
    CREATE TABLE #FeedbackFinal (FeedbackID INT)

    INSERT INTO #FeedbackFinal (FeedbackID)
    SELECT TOP(@totalreturn) FeedbackID
    FROM #FeedbackBuffer
    ORDER BY FeedbackID DESC

    -- Return result
	SELECT f.FeedbackID,
	FeedbackDate,
	f.Subject,
	st.Name Status,
	cast(datepart(hour,ResolutionDate - FeedbackDate) as varchar) + ' : ' +cast(datepart(MINUTE,ResolutionDate - FeedbackDate) as varchar) + ' : ' +cast(datepart(second,ResolutionDate - FeedbackDate) as varchar) Duration,
	Creator.username HandleBy,
	Reviewer.username ReviewBy
	FROM crmFeedback f WITH (NOLOCK)
		INNER JOIN #FeedbackFinal tmp ON tmp.FeedbackID = f.FeedbackID
		INNER JOIN crmStatus(NOLOCK) st ON st.StatusID = f.StatusID
		INNER JOIN bodb02.dbo.Customer(NOLOCK) Creator ON Creator.custid = f.CreatorID
		LEFT JOIN bodb02.dbo.Customer(NOLOCK) Reviewer ON Reviewer.custid = f.ReviewerID
	ORDER BY f.FeedbackID DESC

	SELECT fs.FeedbackID,fs.SettingID,fs.SubSettingID,fs.SubSettingIDLevel3, 'Category' AS SettingType
	FROM #FeedbackFinal fp
		INNER JOIN crmFeedbackSetting fs WITH(NOLOCK) ON fs.FeedbackID=fp.FeedbackID	
		INNER JOIN crmMainCategory m WITH(NOLOCK) ON fs.SettingID=m.MainCategoryID
	ORDER BY fp.FeedbackID DESC

    -- Drop temp tables
    DROP TABLE #tmpUserSitePermission
    DROP TABLE #tmpSite
    DROP TABLE #tmpSitePermission
    DROP TABLE #FeedbackBuffer
    DROP TABLE #FeedbackFinal

END
GO