
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.Acc_CRM_Rpt_DynamicFeedback    Script Date: 3/26/2014 6:06:09 PM ******/
CREATE PROCEDURE [dbo].[Acc_CRM_Rpt_DynamicFeedback]
	@FromDate DATETIME,
	@ToDate DATETIME,
	@ProductID INT = NULL,
	@StatusID INT = NULL,
	@RoleID INT = NULL,
	@MainCategoryID INT = NULL,
	@HandledBy NVARCHAR(30) = NULL,
	@Extension INT = NULL,
	@SiteID INT = NULL,
	@ResponseID INT = NULL,
	@CommunicationID INT = NULL,
	@SubCategoryID INT = NULL,
	@ReviewedBy NVARCHAR(30) = NULL,
	@Subject NVARCHAR(1000) = NULL
AS
/*
	Created: DOM
	Date: 20140228
	Task : Dynamic Report
	DB: DBCRM/bodb_CRM
	Original:

	Revisions:
		
	Param's Explanation:
		
*/

select @Subject = REPLACE(@Subject,'[','%')
select @Subject = REPLACE(@Subject,']','%')

DECLARE @HandledID INT,@ReviewedID INT

select @HandledID=CustID FROM bodb02.dbo.Customer WHERE UserName = @HandledBy
select @ReviewedID=CustID FROM bodb02.dbo.Customer WHERE UserName = @ReviewedBy


CREATE TABLE #Feedback (
	FeedbackID INT 
)
INSERT INTO #Feedback SELECT DISTINCT FeedbackID FROM crmFeedback f WITH(NOLOCK)WHERE FeedbackDate BETWEEN @FromDate AND @ToDate AND (ISNULL(@ProductID,0)=0 OR f.ProductID= @ProductID) AND (ISNULL(@StatusID,0)=0 OR f.StatusID= @StatusID) 
AND (ISNULL(@RoleID,0)=0 OR f.RoleID= @RoleID) 
AND (ISNULL(@MainCategoryID,0)=0 OR f.MainCategoryID= @MainCategoryID) 
AND (ISNULL(@HandledBy,'')='' OR f.CreatorID= @HandledID) 
AND (ISNULL(@SiteID,0)=0 OR f.SiteID= @SiteID) 
AND (ISNULL(@ResponseID,0)=0 OR f.ResponseID= @ResponseID) 
AND (ISNULL(@CommunicationID,0)=0 OR f.CommunicationID= @CommunicationID) 
AND (ISNULL(@SubCategoryID,0)=0 OR f.SubCategoryID= @SubCategoryID) 
AND (ISNULL(@ReviewedBy,'')='' OR f.ReviewerID= @ReviewedID) 
AND (ISNULL(@Extension,0)=0 OR f.StationID = @Extension ) 
AND (ISNULL(@Subject,'')='' OR f.Subject like '%'+@Subject+'%' ) 
AND f.StatusID <> 11004 

SELECT f.FeedbackID,
		f.FeedbackDate,
		mc.Name MainCategory, 
		sc.Name SubCategory,
		cast(datepart(hour,ResolutionDate - FeedbackDate) as varchar) + ' : ' +cast(datepart(MINUTE,ResolutionDate - FeedbackDate) as varchar) + ' : ' +cast(datepart(second,ResolutionDate - FeedbackDate) as varchar) Duration,
		f.Subject,
		st.Name Status,
		c.username HandledBy,
		rv.username ReviewedBy
FROM crmFeedback(NOLOCK) f
LEFT JOIN crmMainCategory(NOLOCK) mc ON mc.MainCategoryID = f.MainCategoryID
LEFT JOIN crmSubCategory(NOLOCK) sc ON sc.MainCategoryID= mc.MainCategoryID and sc.SubCategoryID = f.SubCategoryID
LEFT JOIN crmStatus(NOLOCK) st ON st.StatusID = f.StatusID
INNER JOIN bodb02.dbo.Customer(NOLOCK) c ON c.custid = f.CreatorID
LEFT JOIN bodb02.dbo.Customer(NOLOCK) rv ON rv.custid = f.ReviewerID
WHERE f.FeedbackID IN(SELECT feedbackid from #Feedback)
ORDER BY f.FeedbackDate DESC, f.FeedbackID DESC
DROP TABLE #Feedback

GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_Rpt_DynamicFeedback] TO [bodbAdminNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_Rpt_DynamicFeedback] TO [vnteam]
GO 
