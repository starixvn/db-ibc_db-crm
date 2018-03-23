/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet,vnteam" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_FeedbackSelTop] (
					@top int = 10
				)	
AS
/*
	Created:	Kevin
	Date:		20110722
	Task :		get top 10 feedback info
	DB:			DB06.bodb_CRM
	Original:

	Revisions:
		- 20160308@Billy:	Integrate Sub-Product field - [Redmine: #52998]
		- 20180117@Winnie:	Add Is Related Customer - [Redmine: #88774]
	Param's Explanation:
	
*/
BEGIN		
	SET NOCOUNT ON;	
	;WITH temp AS 
	(
		SELECT TOP (@top)	fb.FeedbackID
						,	fb.CustID
						,	ctm.UserName
						,	fb.TitleID
						,	fb.FirstName
						,	fb.LastName
						,	fb.Phone
						,	fb.MobilePhone
						,	fb.Fax
						,	fb.Email
						,	fb.Skype
						,	fb.MSN
						,	fb.LanguageID
						,	fb.CountryID
						,	fb.CreatorID
						,	c.username AS CreatorName
						,	fb.FeedbackDate
						,	fb.ResolutionDate
						,	fb.CreateDate
						,	fb.SolveDate
						,	fb.CommunicationID
						,	fb.StationID
						,	fb.MainCategoryID
						,	fb.SubCategoryID
						,	fb.SiteID
						,	fb.RoleID
						,	fb.ProductID
						,	fb.SubProductID
						,	fb.BetTypeID
						,	fb.ResponseID
						,	fb.StatusID
						,	CAST(fb.Description AS XML) AS Description
						,	fb.Solution
						,	fb.IsReviewed
						,	fb.Review
						,	fb.ReviewerID
						,	rv.username AS ReviewerName
						,	fbc.IsRelated
						,	fb.Subject
						,	l.list AS relatedCustomer
		FROM	crmFeedbackCustomer fbc WITH (NOLOCK)
		INNER JOIN	crmFeedback fb WITH (NOLOCK)
				ON	fb.FeedbackID = fbc.FeedbackID
		INNER JOIN	crmCustomer ctm WITH (NOLOCK)
				ON	ctm.CustID = fb.CustID
		INNER JOIN	bodb02.dbo.custInfo c WITH (NOLOCK)
				ON	fb.CreatorID = c.custid
		LEFT JOIN	bodb02.dbo.custInfo rv WITH (NOLOCK)
				ON	fb.ReviewerID = rv.custid
		CROSS APPLY	dbo.f_GetRelatedCustomer(fb.FeedbackID) l
		WHERE	fb.StatusID <> 11004
			AND	fbc.IsRelated = 0	
		ORDER BY fb.FeedbackDate DESC
	)
					SELECT	t.FeedbackID
						,	t.CustID
						,	t.UserName
						,	t.TitleID
						,	t.FirstName
						,	t.LastName
						,	t.Phone
						,	t.MobilePhone
						,	t.Fax
						,	t.Email
						,	t.Skype
						,	t.MSN
						,	t.LanguageID
						,	t.CountryID
						,	t.CreatorID
						,	t.CreatorName
						,	t.FeedbackDate
						,	t.ResolutionDate
						,	t.CreateDate
						,	t.SolveDate
						,	t.CommunicationID
						,	t.StationID
						,	t.MainCategoryID
						,	t.SubCategoryID
						,	t.SiteID
						,	t.RoleID
						,	t.ProductID
						,	t.SubProductID
						,	t.BetTypeID
						,	t.ResponseID
						,	t.StatusID						
						,	t.Solution
						,	t.IsReviewed
						,	t.Review
						,	t.ReviewerID
						,	t.ReviewerName
						,	t.IsRelated
						,	t.Subject
						,	t.relatedCustomer
						,	nr.value(N'@Remark',N'nvarchar(max)') AS Description
						,	nr.value(N'@AutoField',N'nvarchar(max)') AS AutoField
	FROM temp t
		OUTER APPLY t.Description.nodes(N'//row') AS A(nr)
		

END;
GO

GRANT EXECUTE ON dbo.Acc_CRM_FeedbackSelTop TO bodbAdminNet;
GO
GRANT VIEW DEFINITION ON dbo.Acc_CRM_FeedbackSelTop TO vnteam;
GO