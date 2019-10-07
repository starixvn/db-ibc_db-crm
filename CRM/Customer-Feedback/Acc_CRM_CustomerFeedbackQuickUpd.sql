/*<info serverAlias="DBCRM-bodb_CRM" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE	dbo.Acc_CRM_CustomerFeedbackQuickUpd (
					@FeedbackID					INT
				,	@UserID						INT
				,	@IP							VARCHAR(50)		= ''
				,	@NoInquiries				SMALLINT		= NULL
				,	@ErrCode					INT				= 0		OUTPUT
				,	@ErrMsg						NVARCHAR(4000)	= ''	OUTPUT					
				)
AS
/*
	Created:	Winnie
	Date:		20190925
	Task :		Update Inquiries
	DB:			DBCRM/bodb_CRM
	Original:

	Revisions:
		- 20190923@Winnie: CRM - Include no. of Inquiries in Feedbacks RedmineID: #120596
	Param's Explanation:		
*/
BEGIN	
	SET NOCOUNT ON;

	DECLARE @NoInquiries_Old				SMALLINT		= NULL,@CustID INT	
	SELECT  @NoInquiries_Old				= Inquiries,@CustID=CustID
	FROM	crmFeedback WITH (NOLOCK)
	WHERE	FeedbackID = @FeedbackID;
	
	UPDATE crmFeedback WITH (ROWLOCK,UPDLOCK)
		SET Inquiries=@NoInquiries
	WHERE	FeedbackID = @FeedbackID

	IF	@@ERROR <> 0
	BEGIN
		SELECT @ErrCode = 101
		SELECT @ErrMsg = 'updated no. of Inquiries unsuccessfuly.';
		RETURN;
	END;

		-- write log
	DECLARE	@OldValues	XML
		,	@NewValues	XML
	
		SELECT	@OldValues = 				
					'<Acc_CRM_CustomerFeedbackQuickUpd>' + 
							'<NoInquiries>'					+ ISNULL(CONVERT(VARCHAR(10),@NoInquiries_Old),'')				+ '</NoInquiries>' + 
							'<FeedbackID>'					+ ISNULL(CONVERT(VARCHAR(10),@FeedbackID),'')					+ '</FeedbackID>' +							
					'</Acc_CRM_CustomerFeedbackQuickUpd>';				
					
				
	SELECT @NewValues = 				
					'<Acc_CRM_CustomerFeedbackQuickUpd>' + 
							'<NoInquiries>'					+ ISNULL(CONVERT(VARCHAR(10),@NoInquiries),'')				+ '</NoInquiries>' + 
							'<FeedbackID>'					+ ISNULL(CONVERT(VARCHAR(10),@FeedbackID),'')					+ '</FeedbackID>' +							
					'</Acc_CRM_CustomerFeedbackQuickUpd>';

	EXECUTE	dbo.WriteLog_UserLog_crmLogFeedback
				@UserID = @UserID
			,	@FeedbackID = @FeedbackID
			,	@CustID = @CustID
			,	@ActionID = 206
			,	@IP = @IP
			,	@Description = NULL
			,	@Solution = NULL
			,	@Review =  NULL
			,	@NewValues = @NewValues
			,	@OldValues = @OldValues;

END;
GO 

GRANT EXECUTE ON dbo.Acc_CRM_CustomerFeedbackQuickUpd TO bodbAdminNet;
GO 
