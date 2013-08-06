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

	DECLARE @category TABLE (MaincategoryID INT, Maincategory NVARCHAR(100),
							 SubcategoryID INT, Subcategory NVARCHAR(100))
	
	INSERT INTO @category(MaincategoryID, Maincategory, SubcategoryID, Subcategory)
	SELECT m.SettingID, m.SettingValue, s.SettingID, s.SettingValue
	FROM crmSettingRelation r WITH(NOLOCK)
		INNER JOIN crmSetting m WITH(NOLOCK) ON r.ParentID = m.SettingID
		INNER JOIN crmSetting s WITH(NOLOCK) ON r.SettingID = s.SettingID
	WHERE s.SettingName = 'Subcategory'
		AND 
		m.SettingName = 'Maincategory'	
	
	;WITH rs AS
	(
		SELECT	ISNULL(m.SettingID, 0) AS MainCategoryID,
				ISNULL(m.SettingValue,'N/A') AS MainCategory, 
				ISNULL(s.SettingID,0) AS SubcategoryID,
				ISNULL(s.SettingValue,'N/A') AS Subcategory,							
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
				LEFT JOIN crmSetting m WITH(NOLOCK) ON fb.MainCategoryID = m.SettingID
				LEFT JOIN crmSetting s WITH(NOLOCK) ON fb.SubCategoryID = s.SettingID
				LEFT JOIN crmSetting st WITH(NOLOCK) ON fb.SiteID = st.SettingID
		WHERE fb.feedbackdate BETWEEN @fromdate AND @todate
				AND fb.ProductID NOT IN (8003, 8005, 8011, 8013, 8014, 8017)
				AND fb.StatusID NOT IN (11004, 11001)
				AND  1 = CASE WHEN @SiteType = 0 AND (((st.SettingID BETWEEN 6000 AND 6199 OR fb.SiteID = 0) AND fb.ProductID <> 8008) OR (st.SettingID BETWEEN 6200 AND 6999)) THEN 1
							  WHEN @SiteType = 1 AND (st.SettingID BETWEEN 6000 AND 6199 OR fb.SiteID = 0) AND fb.ProductID <> 8008 THEN 1
							  WHEN @SiteType = 2 AND st.SettingID BETWEEN 6200 AND 6999 THEN 1
							  ELSE 0 END 				
		GROUP BY m.SettingID,m.SettingValue, s.SettingID, s.SettingValue
	)
	SELECT c.MaincategoryID, c.Maincategory, c.SubcategoryID, c.Subcategory,
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
			
	FROM @category c LEFT JOIN rs ON c.MaincategoryID = rs.MaincategoryID AND c.SubcategoryID = rs.SubcategoryID
	ORDER BY MaincategoryId, SubcategoryID
END

GO
GRANT EXECUTE ON [dbo].[Acc_CRM_Rpt_CustomerStatistics] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_Rpt_CustomerStatistics] TO [vnteam]