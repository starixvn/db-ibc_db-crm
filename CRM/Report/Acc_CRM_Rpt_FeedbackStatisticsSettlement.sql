ALTER PROC [dbo].[Acc_CRM_Rpt_FeedbackStatisticsSettlement]
(
	@Year INT
)
AS
/*
Created: Dom
Date: 20140408
Task : feedback statistics settlement report
DB: DBCRM.bodb_CRM
Original:

Revisions:
		
		
Param's Explanation:
	
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @FromDate smalldatetime, @ToDate smalldatetime
	SELECT @FromDate = CAST (@Year AS VARCHAR(10))+'01'+'01';
	SELECT @ToDate = DATEADD(year,1,@FromDate);

	SELECT 
			Month(f.FeedbackDate) [Month],
			f.CountryID,
			c.CountryName,
			COUNT(f.FeedbackID) NoOfIssues FROM crmFeedback f WITH(NOLOCK) 
	--LEFT JOIN crmMainCategory m WITH(NOLOCK)  ON m.MainCategoryID = f.MainCategoryID
	--LEFT JOIN crmSubCategory s WITH(NOLOCK)  ON s.MainCategoryID = m.MainCategoryID and f.SubCategoryID = s.SubCategoryID
	LEFT JOIN crmCountry c WITH(NOLOCK) ON c.CountryID = f.CountryID
	WHERE f.StationID <> 11004
		AND f.MainCategoryID = 3012
		AND f.FeedbackDate >= @FromDate AND f.FeedbackDate < @ToDate
	GROUP BY Month(f.FeedbackDate),
			f.CountryID,
			c.CountryName
END

GO
GRANT EXECUTE ON [dbo].[Acc_CRM_Rpt_FeedbackStatisticsSettlement] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_Rpt_FeedbackStatisticsSettlement] TO [vnteam] 
GO
--[Acc_CRM_Rpt_FeedbackStatisticsSettlement] 2012
