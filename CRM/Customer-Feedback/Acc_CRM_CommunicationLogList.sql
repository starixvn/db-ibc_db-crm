
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.Acc_CRM_CommunicationLogList    Script Date: 3/26/2014 6:06:04 PM ******/
CREATE PROC Acc_CRM_CommunicationLogList
	@CustID INT,
	@FromDate	DATETIME,
	@ToDate		DATETIME,
	@StatusID	INT = 0,
	@Handler	VARCHAR(30) = ''
AS

/*
Created: Dom
Date: 20140120
Task : update customer basic info
DB: DB052.bodb_CRM
Original:

Revisions:
*/

declare @handlerid int
select @handlerid = CustID
FROM bodb02.dbo.Customer(NOLOCK) WHERE UserName = @Handler

SELECT DISTINCT f.FeedbackID,
		FeedbackDate,
		mc.Name MainCategory,
		sc.Name SubCategory,
		f.Subject,
		st.Name Status,
		cast(datepart(hour,ResolutionDate - FeedbackDate) as varchar) + ' : ' +cast(datepart(MINUTE,ResolutionDate - FeedbackDate) as varchar) + ' : ' +cast(datepart(second,ResolutionDate - FeedbackDate) as varchar) Duration,
		Creator.username HandleBy,
		Reviewer.username ReviewBy
FROM crmFeedback(nolock) f
INNER JOIN crmMainCategory(NOLOCK) mc ON mc.MainCategoryID = f.MainCategoryID
INNER JOIN crmSubCategory(NOLOCK) sc ON sc.SubCategoryID = f.SubCategoryID and sc.MainCategoryID = mc.MainCategoryID
INNER JOIN crmStatus(NOLOCK) st ON st.StatusID = f.StatusID
INNER JOIN bodb02.dbo.Customer(NOLOCK) Creator ON Creator.custid = f.CreatorID
LEFT JOIN bodb02.dbo.Customer(NOLOCK) Reviewer ON Reviewer.custid = f.ReviewerID
LEFT JOIN crmFeedbackCustomer(NOLOCK) cf ON cf.FeedbackID = f.FeedbackID
WHERE (f.custid = @CustID OR cf.CustID = @CustID)
AND f.StatusID <> 11004 -- exclude deleted
and f.CreateDate BETWEEN @fromdate and @todate 
and (isnull(@handler,'')='' OR f.CreatorID = @handlerid)
and (isnull(@StatusID,0)=0 OR f.StatusID = @StatusID)
ORDER BY f.FeedbackID DESC

GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_CommunicationLogList] TO [bodbAdminNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_CommunicationLogList] TO [vnteam]
GO 
