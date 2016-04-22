SET QUOTED_IDENTIFIER ON; 
GO
SET ANSI_NULLS ON; 
GO

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

	CREATE TABLE	#ResultTable (
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
			SELECT @DeletorID = NULL;

		SELECT	cf.CreateDate, cf.CreatorID, cf.FeedbackID, cf.Subject, cf.MainCategoryID, cf.SubCategoryID, cf.CustID
		INTO	#feedback
		FROM	dbo.crmFeedback AS cf WITH (NOLOCK)
		WHERE	cf.StatusID = 11004
			AND	cf.CreatorID = ISNULL(@CreatorID, cf.CreatorID)
			AND	cf.CreateDate >= @FromDate AND cf.CreateDate <= @ToDate;
			
		INSERT INTO #ResultTable
			(	CreateDate  , CreatorID  , DeletorID, FeedbackID  , Subject  , MainCategoryID  , SubCategoryID  , CustID)
		SELECT	f.CreateDate, f.CreatorID, lf.UserID, f.FeedbackID, f.Subject, f.MainCategoryID, f.SubCategoryID, f.CustID
		FROM		#feedback f WITH (NOLOCK)
		CROSS APPLY	(
			SELECT	TOP 1 *
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
				WHERE	ilf.FeedbackID = f.FeedbackID
					AND	CONVERT(NVARCHAR(MAX), ilf.Doing) <> CONVERT(NVARCHAR(MAX), ilf.OldValues)

				UNION ALL

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
					,	ISNULL(ilf.Doing.value('(/Acc_CRM_CommunicationLogUpd/StatusID)[1]', 'INT'), 0) newStatus
					,	ISNULL(ilf.OldValues.value('(/Acc_CRM_CommunicationLogUpd/StatusID)[1]', 'INT'), 0)	oldStatus
				FROM		crmLogFeedback ilf WITH(NOLOCK)
				INNER JOIN	crmLogAction la WITH(NOLOCK)
				ON		ilf.ActionID = la.ActionID
				WHERE	ilf.FeedbackID = f.FeedbackID
					AND	CONVERT(NVARCHAR(MAX), ilf.Doing) <> CONVERT(NVARCHAR(MAX), ilf.OldValues)
			) iq
			WHERE	iq.newStatus = 11004
				AND	iq.oldStatus <> 11004
				AND	iq.ActionID IN (201, 203)
			ORDER BY iq.LogDate
		) lf;
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
	FROM		#ResultTable rt
	INNER JOIN	crmMainCategory mc WITH (NOLOCK)
			ON	rt.MainCategoryID = mc.MainCategoryID
	INNER JOIN	crmSubCategory sc WITH (NOLOCK)
			ON	rt.MainCategoryID = sc.MainCategoryID
			AND	rt.SubCategoryID = sc.SubCategoryID
	INNER JOIN	bodb02.dbo.Customer creator
			ON	rt.CreatorID = creator.custid
	INNER JOIN	bodb02.dbo.Customer deletor
			ON	rt.DeletorID = deletor.custid
	INNER JOIN	crmCustomer c WITH (NOLOCK)
			ON	rt.CustID = c.CustID
	CROSS APPLY	dbo.f_GetRelatedCustomer(rt.FeedbackID) fgrc
	ORDER BY	rt.CreatorID
			,	rt.CreateDate DESC;

	DROP TABLE #feedback;
	DROP TABLE #ResultTable;

END;
GO


GRANT EXECUTE ON dbo.Acc_CRM_Rpt_DeletedFeedbackStatistics TO bodbAdminNet;
GO
GRANT VIEW DEFINITION ON dbo.Acc_CRM_Rpt_DeletedFeedbackStatistics TO vnteam;
GO