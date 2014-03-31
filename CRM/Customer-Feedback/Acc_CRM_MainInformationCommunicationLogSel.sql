
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.Acc_CRM_MainInformationCommunicationLogSel    Script Date: 3/26/2014 6:06:07 PM ******/
CREATE PROC [dbo].[Acc_CRM_MainInformationCommunicationLogSel]
	@CustID INT
AS

/*
Created: Dom
Date: 20140212
Task : Get data for main tab
DB: DBCRM.bodb_CRM
Original:

Revisions:	
	
Param's Explanation:	
*/

SET ROWCOUNT 10

SELECT  DISTINCT f.FeedbackID,
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
INNER JOIN crmSubCategory(NOLOCK) sc ON sc.SubCategoryID = f.SubCategoryID AND sc.MainCategoryID = mc.MainCategoryID
INNER JOIN crmStatus(NOLOCK) st ON st.StatusID = f.StatusID
INNER JOIN bodb02.dbo.Customer(NOLOCK) Creator ON Creator.custid = f.CreatorID
LEFT JOIN bodb02.dbo.Customer(NOLOCK) Reviewer ON Reviewer.custid = f.ReviewerID
LEFT JOIN  crmFeedbackCustomer(NOLOCK) cf ON cf.FeedbackID = f.FeedbackID
WHERE (f.custid = @CustID OR cf.CustID = @CustID)
AND f.StatusID <> 11004 -- exclude deleted
ORDER BY f.FeedbackID DESC

GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_MainInformationCommunicationLogSel] TO [bodbAdminNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_MainInformationCommunicationLogSel] TO [vnteam]
GO 
