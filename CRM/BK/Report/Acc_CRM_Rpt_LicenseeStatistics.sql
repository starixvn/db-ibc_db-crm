  
ALTER PROCEDURE [dbo].[Acc_CRM_Rpt_LicenseeStatistics]
(	
	@fromdate	DATETIME,
	@todate		DATETIME
)
AS
/*
	Created: 20110826@Lukas	
	Task :  daily summary on licensee feedback
	DB: DBCRM.bodb_CRM
	Original:

	Revisions:
		- 20111126@Sophia: . Not to show Status is Pending (StatusID = 11001)	
						   . And enhance the sps
		- 20140523@Dom: modify site condition

	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON

	DECLARE @cols				NVARCHAR(MAX),
			@cols1				NVARCHAR(MAX),
			@sql				NVARCHAR(MAX),
			@ParamDefinition	NVARCHAR(500)	
	 
 
	SELECT	@ParamDefinition = N'@f DATETIME, @t DATETIME',
			@FromDate	= DATEADD(d,0,CONVERT(CHAR(12),@FromDate, 101)),
			@ToDate		= DATEADD(ms,-2,DATEADD(d,1,CONVERT(CHAR(12),@ToDate, 101)))


		SELECT  @cols = COALESCE(@cols + ',[' + s.SiteName + ']','[' + s.SiteName + ']')	
		FROM	crmSite s WITH(NOLOCK)
		WHERE   s.IsLicensee=1
		ORDER BY s.SiteID ASC

		SELECT  @cols1 = COALESCE( @cols1 +'  NVARCHAR(100) ,[' + s.SiteName + ']','[' + s.SiteName + ']')	
		FROM    crmSite s WITH(NOLOCK)
		WHERE   s.IsLicensee = 1
		ORDER BY s.SiteID ASC
		

		SET @sql = '	

	DECLARE @category TABLE (MaincategoryID INT, Maincategory NVARCHAR(100),
							 SubcategoryID INT, Subcategory NVARCHAR(100))
	
	INSERT INTO @category(MaincategoryID, Maincategory, SubcategoryID, Subcategory)
	SELECT m.SettingID, m.SettingValue, s.SettingID, s.SettingValue
	FROM crmSettingRelation r WITH(NOLOCK)
		INNER JOIN crmSetting m WITH(NOLOCK) ON r.ParentID = m.SettingID
		INNER JOIN crmSetting s WITH(NOLOCK) ON r.SettingID = s.SettingID
	WHERE s.SettingName =''Subcategory''
		AND 
		m.SettingName = ''Maincategory''


	DECLARE @tmp TABLE (MainCategoryID INT, SubCategoryID INT, MainCategory NVARCHAR(100), SubCategory NVARCHAR(100), ' + @cols1 + ' NVARCHAR(100) )
	
	INSERT INTO @tmp

	SELECT MainCategoryID, SubCategoryID, MainCategory, SubCategory, ' + @cols + '
	FROM ( 			

			SELECT	ISNULL(fb.FeedbackID,'''') as  FeedbackID,
					ISNULL(c.MaincategoryID, 0) as ''MainCategoryID'',
					ISNULL(c.Maincategory,''N/A'') AS MainCategory, 
					ISNULL(c.SubcategoryID, 0) as ''SubCategoryID'',
					ISNULL(c.Subcategory,''N/A'') AS SubCategory ,
					ISNULL(fb.Site,'''') as Site
			FROM	@category c
			left JOIN	( SELECT	fb.MaincategoryID,  fb.SubcategoryID, fb.FeedbackID, 
									m.SettingValue as MainCategory, 
									s.SettingValue as SubCategory, site.sitename As Site
						FROM crmFeedback fb WITH(NOLOCK) 
						LEFT JOIN crmSetting m WITH(NOLOCK) ON fb.MainCategoryID = m.SettingID
						LEFT JOIN crmSetting s WITH(NOLOCK) ON fb.SubCategoryID = s.SettingID
						INNER JOIN crmSite site WITH(NOLOCK) ON site.SiteID = fb.SiteID
						WHERE   fb.FeedbackDate BETWEEN '''+CONVERT(VARCHAR(20), @FromDate)+''' AND '''+CONVERT(VARCHAR(20), @ToDate)+'''
						AND site.IsLicensee=1
						AND fb.StatusID NOT IN (11004, 11001)
					) fb ON fb.MaincategoryID = c.MaincategoryID AND c.SubcategoryID = fb.SubcategoryID

				 ) p
				PIVOT
				(
					COUNT(FeedbackID)
					FOR site IN (' + @cols + ')
				) AS pvt
			ORDER BY MainCategoryID, SubCategoryID

		SELECT * FROM @tmp '


	EXEC (@sql)
	print @sql;

END




GO
GRANT EXECUTE ON [dbo].[Acc_CRM_Rpt_LicenseeStatistics] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_Rpt_LicenseeStatistics] TO [vnteam]

exec Acc_CRM_Rpt_LicenseeStatistics '20100101','20140505'

