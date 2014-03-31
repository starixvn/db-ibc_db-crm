
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.Acc_CRM_Rpt_CustomerStatisticsDetail    Script Date: 3/26/2014 6:06:09 PM ******/


CREATE PROCEDURE [dbo].[Acc_CRM_Rpt_CustomerStatisticsDetail]
(
	@fromdate	DATETIME,
	@todate		DATETIME,
	@SiteType   SMALLINT = 0
)
AS
/*
	Created: 20110830@Lukas	
	Task :  customer feedback detail report
	DB: DB052.bodb_CRM
	Original:

	Revisions:
		- 20110307@Sophia:	Add parametter @SiteType
							Add column ProductID
	    - 20110312@Sophia: . Show Number Game (ProductID = 8008) for Licensee only
						   . Add condition if SiteID = 0 then list this feedback into IBC group	
						   . Change server name to DB052 instead of DB06
		- 20120420@Sophia: Exclude ProductID = 8014 for Live Casino 	
		- 20120425@Sophia: remove converting @FromDate, @Todate
		- 20120710@Sophia: Exclude ProductID = 8013 for Mini Game 
		- 20120730@Sophia: Exclude ProductID = 8017 for Poker
		- 20130805@Kathy:  Exclude ProductID = 8005 for Bingo
		- 20140303@Dom: Modify for new structure
	Param's Explanation:
		@SiteType: 	0: All
					1: IBC
					2: Licensee				
*/
BEGIN
	SET NOCOUNT ON	

 	
	SELECT	FeedbackID, 
			fb.CustID, 
			fb.TitleID, 
			c.UserName, 
			fb.FirstName, 
			fb.LastName, 
			fb.Phone, 					
			fb.MobilePhone, 
			fb.Fax, 
			fb.Email, 
			fb.Skype, 
			fb.MSN,
			fb.ProductID, 
			fb.LanguageID, 
			fb.CountryID, 
			fb.CreateDate, 		
			fb.CreatorID, 
			ci.UserName as CreatorName, 
			fb.FeedbackDate, 
			fb.ResolutionDate,
			fb.SolveDate, 
			fb.CommunicationID, 
			fb.StationID, 
			fb.MainCategoryID, 		
			fb.SubCategoryID, 
			fb.SiteID, 
			fb.RoleID, 
			fb.ProductID, 
			fb.BetTypeID, 
			fb.ResponseID, 
			fb.StatusID, 		
			fb.Description, 
			fb.Solution, 
			fb.IsReviewed, 
			fb.Review, 
			fb.ReviewerID, 
			fb.Subject
	FROM crmFeedback fb WITH(NOLOCK)
		INNER JOIN crmCustomer c WITH(NOLOCK) ON fb.CustID = c.CustID		
		LEFT JOIN bodb02.dbo.custinfo ci WITH(NOLOCK) ON fb.CreatorID = ci.custID
		LEFT JOIN crmSetting st WITH(NOLOCK) ON fb.SiteID = st.SettingID
	WHERE fb.feedbackdate BETWEEN @fromdate AND @todate		
		AND fb.ProductID NOT IN (8003, 8005, 8011, 8013, 8014, 8017)
		AND fb.StatusID <> 11004
		AND 1 = CASE  WHEN @SiteType = 0 AND (((st.SettingID BETWEEN 6000 AND 6199 OR fb.SiteID = 0) AND fb.ProductID <> 8008) OR (st.SettingID BETWEEN 6200 AND 6999)) THEN 1
					  WHEN @SiteType = 1 AND (st.SettingID BETWEEN 6000 AND 6199 OR fb.SiteID = 0) AND fb.ProductID <> 8008 THEN 1
					  WHEN @SiteType = 2 AND st.SettingID BETWEEN 6200 AND 6999 THEN 1
					  ELSE 0 END 	
	ORDER BY fb.feedbackdate DESC
END



GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_Rpt_CustomerStatisticsDetail] TO [bodbAdminNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_Rpt_CustomerStatisticsDetail] TO [vnteam]
GO 
