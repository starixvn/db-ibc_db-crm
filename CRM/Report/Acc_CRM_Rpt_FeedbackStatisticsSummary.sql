ALTER PROC [dbo].[Acc_CRM_Rpt_FeedbackStatisticsSummary]
(
	@Year INT
)
AS
/*
Created: Dom
Date: 20140408
Task : feedback statistics Summary report
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
			MONTH(f.FeedbackDate) m,
			LEFT(DATENAME(mm,f.FeedbackDate),3) [Month],
			m.MainCategoryID,
			m.Name MainCategory,
			s.SubCategoryID,
			s.Name SubCategory,
			COUNT(f.FeedbackID) NoOfIssues FROM crmFeedback f WITH(NOLOCK) 
	INNER JOIN crmMainCategory m WITH(NOLOCK)  ON m.MainCategoryID = f.MainCategoryID
	INNER JOIN crmSubCategory s WITH(NOLOCK)  ON s.MainCategoryID = m.MainCategoryID and f.SubCategoryID = s.SubCategoryID
	WHERE f.StatusID <> 11004
		AND f.FeedbackDate >= @FromDate AND f.FeedbackDate < @ToDate
	GROUP BY MONTH(f.FeedbackDate),
			LEFT(DATENAME(mm,f.FeedbackDate),3),
			m.MainCategoryID,
			m.Name,
			s.SubCategoryID,
			s.Name
	ORDER BY	m.Name,
				s.SubCategoryID,
				Month(f.FeedbackDate)
END

GO
GRANT EXECUTE ON [dbo].[Acc_CRM_Rpt_FeedbackStatisticsSummary] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_Rpt_FeedbackStatisticsSummary] TO [vnteam] 
GO
--[Acc_CRM_Rpt_FeedbackStatisticsSummary] 2012

