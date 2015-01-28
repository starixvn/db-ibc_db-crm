ALTER PROC [dbo].[Acc_CRM_Rpt_FeedbackStatisticsWagers]
(
	@Year INT,
	@TimeSpan INT
)
AS
/*
Created: Dom
Date: 20140408
Task : feedback statistics Wagers report
DB: DBCRM.bodb_CRM
Original:

Revisions:
		
		
Param's Explanation:
	
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @FromDate datetime
		, @ToDate datetime
	SELECT @FromDate = DATEADD(hour,@TimeSpan,CONVERT( DATETIME, CAST (@Year AS VARCHAR(10))+'01'+'01',102 ));
	SELECT @ToDate = DATEADD(year,1,@FromDate);

	SELECT MONTH( DATEADD(hour,-@TimeSpan,f.FeedbackDate) ) m,
			LEFT(DATENAME(mm,DATEADD(hour,-@TimeSpan,f.FeedbackDate)),3) [Month],
			s.Name SubCategory,
			COUNT(f.FeedbackID) NoOfIssues FROM crmFeedback f WITH(NOLOCK) 
	INNER JOIN crmSubCategory s WITH(NOLOCK)  ON f.MainCategoryID = s.MainCategoryID and f.SubCategoryID = s.SubCategoryID
	WHERE f.StatusID <> 11004
		AND f.MainCategoryID = 3010
		AND f.FeedbackDate >= @FromDate AND f.FeedbackDate < @ToDate
	GROUP BY MONTH( DATEADD(hour,-@TimeSpan,f.FeedbackDate) ), 
			LEFT(DATENAME(mm,DATEADD(hour,-@TimeSpan,f.FeedbackDate)),3),
			s.Name
	ORDER BY MONTH( DATEADD(hour,-@TimeSpan,f.FeedbackDate) )
END

GO
GRANT EXECUTE ON [dbo].[Acc_CRM_Rpt_FeedbackStatisticsWagers] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_Rpt_FeedbackStatisticsWagers] TO [vnteam] 
GO
--[Acc_CRM_Rpt_FeedbackStatisticsWagers] 2012

