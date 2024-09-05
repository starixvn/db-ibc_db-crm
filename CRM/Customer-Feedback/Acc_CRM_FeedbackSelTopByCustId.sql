/*<info serverAlias="DBCRM-bodb_CRM" executers="wsv_nap" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE dbo.Acc_CRM_FeedbackSelTopByCustId @CustID         INT,
                                                   @top            INT           = 10,
                                                   @UserRole       TINYINT       = 2,
                                                   @LicenseeType   INT           = 0,
                                                   @SitePermission NVARCHAR(MAX) = NULL
AS

/*
	Created:	Kevin
	Date:		20110624
	Task :		get top 10 feedback info by custid
	DB:			DB06.bodb_CRM

	Revisions:
        - 20110629@Lukas:  support get multipe related customer
        - 20110722@Kevin:  add @top param
        - 20160308@Billy:  Integrate Sub-Product field - [Redmine: #52998]
        - 20180117@Winnie: Add Is Related Customer - [Redmine: #88774]
        - 20180323@Winnie: CRM - display wrong review information. - [Redmine: #92586]
        - 20171225@Winnie: Change for support multiple product/categories. [RedmineID: #84714]
        - 20190506@Winnie: CN88 Permission RedmineID: #112637
        - 2020816@Winfred: CRM - enhance code to avoid timeout issue RedmineID: #112637
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

    -- #tempFeedback
	DECLARE @i INT = 65000
	CREATE TABLE #tempFeedback (FeedbackID	INT, 
								CustID	INT, 
								Username NVARCHAR(50),
								TitleID INT,
								FirstName NVARCHAR(50),
								LastName NVARCHAR(50),
								Phone NVARCHAR(100),
								MobilePhone NVARCHAR(100),
								Fax  NVARCHAR(50),
								Email  NVARCHAR(254),
								Skype NVARCHAR(100),
								MSN NVARCHAR(100),
								LanguageID INT,
								CountryID INT,
								CreatorID INT,
								CreatorName NVARCHAR(50),
								CreateDate DATETIME,
								FeedbackDate DATETIME,
								ResolutionDate DATETIME,
								SolveDate DATETIME,
								SiteID INT,
								RoleID INT,
								ResponseID INT,
								StatusID INT,
								Description XML,
								Solution NVARCHAR(MAX),
								IsReviewed BIT,
								Review NVARCHAR(MAX),
								ReviewerID INT,
								ReviewerName NVARCHAR(50),
								IsRelated	BIT,
								Subject NVARCHAR(MAX),
								relatedCustomer NVARCHAR(MAX),
								ProvinceID	INT)
	INSERT INTO #tempFeedback 
				(	FeedbackID , 
					CustID	, 
					Username ,
					TitleID ,
					FirstName ,
					LastName ,
					Phone ,
					MobilePhone ,
					Fax ,
					Email  ,
					Skype ,
					MSN ,
					LanguageID ,
					CountryID ,
					CreatorID ,
					CreatorName ,
					CreateDate ,
					FeedbackDate ,
					ResolutionDate ,
					SolveDate ,
					SiteID ,
					RoleID ,
					ResponseID ,
					StatusID ,
					Description ,
					Solution ,
					IsReviewed ,
					Review ,
					ReviewerID ,
					ReviewerName ,
					IsRelated	,
					Subject ,
					relatedCustomer ,
					ProvinceID
					)	
	SELECT TOP (@top)	fb.FeedbackID
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
					,	fb.CreateDate
					,	fb.FeedbackDate
					,	fb.ResolutionDate
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
					,	fbc.IsRelated
					,	fb.Subject
					,	l.list AS relatedCustomer
					,	CASE WHEN @UserRole=1 AND fb.ProvinceID IS NULL THEN 1 ELSE fb.ProvinceID END AS ProvinceID
	FROM		crmFeedbackCustomer fbc WITH (NOLOCK)
	CROSS APPLY	(SELECT TOP 1 * FROM crmFeedback WITH (NOLOCK) WHERE FeedbackID = fbc.FeedbackID) AS fb
	INNER JOIN	crmCustomer ctm WITH (NOLOCK)
			ON	ctm.CustID = fb.CustID
	INNER JOIN	bodb02.dbo.custInfo c WITH (NOLOCK)
			ON	fb.CreatorID = c.custid
	LEFT JOIN	bodb02.dbo.custInfo rv WITH (NOLOCK)
			ON	fb.ReviewerID = rv.custid
	CROSS APPLY	dbo.f_GetRelatedCustomer(fb.FeedbackID) l
    LEFT JOIN #tmpSite si ON fb.SiteID = si.SiteID
    LEFT JOIN #tmpSitePermission sp ON si.SiteID = sp.SiteID
    LEFT JOIN #tmpUserSitePermission usp ON sp.SitePermission = usp.SitePermission
	WHERE	fbc.CustID = @CustID
		AND	fb.StatusID <> 11004
		AND	fb.StatusID <> 11019
		AND ((@UserRole=1 AND ctm.SiteID=33002) OR (@UserRole=2 AND ctm.SiteID<>33002))
        AND (si.SiteOffer = @UserRole OR si.SiteOffer IS NULL)
        AND @LicenseeType <> -1
        AND (si.IsLicensee IS NULL
             OR si.IsLicensee = CASE WHEN @LicenseeType = 0 THEN si.IsLicensee WHEN @LicenseeType = 1 THEN 0 ELSE 1 END)
        AND ((sp.SitePermission IS NULL AND ISNULL(si.IsLicensee, 1) = 1)
             OR sp.SitePermission = usp.SitePermission)
	ORDER BY FeedbackDate DESC

    -- Return data	
	SELECT
		t.FeedbackID
		,	t.CustID
		,	t.UserName
		,	t.TitleID
		,	t.FirstName
		,	t.LastName
		,	t.Phone
		,	t.MobilePhone
		,	t.Fax
		,	t.Email
		,	t.Skype
		,	t.MSN
		,	t.LanguageID
		,	t.CountryID
		,	t.CreatorID
		,	t.CreatorName
		,	t.CreateDate
		,	t.FeedbackDate
		,	t.ResolutionDate
		,	t.SolveDate					
		,	t.SiteID
		,	t.RoleID						
		,	t.ResponseID
		,	t.StatusID					
		,	tmp.Remark AS Description
		,	tmp.AutoField AS AutoField
		,	t.Solution
		,	t.IsReviewed
		,	t.Review
		,	t.ReviewerID
		,	t.ReviewerName AS ReviewerName
		,	t.IsRelated
		,	t.Subject
		,	t.relatedCustomer
		,	t.ProvinceID
	FROM #tempFeedback t
	OUTER APPLY (SELECT TOP (@i) nr.value(N'@Remark',N'nvarchar(max)') AS Remark,
						nr.value(N'@AutoField',N'nvarchar(max)') AS AutoField
				FROM t.Description.nodes(N'//row') AS A(nr)) tmp
	OPTION (OPTIMIZE FOR (@i = 1));
	

	SELECT fs.FeedbackID,fs.SettingID,fs.SubSettingID,fs.SubSettingIDLevel3,
	CASE	WHEN m.MainCategoryID	IS NOT NULL THEN 'Category' 
			WHEN s.StationID		IS NOT NULL THEN 'Station' 
			WHEN p.SettingID		IS NOT NULL THEN 'Product' 
			WHEN c.SettingID		IS NOT NULL THEN 'Communication' 
			END AS SettingType
	FROM #tempFeedback fp
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

    -- Drop temp tables
    DROP TABLE #tmpUserSitePermission
    DROP TABLE #tmpSite
    DROP TABLE #tmpSitePermission
    DROP TABLE #tempFeedback

END
GO