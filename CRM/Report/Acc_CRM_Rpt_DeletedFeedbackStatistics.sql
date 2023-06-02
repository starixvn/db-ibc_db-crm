/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

USE bodb_CRM
GO

ALTER PROCEDURE [dbo].[Acc_CRM_Rpt_DeletedFeedbackStatistics]
					@CreatorName	VARCHAR(30) = NULL
				,	@DeletorName	VARCHAR(30) = NULL
				,	@FromDate		DATETIME
				,	@ToDate			DATETIME
				,	@Userrole		TINYINT=2
AS

/*
	Created:	20151214@Billy
	Task:		Deleted Feedback Statistics Report [Redmine: #49318]
	Revisions:
	    - 20180529@Vicky: change the query to use index on DBACC [RedmineID: #95024]
		- 20171225@Winnie: Change for support multiple product/categories. [RedmineID: #84714]
	    - 20190506@Winnie:  CN88 Permission RedmineID: #112637      
		- 20190905@Winnie: CRM - Left panel did not show Super, Master, Agent  [RedmineId: #119708] 
        - 20230427@Ned.Le: Database - HA DB061/DB062 (#169643)
        - 20230523@Ned.Le: CRM | Report-> Deleted Feedback Statistic: Unable to show feedback of licensee which deleted by function Multiple Review & Update status (#188634)
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
					,	Username		NVARCHAR(50)
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

		SELECT	cf.CreateDate, cf.CreatorID, cf.FeedbackID, cf.Subject, c.UserName
		INTO	#feedback
		FROM	dbo.crmFeedback AS cf WITH (NOLOCK)
			INNER JOIN crmCustomer c WITH(NOLOCK) ON cf.custID=c.CustID
		WHERE	cf.StatusID IN( 11004,11019)
			AND	cf.CreatorID = ISNULL(@CreatorID, cf.CreatorID)
			AND	cf.CreateDate >= @FromDate AND cf.CreateDate <= @ToDate
			AND ((@Userrole=1 AND c.siteID=33002) OR (@Userrole=2 AND ISNULL(c.siteID,0)<>33002))
			
		INSERT INTO #ResultTable
			(	CreateDate  , CreatorID  , DeletorID, FeedbackID  , Subject  , Username)
		SELECT	f.CreateDate, f.CreatorID, lf.UserID, f.FeedbackID, f.Subject, f.Username
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
			WHERE	iq.newStatus IN( 11004,11019)
				AND	iq.oldStatus NOT IN( 11004,11019)
				AND	iq.ActionID IN (201, 203)
				AND	iq.UserID = ISNULL(@DeletorID, iq.UserID)
			ORDER BY iq.LogDate
		) lf;

        INSERT INTO #ResultTable (CreateDate, CreatorID, DeletorID, FeedbackID, Subject, Username)
        SELECT f.CreateDate, f.CreatorID, l.UserID DeletorID, f.FeedbackID, f.Subject, f.UserName
        FROM #feedback f
             INNER JOIN bodb_CRM.dbo.crmLogFeedback l (NOLOCK) ON f.FeedbackID = l.FeedbackID
        WHERE l.ActionID = 204
              AND ISNULL(l.Doing.value('(/Acc_CRM_UpdMultipleReviewAndStatus/StatusID)[1]', 'INT'), 0) IN (11004,11019);
	END;

	SELECT	rt.CreateDate		CreateDate
		,	creator.username	Handler
		,	deletor.username	Deletor
		,	rt.FeedbackID		FeedbackID
		,	rt.Subject			Subject	
		,	rt.UserName			Customer
		,	fgrc.list			RelatedCustomer
	FROM		#ResultTable rt
	INNER JOIN	bodb02.dbo.Customer creator
			ON	rt.CreatorID = creator.custid
	INNER JOIN	bodb02.dbo.Customer deletor
			ON	rt.DeletorID = deletor.custid	
	CROSS APPLY	dbo.f_GetRelatedCustomer(rt.FeedbackID) fgrc
	ORDER BY	rt.CreatorID
			,	rt.CreateDate DESC;

	
	SELECT fs.FeedbackID,fs.SettingID,fs.SubSettingID,fs.SubSettingIDLevel3,
	CASE	WHEN m.MainCategoryID	IS NOT NULL THEN 'Category' 
			WHEN s.StationID		IS NOT NULL THEN 'Station' 
			WHEN p.SettingID		IS NOT NULL THEN 'Product' 
			WHEN c.SettingID		IS NOT NULL THEN 'Communication' 
			END AS SettingType
	FROM #ResultTable fp
		INNER JOIN crmFeedbackSetting fs WITH(NOLOCK) 
			ON fs.FeedbackID=fp.FeedbackID	
		LEFT JOIN crmMainCategory m 
			ON fs.SettingID=m.MainCategoryID
		LEFT JOIN crmStation s 
			ON fs.SettingID=s.StationID
		LEFT JOIN crmSetting p
			ON fs.SettingID=p.SettingID AND p.SettingName='Product'
		LEFT JOIN crmSetting c
			ON fs.SettingID=c.SettingID AND c.SettingName='Communication'	

    DROP TABLE #feedback;
	DROP TABLE #ResultTable;

END;
GO

