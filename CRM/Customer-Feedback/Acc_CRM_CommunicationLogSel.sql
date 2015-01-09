
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

/****** Object:  Stored Procedure dbo.Acc_CRM_CommunicationLogSel    Script Date: 3/26/2014 6:06:04 PM ******/
ALTER PROC [dbo].[Acc_CRM_CommunicationLogSel]
	@FeedbackID INT
AS

/*
Created: Dom
Date: 20140120
Task : Select Communication Log detail
DB: DB052.bodb_CRM
Original:

Revisions:
	- 20141118@Dom: add more fields of communication tool
*/

SELECT f.FeedbackID,
		f.CustID,
		c.UserName,
		f.FeedbackDate,
		f.ResolutionDate,
		f.CommunicationID,
		f.MainCategoryID,
		f.ProductID,
		f.StatusID,
		f.RoleID,
		f.StationID,
		f.CountryID,
		f.LanguageID,
		f.SubCategoryID,
		f.BetTypeID,
		f.SiteID,
		f.ResponseID,
		f.Subject,
		f.Description,
		f.Solution,
		f.IsReviewed,
		f.Review,
		review.username reviewer,
		f.SolveDate,
		f.LicenseeType
FROM crmFeedback(nolock) f
LEFT join crmCustomer(nolock) c on c.CustID = f.CustID
LEFT JOIN bodb02.dbo.Customer(NOLOCK) review on f.ReviewerID = review.custid
WHERE f.FeedbackID = @FeedbackID



SELECT cf.CustID,ISNULL(c.UserName,c1.username ) UserName
FROM crmFeedbackCustomer(NOLOCK) cf 
LEFT JOIN crmCustomer(NOLOCK) c ON c.CustID = cf.CustID
LEFT JOIN bodb02.dbo.Customer(NOLOCK) c1 ON c1.custid = cf.CustID
WHERE cf.FeedbackID = @FeedbackID 
AND cf.IsRelated = 1


GO

SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GO 
 GRANT EXECUTE ON [dbo].[Acc_CRM_CommunicationLogSel] TO [bodbAdminNet]
GO 
 GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_CommunicationLogSel] TO [vnteam]
GO 
