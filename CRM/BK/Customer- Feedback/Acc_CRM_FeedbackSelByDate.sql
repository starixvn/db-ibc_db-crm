/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet,vnteam" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE	[dbo].[Acc_CRM_FeedbackSelByDate] (
					@CustID			INT
				,	@FromDate		DATETIME
				,	@ToDate			DATETIME
)	
AS
/*
	Created:	Lukas
	Date:		20101023
	Task:		get feedback info
	DB:			DB06.bodb_CRM
	Original:

	Revisions:
		- 20110622@Kevin:	remove paging
		- 20110629@Lukas:	support get multipe related customer
		- 20160308@Billy:	Integrate Sub-Product field - [Redmine: #52998]
		- 20180117@Winnie:	Add Is Related Customer - [Redmine: #88774]
	Param's Explanation:
	
*/
BEGIN		
	SET NOCOUNT ON
		
	SELECT	@FromDate	= DATEADD(d, 0, CONVERT(CHAR(12), @FromDate, 101))
		,	@ToDate		= DATEADD(ms, -2, DATEADD(d, 1, CONVERT(CHAR(12), @ToDate, 101)))

	;WITH temp AS
	(
		SELECT 	fb.FeedbackID
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
			,	fb.msn
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
		FROM		crmFeedbackCustomer fbc WITH(NOLOCK)
		INNER JOIN	crmFeedback fb WITH(NOLOCK)
				ON	fb.FeedbackID = fbc.FeedbackID
		INNER JOIN	crmCustomer ctm WITH(NOLOCK)
				ON	ctm.CustID = fb.CustID
		INNER JOIN	bodb02.dbo.custinfo c WITH(NOLOCK)
				ON	fb.CreatorID = c.custID
		LEFT JOIN	bodb02.dbo.custinfo rv WITH(NOLOCK)
				ON	fb.ReviewerID = rv.custID
		CROSS APPLY	dbo.f_GetRelatedCustomer(fb.FeedbackID) l
		WHERE	fbc.CustID = @CustID 
			AND	fb.FeedbackDate BETWEEN @FromDate AND @ToDate
			AND	fb.StatusID <> 11004
	
	)

	SELECT 
			t.FeedbackID
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
			,	t.msn
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
			,nr.value(N'@Remark',N'nvarchar(max)') AS Description
	FROM temp t
	OUTER APPLY t.Description.nodes(N'//row') AS A(nr)
	ORDER BY t.FeedbackDate DESC
END
GO

GRANT EXECUTE ON [dbo].[Acc_CRM_FeedbackSelByDate] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_FeedbackSelByDate] TO [vnteam]
GO