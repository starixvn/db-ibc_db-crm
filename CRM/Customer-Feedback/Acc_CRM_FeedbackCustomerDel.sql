
ALTER PROCEDURE [dbo].[Acc_CRM_FeedbackCustomerDel]
(
	@UserID				INT,
	@FeedbackID			INT,
	@RelatedCustID		INT				= NULL,	
	@IP					VARCHAR(15),
	@ErrCode			INT				= 0 OUTPUT,
	@ErrMsg				NVARCHAR(4000)	= '' OUTPUT	
)
AS
/*
Created: Lukas
Date: 20101023
Task : delete feedback related
DB: DB06.bodb_CRM
Original:

Revisions:
	
Param's Explanation:
	
*/
BEGIN
	SET NOCOUNT ON
	
	DELETE FROM crmFeedbackCustomer WITH(ROWLOCK,UPDLOCK)
	WHERE 
		FeedbackID = @FeedbackID
		AND
		CustID = @RelatedCustID

	-- write log
	DECLARE @LogElement XML

	SELECT @LogElement = 				
					'<Acc_CRM_FeedbackCustomerDel>' + --SP Name						
						'<RelatedCustID>'			+ ISNULL(CONVERT(VARCHAR(10),@RelatedCustID),'')	+ '</RelatedCustID>' +						
					'</Acc_CRM_FeedbackCustomerDel>'
				

	EXEC [dbo].[WriteLog_UserLog_crmLogFeedback]
					@UserID = @UserID, 
					@FeedbackID = @FeedbackID,
					@CustID = @RelatedCustID,  
					@ActionID = 402, 
					@IP = @IP, 
					@Description = '', 
					@Solution = '',
					@Review =  '',
					@Doing = @LogElement
END


GO
GRANT EXECUTE ON [dbo].[Acc_CRM_FeedbackCustomerDel] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_FeedbackCustomerDel] TO [vnteam] 