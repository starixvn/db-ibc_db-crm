ALTER PROCEDURE dbo.Acc_CRM_Rpt_DeletedFeedbackStatistics
					@CreatorName	VARCHAR(30) = NULL
				,	@DeletorName	VARCHAR(30) = NULL
				,	@FromDate		DATETIME
				,	@ToDate			DATETIME
AS
/*
	Created:	20151214@Billy
	Task:		Deleted Feedback Statistics Report [Redmine: #49318]
	Revisions:
	Parameters' Explanation:
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE	@CreatorID		INT
		,	@DeletorID		INT;

	DECLARE	@ResultTable	TABLE (
								CreateDate		DATETIME
							,	CreatorID		INT
							,	DeletorID		INT
							,	FeedbackID		INT
							,	Subject			NVARCHAR(200)
							,	MainCategoryID	INT
							,	SubCategoryID	INT
							,	CustID			INT
							);

	IF	@CreatorName = '' OR @CreatorName IS NULL
		SELECT	@CreatorID = -1;
	ELSE
		SELECT	@CreatorID = c.custid
		FROM	bodb02.dbo.Customer c WITH (NOLOCK)
		WHERE	c.username = @CreatorName;

	IF	@DeletorName = '' OR @DeletorName IS NULL
		SELECT	@DeletorID = -1;
	ELSE
		SELECT	@DeletorID = c.custid
		FROM	bodb02.dbo.Customer c WITH (NOLOCK)
		WHERE	c.username = @DeletorName;
	
	IF	@CreatorID IS NOT NULL AND @DeletorID IS NOT NULL
	BEGIN
		IF @CreatorID = -1
			SELECT @CreatorID = NULL;

		IF @DeletorID = -1
			SELECT @DeletorID = NULL

		;WITH logFeedback AS (
			SELECT	*,
					ROW_NUMBER() OVER (PARTITION BY iq.FeedbackID ORDER BY iq.LogDate DESC) RowNumber
			FROM (
				SELECT	ilf.LogID
					,	ilf.LogDate
					,	ilf.FeedbackID
					,	ilf.CustID
					,	ilf.UserID
					,	ilf.ActionID
					,	ilf.IP
					,	ilf.Description
					,	ilf.Solution
					,	ilf.Review
					,	ISNULL(ilf.Doing.value('(/Acc_CRM_FeedbackUpd/StatusID)[1]', 'INT'), 0) newStatus
					,	ISNULL(ilf.OldValues.value('(/Acc_CRM_FeedbackUpd/StatusID)[1]', 'INT'), 0)	oldStatus
				FROM		crmLogFeedback ilf WITH(NOLOCK)
				INNER JOIN	crmLogAction la WITH(NOLOCK)
				ON		ilf.ActionID = la.ActionID
				WHERE	CONVERT(NVARCHAR(MAX), ilf.Doing) <> CONVERT(NVARCHAR(MAX), ilf.OldValues)
			) iq
			WHERE	iq.newStatus = 11004
				AND	iq.oldStatus <> 11004
				AND	iq.ActionID = 201
		)
		INSERT INTO @ResultTable (
				CreateDate  , CreatorID  , DeletorID, FeedbackID  , Subject  , MainCategoryID  , SubCategoryID  , CustID)
		SELECT	f.CreateDate, f.CreatorID, lf.UserID, f.FeedbackID, f.Subject, f.MainCategoryID, f.SubCategoryID, f.CustID
		FROM		crmFeedback f WITH (NOLOCK)
		INNER JOIN	logFeedback lf WITH (NOLOCK)
		ON		f.FeedbackID = lf.FeedbackID
		WHERE	f.StatusID = 11004
			AND	f.CreatorID = ISNULL(@CreatorID, f.CreatorID)
			AND	lf.UserID = ISNULL(@DeletorID, lf.UserID)
			AND	f.CreateDate BETWEEN @FromDate AND @ToDate
			AND	lf.RowNumber = 1;
	END;

	SELECT	rt.CreateDate		CreateDate
		,	creator.username	Handler
		,	deletor.username	Deletor
		,	rt.FeedbackID		FeedbackID
		,	rt.Subject			Subject
		,	mc.Name				MainCategory
		,	sc.Name				SubCategory
		,	c.UserName			Customer
		,	fgrc.list			RelatedCustomer
	FROM		@ResultTable rt
	INNER JOIN	crmMainCategory mc WITH (NOLOCK)
			ON	rt.MainCategoryID = mc.MainCategoryID
	INNER JOIN	crmSubCategory sc WITH (NOLOCK)
			ON	rt.SubCategoryID = sc.SubCategoryID
	INNER JOIN	bodb02.dbo.Customer creator
			ON	rt.CreatorID = creator.custid
	INNER JOIN	bodb02.dbo.Customer deletor
			ON	rt.DeletorID = deletor.custid
	INNER JOIN	crmCustomer c WITH (NOLOCK)
			ON	rt.CustID = c.CustID
	CROSS APPLY	dbo.f_GetRelatedCustomer(rt.CustID) fgrc
	ORDER BY	rt.CreatorID,
				rt.CreateDate DESC;

END;
GO


GRANT EXECUTE ON dbo.Acc_CRM_Rpt_DeletedFeedbackStatistics TO bodbAdminNet;
GO
GRANT VIEW DEFINITION ON dbo.Acc_CRM_Rpt_DeletedFeedbackStatistics TO vnteam;
GO