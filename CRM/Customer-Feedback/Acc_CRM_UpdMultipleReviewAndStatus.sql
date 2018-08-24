/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet,vnteam" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE	[dbo].[Acc_CRM_UpdMultipleReviewAndStatus]
					@ListFeedbackID		VARCHAR(MAX)	
				,	@StatusID			INT
				,	@IsReviewed			BIT	
				,	@UpdateReviewedMode	TINYINT			= 0
				,	@ReviewNote			NVARCHAR(MAX)=NULL				
				,	@ReviewerID			INT
				,	@UserID				INT
				,	@IP					VARCHAR(15)
				,	@ErrCode			INT				= 0		OUTPUT
				,	@ErrMsg				NVARCHAR(4000)	= ''	OUTPUT
AS
/*
	Created:	20180810@Winnie
	Task :		Update Multiple review and Status
	DB:			DBCRM.bodb_CRM
	Original:

	Revisions:
		- 20180810@Winnie:  Create SP - Redmine: #99604
	Param's Explanation:
		- @UpdateReviewedMode: Kind of update review
			0	Do nothing
			1	Update review
			2	remove review
*/
BEGIN
	IF	ISNULL(@ListFeedbackID, '') = ''	
	OR	ISNULL(@StatusID, 0) = 0 

	BEGIN
		SELECT	@ErrCode = 100
			,	@ErrMsg = 'Incorrect Data.';
		RETURN;
	END;



	CREATE TABLE #tempFb(FeedbackID INT PRIMARY KEY)
	DECLARE @FeedbackID INT 
	DECLARE @CustID		INT 
	INSERT INTO #tempFb(FeedbackID)	
	SELECT val
	FROM dbo.f_CRM_strSplit(@ListFeedbackID,',')

	UPDATE c
		SET c.IsReviewed=CASE	WHEN @UpdateReviewedMode = 0 THEN IsReviewed 
								WHEN @UpdateReviewedMode = 1 THEN 1
								WHEN @UpdateReviewedMode = 2 THEN 0
								ELSE IsReviewed END,		
			c.ReviewerID=CASE	WHEN @UpdateReviewedMode = 0 THEN ReviewerID 
								WHEN @UpdateReviewedMode = 1 THEN @ReviewerID
								WHEN @UpdateReviewedMode = 2 THEN NULL
								ELSE ReviewerID END,
			c.StatusID=@StatusID,
			c.Review=	CASE	WHEN @UpdateReviewedMode = 0 THEN Review 
								WHEN @UpdateReviewedMode = 1 THEN @ReviewNote 
								WHEN @UpdateReviewedMode = 2 THEN NULL
								ELSE Review END ,
			c.SolveDate=CASE	WHEN @UpdateReviewedMode = 0 THEN SolveDate 
								WHEN @UpdateReviewedMode = 1 THEN GETDATE() 
								WHEN @UpdateReviewedMode = 2 THEN NULL 
								ELSE SolveDate END
	FROM	crmFeedback c WITH(ROWLOCK)
		INNER JOIN #tempFb t ON c.FeedbackID=t.FeedbackID

	IF	@@ERROR <> 0
	BEGIN
		SELECT	@ErrCode = 102
			,	@ErrMsg = 'Update Multiple review unsuccessfuly.';

		RETURN;
	END;
	
-- Write Log
DECLARE	@LogElement XML;

WHILE EXISTS (SELECT 1 FROM #tempFb)
	BEGIN
		SELECT TOP 1 @FeedbackID=FeedbackID FROM #tempFb	
		SELECT @CustID=Custid FROM crmFeedback WITH(NOLOCK) WHERE FeedbackID=@FeedbackID
																																																																											SELECT	@LogElement =
					'<Acc_CRM_UpdMultipleReviewAndStatus>' + 
						'<FeedbackID>'					+ ISNULL(CONVERT(VARCHAR(5),@FeedbackID),'')					+ '</FeedbackID>' +
						'<IsReviewed>'					+ ISNULL(CONVERT(VARCHAR(5),@IsReviewed),'')					+ '</IsReviewed>' +
						'<StatusID>'					+ ISNULL(CONVERT(VARCHAR(5),@StatusID),'')						+ '</StatusID>' +
						'<ReviewerID>'					+ ISNULL(CONVERT(VARCHAR(5),@ReviewerID),'')					+ '</ReviewerID>' +
						'<ReviewNote>'					+ ISNULL(dbo.f_EncodeXMLValue(@ReviewNote),'')					+ '</ReviewNote>' +						
					'</Acc_CRM_UpdMultipleReviewAndStatus>';
		DELETE FROM #tempFb WHERE FeedbackID=@FeedbackID
		EXECUTE	dbo.WriteLog_UserLog_crmLogFeedback
					@UserID = @UserID
				,	@FeedbackID = @FeedbackID
				,	@CustID = @CustID
				,	@ActionID = 204
				,	@IP = @IP
				,	@Description = NULL
				,	@Solution = NULL
				,	@Review =  @ReviewNote
				,	@NewValues = @LogElement;
	END
END;					

GO
