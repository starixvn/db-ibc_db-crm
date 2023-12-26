/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE [dbo].[Acc_CRM_FeedbackSelTop] (
					@top            INT           = 10,
					@UserRole       TINYINT       = 2,
                    @LicenseeType   TINYINT       = 0,
                    @SitePermission NVARCHAR(MAX) = NULL
				)
AS

/*
	Created:	Kevin
	Date:		20110722
	Task :		get top 10 feedback info
	DB:			DB06.bodb_CRM
	Original:

	Revisions:
		- 20160308@Billy:	Integrate Sub-Product field - [Redmine: #52998]
		- 20180117@Winnie:	Add Is Related Customer - [Redmine: #88774]
		- 20171225@Winnie: Change for support multiple product/categories. [RedmineID: #84714]
		- 20190506@Winnie:  CN88 Permission RedmineID: #112637
        - 20230823@Ned.Le: CRM - Security improvement - Separate accessible data for Credit and Licensee Users (#192556)
        - 20231128@Ned.Le: CRM - Security improvement - Separate accessible data for Credit Sites (#197343)

	Param's Explanation:
        - @LicenseeType = 0: Both
                          1: Credit
                          2: Licensee
        - @SitePermission: Value depend on user's permission and maybe NULL
*/

BEGIN

	SET NOCOUNT ON

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
    FROM bodb_CRM.dbo.crmSetting sc
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

    -- #tmpFeedbackIDList
    CREATE TABLE #tmpFeedbackIDList (FeedbackID INT)

    INSERT INTO #tmpFeedbackIDList (FeedbackID)
	SELECT TOP (@top) fb.FeedbackID
	FROM bodb_CRM.dbo.crmFeedbackCustomer fbc WITH (NOLOCK)
		INNER JOIN bodb_CRM.dbo.crmFeedback fb WITH (NOLOCK) ON	fb.FeedbackID = fbc.FeedbackID
        LEFT JOIN #tmpSite si ON fb.SiteID = si.SiteID
        LEFT JOIN #tmpSitePermission sp ON si.SiteID = sp.SiteID
        LEFT JOIN #tmpUserSitePermission usp ON sp.SitePermission = sp.SitePermission
	WHERE fb.StatusID NOT IN( 11004,11019)
		AND	fbc.IsRelated = 0	
		AND si.SiteOffer = @UserRole
        AND (si.IsLicensee IS NULL
             OR si.IsLicensee = CASE WHEN @LicenseeType = 0 THEN si.IsLicensee WHEN @LicenseeType = 1 THEN 0 ELSE 1 END)
        AND (ISNULL(sp.SitePermission, '') = CASE WHEN @LicenseeType = 0 THEN CASE WHEN si.IsLicensee = 0 THEN usp.SitePermission ELSE ISNULL(sp.SitePermission, '') END
                                                  WHEN @LicenseeType = 1 THEN usp.SitePermission
                                                  WHEN @LicenseeType = 2 THEN ISNULL(sp.SitePermission, '') END)
	ORDER BY fb.FeedbackDate DESC

    -- Get data to return
	;WITH CTE AS (
		SELECT	fb.FeedbackID
		,	fb.CustID
		,	ctm.UserName
		,	fb.TitleID
		,	fb.FirstName
		,	fb.LastName
		,	fb.Phone
		,	fb.MobilePhone
		,	fb.Fax
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
		,	CAST(fb.Description AS XML) AS Description
		,	fb.Solution
		,	fb.IsReviewed
		,	fb.Review
		,	fb.ReviewerID
		,	rv.username AS ReviewerName
		,	0 AS IsRelated
		,	fb.Subject
		,	l.list AS relatedCustomer
		,   fb.ProvinceID
	FROM #tmpFeedbackIDList t
		INNER JOIN crmFeedback fb WITH (NOLOCK) ON fb.FeedbackID = t.FeedbackID
		INNER JOIN crmCustomer ctm WITH (NOLOCK) ON ctm.CustID = fb.CustID	
		LEFT JOIN bodb02.dbo.custInfo rv WITH (NOLOCK) ON	fb.ReviewerID = rv.custid 
		INNER JOIN	bodb02.dbo.custInfo c WITH (NOLOCK) ON	fb.CreatorID = c.custid
		CROSS APPLY	dbo.f_GetRelatedCustomer(fb.FeedbackID) l
	) 
	SELECT	fb.FeedbackID
		,	fb.CustID
		,	fb.UserName
		,	fb.TitleID
		,	fb.FirstName
		,	fb.LastName
		,	fb.Phone
		,	fb.MobilePhone
		,	fb.Fax
		,	fb.Email
		,	fb.Skype
		,	fb.MSN
		,	fb.LanguageID
		,	fb.CountryID
		,	fb.CreatorID
		,	fb.CreatorName
		,	fb.FeedbackDate
		,	fb.ResolutionDate
		,	fb.CreateDate
		,	fb.SolveDate					
		,	fb.SiteID
		,	fb.RoleID						
		,	fb.ResponseID
		,	fb.StatusID						
		,	fb.Solution
		,	fb.IsReviewed
		,	fb.Review
		,	fb.ReviewerID
		,	fb.ReviewerName
		,	fb.IsRelated
		,	fb.Subject
		,	fb.relatedCustomer
		,	nr.value(N'@Remark',N'nvarchar(max)') AS Description
		,	nr.value(N'@AutoField',N'nvarchar(max)') AS AutoField
		,   fb.ProvinceID
	FROM CTE fb
		OUTER APPLY fb.Description.nodes(N'//row') AS A(nr)
	
	SELECT fs.FeedbackID,fs.SettingID,fs.SubSettingID,fs.SubSettingIDLevel3,
	CASE	WHEN m.MainCategoryID	IS NOT NULL THEN 'Category' 
			WHEN s.StationID		IS NOT NULL THEN 'Station' 
			WHEN p.SettingID		IS NOT NULL THEN 'Product' 
			WHEN c.SettingID		IS NOT NULL THEN 'Communication' 
			END AS SettingType
	FROM #tmpFeedbackIDList fp
		INNER JOIN crmFeedbackSetting fs WITH(NOLOCK) 
			ON fs.FeedbackID=fp.FeedbackID	
		LEFT JOIN crmMainCategory m 
			ON fs.SettingID=m.MainCategoryID
		LEFT JOIN crmStation s 
			ON fs.SettingID=s.StationID
		LEFT JOIN crmSetting p
			ON fs.SettingID=p.SettingID AND p.SettingName='Product'
		LEFT JOIN crmSetting c
			ON fs.SettingID=c.SettingID AND c.SettingName='Communication'

    -- DROP temp tables
    DROP TABLE #tmpUserSitePermission
    DROP TABLE #tmpSite
    DROP TABLE #tmpSitePermission
    DROP TABLE #tmpFeedbackIDList
END;
GO

GRANT EXECUTE ON dbo.Acc_CRM_FeedbackSelTop TO bodbAdminNet;
GO