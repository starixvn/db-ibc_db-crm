/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_Rpt_FeedbackStatistics]
(
	@Type			INT,
	@FromDate		DATETIME,
	@ToDate			DATETIME,
	@FromDuration	VARCHAR(100),
	@ToDuration		VARCHAR(100),
	@UserRole		TINYINT=2
)
AS
/*
Created: Lukas
Date: 20101116
Task : feedback statistics report
DB: DB052.bodb_CRM
Original:

Revisions:
		- 20110818@Kevin: add new filter: Communication
		- 20110622@Kevin: add new filter: Status, Response, Product, Category
		- 20110628@Lukas: add filter Licensee & remove licensees from 'site' filter
		- 20111011@Lukas: Add filter duration
		- 20120425@Sophia: remove converting @FromDate, @Todate
		- 20120103@Lukas: exclude Pending feedback (statusID = 11001)
		- 20140523@Dom: modify site condition
		- 20180420@Winnie: FB Statistics report - There is no data when filter By Site RedmineID:#94047
		- 20171225@Winnie: Change for support multiple product/categories. [RedmineID: #84714]
		- 20190506@Winnie:  CN88 Permission RedmineID: #112637      
Param's Explanation:
	@Type:	- 1		By Creator
			- 2		By Country
			- 3		By Role
			- 4		By Site
			- 5		By Status
			- 6		By Customer Response
			- 7		By Product
			- 8		By Category
			- 9		Licensees
			- 10	Communication
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @cols				NVARCHAR(MAX),
			@sql				NVARCHAR(MAX),
			@ParamDefinition	NVARCHAR(500),
			@fDuration			INT,
			@tDuration			INT

	--DECLARE @Items TABLE(ID INT PRIMARY KEY, Item INT)
	DECLARE @Items TABLE(ID INT IDENTITY PRIMARY KEY, Item INT)

	SELECT	@ParamDefinition = N'@f DATETIME, @t DATETIME, @fDuration INT, @tDuration INT'

	DECLARE @tmp TABLE (ID INT IDENTITY PRIMARY KEY, val INT)
	INSERT INTO @tmp(val) SELECT CONVERT(INT,val) FROM dbo.f_split(@FromDuration,':')
	INSERT INTO @tmp(val) SELECT CONVERT(INT,val) FROM dbo.f_split(@ToDuration,':')

	SELECT @fDuration = SUM(CASE WHEN ID = 1 THEN val*24*60*60 
								WHEN ID = 2 THEN val*60*60 
								WHEN ID = 3 THEN val*60 
								WHEN ID = 4 THEN val
								ELSE 0
							END),
		   @tDuration = SUM(CASE WHEN ID = 5 THEN val*24*60*60 
								WHEN ID = 6 THEN val*60*60 
								WHEN ID = 7 THEN val*60 
								WHEN ID = 8 THEN val
								ELSE 0
							END)
	FROM @tmp

	IF @fDuration = 0 AND @tDuration = 0
	BEGIN
		SET @tDuration = 2100000000
	END
	
	IF @Type = 1	--- creator
	BEGIN		
		
		INSERT INTO @Items(Item)
			SELECT c.custid FROM crmfeedback fb WITH(NOLOCK) 
						INNER JOIN bodb02.dbo.customer c WITH(NOLOCK) ON fb.creatorID = c.custid
			WHERE fb.FeedbackDate BETWEEN @FromDate AND @ToDate
					AND fb.StatusID NOT IN (11001,11004,11019,11016)
					AND DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
					AND DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration
			GROUP BY 
				c.UserName, c.CustID
			ORDER BY c.UserName
		--
		SELECT @cols = COALESCE(@cols + ',[' + c.UserName + ']','[' + c.UserName + ']')
		FROM	@Items i INNER JOIN bodb02.dbo.customer c WITH(NOLOCK) ON i.item = c.CustId
		--ORDER BY c.UserName ASC
		IF(@UserRole=2)
		BEGIN
			SELECT @sql = '	SELECT MainCategoryID, SubCategoryID, MainCategory, SubCategory, ' + @cols + '
							FROM (
					  				SELECT DISTINCT	fb.FeedbackID, 
											fs.SettingID as ''MainCategoryID'',
											m.SettingValue AS MainCategory, 
											fs.SubSettingID as ''SubCategoryID'',
											s.SettingValue AS SubCategory ,
											c.username AS CreatorName
									FROM crmFeedback fb WITH(NOLOCK) 
											INNER JOIN crmFeedbackSetting fs  WITH(NOLOCK)	ON fb.FeedbackID=fs.FeedbackID	
											INNER JOIN crmSetting m WITH(NOLOCK) ON fs.SettingID = m.SettingID AND m.SettingName=''MainCategory'' AND m.siteOffer=2
											INNER JOIN crmSetting s WITH(NOLOCK) ON fs.SubSettingID = s.SettingID AND s.SettingName=''SubCategory'' AND s.siteOffer=2
											LEFT JOIN bodb02.dbo.customer c WITH(NOLOCK) ON fb.CreatorID = c.CustID
									WHERE fb.FeedbackDate BETWEEN @f AND @t
											AND fb.StatusID NOT IN (11001,11004,11019,11016)
											AND DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
											AND DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration
								 ) p
								PIVOT
								(
									COUNT(FeedbackID)
									FOR CreatorName IN (' + @cols + ')
								) AS pvt
							ORDER BY MainCategory, SubCategory
							'
		END
		ELSE
		BEGIN
				SELECT @sql = '	SELECT MainCategoryID, SubCategoryID, MainCategory, SubCategory, ' + @cols + '
							FROM (
					  				SELECT DISTINCT	fb.FeedbackID, 
											fs.SettingID as ''MainCategoryID'',
											m.SettingValue AS MainCategory, 
											fs.SubSettingID as ''SubCategoryID'',
											s.SettingValue AS SubCategory ,
											c.username AS CreatorName
									FROM crmFeedback fb WITH(NOLOCK) 
											INNER JOIN crmFeedbackSetting fs  WITH(NOLOCK)	ON fb.FeedbackID=fs.FeedbackID	
											INNER JOIN crmSetting m WITH(NOLOCK) ON fs.SettingID = m.SettingID AND m.SettingName=''MainCategory'' AND m.siteOffer=1
											INNER JOIN crmSetting s WITH(NOLOCK) ON fs.SubSettingID = s.SettingID AND s.SettingName=''SubCategory'' AND s.siteOffer=1
											LEFT JOIN bodb02.dbo.customer c WITH(NOLOCK) ON fb.CreatorID = c.CustID
									WHERE fb.FeedbackDate BETWEEN @f AND @t
											AND fb.StatusID NOT IN (11001,11004,11019,11016)
											AND DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
											AND DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration
								 ) p
								PIVOT
								(
									COUNT(FeedbackID)
									FOR CreatorName IN (' + @cols + ')
								) AS pvt
							ORDER BY MainCategory, SubCategory
							'
		END
		EXECUTE sp_executesql @sql, @ParamDefinition, @f = @FromDate, @t = @ToDate, @fDuration = @fDuration, @tDuration = @tDuration
	
		SELECT	Item
		FROM	@Items
		
		RETURN
	END
	IF @Type = 2	-- country
	BEGIN
		
		INSERT INTO @Items(Item)
			SELECT ISNULL(ct.CountryID,0)
			FROM crmfeedback fb WITH(NOLOCK) 
					LEFT JOIN crmCountry ct WITH(NOLOCK) ON fb.CountryID = ct.CountryID
			WHERE fb.FeedbackDate BETWEEN @FromDate AND @ToDate
					AND fb.StatusID NOT IN (11001,11004,11019,11016)
					AND DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
					AND DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration
					AND ct.siteoffer=@UserRole
			GROUP BY ct.CountryName, ct.CountryID
			ORDER BY ct.CountryName ASC
		--	

		SELECT @cols = COALESCE(@cols + ',[' + ct.CountryName + ']','[' + ct.CountryName + ']')
		FROM	@Items i INNER JOIN crmCountry ct WITH(NOLOCK) ON i.Item = ct.CountryID WHERE ct.siteOffer=@UserRole
		--ORDER BY ct.CountryName ASC
		
		IF EXISTS (SELECT 1 FROM @Items WHERE Item = 0)
		BEGIN
			--- modify to push N/A at the end of line
			DELETE FROM @Items WHERE Item = 0		
			SET @cols = COALESCE(@cols + ',[N/A]','[N/A]')
			INSERT INTO @Items VALUES(0)
		END
		IF @UserRole=2
		BEGIN
			SELECT @sql = '	SELECT MainCategoryID, SubCategoryID, MainCategory, SubCategory, ' + @cols + '
							FROM (
					  				SELECT DISTINCT	fb.FeedbackID, 
											fs.SettingID as ''MainCategoryID'',
											m.SettingValue AS MainCategory, 
											fs.SubSettingID as ''SubCategoryID'',
											s.SettingValue AS SubCategory ,
											ISNULL(ct.CountryName,''N/A'') AS CountryName
									FROM crmFeedback fb WITH(NOLOCK) 
											INNER JOIN crmFeedbackSetting fs  WITH(NOLOCK)	ON fb.FeedbackID=fs.FeedbackID	
											INNER JOIN crmSetting m WITH(NOLOCK) ON fs.SettingID = m.SettingID AND m.SettingName=''MainCategory'' AND m.siteoffer=2
											INNER JOIN crmSetting s WITH(NOLOCK) ON fs.SubSettingID = s.SettingID AND s.SettingName=''SubCategory'' AND s.siteoffer=2
											LEFT JOIN crmCountry ct WITH(NOLOCK) ON fb.CountryId = ct.CountryID
									WHERE fb.FeedbackDate BETWEEN @f AND @t
											AND fb.StatusID NOT IN (11001,11004,11019,11016)
											AND DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
											AND DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration
											AND ct.siteoffer=2
								 ) p
								PIVOT
								(
									COUNT(FeedbackID)
									FOR CountryName IN (' + @cols + ')
								) AS pvt
							ORDER BY MainCategory, SubCategory
							'
		END
		ELSE
		BEGIN
			SELECT @sql = '	SELECT MainCategoryID, SubCategoryID, MainCategory, SubCategory, ' + @cols + '
							FROM (
					  				SELECT DISTINCT	fb.FeedbackID, 
											fs.SettingID as ''MainCategoryID'',
											m.SettingValue AS MainCategory, 
											fs.SubSettingID as ''SubCategoryID'',
											s.SettingValue AS SubCategory ,
											ISNULL(ct.CountryName,''N/A'') AS CountryName
									FROM crmFeedback fb WITH(NOLOCK) 
											INNER JOIN crmFeedbackSetting fs  WITH(NOLOCK)	ON fb.FeedbackID=fs.FeedbackID	
											INNER JOIN crmSetting m WITH(NOLOCK) ON fs.SettingID = m.SettingID AND m.SettingName=''MainCategory'' AND m.siteoffer=1
											INNER JOIN crmSetting s WITH(NOLOCK) ON fs.SubSettingID = s.SettingID AND s.SettingName=''SubCategory'' AND s.siteoffer=1
											LEFT JOIN crmCountry ct WITH(NOLOCK) ON fb.CountryId = ct.CountryID
									WHERE fb.FeedbackDate BETWEEN @f AND @t
											AND fb.StatusID NOT IN (11001,11004,11019,11016)
											AND DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
											AND DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration
											AND ct.siteoffer=1
								 ) p
								PIVOT
								(
									COUNT(FeedbackID)
									FOR CountryName IN (' + @cols + ')
								) AS pvt
							ORDER BY MainCategory, SubCategory
							'
		END
		EXECUTE sp_executesql @sql, @ParamDefinition, @f = @FromDate, @t = @ToDate, @fDuration = @fDuration, @tDuration = @tDuration

		SELECT	Item
		FROM	@Items i 	

		RETURN
	END
	IF @Type = 3	-- Role
	BEGIN
		
		INSERT INTO @Items(Item)
			SELECT r.SettingID 
			FROM crmfeedback fb WITH(NOLOCK) 
					INNER JOIN crmSetting r WITH(NOLOCK) ON fb.RoleID = r.SettingID
			WHERE fb.FeedbackDate BETWEEN @FromDate AND @ToDate
					AND fb.StatusID NOT IN (11001,11004,11019,11016)
					AND DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
					AND DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration
					AND r.siteoffer=@UserRole
			GROUP BY r.SettingValue, r.SettingID
			ORDER BY r.SettingID ASC
			
		--
		SELECT @cols = COALESCE(@cols + ',[' + r.SettingValue + ']','[' + r.SettingValue + ']')
		FROM	@Items i INNER JOIN crmSetting r WITH(NOLOCK) ON i.Item = r.SettingID  WHERE r.siteOffer=@UserRole
		--ORDER BY r.SettingID ASC
		IF(@UserRole=2)
		BEGIN
			SELECT @sql = '	SELECT MainCategoryID, SubCategoryID, MainCategory, SubCategory, ' + @cols + '	
							FROM (	
					  				SELECT	DISTINCT fb.FeedbackID, 
											fs.SettingID as ''MainCategoryID'',
											m.SettingValue AS MainCategory, 
											fs.SubSettingID as ''SubCategoryID'',
											s.SettingValue AS SubCategory ,
											r.SettingValue AS Role	
									FROM crmFeedback fb WITH(NOLOCK) 
											INNER JOIN crmFeedbackSetting fs  WITH(NOLOCK)	ON fb.FeedbackID=fs.FeedbackID	
											INNER JOIN crmSetting m WITH(NOLOCK) ON fs.SettingID = m.SettingID AND m.SettingName=''MainCategory'' AND m.siteoffer=2
											INNER JOIN crmSetting s WITH(NOLOCK) ON fs.SubSettingID = s.SettingID AND s.SettingName=''SubCategory'' AND s.siteoffer=2
											LEFT JOIN crmSetting r WITH(NOLOCK) ON fb.RoleID = r.SettingID
									WHERE fb.FeedbackDate BETWEEN @f AND @t
											AND fb.StatusID NOT IN (11001,11004,11019,11016)
											AND DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
											AND DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration
											AND r.siteOffer=2
								 ) p
								PIVOT
								(
									COUNT(FeedbackID)
									FOR Role IN (' + @cols + ')
								) AS pvt
							ORDER BY MainCategory, SubCategory
							'
		END
		ELSE
		BEGIN
			SELECT @sql = '	SELECT MainCategoryID, SubCategoryID, MainCategory, SubCategory, ' + @cols + '	
							FROM (	
					  				SELECT	DISTINCT fb.FeedbackID, 
											fs.SettingID as ''MainCategoryID'',
											m.SettingValue AS MainCategory, 
											fs.SubSettingID as ''SubCategoryID'',
											s.SettingValue AS SubCategory ,
											r.SettingValue AS Role	
									FROM crmFeedback fb WITH(NOLOCK) 
											INNER JOIN crmFeedbackSetting fs  WITH(NOLOCK)	ON fb.FeedbackID=fs.FeedbackID	
											INNER JOIN crmSetting m WITH(NOLOCK) ON fs.SettingID = m.SettingID AND m.SettingName=''MainCategory'' AND m.siteoffer=1
											INNER JOIN crmSetting s WITH(NOLOCK) ON fs.SubSettingID = s.SettingID AND s.SettingName=''SubCategory'' AND s.siteoffer=1
											LEFT JOIN crmSetting r WITH(NOLOCK) ON fb.RoleID = r.SettingID
									WHERE fb.FeedbackDate BETWEEN @f AND @t
											AND fb.StatusID NOT IN (11001,11004,11019,11016)
											AND DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
											AND DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration
											AND r.siteOffer=1
								 ) p
								PIVOT
								(
									COUNT(FeedbackID)
									FOR Role IN (' + @cols + ')
								) AS pvt
							ORDER BY MainCategory, SubCategory
							'
		END
		EXECUTE sp_executesql @sql, @ParamDefinition, @f = @FromDate, @t = @ToDate, @fDuration = @fDuration, @tDuration = @tDuration

		SELECT	Item
		FROM	@Items i

		RETURN
	END
	IF @Type = 4	-- Site
	BEGIN

		INSERT INTO @Items(Item)
		SELECT ISNULL(fb.SiteID,0)
		FROM crmfeedback fb WITH(NOLOCK) 
				LEFT JOIN crmSite r WITH(NOLOCK) ON fb.SiteID = r.SiteID
		WHERE fb.FeedbackDate BETWEEN @FromDate AND @ToDate				
				AND fb.StatusID NOT IN (11001,11004,11019,11016)
				AND DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
				AND DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration
				AND r.siteoffer=@UserRole
		GROUP BY r.SiteName, fb.SiteID
		ORDER BY r.SiteName ASC
					 
		--
		SELECT @cols = COALESCE(@cols + ',[' + r.SettingValue + ']','[' + r.SettingValue + ']')
		FROM	@Items i INNER JOIN crmSetting r WITH(NOLOCK) ON i.Item = r.SettingID
			WHERE r.siteoffer=@UserRole
		--ORDER BY r.SettingValue ASC
	
		IF EXISTS (SELECT 1 FROM @Items WHERE Item = 0)
		BEGIN
			DELETE FROM @Items WHERE Item = 0
			SET @cols = COALESCE(@cols + ',[N/A]','[N/A]')
			INSERT INTO @Items VALUES(0)
		END
		IF(@UserRole=2)
		BEGIN
			SELECT @sql = '	SELECT MainCategoryID, SubCategoryID, MainCategory, SubCategory, ' + @cols + '
							FROM (
					  				SELECT	DISTINCT fb.FeedbackID, 
											fs.SettingID as ''MainCategoryID'',
											m.SettingValue AS MainCategory, 
											fs.SubSettingID as ''SubCategoryID'',
											s.SettingValue AS SubCategory ,
											ISNULL(site.SiteName,''N/A'') As Site
									FROM crmFeedback fb WITH(NOLOCK) 
											INNER JOIN crmFeedbackSetting fs  WITH(NOLOCK)	ON fb.FeedbackID=fs.FeedbackID	
											INNER JOIN crmSetting m WITH(NOLOCK) ON fs.SettingID = m.SettingID AND m.SettingName=''MainCategory'' AND m.siteoffer=2
											INNER JOIN crmSetting s WITH(NOLOCK) ON fs.SubSettingID = s.SettingID AND s.SettingName=''SubCategory'' AND s.siteoffer=2
											LEFT JOIN crmSite site WITH(NOLOCK) ON fb.SiteID = site.SiteID
									WHERE fb.FeedbackDate BETWEEN @f AND @t										
											AND fb.StatusID NOT IN (11001,11004,11019,11016)
											AND DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
											AND DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration
											AND site.siteoffer=2
								 ) p
								PIVOT
								(
									COUNT(FeedbackID)
									FOR Site IN (' + @cols + ')
								) AS pvt
							ORDER BY MainCategory, SubCategory
							'
		END
		ELSE
		BEGIN
			SELECT @sql = '	SELECT MainCategoryID, SubCategoryID, MainCategory, SubCategory, ' + @cols + '
							FROM (
					  				SELECT	DISTINCT fb.FeedbackID, 
											fs.SettingID as ''MainCategoryID'',
											m.SettingValue AS MainCategory, 
											fs.SubSettingID as ''SubCategoryID'',
											s.SettingValue AS SubCategory ,
											ISNULL(site.SiteName,''N/A'') As Site
									FROM crmFeedback fb WITH(NOLOCK) 
											INNER JOIN crmFeedbackSetting fs  WITH(NOLOCK)	ON fb.FeedbackID=fs.FeedbackID	
											INNER JOIN crmSetting m WITH(NOLOCK) ON fs.SettingID = m.SettingID AND m.SettingName=''MainCategory'' AND m.siteoffer=1
											INNER JOIN crmSetting s WITH(NOLOCK) ON fs.SubSettingID = s.SettingID AND s.SettingName=''SubCategory'' AND s.siteoffer=1
											LEFT JOIN crmSite site WITH(NOLOCK) ON fb.SiteID = site.SiteID
									WHERE fb.FeedbackDate BETWEEN @f AND @t										
											AND fb.StatusID NOT IN (11001,11004,11019,11016)
											AND DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
											AND DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration
											AND site.siteoffer=1
								 ) p
								PIVOT
								(
									COUNT(FeedbackID)
									FOR Site IN (' + @cols + ')
								) AS pvt
							ORDER BY MainCategory, SubCategory
							'
		END
		EXECUTE sp_executesql @sql, @ParamDefinition, @f = @FromDate, @t = @ToDate, @fDuration = @fDuration, @tDuration = @tDuration
		
		SELECT	Item 
		FROM	@Items i		

		RETURN
	END
	IF @Type = 5	-- status
	BEGIN	
		INSERT INTO @Items(Item)
			SELECT r.SettingID 
			FROM crmfeedback fb WITH(NOLOCK) 
					INNER JOIN crmSetting r WITH(NOLOCK) ON fb.StatusID = r.SettingID
			WHERE fb.FeedbackDate BETWEEN @FromDate AND @ToDate
					AND fb.StatusID NOT IN (11001,11004,11019,11016)
					AND DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
					AND DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration
					AND r.siteoffer=@UserRole
			GROUP BY r.SettingValue, r.SettingID
			ORDER BY r.SettingValue ASC
		--
	
		SELECT @cols = COALESCE(@cols + ',[' + r.SettingValue + ']','[' + r.SettingValue + ']')
		FROM	@Items i INNER JOIN crmSetting r WITH(NOLOCK) ON i.Item = r.SettingID
			WHERE r.siteoffer=@UserRole
			
		--ORDER BY r.SettingValue ASC
		IF @UserRole=2
		BEGIN
			SELECT @sql = '	SELECT MainCategoryID, SubCategoryID, MainCategory, SubCategory, ' + @cols + '
							FROM (
					  				SELECT	DISTINCT fb.FeedbackID, 
											fs.SettingID as ''MainCategoryID'',
											m.SettingValue AS MainCategory, 
											fs.SubSettingID as ''SubCategoryID'',
											s.SettingValue AS SubCategory ,
											st.SettingValue As [status]
									FROM crmFeedback fb WITH(NOLOCK) 
											INNER JOIN crmFeedbackSetting fs  WITH(NOLOCK)	ON fb.FeedbackID=fs.FeedbackID	
											INNER JOIN crmSetting m WITH(NOLOCK) ON fs.SettingID = m.SettingID AND m.SettingName=''MainCategory'' AND m.siteoffer=2
											INNER JOIN crmSetting s WITH(NOLOCK) ON fs.SubSettingID = s.SettingID AND s.SettingName=''SubCategory'' AND s.siteoffer=2
											INNER JOIN crmSetting st WITH(NOLOCK) ON fb.StatusID = st.SettingID
									WHERE fb.FeedbackDate BETWEEN @f AND @t
											AND fb.StatusID NOT IN (11001,11004,11019,11016)
											AND DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
											AND DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration
											AND st.Siteoffer=2
								 ) p
								PIVOT
								(
									COUNT(FeedbackID)
									FOR [status] IN (' + @cols + ')
								) AS pvt
							ORDER BY MainCategory, SubCategory
							'						
		END
		ELSE
		BEGIN
			SELECT @sql = '	SELECT MainCategoryID, SubCategoryID, MainCategory, SubCategory, ' + @cols + '
							FROM (
					  				SELECT	DISTINCT fb.FeedbackID, 
											fs.SettingID as ''MainCategoryID'',
											m.SettingValue AS MainCategory, 
											fs.SubSettingID as ''SubCategoryID'',
											s.SettingValue AS SubCategory ,
											st.SettingValue As [status]
									FROM crmFeedback fb WITH(NOLOCK) 
											INNER JOIN crmFeedbackSetting fs  WITH(NOLOCK)	ON fb.FeedbackID=fs.FeedbackID	
											INNER JOIN crmSetting m WITH(NOLOCK) ON fs.SettingID = m.SettingID AND m.SettingName=''MainCategory'' AND m.siteoffer=1
											INNER JOIN crmSetting s WITH(NOLOCK) ON fs.SubSettingID = s.SettingID AND s.SettingName=''SubCategory'' AND s.siteoffer=1
											INNER JOIN crmSetting st WITH(NOLOCK) ON fb.StatusID = st.SettingID
									WHERE fb.FeedbackDate BETWEEN @f AND @t
											AND fb.StatusID NOT IN (11001,11004,11019,11016)
											AND DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
											AND DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration
											AND st.Siteoffer=1
								 ) p
								PIVOT
								(
									COUNT(FeedbackID)
									FOR [status] IN (' + @cols + ')
								) AS pvt
							ORDER BY MainCategory, SubCategory
							'
		END
		EXECUTE sp_executesql @sql, @ParamDefinition, @f = @FromDate, @t = @ToDate, @fDuration = @fDuration, @tDuration = @tDuration

		SELECT	Item
		FROM	@Items i

		RETURN
	END
	IF @Type = 6	-- customer response
	BEGIN

		INSERT INTO @Items(Item)
			SELECT r.SettingID 
			FROM crmfeedback fb WITH(NOLOCK) 
					INNER JOIN crmSetting r WITH(NOLOCK) ON fb.ResponseID = r.SettingID
			WHERE fb.FeedbackDate BETWEEN @FromDate AND @ToDate
					AND fb.StatusID NOT IN (11001,11004,11019,11016)
					AND DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
					AND DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration
					AND r.siteoffer=@UserRole
			GROUP BY r.SettingValue, r.SettingID
			ORDER BY r.SettingValue ASC
		--
		SELECT @cols = COALESCE(@cols + ',[' + r.SettingValue + ']','[' + r.SettingValue + ']')
		FROM	@Items i INNER JOIN crmSetting r WITH(NOLOCK) ON i.Item = r.SettingID
			WHERE r.siteoffer=@UserRole
		--ORDER BY r.SettingValue ASC

		IF @UserRole=2
		BEGIN
			SELECT @sql = '	SELECT MainCategoryID, SubCategoryID, MainCategory, SubCategory, ' + @cols + '
							FROM (
					  				SELECT	DISTINCT fb.FeedbackID, 
											fs.SettingID as ''MainCategoryID'',
											m.SettingValue AS MainCategory, 
											fs.SubSettingID as ''SubCategoryID'',
											s.SettingValue AS SubCategory ,
											st.SettingValue As Response
									FROM crmFeedback fb WITH(NOLOCK) 
											INNER JOIN crmFeedbackSetting fs  WITH(NOLOCK)	ON fb.FeedbackID=fs.FeedbackID	
											INNER JOIN crmSetting m WITH(NOLOCK) ON fs.SettingID = m.SettingID AND m.SettingName=''MainCategory'' AND m.siteoffer=2
											INNER JOIN crmSetting s WITH(NOLOCK) ON fs.SubSettingID = s.SettingID AND s.SettingName=''SubCategory'' AND s.siteoffer=2
											LEFT JOIN crmSetting st WITH(NOLOCK) ON fb.ResponseID = st.SettingID
									WHERE fb.FeedbackDate BETWEEN @f AND @t
											AND fb.StatusID NOT IN (11001,11004,11019,11016)
											AND DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
											AND DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration
											AND st.siteoffer=2
								 ) p
								PIVOT
								(
									COUNT(FeedbackID)
									FOR Response IN (' + @cols + ')
								) AS pvt
							ORDER BY MainCategory, SubCategory
							'
		END
		ELSE
		BEGIN
			SELECT @sql = '	SELECT MainCategoryID, SubCategoryID, MainCategory, SubCategory, ' + @cols + '
							FROM (
					  				SELECT	DISTINCT fb.FeedbackID, 
											fs.SettingID as ''MainCategoryID'',
											m.SettingValue AS MainCategory, 
											fs.SubSettingID as ''SubCategoryID'',
											s.SettingValue AS SubCategory ,
											st.SettingValue As Response
									FROM crmFeedback fb WITH(NOLOCK) 
											INNER JOIN crmFeedbackSetting fs  WITH(NOLOCK)	ON fb.FeedbackID=fs.FeedbackID	
											INNER JOIN crmSetting m WITH(NOLOCK) ON fs.SettingID = m.SettingID AND m.SettingName=''MainCategory'' AND m.siteoffer=1
											INNER JOIN crmSetting s WITH(NOLOCK) ON fs.SubSettingID = s.SettingID AND s.SettingName=''SubCategory'' AND s.siteoffer=1
											LEFT JOIN crmSetting st WITH(NOLOCK) ON fb.ResponseID = st.SettingID
									WHERE fb.FeedbackDate BETWEEN @f AND @t
											AND fb.StatusID NOT IN (11001,11004,11019,11016)
											AND DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
											AND DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration
											AND st.siteoffer=1
								 ) p
								PIVOT
								(
									COUNT(FeedbackID)
									FOR Response IN (' + @cols + ')
								) AS pvt
							ORDER BY MainCategory, SubCategory
							'
		END
		EXECUTE sp_executesql @sql, @ParamDefinition, @f = @FromDate, @t = @ToDate, @fDuration = @fDuration, @tDuration = @tDuration

		SELECT	Item
		FROM	@Items i

		RETURN
	END
	IF @Type = 7	-- product
	BEGIN
		
		INSERT INTO @Items(Item)
		SELECT DISTINCT fs.SettingID
		FROM crmfeedback fb WITH(NOLOCK) 
			INNER JOIN crmFeedbackSetting fs  WITH(NOLOCK)	ON fb.FeedbackID=fs.FeedbackID	
			INNER JOIN crmSetting r WITH(NOLOCK) ON fs.SettingID = r.SettingID AND r.SettingName='Product'
		WHERE fb.FeedbackDate BETWEEN @FromDate AND @ToDate
			AND fb.StatusID NOT IN (11001,11004,11019,11016)
			AND DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
			AND DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration
			AND r.siteoffer=@UserRole
	
		SELECT @cols = COALESCE(@cols + ',[' + r.SettingValue + ']','[' + r.SettingValue + ']')
		FROM	@Items i INNER JOIN crmSetting r WITH(NOLOCK) ON i.Item = r.SettingID WHERE r.siteoffer=@UserRole
		--ORDER BY r.SettingValue ASC
		
		IF EXISTS (SELECT 1 FROM @Items WHERE Item = 0)
		BEGIN
			DELETE FROM @Items WHERE Item = 0
			SET @cols = COALESCE(@cols + ',[N/A]','[N/A]')
			INSERT INTO @Items VALUES(0)	
				
		END
		IF(@UserRole=2)
		BEGIN
			SELECT @sql = '	SELECT MainCategoryID, SubCategoryID, MainCategory, SubCategory, ' + @cols + '
							FROM (
					  				SELECT DISTINCT
											fb.FeedbackID, 
											fs.SettingID as ''MainCategoryID'',
											m.SettingValue AS MainCategory, 
											fs.SubSettingID as ''SubCategoryID'',
											s.SettingValue AS SubCategory ,
											p.SettingValue As Product
									FROM crmFeedback fb WITH(NOLOCK) 
											INNER JOIN crmFeedbackSetting fs  WITH(NOLOCK)	ON fb.FeedbackID=fs.FeedbackID	
											INNER JOIN crmSetting m WITH(NOLOCK) ON fs.SettingID = m.SettingID AND m.SettingName=''MainCategory'' AND m.siteoffer=2
											INNER JOIN crmSetting s WITH(NOLOCK) ON fs.SubSettingID = s.SettingID AND s.SettingName=''SubCategory'' AND s.siteoffer=2
											INNER JOIN crmFeedbackSetting st WITH(NOLOCK) ON fs.FeedbackID = st.FeedbackID
											INNER JOIN crmSetting p WITH(NOLOCK) ON st.SettingID = p.SettingID AND p.SettingName=''Product''
									WHERE fb.FeedbackDate BETWEEN @f AND @t
											AND fb.StatusID NOT IN (11001,11004,11019,11016)
											AND DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
											AND DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration
											AND p.siteoffer=2
								 ) p
								PIVOT
								(
									COUNT(FeedbackID)
									FOR Product IN (' + @cols + ')
								) AS pvt
							ORDER BY MainCategory, SubCategory
							'
		END
		ELSE
		BEGIN
			SELECT @sql = '	SELECT MainCategoryID, SubCategoryID, MainCategory, SubCategory, ' + @cols + '
							FROM (
					  				SELECT DISTINCT
											fb.FeedbackID, 
											fs.SettingID as ''MainCategoryID'',
											m.SettingValue AS MainCategory, 
											fs.SubSettingID as ''SubCategoryID'',
											s.SettingValue AS SubCategory ,
											p.SettingValue As Product
									FROM crmFeedback fb WITH(NOLOCK) 
											INNER JOIN crmFeedbackSetting fs  WITH(NOLOCK)	ON fb.FeedbackID=fs.FeedbackID	
											INNER JOIN crmSetting m WITH(NOLOCK) ON fs.SettingID = m.SettingID AND m.SettingName=''MainCategory'' AND m.siteoffer=1
											INNER JOIN crmSetting s WITH(NOLOCK) ON fs.SubSettingID = s.SettingID AND s.SettingName=''SubCategory'' AND s.siteoffer=1
											INNER JOIN crmFeedbackSetting st WITH(NOLOCK) ON fs.FeedbackID = st.FeedbackID
											INNER JOIN crmSetting p WITH(NOLOCK) ON st.SettingID = p.SettingID AND p.SettingName=''Product''
									WHERE fb.FeedbackDate BETWEEN @f AND @t
											AND fb.StatusID NOT IN (11001,11004,11019,11016)
											AND DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
											AND DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration
											AND p.siteoffer=1
								 ) p
								PIVOT
								(
									COUNT(FeedbackID)
									FOR Product IN (' + @cols + ')
								) AS pvt
							ORDER BY MainCategory, SubCategory
							'
		END
		EXECUTE sp_executesql @sql, @ParamDefinition, @f = @FromDate, @t = @ToDate, @fDuration = @fDuration, @tDuration = @tDuration

		SELECT	Item
		FROM	@Items i		

		RETURN
	END
	IF @Type = 8	-- Main Category
	BEGIN

		INSERT INTO @Items(Item)
			SELECT DISTINCT fs.SettingID 
			FROM crmfeedback fb WITH(NOLOCK) 
				INNER JOIN crmFeedbackSetting fs  WITH(NOLOCK)	ON fb.FeedbackID=fs.FeedbackID					
				INNER JOIN crmSetting r WITH(NOLOCK) ON fs.SettingID = r.SettingID AND r.SettingName='MainCategory'
			WHERE fb.FeedbackDate BETWEEN @FromDate AND @ToDate
					AND fb.StatusID NOT IN (11001,11004,11019,11016)
					AND DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
					AND DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration
					AND r.siteoffer=@UserRole

		SELECT @cols = COALESCE(@cols + ',[' + r.SettingValue + ']','[' + r.SettingValue + ']')
		FROM	@Items i INNER JOIN crmSetting r WITH(NOLOCK) ON i.Item = r.SettingID WHERE r.siteoffer=@UserRole
		--ORDER BY r.SettingValue ASC

		IF @UserRole=2
		BEGIN
			SELECT @sql = '	SELECT MainCategoryID, SubCategoryID, MainCategory, SubCategory, ' + @cols + '
							FROM (
					  				SELECT	DISTINCT fb.FeedbackID, 
											fs.SettingID as ''MainCategoryID'',
											m.SettingValue AS MainCategory, 
											fs.SubSettingID as ''SubCategoryID'',
											s.SettingValue AS SubCategory ,
											m.SettingValue As Category
									FROM crmFeedback fb WITH(NOLOCK) 
											INNER JOIN crmFeedbackSetting fs  WITH(NOLOCK)	ON fb.FeedbackID=fs.FeedbackID	
											INNER JOIN crmSetting m WITH(NOLOCK) ON fs.SettingID = m.SettingID AND m.SettingName=''MainCategory'' AND m.siteoffer=2
											INNER JOIN crmSetting s WITH(NOLOCK) ON fs.SubSettingID = s.SettingID AND s.SettingName=''SubCategory'' AND s.siteoffer=2
									WHERE fb.FeedbackDate BETWEEN @f AND @t
											AND fb.StatusID NOT IN (11001,11004,11019,11016)
											AND DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
											AND DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration
								 ) p
								PIVOT
								(
									COUNT(FeedbackID)
									FOR Category IN (' + @cols + ')
								) AS pvt
							ORDER BY MainCategory, SubCategory
							'
		END			
		ELSE
		BEGIN
			SELECT @sql = '	SELECT MainCategoryID, SubCategoryID, MainCategory, SubCategory, ' + @cols + '
							FROM (
					  				SELECT	DISTINCT fb.FeedbackID, 
											fs.SettingID as ''MainCategoryID'',
											m.SettingValue AS MainCategory, 
											fs.SubSettingID as ''SubCategoryID'',
											s.SettingValue AS SubCategory ,
											m.SettingValue As Category
									FROM crmFeedback fb WITH(NOLOCK) 
											INNER JOIN crmFeedbackSetting fs  WITH(NOLOCK)	ON fb.FeedbackID=fs.FeedbackID	
											INNER JOIN crmSetting m WITH(NOLOCK) ON fs.SettingID = m.SettingID AND m.SettingName=''MainCategory'' AND m.siteoffer=1
											INNER JOIN crmSetting s WITH(NOLOCK) ON fs.SubSettingID = s.SettingID AND s.SettingName=''SubCategory'' AND s.siteoffer=1
									WHERE fb.FeedbackDate BETWEEN @f AND @t
											AND fb.StatusID NOT IN (11001,11004,11019,11016)
											AND DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
											AND DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration
								 ) p
								PIVOT
								(
									COUNT(FeedbackID)
									FOR Category IN (' + @cols + ')
								) AS pvt
							ORDER BY MainCategory, SubCategory
							'
		END			
		EXECUTE sp_executesql @sql, @ParamDefinition, @f = @FromDate, @t = @ToDate, @fDuration = @fDuration, @tDuration = @tDuration

		SELECT	Item
		FROM	@Items i

		RETURN
	END
	IF @Type = 9	-- Licensees
	BEGIN

		INSERT INTO @Items(Item)
			SELECT r.SiteID 
			FROM crmfeedback fb WITH(NOLOCK) 
					INNER JOIN crmSite r WITH(NOLOCK) ON fb.SiteID = r.SiteID
			WHERE fb.FeedbackDate BETWEEN @FromDate AND @ToDate
					AND r.IsLicensee=1--r.SettingID >= 6200				
					AND fb.StatusID NOT IN (11001,11004,11019,11016)
					AND DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
					AND DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration
					AND r.siteoffer=@UserRole
			GROUP BY r.SiteName, r.SiteID
			ORDER BY r.SiteName ASC
		--
		SELECT @cols = COALESCE(@cols + ',[' + r.SettingValue + ']','[' + r.SettingValue + ']')
		FROM	@Items i INNER JOIN crmSetting r WITH(NOLOCK) ON i.Item = r.SettingID WHERE r.siteoffer=@UserRole
		--ORDER BY r.SettingValue ASC
	
		IF @UserRole=2
		BEGIN
			SELECT @sql = '	SELECT MainCategoryID, SubCategoryID, MainCategory, SubCategory, ' + @cols + '
							FROM (
					  				SELECT	DISTINCT fb.FeedbackID, 
											fs.SettingID as ''MainCategoryID'',
											m.SettingValue AS MainCategory, 
											fs.SubSettingID as ''SubCategoryID'',
											s.SettingValue AS SubCategory ,
											st.SiteName As Site
									FROM crmFeedback fb WITH(NOLOCK) 
											INNER JOIN crmFeedbackSetting fs  WITH(NOLOCK)	ON fb.FeedbackID=fs.FeedbackID	
											INNER JOIN crmSetting m WITH(NOLOCK) ON fs.SettingID = m.SettingID AND m.SettingName=''MainCategory'' AND m.siteoffer=2
											INNER JOIN crmSetting s WITH(NOLOCK) ON fs.SubSettingID = s.SettingID AND s.SettingName=''SubCategory'' AND s.siteoffer=2
											LEFT JOIN crmSite st WITH(NOLOCK) ON fb.SiteID = st.SiteID
									WHERE fb.FeedbackDate BETWEEN @f AND @t
											AND st.IsLicensee = 1
											AND fb.StatusID NOT IN (11001,11004,11019,11016)
											AND DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
											AND DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration
											AND st.siteoffer=2
								 ) p
								PIVOT
								(
									COUNT(FeedbackID)
									FOR site IN (' + @cols + ')
								) AS pvt
							ORDER BY MainCategory, SubCategory
							'
		END
		ELSE
		BEGIN
			SELECT @sql = '	SELECT MainCategoryID, SubCategoryID, MainCategory, SubCategory, ' + @cols + '
							FROM (
					  				SELECT	DISTINCT fb.FeedbackID, 
											fs.SettingID as ''MainCategoryID'',
											m.SettingValue AS MainCategory, 
											fs.SubSettingID as ''SubCategoryID'',
											s.SettingValue AS SubCategory ,
											st.SiteName As Site
									FROM crmFeedback fb WITH(NOLOCK) 
											INNER JOIN crmFeedbackSetting fs  WITH(NOLOCK)	ON fb.FeedbackID=fs.FeedbackID	
											INNER JOIN crmSetting m WITH(NOLOCK) ON fs.SettingID = m.SettingID AND m.SettingName=''MainCategory'' AND m.siteoffer=1
											INNER JOIN crmSetting s WITH(NOLOCK) ON fs.SubSettingID = s.SettingID AND s.SettingName=''SubCategory'' AND s.siteoffer=1
											LEFT JOIN crmSite st WITH(NOLOCK) ON fb.SiteID = st.SiteID
									WHERE fb.FeedbackDate BETWEEN @f AND @t
											AND st.IsLicensee = 1
											AND fb.StatusID NOT IN (11001,11004,11019,11016)
											AND DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
											AND DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration
											AND st.siteoffer=1
								 ) p
								PIVOT
								(
									COUNT(FeedbackID)
									FOR site IN (' + @cols + ')
								) AS pvt
							ORDER BY MainCategory, SubCategory
							'
		END
		EXECUTE sp_executesql @sql, @ParamDefinition, @f = @FromDate, @t = @ToDate, @fDuration = @fDuration, @tDuration = @tDuration

		SELECT	Item
		FROM	@Items i

		RETURN
	END
	IF @Type = 10	-- communication
	BEGIN
		
		INSERT INTO @Items(Item)
		SELECT DISTINCT fs.SettingID 
		FROM crmfeedback fb WITH(NOLOCK) 
			INNER JOIN crmFeedbackSetting fs  WITH(NOLOCK)	ON fb.FeedbackID=fs.FeedbackID					
			INNER JOIN crmSetting r WITH(NOLOCK) ON fs.SettingID = r.SettingID AND r.SettingName='communication'				
		WHERE fb.FeedbackDate BETWEEN @FromDate AND @ToDate
				AND fb.StatusID NOT IN (11001,11004,11019,11016)
				AND DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
				AND DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration
				AND r.siteoffer=@UserRole
		
		SELECT @cols = COALESCE(@cols + ',[' + r.SettingValue + ']','[' + r.SettingValue + ']')
		FROM	@Items i INNER JOIN crmSetting r WITH(NOLOCK) ON i.Item = r.SettingID WHERE r.siteoffer=@UserRole
		--ORDER BY r.SettingValue ASC
		IF @UserRole=2
		BEGIN
			SELECT @sql = '	SELECT MainCategoryID, SubCategoryID, MainCategory, SubCategory, ' + @cols + '
							FROM (
					  				SELECT	DISTINCT fb.FeedbackID, 
											fs.SettingID as ''MainCategoryID'',
											m.SettingValue AS MainCategory, 
											fs.SubSettingID as ''SubCategoryID'',
											s.SettingValue AS SubCategory ,
											p.SettingValue As Communication
									FROM crmFeedback fb WITH(NOLOCK) 
											INNER JOIN crmFeedbackSetting fs  WITH(NOLOCK)	ON fb.FeedbackID=fs.FeedbackID	
											INNER JOIN crmSetting m WITH(NOLOCK) ON fs.SettingID = m.SettingID AND m.SettingName=''MainCategory'' AND m.siteoffer=2
											INNER JOIN crmSetting s WITH(NOLOCK) ON fs.SubSettingID = s.SettingID AND s.SettingName=''SubCategory'' AND s.siteoffer=2
											INNER JOIN crmFeedbackSetting st WITH(NOLOCK) ON fs.FeedbackID = st.FeedbackID
											INNER JOIN crmSetting p WITH(NOLOCK) ON st.SettingID = p.SettingID AND p.SettingName=''communication''
									WHERE fb.FeedbackDate BETWEEN @f AND @t
											AND fb.StatusID NOT IN (11001,11004,11019,11016)
											AND DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
											AND DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration
											AND p.siteoffer=2
								 ) p
								PIVOT
								(
									COUNT(FeedbackID)
									FOR Communication IN (' + @cols + ')
								) AS pvt
							ORDER BY MainCategory, SubCategory
							'
		END
		ELSE
		BEGIN
			SELECT @sql = '	SELECT MainCategoryID, SubCategoryID, MainCategory, SubCategory, ' + @cols + '
							FROM (
					  				SELECT	DISTINCT fb.FeedbackID, 
											fs.SettingID as ''MainCategoryID'',
											m.SettingValue AS MainCategory, 
											fs.SubSettingID as ''SubCategoryID'',
											s.SettingValue AS SubCategory ,
											p.SettingValue As Communication
									FROM crmFeedback fb WITH(NOLOCK) 
											INNER JOIN crmFeedbackSetting fs  WITH(NOLOCK)	ON fb.FeedbackID=fs.FeedbackID	
											INNER JOIN crmSetting m WITH(NOLOCK) ON fs.SettingID = m.SettingID AND m.SettingName=''MainCategory'' AND m.siteoffer=1
											INNER JOIN crmSetting s WITH(NOLOCK) ON fs.SubSettingID = s.SettingID AND s.SettingName=''SubCategory'' AND s.siteoffer=1
											INNER JOIN crmFeedbackSetting st WITH(NOLOCK) ON fs.FeedbackID = st.FeedbackID
											INNER JOIN crmSetting p WITH(NOLOCK) ON st.SettingID = p.SettingID AND p.SettingName=''communication''
									WHERE fb.FeedbackDate BETWEEN @f AND @t
											AND fb.StatusID NOT IN (11001,11004,11019,11016)
											AND DATEDIFF(s,FeedbackDate,ResolutionDate) >= @fDuration
											AND DATEDIFF(s,FeedbackDate,ResolutionDate) <= @tDuration
											AND p.siteoffer=1
								 ) p
								PIVOT
								(
									COUNT(FeedbackID)
									FOR Communication IN (' + @cols + ')
								) AS pvt
							ORDER BY MainCategory, SubCategory
							'
		END
		EXECUTE sp_executesql @sql, @ParamDefinition, @f = @FromDate, @t = @ToDate, @fDuration = @fDuration, @tDuration = @tDuration

		SELECT	Item
		FROM	@Items i

		RETURN
	END
END


GO
