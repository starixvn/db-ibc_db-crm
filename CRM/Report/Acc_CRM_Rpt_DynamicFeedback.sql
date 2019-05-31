/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_CRM_Rpt_DynamicFeedback]
					@FromDate			DATETIME
				,	@ToDate				DATETIME
				,	@ProductID			INT				= NULL
				,	@SubProductID		INT				= NULL
				,	@StatusID			INT				= NULL
				,	@RoleID				INT				= NULL
				,	@MainCategoryID		INT				= NULL
				,	@HandledBy			NVARCHAR(30)	= NULL
				,	@Extension			INT				= NULL
				,	@SiteID				INT				= NULL
				,	@ResponseID			INT				= NULL
				,	@CommunicationID	INT				= NULL
				,	@SubCategoryID		INT				= NULL
				,	@ReviewedBy			NVARCHAR(30)	= NULL
				,	@Subject			NVARCHAR(1000)	= NULL
AS 
/*
	Created:	DOM
	Date:		20140228
	Task:		Dynamic Report
	DB:			DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20160318@Billy:	Integrate Sub-Product Setting - [Redmine: #52998]
		- 20180529@Vicky: change the query to use index on DBACC [RedmineID: #95024]
		
	Param's Explanation:
		
*/

SELECT	@Subject = REPLACE(@Subject, '[', '%');
SELECT	@Subject = REPLACE(@Subject,']','%');

DECLARE	@HandledID		INT
	,	@ReviewedID		INT;

SELECT	@HandledID = CustID 
FROM	DBACC.bodb02.dbo.Customer WITH (NOLOCK)
WHERE	UserName = @HandledBy;

SELECT	@ReviewedID = CustID
FROM	DBACC.bodb02.dbo.Customer WITH (NOLOCK)
WHERE	UserName = @ReviewedBy;


CREATE TABLE	#Feedback (
					FeedbackID		INT 
				);
INSERT INTO #Feedback
SELECT DISTINCT	FeedbackID
FROM	crmFeedback f WITH (NOLOCK)
WHERE	FeedbackDate BETWEEN @FromDate AND @ToDate
	AND	(ISNULL(@ProductID, 0) = 0 OR f.ProductID = @ProductID)
	AND	(ISNULL(@SubProductID, 0) = 0 OR f.SubProductID = @SubProductID)
	AND	(ISNULL(@StatusID, 0) = 0 OR f.StatusID = @StatusID) 
	AND	(ISNULL(@RoleID, 0) = 0 OR f.RoleID = @RoleID) 
	AND	(ISNULL(@MainCategoryID, 0) = 0 OR f.MainCategoryID = @MainCategoryID) 
	AND	(ISNULL(@HandledBy, '') = '' OR f.CreatorID = @HandledID) 
	AND	(ISNULL(@SiteID, 0) = 0 OR f.SiteID = @SiteID) 
	AND	(ISNULL(@ResponseID, 0) = 0 OR f.ResponseID = @ResponseID) 
	AND	(ISNULL(@CommunicationID, 0) = 0 OR f.CommunicationID = @CommunicationID) 
	AND	(ISNULL(@SubCategoryID, 0) = 0 OR f.SubCategoryID = @SubCategoryID) 
	AND	(ISNULL(@ReviewedBy, '') = '' OR f.ReviewerID = @ReviewedID) 
	AND	(ISNULL(@Extension, 0) = 0 OR f.StationID = @Extension ) 
	AND	(ISNULL(@Subject, '') = '' OR f.Subject LIKE '%' + @Subject + '%') 
	AND	f.StatusID <> 11004; 

SELECT	f.FeedbackID
	,	f.FeedbackDate
	,	mc.Name MainCategory
	,	sc.Name SubCategory
	,	CAST(DATEPART(HOUR, ResolutionDate - FeedbackDate) AS VARCHAR)
	+	' : ' + CAST(DATEPART(MINUTE, ResolutionDate - FeedbackDate) AS VARCHAR)
	+	' : ' + CAST(DATEPART(SECOND, ResolutionDate - FeedbackDate) AS VARCHAR) Duration
	,	f.Subject
	,	st.Name Status
	,	c.username HandledBy
	,	rv.username ReviewedBy
	,	cust.UserName
FROM		crmFeedback f WITH (NOLOCK) 
LEFT JOIN	crmMainCategory mc WITH (NOLOCK)
		ON	mc.MainCategoryID = f.MainCategoryID
LEFT JOIN	crmSubCategory sc WITH (NOLOCK)
		ON	sc.MainCategoryID= mc.MainCategoryID
		AND	sc.SubCategoryID = f.SubCategoryID
LEFT JOIN	crmStatus st WITH (NOLOCK)
		ON	st.StatusID = f.StatusID
INNER JOIN	bodb02.dbo.Customer c WITH (NOLOCK)
		ON	c.custid = f.CreatorID
LEFT JOIN	bodb02.dbo.Customer rv WITH (NOLOCK)
		ON	rv.custid = f.ReviewerID
INNER JOIN	crmCustomer cust WITH(NOLOCK)
		ON	cust.CustID = f.CustID
WHERE	f.FeedbackID IN (SELECT feedbackid FROM #Feedback)
ORDER BY f.FeedbackDate DESC, f.FeedbackID DESC;

DROP TABLE #Feedback;

GO
