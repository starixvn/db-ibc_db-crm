SET QUOTED_IDENTIFIER ON; 
GO
SET ANSI_NULLS ON; 
GO

ALTER PROCEDURE	dbo.Acc_CRM_CommunicationLogSel
					@FeedbackID INT
AS
/*
	Created:	Dom
	Date:		20140120
	Task:		Select Communication Log detail
	DB:			DB052.bodb_CRM
	Original:

	Revisions:
		- 20141118@Dom:		add more fields of communication tool
		- 20160308@Billy:	Integrate Sub-Product field - [Redmine: #52998]
*/
BEGIN
	SELECT	f.FeedbackID
		,	f.CustID
		,	c.UserName
		,	f.FeedbackDate
		,	f.ResolutionDate
		,	f.CommunicationID
		,	f.MainCategoryID
		,	f.ProductID
		,	f.SubProductID
		,	f.StatusID
		,	f.RoleID
		,	f.StationID
		,	f.CountryID
		,	f.LanguageID
		,	f.SubCategoryID
		,	f.BetTypeID
		,	f.SiteID
		,	f.ResponseID
		,	f.Subject
		,	f.Description
		,	f.Solution
		,	f.IsReviewed
		,	f.Review
		,	review.username reviewer
		,	f.SolveDate
		,	f.LicenseeType
	FROM		dbo.crmFeedback AS f WITH (NOLOCK)
	LEFT JOIN	dbo.crmCustomer AS c WITH (NOLOCK)
			ON	c.CustID = f.CustID
	LEFT JOIN	bodb02.dbo.Customer AS review WITH (NOLOCK)
			ON	f.ReviewerID = review.custid
	WHERE	f.FeedbackID = @FeedbackID;

	SELECT	cf.CustID
		,	ISNULL(c.UserName, c1.username ) UserName
	FROM		dbo.crmFeedbackCustomer AS cf WITH (NOLOCK)
	LEFT JOIN	dbo.crmCustomer AS c WITH (NOLOCK)
			ON	c.CustID = cf.CustID
	LEFT JOIN	bodb02.dbo.Customer AS c1 WITH (NOLOCK)
			ON	c1.custid = cf.CustID
	WHERE	cf.FeedbackID = @FeedbackID 
		AND	cf.IsRelated = 1;
END;
GO

GRANT EXECUTE ON dbo.Acc_CRM_CommunicationLogSel TO bodbAdminNet;
GO 
GRANT VIEW DEFINITION ON dbo.Acc_CRM_CommunicationLogSel TO vnteam;
GO 
