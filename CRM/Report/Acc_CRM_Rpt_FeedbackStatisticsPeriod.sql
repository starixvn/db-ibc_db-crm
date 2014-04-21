ALTER PROC [dbo].[Acc_CRM_Rpt_FeedbackStatisticsPeriod]
(
	@FromDate		DATETIME,
	@ToDate			DATETIME,
	@MainCategoryID INT = 0,
	@SubCategoryID INT = 0
)
AS
/*
Created: Dom
Date: 20140408
Task : feedback statistics report period
DB: DBCRM.bodb_CRM
Original:

Revisions:
		
		
Param's Explanation:
	
*/
BEGIN
	SET NOCOUNT ON

	SELECT m.Name MainCategory, 
			s.Name SubCategory, 
			f.FeedbackDate,
			ISNULL(f.CountryID,0) CountryID,
			ISNULL(c.CountryName,'N/A') CountryName,
			COUNT(f.FeedbackID) NoOfIssues FROM crmFeedback f WITH(NOLOCK) 
	LEFT JOIN crmMainCategory m WITH(NOLOCK)  ON m.MainCategoryID = f.MainCategoryID
	LEFT JOIN crmSubCategory s WITH(NOLOCK)  ON s.MainCategoryID = m.MainCategoryID and f.SubCategoryID = s.SubCategoryID
	LEFT JOIN crmCountry c WITH(NOLOCK) ON c.CountryID = f.CountryID
	WHERE f.StationID <> 11004
	AND f.FeedbackDate BETWEEN @FromDate AND @ToDate
	AND (@MainCategoryID = 0 OR f.MainCategoryID = @MainCategoryID)
	AND (@SubCategoryID = 0 OR f.SubCategoryID = @SubCategoryID)
	GROUP BY m.Name, s.Name, f.FeedbackDate,c.CountryName,f.CountryID
	ORDER BY f.CountryID ASC
END

GO
GRANT EXECUTE ON [dbo].[Acc_CRM_Rpt_FeedbackStatisticsPeriod] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_Rpt_FeedbackStatisticsPeriod] TO [vnteam] 
GO
--Acc_CRM_Rpt_FeedbackStatisticsPeriod '20140101','20140401'
