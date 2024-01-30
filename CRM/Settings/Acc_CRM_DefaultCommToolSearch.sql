/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE	dbo.Acc_CRM_DefaultCommToolSearch @Username       NVARCHAR(MAX) = NULL,
                                                  @Category       NVARCHAR(MAX) = NULL,
                                                  @SubCategory    NVARCHAR(MAX) = NULL,
                                                  @IsDisableCat   BIT           = 1,
                                                  @UserRole       TINYINT       = 2,
                                                  @LicenseeType   INT           = 0,
                                                  @SitePermission NVARCHAR(MAX) = NULL,
                                                  @PageSize       INT           = 0,
                                                  @PageIndex      INT           = 0,
                                                  @TotalRows      INT           = 0 OUTPUT
AS

/*
	Created:	Winnie
	Date:		20191017
	Task:		Select Communication 
	DB:			DB052.bodb_CRM
	Original:

	Revisions:
		- 20191017@Winnie:	Select Communication RedmineID: #122087
        - 20231128@Ned.Le: CRM - Security improvement - Separate accessible data for Credit Sites (#197343)

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


    --------------------
    -- Declare variables

	DECLARE @RowStart INT, @RowEnd INT, @Username2 VARCHAR(30)

	SELECT @PageIndex = @PageIndex - 1
			,@RowStart = @PageSize * @PageIndex + 1
			,@RowEnd = @RowStart + @PageSize - 1


    ---------------
    -- Prepare data

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

    -- #MainCategory
	CREATE TABLE #MainCategory(SettingID INT PRIMARY KEY,SettingValue NVARCHAR(100))

	INSERT INTO #MainCategory(SettingID,SettingValue)
	SELECT SettingID,SettingValue
	FROM [dbo].[crmSetting] WITH(NOLOCK) WHERE [SettingName]='MainCategory'
	UNION ALL
	SELECT 0,'Any'

    -- #SubCategory
	CREATE TABLE #SubCategory(SettingID INT PRIMARY KEY,SettingValue NVARCHAR(100))

	INSERT INTO #SubCategory(SettingID,SettingValue)
	SELECT SettingID,SettingValue
	FROM [dbo].[crmSetting] WITH(NOLOCK) WHERE [SettingName]='SubCategory'
	UNION ALL
	SELECT 0,'Any'

	SELECT @Username2=CAST(@Username AS VARCHAR(30))


    ----------------
    -- Get main data

	CREATE TABLE #tmp (DefaultCommID INT,UserName NVARCHAR(50),Role VARCHAR(10),CustID INT,Category VARCHAR(MAX),SubCategory VARCHAR(MAX),CommTool VARCHAR(MAX))

	INSERT INTO #tmp(DefaultCommID ,UserName,CustID,Role ,Category ,SubCategory ,CommTool)
	SELECT DISTINCT
	 a.DefaultCommID,
     cc.UserName 
	  
	  ,cc.CustID
	  , 'Guest'
	  ,STUFF(
						(   SELECT ', ' + b.SettingValue
							FROM [crmDefaultCommTool] c WITH(NOLOCK)
								INNER JOIN #MainCategory b  ON c.SettingID=b.[SettingID]
							WHERE c.DefaultCommID=a.DefaultCommID  AND c.SettingType=1
							FOR xml path('')
						)
						, 1
						, 1
						, '') AS [Category]
     
	    ,STUFF(
						(   SELECT ', '+ b.SettingValue
							FROM [crmDefaultCommTool] c WITH(NOLOCK)
								INNER JOIN #SubCategory b  ON c.SettingID=b.[SettingID]
							WHERE c.DefaultCommID = a.[DefaultCommID] AND c.SettingType=2
							FOR xml path('')
						)
						, 1
						, 1
						, '') AS [SubCategory]

		,STUFF(
						(   SELECT ', ' + b.SettingValue
							FROM [crmDefaultCommTool] c WITH(NOLOCK)
								INNER JOIN crmSetting b WITH(NOLOCK) ON c.SettingID=b.[SettingID]
							WHERE c.DefaultCommID = a.[DefaultCommID] AND c.SettingType=3
							FOR xml path('')
						)
						, 1
						, 1
						, '') AS [CommTool]   
	FROM [crmDefaultCommTool] a WITH(NOLOCK) 	
         INNER JOIN crmCustomer cc WITH(NOLOCK) ON a.CustID=cc.CustID
         LEFT JOIN #tmpSite si ON cc.SiteID = si.SiteID
         LEFT JOIN #tmpSitePermission sp ON si.SiteID = sp.SiteID
         LEFT JOIN #tmpUserSitePermission usp ON sp.SitePermission = sp.SitePermission
	WHERE a.DefaultCommID<>0 AND cc.CustID<0 AND  (UserName LIKE '%'+@Username+'%' OR @Username IS NULL) 
		AND(@IsDisableCat=1 OR (@IsDisableCat=0
		AND
		STUFF(
							(   SELECT ',' + CONVERT(  varchar(50),c.settingID)
								FROM [crmDefaultCommTool] c WITH(NOLOCK)									
								WHERE c.DefaultCommID=a.DefaultCommID  AND c.SettingType=1
								ORDER BY c.settingID ASC
								FOR xml path('')
							)
							, 1
							, 1
							, '')=@Category
		AND 
		STUFF(
						(   SELECT ','+ CONVERT(  varchar(50),c.settingID)
							FROM [crmDefaultCommTool] c WITH(NOLOCK)								
							WHERE c.DefaultCommID = a.[DefaultCommID] AND c.SettingType=2
							ORDER BY c.settingID ASC
							FOR xml path('')
						)
						, 1
						, 1
						, '') =@SubCategory		
		))
        AND (si.SiteOffer = @UserRole OR si.SiteOffer IS NULL)
        AND @LicenseeType <> -1
        AND (si.IsLicensee IS NULL
             OR si.IsLicensee = CASE WHEN @LicenseeType = 0 THEN si.IsLicensee WHEN @LicenseeType = 1 THEN 0 ELSE 1 END)
        AND ((sp.SitePermission IS NULL AND ISNULL(si.IsLicensee, 1) = 1)
             OR sp.SitePermission = usp.SitePermission)
	UNION ALL
	SELECT DISTINCT
	 a.DefaultCommID,
	 cc.UserName ,
	   cc.CustID
	  ,CASE WHEN cc.roleid=1 THEN 'Member'
			WHEN cc.roleid=2 THEN 'Agent'
			WHEN cc.roleid=3 THEN 'Master'
			WHEN cc.roleid=4 THEN 'Super'
			ELSE 'Guest' END
	  ,STUFF(
						(   SELECT ', ' + b.SettingValue
							FROM [crmDefaultCommTool] c WITH(NOLOCK)
								INNER JOIN #MainCategory b  ON c.SettingID=b.[SettingID]
							WHERE c.DefaultCommID=a.DefaultCommID  AND c.SettingType=1
							FOR xml path('')
						)
						, 1
						, 1
						, '') AS [Category]
     
		,STUFF(
						(   SELECT ', '+ b.SettingValue
							FROM [crmDefaultCommTool] c WITH(NOLOCK)
								INNER JOIN #SubCategory b  ON c.SettingID=b.[SettingID]
							WHERE c.DefaultCommID = a.[DefaultCommID] AND c.SettingType=2
							FOR xml path('')
						)
						, 1
						, 1
						, '') AS [SubCategory]

		,STUFF(
						(   SELECT ', ' + b.SettingValue
							FROM [crmDefaultCommTool] c WITH(NOLOCK)
								INNER JOIN crmSetting b WITH(NOLOCK) ON c.SettingID=b.[SettingID]
							WHERE c.DefaultCommID = a.[DefaultCommID] AND c.SettingType=3
							FOR xml path('')
						)
						, 1
						, 1
						, '') AS [CommTool]   
	FROM [crmDefaultCommTool] a WITH(NOLOCK) 	
         INNER JOIN bodb02.dbo.Customer cc WITH(NOLOCK) ON a.CustID=cc.CustID
         LEFT JOIN #tmpSite si ON cc.site = si.SiteName
         LEFT JOIN #tmpSitePermission sp ON si.SiteID = sp.SiteID
         LEFT JOIN #tmpUserSitePermission usp ON sp.SitePermission = sp.SitePermission
	WHERE a.DefaultCommID<>0 AND  (UserName LIKE '%'+@Username2+'%' OR @Username2 IS NULL) 
		AND(@IsDisableCat=1 OR (@IsDisableCat=0
		AND
		STUFF(
							(   SELECT ',' + CONVERT(  varchar(50),c.settingID)
								FROM [crmDefaultCommTool] c WITH(NOLOCK)									
								WHERE c.DefaultCommID=a.DefaultCommID  AND c.SettingType=1
								ORDER BY c.settingID ASC
								FOR xml path('')
							)
							, 1
							, 1
							, '')=@Category
		AND 
		STUFF(
						(   SELECT ','+ CONVERT(  varchar(50),c.settingID)
							FROM [crmDefaultCommTool] c WITH(NOLOCK)								
							WHERE c.DefaultCommID = a.[DefaultCommID] AND c.SettingType=2
							ORDER BY c.settingID ASC
							FOR xml path('')
						)
						, 1
						, 1
						, '') =@SubCategory		
		))
        AND (si.SiteOffer = @UserRole OR si.SiteOffer IS NULL)
        AND @LicenseeType <> -1
        AND (si.IsLicensee IS NULL
             OR si.IsLicensee = CASE WHEN @LicenseeType = 0 THEN si.IsLicensee WHEN @LicenseeType = 1 THEN 0 ELSE 1 END)
        AND ((sp.SitePermission IS NULL AND ISNULL(si.IsLicensee, 1) = 1)
             OR sp.SitePermission = usp.SitePermission)


    --------------
    -- Return data

	IF @TotalRows=0
	BEGIN
		SELECT @TotalRows=COUNT(1) FROM #tmp
	END

	IF ((@PageSize <= 0) AND (@PageIndex <= 0))
	BEGIN
		SELECT * FROM #tmp
		ORDER BY DefaultCommID DESC,UserName ASC
	END
	ELSE 
	BEGIN
		WITH pag as
		(
			SELECT DefaultCommID, ROW_NUMBER() OVER(ORDER BY DefaultCommID DESC,UserName ASC) AS RowNum 
			FROM #tmp			
		)
		SELECT 	*
		FROM #tmp(NOLOCK) c 
			INNER JOIN pag ON c.DefaultCommID = pag.DefaultCommID
		WHERE pag.RowNum BETWEEN @RowStart AND @RowEnd
	END


    ------------
    -- Drop data

    DROP TABLE #tmpUserSitePermission
    DROP TABLE #tmpSite
    DROP TABLE #tmpSitePermission

    DROP TABLE #MainCategory
    DROP TABLE #SubCategory

    DROP TABLE #tmp

END
GO



