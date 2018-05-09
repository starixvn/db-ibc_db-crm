/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet,vnteam" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_Rpt_CustomerStatistics]
(
	@fromdate	DATETIME,
	@todate		DATETIME,
	@SiteType   SMALLINT = 0
)
AS
/*
	Created: 20110826@Lukas	
	Task :  daily summary on customer feedback
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20111126@Sophia: Not to show Status is Pending (StatusID = 11001)	
		- 20110307@Sophia: Add parametter @SiteType
		- 20110312@Sophia: . Show Number Game (ProductID = 8008) for Licensee only
						   . Add condition if SiteID = 0 then list this feedback into IBC group
						   . Change server name to DB052 instead of DB06
		- 20120420@Sophia: Exclude ProductID = 8014 for Live Casino 
		- 20120425@Sophia: remove converting @FromDate, @Todate
		- 20120710@Sophia: Exclude ProductID = 8013 for Mini Game
		- 20120730@Sophia: Exclude ProductID = 8017 for Poker
		- 20130607@Elodie: Add CommunicationID (1005->1010)
		- 20130805@Kathy:  Exclude ProductID = 8005 for Bingo
		- 20140523@Dom: modify site condition
		- 20171225@Winnie: Change for support multiple product/categories. [RedmineID: #84714]	
	Param's Explanation:
		@SiteType: 	0: All
					1: IBC
					2: Licensee
								
*/
BEGIN
	SET NOCOUNT ON
	CREATE TABLE #DATA(MainCategoryID INT,SubcategoryID INT,Call BIGINT,Email BIGINT,MSN BIGINT,Skype BIGINT,LiveChat BIGINT,NA BIGINT,Yahoo BIGINT,WeChat BIGINT,Line BIGINT,WhatsApp BIGINT,QQ BIGINT)

	IF @SiteType = 0
	BEGIN			
		INSERT INTO #DATA	
		SELECT	ISNULL(fm.SettingID, 0) AS MainCategoryID,
				ISNULL(fm.SubSettingID,0) AS SubcategoryID,					
				SUM(CASE WHEN fc.SettingID = 1000 THEN 1 ELSE 0 END) Call,
				SUM(CASE WHEN fc.SettingID = 1001 THEN 1 ELSE 0 END) Email,
				SUM(CASE WHEN fc.SettingID = 1002 THEN 1 ELSE 0 END) MSN,
				SUM(CASE WHEN fc.SettingID = 1003 THEN 1 ELSE 0 END) Skype,
				SUM(CASE WHEN fc.SettingID = 1004 THEN 1 ELSE 0 END) LiveChat,
				SUM(CASE WHEN fc.SettingID = 1005 THEN 1 ELSE 0 END) NA,
				SUM(CASE WHEN fc.SettingID = 1006 THEN 1 ELSE 0 END) Yahoo,	
				SUM(CASE WHEN fc.SettingID = 1007 THEN 1 ELSE 0 END) WeChat,
				SUM(CASE WHEN fc.SettingID = 1008 THEN 1 ELSE 0 END) Line,
				SUM(CASE WHEN fc.SettingID = 1009 THEN 1 ELSE 0 END) WhatsApp,
				SUM(CASE WHEN fc.SettingID = 1010 THEN 1 ELSE 0 END) QQ
	
		FROM crmFeedback fb WITH(NOLOCK) 
		INNER JOIN crmFeedbackSetting fm WITH(NOLOCK) ON fb.FeedbackID=fm.FeedbackID
		INNER JOIN crmFeedbackSetting fc WITH(NOLOCK) ON fb.FeedbackID=fc.FeedbackID
		INNER JOIN crmMainCategory m WITH(NOLOCK) ON fm.SettingID=m.MainCategoryID			
		INNER JOIN crmFeedbackSetting fp WITH(NOLOCK) ON fb.FeedbackID=fp.FeedbackID
		INNER JOIN crmSetting p WITH(NOLOCK) ON fp.SettingID=p.SettingID AND p.SettingName='Product'	
		LEFT JOIN crmSite [site] WITH(NOLOCK) ON [site].SiteID = fb.SiteID
		WHERE fb.feedbackdate BETWEEN @fromdate AND @todate
				AND fp.SubSettingID NOT IN (8003, 8005, 8008, 8011, 8013, 8014, 8017)
				AND fb.StatusID NOT IN (11004, 11001)
				AND ((([site].IsLicensee=0 OR fb.SiteID = 0)) OR ([site].IsLicensee=1))		
		GROUP BY	ISNULL(fm.SettingID, 0),
					ISNULL(fm.SubSettingID,0)				
		ORDER  BY ISNULL(fm.SettingID, 0),
				ISNULL(fm.SubSettingID,0)

	END
	ELSE IF @SiteType = 1
	BEGIN
		INSERT INTO #DATA	
		SELECT	ISNULL(fm.SettingID, 0) AS MainCategoryID,
				ISNULL(fm.SubSettingID,0) AS SubcategoryID,						
				SUM(CASE WHEN fc.SettingID = 1000 THEN 1 ELSE 0 END) Call,
				SUM(CASE WHEN fc.SettingID = 1001 THEN 1 ELSE 0 END) Email,
				SUM(CASE WHEN fc.SettingID = 1002 THEN 1 ELSE 0 END) MSN,
				SUM(CASE WHEN fc.SettingID = 1003 THEN 1 ELSE 0 END) Skype,
				SUM(CASE WHEN fc.SettingID = 1004 THEN 1 ELSE 0 END) LiveChat,
				SUM(CASE WHEN fc.SettingID = 1005 THEN 1 ELSE 0 END) NA,
				SUM(CASE WHEN fc.SettingID = 1006 THEN 1 ELSE 0 END) Yahoo,	
				SUM(CASE WHEN fc.SettingID = 1007 THEN 1 ELSE 0 END) WeChat,
				SUM(CASE WHEN fc.SettingID = 1008 THEN 1 ELSE 0 END) Line,
				SUM(CASE WHEN fc.SettingID = 1009 THEN 1 ELSE 0 END) WhatsApp,
				SUM(CASE WHEN fc.SettingID = 1010 THEN 1 ELSE 0 END) QQ			
		FROM crmFeedback fb WITH(NOLOCK) 
		INNER JOIN crmFeedbackSetting fm WITH(NOLOCK) ON fb.FeedbackID=fm.FeedbackID
		INNER JOIN crmFeedbackSetting fc WITH(NOLOCK) ON fb.FeedbackID=fc.FeedbackID		
		INNER JOIN crmMainCategory m WITH(NOLOCK) ON fm.SettingID=m.MainCategoryID	
		LEFT JOIN  crmSubCategory s WITH(NOLOCK) ON fm.SubSettingID=s.SubCategoryID AND s.MainCategoryID=m.MainCategoryID
		INNER JOIN crmFeedbackSetting fp WITH(NOLOCK) ON fb.FeedbackID=fp.FeedbackID
		INNER JOIN crmSetting p WITH(NOLOCK) ON fp.SettingID=p.SettingID AND p.SettingName='Product'	
		LEFT JOIN crmSite [site] WITH(NOLOCK) ON [site].SiteID = fb.SiteID
		WHERE fb.feedbackdate BETWEEN @fromdate AND @todate
				AND fp.SubSettingID NOT IN (8003, 8005, 8008, 8011, 8013, 8014, 8017)
				AND fb.StatusID NOT IN (11004, 11001)
				AND (([site].IsLicensee=0 OR fb.SiteID = 0))
		GROUP BY	ISNULL(fm.SettingID, 0),
					ISNULL(fm.SubSettingID,0)					
		ORDER  BY ISNULL(fm.SettingID, 0),
				ISNULL(fm.SubSettingID,0)
	END
	ELSE IF @SiteType = 2
	BEGIN
		INSERT INTO #DATA	
		SELECT	ISNULL(fm.SettingID, 0) AS MainCategoryID,
				ISNULL(fm.SubSettingID,0) AS SubcategoryID,											
				SUM(CASE WHEN fc.SettingID = 1000 THEN 1 ELSE 0 END) Call,
				SUM(CASE WHEN fc.SettingID = 1001 THEN 1 ELSE 0 END) Email,
				SUM(CASE WHEN fc.SettingID = 1002 THEN 1 ELSE 0 END) MSN,
				SUM(CASE WHEN fc.SettingID = 1003 THEN 1 ELSE 0 END) Skype,
				SUM(CASE WHEN fc.SettingID = 1004 THEN 1 ELSE 0 END) LiveChat,
				SUM(CASE WHEN fc.SettingID = 1005 THEN 1 ELSE 0 END) NA,
				SUM(CASE WHEN fc.SettingID = 1006 THEN 1 ELSE 0 END) Yahoo,	
				SUM(CASE WHEN fc.SettingID = 1007 THEN 1 ELSE 0 END) WeChat,
				SUM(CASE WHEN fc.SettingID = 1008 THEN 1 ELSE 0 END) Line,
				SUM(CASE WHEN fc.SettingID = 1009 THEN 1 ELSE 0 END) WhatsApp,
				SUM(CASE WHEN fc.SettingID = 1010 THEN 1 ELSE 0 END) QQ			
		FROM crmFeedback fb WITH(NOLOCK) 
		INNER JOIN crmFeedbackSetting fm WITH(NOLOCK) ON fb.FeedbackID=fm.FeedbackID
		INNER JOIN crmFeedbackSetting fc WITH(NOLOCK) ON fb.FeedbackID=fc.FeedbackID	
		INNER JOIN crmMainCategory m WITH(NOLOCK) ON fm.SettingID=m.MainCategoryID	
		LEFT JOIN  crmSubCategory s WITH(NOLOCK) ON fm.SubSettingID=s.SubCategoryID AND s.MainCategoryID=m.MainCategoryID
		INNER JOIN crmFeedbackSetting fp WITH(NOLOCK) ON fb.FeedbackID=fp.FeedbackID
		INNER JOIN crmSetting p WITH(NOLOCK) ON fp.SettingID=p.SettingID AND p.SettingName='Product'		
		LEFT JOIN crmSite [site] WITH(NOLOCK) ON [site].SiteID = fb.SiteID
		WHERE fb.feedbackdate BETWEEN @fromdate AND @todate
				AND fp.SubSettingID NOT IN (8003, 8005, 8008, 8011, 8013, 8014, 8017)
				AND fb.StatusID NOT IN (11004, 11001)
				AND ([site].IsLicensee=1)
		GROUP BY	ISNULL(fm.SettingID, 0),
					ISNULL(fm.SubSettingID,0)				
		ORDER  BY ISNULL(fm.SettingID, 0),
				ISNULL(fm.SubSettingID,0)

	END
	
	SELECT m.MainCategoryID,
			m.Name MainCategory,
			s.SubCategoryID,
			s.Name SubCategory,
			ISNULL(Call,0)		AS Call,
			ISNULL(Email,0)		AS Email,
			ISNULL(MSN,0)		AS MSN,
			ISNULL(Skype,0)		AS Skype,
			ISNULL(LiveChat,0)	AS LiveChat,
			ISNULL(NA,0)		AS NA,
			ISNULL(Yahoo,0)		AS Yahoo,
			ISNULL(WeChat,0)	AS WeChat,
			ISNULL(Line,0)		AS Line,
			ISNULL(WhatsApp,0)	AS WhatsApp,
			ISNULL(QQ,0)		AS QQ
		from crmMainCategory m WITH(NOLOCK) 
		INNER JOIN crmSubCategory s WITH(NOLOCK)  ON s.MainCategoryID = m.MainCategoryID
		LEFT JOIN #data d on d.MainCategoryID = m.MainCategoryID and d.SubcategoryID = s.SubCategoryID
		ORDER by m.MainCategoryID,s.SubcategoryID
		DROP TABLE #data	
END



GO
GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_Rpt_CustomerStatistics] TO [bodbAdminNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_Rpt_CustomerStatistics] TO [vnteam]
GO 
