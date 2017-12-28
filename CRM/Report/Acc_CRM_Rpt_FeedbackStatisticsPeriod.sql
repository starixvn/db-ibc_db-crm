/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet,vnteam" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_Rpt_FeedbackStatisticsPeriod]
(
	@FromDate		DATETIME,
	@ToDate			DATETIME,
	@MainCategoryID INT = 0,
	@SubCategoryID	INT = 0
)
AS
/*
Created: Dom
Date: 20140408
Task : feedback statistics report period
DB: DBCRM.bodb_CRM
Original:

Revisions:
		- 20171225@Winnie: Change for support multiple product/categories. [RedmineID: #84714]
		
Param's Explanation:
	
*/
BEGIN
	SET NOCOUNT ON

	IF(@MainCategoryID<>0)
	BEGIN
		SELECT m.Name MainCategory, 
				s.Name SubCategory, 
				f.FeedbackDate,
				ISNULL(f.CountryID,0) CountryID,
				ISNULL(c.CountryName,'N/A') CountryName,
				COUNT(distinct f.FeedbackID) NoOfIssues 
		FROM crmFeedback f WITH(NOLOCK)	
		INNER JOIN dbo.f_GetFeedbackSetting(0,@MainCategoryID,@SubCategoryID,2) fs ON f.FeedbackID=fs.FeedbackID	
		INNER JOIN crmMainCategory m WITH(NOLOCK)  ON m.MainCategoryID = fs.SettingID 
		INNER JOIN crmSubCategory s WITH(NOLOCK)  ON  fs.SubSettingID = s.SubCategoryID AND s.MainCategoryID = m.MainCategoryID 
		LEFT JOIN crmCountry c WITH(NOLOCK) ON c.CountryID = f.CountryID 
		WHERE f.StatusID <> 11004
		AND f.FeedbackDate BETWEEN @FromDate AND @ToDate
		AND (@MainCategoryID = 0 OR f.MainCategoryID = @MainCategoryID)
		AND (@SubCategoryID = 0 OR f.SubCategoryID = @SubCategoryID)
		GROUP BY m.Name, s.Name, f.FeedbackDate,c.CountryName,f.CountryID
		ORDER BY f.FeedbackDate DESC
	END
	ELSE 
	BEGIN
		SELECT m.Name MainCategory, 
				s.Name SubCategory, 
				f.FeedbackDate,
				ISNULL(f.CountryID,0) CountryID,
				ISNULL(c.CountryName,'N/A') CountryName,
				COUNT(distinct f.FeedbackID) NoOfIssues 
		FROM crmFeedback f WITH(NOLOCK)	
		INNER JOIN crmFeedbackSetting fs  WITH(NOLOCK)	ON f.FeedbackID=fs.FeedbackID	
		INNER JOIN crmMainCategory m WITH(NOLOCK)  ON m.MainCategoryID = fs.SettingID
		INNER JOIN crmSubCategory s WITH(NOLOCK)  ON  fs.SubSettingID = s.SubCategoryID AND s.MainCategoryID = m.MainCategoryID 
		LEFT JOIN crmCountry c WITH(NOLOCK) ON c.CountryID = f.CountryID 
		WHERE f.StatusID <> 11004
		AND f.FeedbackDate BETWEEN @FromDate AND @ToDate
		AND (@MainCategoryID = 0 OR f.MainCategoryID = @MainCategoryID)
		AND (@SubCategoryID = 0 OR f.SubCategoryID = @SubCategoryID)
		GROUP BY m.Name, s.Name, f.FeedbackDate,c.CountryName,f.CountryID
		ORDER BY f.FeedbackDate DESC
	END
END



GO
