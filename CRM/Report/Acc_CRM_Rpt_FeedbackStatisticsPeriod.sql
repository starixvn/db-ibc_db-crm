/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_Rpt_FeedbackStatisticsPeriod]
(
	@FromDate		DATETIME,
	@ToDate			DATETIME,
	@MainCategoryID INT = 0,
	@SubCategoryID	INT = 0,
	@UserRole		INT = 2
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
		- 20190506@Winnie:  CN88 Permission RedmineID: #112637     
Param's Explanation:
	
*/
BEGIN
	SET NOCOUNT ON

	IF(@MainCategoryID<>0)
	BEGIN
		SELECT 		
				f.FeedbackDate,
				ISNULL(f.CountryID,0) CountryID,
				ISNULL(c.CountryName,'N/A') CountryName,
				COUNT(distinct f.FeedbackID) NoOfIssues 
		FROM crmFeedback f WITH(NOLOCK)	
		INNER JOIN dbo.f_GetFeedbackSetting(0,@MainCategoryID,@SubCategoryID,2) fs ON f.FeedbackID=fs.FeedbackID		
		LEFT JOIN crmCountry c WITH(NOLOCK) ON c.CountryID = f.CountryID 
		WHERE f.StatusID NOT IN( 11004,11019)
		AND f.FeedbackDate BETWEEN @FromDate AND @ToDate	
		AND c.siteoffer=@UserRole
		GROUP BY f.FeedbackDate,c.CountryName,f.CountryID
		ORDER BY f.FeedbackDate DESC
	END
	ELSE 
	BEGIN
		SELECT 
				f.FeedbackDate,
				ISNULL(f.CountryID,0) CountryID,
				ISNULL(c.CountryName,'N/A') CountryName,
				COUNT(distinct f.FeedbackID) NoOfIssues 
		FROM crmFeedback f WITH(NOLOCK)	
		LEFT JOIN crmCountry c WITH(NOLOCK) ON c.CountryID = f.CountryID 
		WHERE f.StatusID NOT IN( 11004,11019)
		AND f.FeedbackDate BETWEEN @FromDate AND @ToDate	
		AND c.siteoffer=@UserRole	
		GROUP BY 
				 f.FeedbackDate,c.CountryName,f.CountryID
		ORDER BY f.FeedbackDate DESC
	END
END



GO
