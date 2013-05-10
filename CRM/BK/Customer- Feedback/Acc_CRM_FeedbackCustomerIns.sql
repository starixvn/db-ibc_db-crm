ALTER PROCEDURE [dbo].[Acc_CRM_FeedbackCustomerIns_bk]
(
	@UserID				INT,
	@FeedbackID			INT,
	@RelatedCustID		INT				= NULL,	
	@IsRelated			BIT				= 0,
	@IP					VARCHAR(15),
	@ErrCode			INT				= 0 OUTPUT,
	@ErrMsg				NVARCHAR(4000)	= '' OUTPUT	
)
AS
/*
Created: Lukas
Date: 20101023
Task : insert feedback related
DB: DB052.bodb_CRM     
Original:

Revisions:
	- 20120323@Elodie: change DB06 to DB052, 
					   edit @ErrMsg value and don't insert when the feedback related customer already existed.
Param's Explanation:  
	
*/
BEGIN
	SET NOCOUNT ON
	
	IF EXISTS (SELECT 1 FROM crmFeedbackCustomer WITH(NOLOCK) WHERE FeedbackID = @FeedbackID AND CustID = @RelatedCustID)
	BEGIN
		SELECT @ErrCode = 100, 
			   @ErrMsg = 'This feedback related customer already existed.'
		RETURN
	END
	
	INSERT INTO crmFeedbackCustomer(FeedbackID, CustID, IsRelated)
							VALUES(@FeedbackID, @RelatedCustID, @IsRelated)
	-- write log
	DECLARE @LogElement XML

	SELECT @LogElement = 				
					'<Acc_CRM_FeedbackCustomerIns>' + --SP Name						
						'<RelatedCustID>'			+ ISNULL(CONVERT(VARCHAR(10),@RelatedCustID),'')	+ '</RelatedCustID>' +						
						'<IsRelated>'				+ ISNULL(CONVERT(CHAR(1),@IsRelated),'')			+ '</IsRelated>' +
					'</Acc_CRM_FeedbackCustomerIns>'

	EXEC [dbo].[WriteLog_UserLog_crmLogFeedback]
					@UserID = @UserID, 
					@FeedbackID = @FeedbackID,
					@CustID = @RelatedCustID,  
					@ActionID = 400, 
					@IP = @IP, 
					@Description = '', 
					@Solution = '',
					@Review =  '',
					@Doing = @LogElement
END

GO
GRANT EXECUTE ON [dbo].[Acc_CRM_FeedbackCustomerIns_bk] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_CRM_FeedbackCustomerIns_bk] TO [vnteam] 