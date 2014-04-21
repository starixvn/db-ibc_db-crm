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
		SELECT	ISNULL(fb.MainCategoryID, 0) AS MainCategoryID,
				ISNULL(fb.SubcategoryID,0) AS SubcategoryID,					
				SUM(CASE WHEN CommunicationID = 1000 THEN 1 ELSE 0 END) Call,
				SUM(CASE WHEN CommunicationID = 1001 THEN 1 ELSE 0 END) Email,
				SUM(CASE WHEN CommunicationID = 1002 THEN 1 ELSE 0 END) MSN,
				SUM(CASE WHEN CommunicationID = 1003 THEN 1 ELSE 0 END) Skype,
				SUM(CASE WHEN CommunicationID = 1004 THEN 1 ELSE 0 END) LiveChat,
				SUM(CASE WHEN CommunicationID = 1005 THEN 1 ELSE 0 END) NA,
				SUM(CASE WHEN CommunicationID = 1006 THEN 1 ELSE 0 END) Yahoo,	
				SUM(CASE WHEN CommunicationID = 1007 THEN 1 ELSE 0 END) WeChat,
				SUM(CASE WHEN CommunicationID = 1008 THEN 1 ELSE 0 END) Line,
				SUM(CASE WHEN CommunicationID = 1009 THEN 1 ELSE 0 END) WhatsApp,
				SUM(CASE WHEN CommunicationID = 1010 THEN 1 ELSE 0 END) QQ
	
		FROM crmFeedback fb WITH(NOLOCK) 
		LEFT JOIN crmSite [site] WITH(NOLOCK) ON [site].SiteID = fb.SiteID
		WHERE fb.feedbackdate BETWEEN @fromdate AND @todate
				AND fb.ProductID NOT IN (8003, 8005, 8011, 8013, 8014, 8017)
				AND fb.StatusID NOT IN (11004, 11001)
				AND ((([site].SiteID BETWEEN 6000 AND 6199 OR fb.SiteID = 0) AND fb.ProductID <> 8008) OR ([site].SiteID BETWEEN 6200 AND 6999))
		
		GROUP BY ISNULL(fb.MainCategoryID, 0),
				ISNULL(fb.SubcategoryID,0)
		ORDER  BY ISNULL(fb.MainCategoryID, 0),
				ISNULL(fb.SubcategoryID,0)

		select m.MainCategoryID,
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
		INNER JOIN crmSubCategory s WITH(NOLOCK) ON s.MainCategoryID = m.MainCategoryID
		LEFT JOIN #data d on d.MainCategoryID = m.MainCategoryID and d.SubcategoryID = s.SubCategoryID
		ORDER by m.MainCategoryID,s.SubcategoryID
		DROP TABLE #data
	END
	ELSE IF @SiteType = 1
	BEGIN
		INSERT INTO #DATA			
		SELECT	ISNULL(fb.MainCategoryID, 0) AS MainCategoryID,
				ISNULL(fb.SubcategoryID,0) AS SubcategoryID,					
				SUM(CASE WHEN CommunicationID = 1000 THEN 1 ELSE 0 END) Call,
				SUM(CASE WHEN CommunicationID = 1001 THEN 1 ELSE 0 END) Email,
				SUM(CASE WHEN CommunicationID = 1002 THEN 1 ELSE 0 END) MSN,
				SUM(CASE WHEN CommunicationID = 1003 THEN 1 ELSE 0 END) Skype,
				SUM(CASE WHEN CommunicationID = 1004 THEN 1 ELSE 0 END) LiveChat,
				SUM(CASE WHEN CommunicationID = 1005 THEN 1 ELSE 0 END) NA,
				SUM(CASE WHEN CommunicationID = 1006 THEN 1 ELSE 0 END) Yahoo,	
				SUM(CASE WHEN CommunicationID = 1007 THEN 1 ELSE 0 END) WeChat,
				SUM(CASE WHEN CommunicationID = 1008 THEN 1 ELSE 0 END) Line,
				SUM(CASE WHEN CommunicationID = 1009 THEN 1 ELSE 0 END) WhatsApp,
				SUM(CASE WHEN CommunicationID = 1010 THEN 1 ELSE 0 END) QQ			
		FROM crmFeedback fb WITH(NOLOCK) 
		LEFT JOIN crmSite [site] WITH(NOLOCK) ON [site].SiteID = fb.SiteID
		WHERE fb.feedbackdate BETWEEN @fromdate AND @todate
				AND fb.ProductID NOT IN (8003, 8005, 8011, 8013, 8014, 8017)
				AND fb.StatusID NOT IN (11004, 11001)
				AND (([site].SiteID BETWEEN 6000 AND 6199 OR fb.SiteID = 0) AND fb.ProductID <> 8008)
		
		GROUP BY ISNULL(fb.MainCategoryID, 0),
				ISNULL(fb.SubcategoryID,0)
		ORDER  BY ISNULL(fb.MainCategoryID, 0),
				ISNULL(fb.SubcategoryID,0)

		select m.MainCategoryID,
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
	ELSE IF @SiteType = 2
	BEGIN
		INSERT INTO #DATA			
		SELECT	ISNULL(fb.MainCategoryID, 0) AS MainCategoryID,
				ISNULL(fb.SubcategoryID,0) AS SubcategoryID,					
				SUM(CASE WHEN CommunicationID = 1000 THEN 1 ELSE 0 END) Call,
				SUM(CASE WHEN CommunicationID = 1001 THEN 1 ELSE 0 END) Email,
				SUM(CASE WHEN CommunicationID = 1002 THEN 1 ELSE 0 END) MSN,
				SUM(CASE WHEN CommunicationID = 1003 THEN 1 ELSE 0 END) Skype,
				SUM(CASE WHEN CommunicationID = 1004 THEN 1 ELSE 0 END) LiveChat,
				SUM(CASE WHEN CommunicationID = 1005 THEN 1 ELSE 0 END) NA,
				SUM(CASE WHEN CommunicationID = 1006 THEN 1 ELSE 0 END) Yahoo,	
				SUM(CASE WHEN CommunicationID = 1007 THEN 1 ELSE 0 END) WeChat,
				SUM(CASE WHEN CommunicationID = 1008 THEN 1 ELSE 0 END) Line,
				SUM(CASE WHEN CommunicationID = 1009 THEN 1 ELSE 0 END) WhatsApp,
				SUM(CASE WHEN CommunicationID = 1010 THEN 1 ELSE 0 END) QQ			
		FROM crmFeedback fb WITH(NOLOCK) 
		LEFT JOIN crmSite [site] WITH(NOLOCK) ON [site].SiteID = fb.SiteID
		WHERE fb.feedbackdate BETWEEN @fromdate AND @todate
				AND fb.ProductID NOT IN (8003, 8005, 8011, 8013, 8014, 8017)
				AND fb.StatusID NOT IN (11004, 11001)
				AND ([site].SiteID BETWEEN 6200 AND 6999)
		
		GROUP BY ISNULL(fb.MainCategoryID, 0),
				ISNULL(fb.SubcategoryID,0)
		ORDER  BY ISNULL(fb.MainCategoryID, 0),
				ISNULL(fb.SubcategoryID,0)

		select m.MainCategoryID,
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
	
END


GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_Rpt_CustomerStatistics] TO [bodbAdminNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_Rpt_CustomerStatistics] TO [vnteam]
GO 
