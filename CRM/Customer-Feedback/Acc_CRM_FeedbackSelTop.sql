/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE [dbo].[Acc_CRM_FeedbackSelTop] (
					@top          INT = 10,
					@UserRole     TINYINT,
                    @LicenseeType TINYINT = 0,
                    @SiteLabel    VARCHAR(MAX) = NULL
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
        - @SiteLabel: Value depend on user's permission and maybe NULL
*/

BEGIN

	SET NOCOUNT ON

    -- #tmpSiteLabel
    CREATE TABLE #tmpSiteLabel (SiteLabel VARCHAR(50))

    INSERT INTO #tmpSiteLabel (SiteLabel)
    SELECT value SiteLabel
    FROM STRING_SPLIT(@SiteLabel, ',')

    -- #tmpSite
    CREATE TABLE #tmpSite (
        SiteID     INT,
        SiteName   NVARCHAR(100),
        SiteLabel  VARCHAR(50),
        IsLicensee INT
    )

    IF (@UserRole = 2)
    BEGIN
        INSERT INTO #tmpSite (
            SiteID,
            SiteName,
            SiteLabel,
            IsLicensee
        )
        SELECT s.SettingID SiteID,
               s.SettingValue SiteName,
               s.ExtraInfo SiteLabel,
               CASE WHEN sr.ParentID = 33000 THEN 1
                    WHEN sr.ParentID = 33001 THEN 0
                    ELSE -1 END IsLicensee
        FROM bodb_CRM.dbo.crmSettingRelation sr WITH (NOLOCK)
             INNER JOIN	bodb_CRM.dbo.crmSetting s WITH(NOLOCK) ON sr.SettingID = s.SettingID AND s.SettingName = 'Site'
        WHERE sr.ParentID IN (33000, 33001)
    END
    ELSE IF (@UserRole = 1)
	BEGIN
        INSERT INTO #tmpSite (
            SiteID,
            SiteName,
            SiteLabel,
            IsLicensee
        )
        SELECT s.SettingID SiteID,
               s.SettingValue SiteName,
               s.ExtraInfo SiteLabel,
               0 IsLicensee
        FROM bodb_CRM.dbo.crmSetting s WITH (NOLOCK)
		WHERE s.SettingID = 33002
    END

    CREATE CLUSTERED INDEX CIX_tmpSite ON #tmpSite(SiteID)

    -- #tmpFeedbackIDList
    CREATE TABLE #tmpFeedbackIDList (FeedbackID INT)

    INSERT INTO #tmpFeedbackIDList (FeedbackID)
	SELECT TOP (@top) fb.FeedbackID
	FROM bodb_CRM.dbo.crmFeedbackCustomer fbc WITH (NOLOCK)
		INNER JOIN bodb_CRM.dbo.crmFeedback fb WITH (NOLOCK) ON	fb.FeedbackID = fbc.FeedbackID
        LEFT JOIN #tmpSite s ON fb.SiteID = s.SiteID
        LEFT JOIN #tmpSiteLabel sl ON s.SiteLabel = sl.SiteLabel
	WHERE fb.StatusID NOT IN( 11004,11019)
		AND	fbc.IsRelated = 0	
		AND ((@UserRole=1 AND fb.SiteID=33002) OR (@UserRole=2 AND fb.SiteID<>33002))
        AND (s.IsLicensee IS NULL
             OR s.IsLicensee = CASE WHEN @LicenseeType = 0 THEN s.IsLicensee WHEN @LicenseeType = 1 THEN 0 ELSE 1 END)
        AND (ISNULL(s.SiteLabel, '') = CASE WHEN @LicenseeType = 0 THEN CASE WHEN s.IsLicensee = 0 THEN sl.SiteLabel ELSE ISNULL(s.SiteLabel, '') END
                                            WHEN @LicenseeType = 1 THEN sl.SiteLabel
                                            WHEN @LicenseeType = 2 THEN ISNULL(s.SiteLabel, '') END)
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
    DROP TABLE #tmpSiteLabel
    DROP TABLE #tmpSite
    DROP TABLE #tmpFeedbackIDList
END;
GO

GRANT EXECUTE ON dbo.Acc_CRM_FeedbackSelTop TO bodbAdminNet;
GO