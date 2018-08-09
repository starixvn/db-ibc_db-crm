 /*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet,vnteam" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE dbo.Acc_CRM_Rpt_FeedbackStatisticsSettlement
(
	@Year INT,
	@TimeSpan INT
)
AS
/*
Created: Dom
Date: 20140408
Task : feedback statistics settlement report
DB: DBCRM.bodb_CRM
Original:

Revisions:
		- 20171225@Winnie: Change for support multiple product/categories. [RedmineID: #84714]		
Param's Explanation:
	
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @FromDate datetime
		, @ToDate datetime
	SELECT @FromDate = DATEADD(hour,@TimeSpan,CONVERT( DATETIME, CAST (@Year AS VARCHAR(10))+'01'+'01',102 ));
	SELECT @ToDate = DATEADD(year,1,@FromDate);
	SELECT 
			MONTH( DATEADD(hour,-@TimeSpan,f.FeedbackDate)) [Month],
			f.CountryID,
			c.CountryName,
			COUNT(f.FeedbackID) NoOfIssues 
	FROM crmFeedback f WITH(NOLOCK) 
	 INNER JOIN crmFeedbackSetting fs WITH(NOLOCK) ON f.FeedbackID=fs.FeedbackID
	--LEFT JOIN crmMainCategory m WITH(NOLOCK)  ON m.MainCategoryID = f.MainCategoryID
	--LEFT JOIN crmSubCategory s WITH(NOLOCK)  ON s.MainCategoryID = m.MainCategoryID and f.SubCategoryID = s.SubCategoryID
	LEFT JOIN crmCountry c WITH(NOLOCK) ON c.CountryID = f.CountryID
	WHERE f.StatusID <> 11004
		AND fs.SettingID = 3025
		AND f.FeedbackDate >= @FromDate AND f.FeedbackDate < @ToDate
	GROUP BY MONTH( DATEADD(hour,-@TimeSpan,f.FeedbackDate)),
			f.CountryID,
			c.CountryName
END

GO
GRANT EXECUTE ON [dbo].[Acc_CRM_Rpt_FeedbackStatisticsSettlement] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_Rpt_FeedbackStatisticsSettlement] TO [vnteam] 
GO
--[Acc_CRM_Rpt_FeedbackStatisticsSettlement] 2010,-12

